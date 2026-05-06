#!/usr/bin/env bash
# Generic agent startup — fires on SessionStart and PostCompact.
# Loads global + project AGENTS.md directives back into context.
# Projects extend by providing .pi/hooks/agent-startup-local.sh

GLOBAL_AGENTS="$HOME/AGENTS.md"
PROJECT_AGENTS="./.agents/AGENTS.md"
PROJECT_LOCAL="./.agents/hooks/agent-startup-local.sh"

global_content=""
if [ -f "$GLOBAL_AGENTS" ]; then
    global_content="$(cat "$GLOBAL_AGENTS")"
fi

project_content=""
if [ -f "$PROJECT_AGENTS" ]; then
    project_content="$(cat "$PROJECT_AGENTS")"
fi

local_content=""
if [ -f "$PROJECT_LOCAL" ]; then
    # shellcheck disable=SC1090
    local_content="$(bash "$PROJECT_LOCAL" 2>/dev/null)"
fi

context="== AGENT DIRECTIVES — RELOAD AND APPLY ==
The following directives were just (re)loaded from ~/AGENTS.md and ./.agents/AGENTS.md.
Treat them as authoritative for the rest of this session. They override any contradictory
default behavior. If you previously drifted from these rules (e.g. omitted rtk prefix,
used grep/find instead of rg/fd, skipped Serena for code reads, took outward-facing
actions without explicit confirmation), correct course now.

== ~/AGENTS.md ==
${global_content}

== .agents/AGENTS.md ==
${project_content:-"(not found)"}"

if [ -n "$local_content" ]; then
    context="${context}

== project local startup ==
${local_content}"
fi

echo "- Caveman mode: full — apply to all prose immediately"

{
    echo "agent-startup: HOOK_EVENT_NAME=${HOOK_EVENT_NAME:-SessionStart}"
    echo "agent-startup: global=${GLOBAL_AGENTS} $([ -f "$GLOBAL_AGENTS" ] && echo '(loaded)' || echo '(missing)')"
    echo "agent-startup: project=${PROJECT_AGENTS} $([ -f "$PROJECT_AGENTS" ] && echo '(loaded)' || echo '(missing)')"
    echo "agent-startup: local=${PROJECT_LOCAL} $([ -f "$PROJECT_LOCAL" ] && echo '(loaded)' || echo '(missing)')"
} >&2

printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}' \
    "${HOOK_EVENT_NAME:-SessionStart}" \
    "$(printf '%s' "$context" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n')"
