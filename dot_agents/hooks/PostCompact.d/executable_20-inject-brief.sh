#!/usr/bin/env bash
# PostCompact: inject the assembled recovery brief right after compaction.
# In Claude Code, recovery also surfaces as SessionStart(source=compact); both
# read the same brief and dedupe via nb_emit_brief's mtime marker, so whichever
# the runtime fires (or both) yields a single injection.
set -uo pipefail
source "$(dirname "$0")/../lib-notebook.sh"
source "$(dirname "$0")/../lib-pi-adapter.sh"
source "$(dirname "$0")/../lib-log.sh"
[ -n "${AGENTS_SUMMARIZER:-}" ] && exit 0

PAYLOAD=$(pi_adapt)
SID=$(nb_json "$PAYLOAD" '.session_id')
CWD=$(nb_json "$PAYLOAD" '.cwd')
[ -n "$SID" ] || exit 0
DIR=$(nb_session_dir "$SID" "$CWD") || exit 0
log_setup "inject-brief"
log_op "EMIT SID=$SID dir=$DIR"
nb_emit_brief "$DIR"
exit 0
