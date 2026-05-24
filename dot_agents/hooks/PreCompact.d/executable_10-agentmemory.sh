#!/usr/bin/env bash
source "$HOME/.agents/hooks/lib-wrapper.sh"
am_log_setup "pre-compact"
stdin_data=$(cat)
am_info "COMPACT FIRING — saving memory snapshot"
am_debug "payload: $stdin_data"
am_run_node "/home/mcrowe/Programming/AI/agentmemory/plugin/scripts/pre-compact.mjs" "$stdin_data"
