#!/usr/bin/env bash
source "$HOME/.agents/hooks/lib-wrapper.sh"
am_log_setup "prompt-submit"
stdin_data=$(cat)
am_run_node "/home/mcrowe/Programming/AI/agentmemory/plugin/scripts/prompt-submit.mjs" "$stdin_data"
