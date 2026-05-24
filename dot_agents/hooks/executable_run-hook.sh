#!/usr/bin/env bash
# ~/.agents/hooks/run-hook.sh — universal hook dispatcher
#
# Usage:
#   run-hook.sh <HookName>
#
# Reads stdin (the hook payload), logs it, then runs every *.sh in
# ~/.agents/hooks/<HookName>.d/ in sorted order, passing the payload via stdin.
#
# Logging:
#   ~/.agents/logs/<project-slug>/hooks.log  — all events + output
#   AGENT_HOOK_DEBUG=1  — enable verbose payload logging
#
# Both Claude Code and GSD point their hook entries at this script with
# the event name as the sole argument.

set -euo pipefail

# Recursion guard: the notebook summarizer spawns `claude -p`, which fires its
# own hooks. AGENTS_SUMMARIZER=1 in that child's env makes the entire dispatch
# no-op here, preventing a fork bomb. Drain stdin so the caller never EPIPEs.
if [[ -n "${AGENTS_SUMMARIZER:-}" ]]; then
    cat >/dev/null 2>&1 || true
    exit 0
fi

HOOK_NAME="${1:-unknown}"
HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCH_DIR="$HOOKS_DIR/${HOOK_NAME}.d"

# Context events may inject text into the LLM. A .d/ script opts in by printing
# a sentinel-delimited block (NB_CTX_BEGIN/END); for these events only, that
# block is forwarded to real stdout. All other script output stays swallowed
# (logged), so unrelated handlers (agentmemory, etc.) never leak into context.
NB_CTX_BEGIN='<<<NB_CTX_BEGIN>>>'
NB_CTX_END='<<<NB_CTX_END>>>'
case " SessionStart UserPromptSubmit PostCompact PreCompact " in
    *" $HOOK_NAME "*) IS_CONTEXT_EVENT=1 ;;
    *)               IS_CONTEXT_EVENT=0 ;;
esac
FORWARD=""

# ── Logging setup ────────────────────────────────────────────────────────────

# Share _log_safe_dir with the handler lib so the dispatcher (hooks.log) and the
# handlers (full.log/ops.log via lib-log.sh) resolve the SAME log dir — one fire,
# one dir. Sourcing only DEFINES functions; log_setup (the tee/exec redirect) is
# never called here, so the dispatcher's context-forwarding stdout is untouched.
source "$HOOKS_DIR/lib-log.sh"

SAFE_DIR=$(_log_safe_dir)
LOG_DIR="$HOME/.agents/logs/$SAFE_DIR"
LOG_FILE="$LOG_DIR/hooks.log"
mkdir -p "$LOG_DIR"

log_info() {
    printf '[%s] [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$HOOK_NAME" "$*" >> "$LOG_FILE"
}

log_debug() {
    [[ "${AGENT_HOOK_DEBUG:-0}" == "1" ]] || return 0
    printf '[%s] [%s] DEBUG %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$HOOK_NAME" "$*" >> "$LOG_FILE"
}

# ── Read stdin payload ────────────────────────────────────────────────────────

PAYLOAD=$(cat)
log_info "DISPATCH start (PPID=$PPID)"
log_debug "payload: $PAYLOAD"

# ── Run handlers ─────────────────────────────────────────────────────────────

if [[ ! -d "$DISPATCH_DIR" ]]; then
    log_info "no dispatch dir at $DISPATCH_DIR — nothing to run"
    exit 0
fi

# Collect scripts sorted by name; skip non-executables
mapfile -t SCRIPTS < <(find "$DISPATCH_DIR" -maxdepth 1 -name '*.sh' -perm /111 | sort)

if [[ ${#SCRIPTS[@]} -eq 0 ]]; then
    log_debug "no executable *.sh in $DISPATCH_DIR"
    exit 0
fi

EXIT_CODE=0
for SCRIPT in "${SCRIPTS[@]}"; do
    SCRIPT_NAME="$(basename "$SCRIPT")"
    log_info "  → $SCRIPT_NAME"

    # Pass payload via stdin; capture combined output for logging.
    if SCRIPT_OUT=$(echo "$PAYLOAD" | AGENT_HOOK_DEBUG="${AGENT_HOOK_DEBUG:-0}" bash "$SCRIPT" 2>&1); then
        log_debug "  output: $SCRIPT_OUT"
        log_info "  ✓ $SCRIPT_NAME"
    else
        rc=$?
        log_info "  ✗ $SCRIPT_NAME exited $rc"
        log_debug "  output: $SCRIPT_OUT"
        # Track highest exit code (2 = blocking veto takes priority)
        [[ "$rc" -gt "$EXIT_CODE" ]] && EXIT_CODE=$rc
        # Forward output to real stderr so Claude Code shows the message
        [[ -n "$SCRIPT_OUT" ]] && printf '%s\n' "$SCRIPT_OUT" >&2
    fi

    # For context events, forward only an opt-in sentinel block to real stdout.
    if [[ "$IS_CONTEXT_EVENT" == "1" ]]; then
        block=$(printf '%s' "$SCRIPT_OUT" | sed -n "/$NB_CTX_BEGIN/,/$NB_CTX_END/p" | sed "/$NB_CTX_BEGIN/d;/$NB_CTX_END/d")
        if [[ -n "$block" ]]; then
            FORWARD+="$block"$'\n'
        fi
    fi
done

# Emit accumulated context (SessionStart/UserPromptSubmit add stdout to context).
if [[ "$IS_CONTEXT_EVENT" == "1" && -n "$FORWARD" ]]; then
    printf '%s' "$FORWARD"
fi

log_info "DISPATCH end (exit=$EXIT_CODE)"
exit $EXIT_CODE
