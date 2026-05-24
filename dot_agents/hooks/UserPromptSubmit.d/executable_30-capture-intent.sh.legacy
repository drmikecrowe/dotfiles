#!/usr/bin/env bash
# UserPromptSubmit: capture the user's prompt VERBATIM into the notebook.
# No LLM. The clean human voice — preserved exactly, code pastes trimmed.
set -uo pipefail
source "$(dirname "$0")/../lib-notebook.sh"
source "$(dirname "$0")/../lib-pi-adapter.sh"
source "$(dirname "$0")/../lib-log.sh"
[ -n "${AGENTS_SUMMARIZER:-}" ] && exit 0

PAYLOAD=$(pi_adapt)
PROMPT=$(nb_json "$PAYLOAD" '.prompt')
[ -n "$PROMPT" ] || exit 0

# Drop injected automation prompts — keep human-authored instructions only.
case "$PROMPT" in
    '[system notification'*) exit 0 ;;
    '<command-'*)            exit 0 ;;
esac
printf '%s' "$PROMPT" | grep -q '\[GSD Context Metadata\]' && exit 0
printf '%s' "$PROMPT" | grep -q 'Respond only to the final user message below' && exit 0

SID=$(nb_json "$PAYLOAD" '.session_id')
CWD=$(nb_json "$PAYLOAD" '.cwd')
[ -n "$SID" ] || exit 0
DIR=$(nb_session_dir "$SID" "$CWD") || exit 0
mkdir -p "$DIR" 2>/dev/null || true
log_setup "capture-intent"

TRIMMED=$(nb_trim "$PROMPT" 1500)
{
    printf '\n### %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s\n' "$TRIMMED"
} >> "$DIR/intent.md"
log_op "CAPTURED SID=$SID len=${#PROMPT}"
exit 0
