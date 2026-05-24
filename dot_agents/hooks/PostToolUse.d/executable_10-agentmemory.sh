#!/usr/bin/env bash
source "$HOME/.agents/hooks/lib-wrapper.sh"
am_log_setup "post-tool-use"
stdin_data=$(cat)
am_debug "tool=${CLAUDE_TOOL_NAME:-unknown}"
am_run_node "/home/mcrowe/Programming/AI/agentmemory/plugin/scripts/post-tool-use.mjs" "$stdin_data"
