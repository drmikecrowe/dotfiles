#!/usr/bin/env bash
source "$HOME/.agents/hooks/lib-wrapper.sh"
am_log_setup "session-start"
stdin_data=$(cat)
am_debug "trigger=${CLAUDE_HOOK_TRIGGER:-unknown} cwd=${PWD}"
am_run_node "/home/mcrowe/Programming/AI/agentmemory/plugin/scripts/session-start.mjs" "$stdin_data"
