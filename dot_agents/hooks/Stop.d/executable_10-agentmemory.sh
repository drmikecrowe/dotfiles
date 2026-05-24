#!/usr/bin/env bash
source "$HOME/.agents/hooks/lib-wrapper.sh"
am_log_setup "stop"
stdin_data=$(cat)
am_info "SESSION STOP — saving session memory"
am_run_node "/home/mcrowe/Programming/AI/agentmemory/plugin/scripts/stop.mjs" "$stdin_data"
