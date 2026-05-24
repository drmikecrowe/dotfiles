#!/usr/bin/env bash
# ~/.agents/hooks/lib-log.sh — shared hook logging library
#
# Usage in hook scripts:
#   source "$(dirname "$0")/lib-log.sh"
#   log_setup "hook-name"    # once, after stdin read; before real work
#   log_op "decision msg"    # at strategic decision points
#
# LOG_FULL: all stdout+stderr tee'd here — Claude still gets them unchanged
# LOG_OPS:  strategic op messages only; quick human-readable decision trail
#
# Safe dir: git-root path with / → - (-home-mcrowe-Programming-myproject)
#           Matches Claude Code project log dir format (leading / → leading -)
#           Falls back to session-$PPID when not in a git repo.

_log_safe_dir() {
    local git_root
    git_root=$(git rev-parse --show-toplevel 2>/dev/null) || git_root=""
    if [[ -n "$git_root" ]]; then
        printf '%s' "$git_root" | sed 's|/|-|g'
    else
        # No git repo: slug off cwd, NOT $PPID. The dispatcher and its child
        # handlers run under different PPIDs, so a session-$PPID fallback
        # scattered one event's logs across two throwaway dirs. cwd is stable
        # (hook child cwd == project dir), so every fire from the same project
        # now shares one findable dir. Matches Claude Code's leading-/ → - slug.
        printf '%s' "$PWD" | sed 's|/|-|g'
    fi
}

log_setup() {
    export HOOK_NAME="${1:-unknown}"
    local safe_dir
    safe_dir=$(_log_safe_dir)

    export LOG_DIR="$HOME/.agents/logs/$safe_dir"
    export LOG_FULL="$LOG_DIR/full.log"
    export LOG_OPS="$LOG_DIR/ops.log"

    mkdir -p "$LOG_DIR" 2>/dev/null || true

    # Write session boundary directly to file BEFORE tee redirect —
    # prevents the boundary header from appearing in Claude's tool output.
    printf '\n━━━ %s [%s] PPID=%s ━━━\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$HOOK_NAME" "$PPID" \
        >> "$LOG_FULL" 2>/dev/null || true

    # Save original fds, then tee both stdout and stderr through LOG_FULL.
    # tee passes everything to the original fds unchanged, so Claude still
    # receives stdout/stderr exactly as before.
    exec 3>&1 4>&2
    exec 1> >(tee -a "$LOG_FULL" >&3) 2> >(tee -a "$LOG_FULL" >&4)

    trap '_log_on_exit' EXIT
    log_op "START"
}

_log_on_exit() {
    local code=$?
    log_op "END (exit=$code)"
    # Restore original fds — sends EOF to tee processes so they flush before exit
    exec 1>&3 2>&4 3>&- 4>&- 2>/dev/null || true
}

log_op() {
    local msg="$*"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    local line="[$ts] [$HOOK_NAME] $msg"
    # Ops log: strategic decisions only
    printf '%s\n' "$line" >> "${LOG_OPS:-/tmp/agents-ops.log}" 2>/dev/null || true
    # Full log: direct write (bypasses tee — avoids double-logging via stdout)
    printf '  OP: %s\n' "$line" >> "${LOG_FULL:-/tmp/agents-full.log}" 2>/dev/null || true
}
