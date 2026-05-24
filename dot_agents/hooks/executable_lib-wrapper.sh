#!/usr/bin/env bash
# ~/.agents/hooks/lib-wrapper.sh
# agentmemory-specific hook plumbing.
# Delegates logging to ~/.agents/hooks/lib-log.sh (generic).
#
# Debug mode: AGENT_HOOK_DEBUG=1 enables verbose payload logging.

# Load optional local .env from agentmemory dir (AGENT_HOOK_DEBUG, etc.)
[[ -f "$HOME/.agents/hooks/agentmemory/.env" ]] && source "$HOME/.agents/hooks/agentmemory/.env"

AGENT_HOOK_DEBUG="${AGENT_HOOK_DEBUG:-0}"

# Use generic logging lib — sets LOG_DIR, LOG_FULL, LOG_OPS, log_op()
source "$HOME/.agents/hooks/lib-log.sh"

# Aliases so existing scripts keep working unchanged
am_log_setup() { log_setup "$1"; }
am_info()       { log_op "INFO  $*"; }
am_debug()      { [[ "$AGENT_HOOK_DEBUG" == "1" ]] || return 0; log_op "DEBUG $*"; }

am_run_node() {
    local script="$1"
    local stdin_data="$2"

    log_op "START node $script"
    am_debug "STDIN payload: $stdin_data"

    local node_out node_rc
    node_out=$(printf '%s' "$stdin_data" | node "$script" 2>&1)
    node_rc=$?

    am_debug "node exit=$node_rc output=$node_out"
    log_op "END exit=$node_rc"

    if [[ $node_rc -ne 0 ]]; then
        printf '[agentmemory/%s] node exited %s: %s\n' "$HOOK_NAME" "$node_rc" "$node_out" >&2
    fi

    return $node_rc
}
