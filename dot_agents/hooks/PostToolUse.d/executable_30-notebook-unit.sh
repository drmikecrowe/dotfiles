#!/usr/bin/env bash
# PostToolUse: auto-mode unit boundary. When a GSD task/slice completion tool
# fires, a unit of work just closed cleanly — spawn a detached summarizer.
# (The parent auto-mode loop never ends a turn, so Stop won't fire per unit;
# this is the auto-mode-specific trigger feeding the same notebook.)
set -uo pipefail
source "$(dirname "$0")/../lib-notebook.sh"
source "$(dirname "$0")/../lib-pi-adapter.sh"
[ -n "${AGENTS_SUMMARIZER:-}" ] && exit 0

PAYLOAD=$(pi_adapt)
TOOL=$(nb_json "$PAYLOAD" '.tool_name')
printf '%s' "$TOOL" | grep -Eq 'gsd_(task|slice)_complete|gsd_complete_(task|slice)' || exit 0

SID=$(nb_json "$PAYLOAD" '.session_id')
CWD=$(nb_json "$PAYLOAD" '.cwd')
TRANSCRIPT=$(nb_json "$PAYLOAD" '.transcript_path')
[ -n "$SID" ] || exit 0
DIR=$(nb_session_dir "$SID" "$CWD") || exit 0
mkdir -p "$DIR" 2>/dev/null || true

# Unit boundary supersedes turn cadence — reset the interactive counter.
echo 0 > "$DIR/.turns" 2>/dev/null || true
nb_spawn_summarizer "$DIR" "$TRANSCRIPT"
exit 0
