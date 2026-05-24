#!/usr/bin/env bash
# PreCompact: final quick fold. Run ONE synchronous summarizer pass over the
# tail (everything since the last offset) so the brief is complete the moment
# compaction recovery happens. Synchronous is fine — compaction is already a
# pause, and detaching would race the imminent context swap.
set -uo pipefail
source "$(dirname "$0")/../lib-notebook.sh"
source "$(dirname "$0")/../lib-pi-adapter.sh"
source "$(dirname "$0")/../lib-log.sh"
[ -n "${AGENTS_SUMMARIZER:-}" ] && exit 0

PAYLOAD=$(pi_adapt)
SID=$(nb_json "$PAYLOAD" '.session_id')
CWD=$(nb_json "$PAYLOAD" '.cwd')
TRANSCRIPT=$(nb_json "$PAYLOAD" '.transcript_path')

# Fallback: GSD/pi PreCompact payload carries no transcript_path — derive from cwd.
# Claude Code stores transcripts at ~/.claude/projects/<slug>/<sid>.jsonl
# where <slug> preserves the leading dash from /home → -home-mcrowe-...
if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
    base="${CWD:-$PWD}"
    cc_slug=$(printf '%s' "$base" | sed 's#/#-#g')  # preserves leading -
    pdir="$HOME/.claude/projects/$cc_slug"
    [ -d "$pdir" ] && TRANSCRIPT=$(ls -t "$pdir"/*.jsonl 2>/dev/null | grep -v 'agent-' | head -1)
fi

[ -n "$SID" ] && [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0
DIR=$(nb_session_dir "$SID" "$CWD") || exit 0
mkdir -p "$DIR" 2>/dev/null || true
log_setup "fold-tail"

log_op "FOLD SID=$SID transcript=$TRANSCRIPT"
BIN="$HOME/.agents/bin/summarize-thread.sh"
[ -x "$BIN" ] && "$BIN" --session-dir "$DIR" --transcript "$TRANSCRIPT" >/dev/null 2>&1 || true
log_op "FOLD done"
exit 0
