#!/usr/bin/env bash
source "$HOME/.agents/hooks/lib-wrapper.sh"
am_log_setup "pre-tool-use"
stdin_data=$(cat)
am_debug "tool=${CLAUDE_TOOL_NAME:-unknown}"
am_run_node "/home/mcrowe/Programming/AI/agentmemory/plugin/scripts/pre-tool-use.mjs" "$stdin_data"
