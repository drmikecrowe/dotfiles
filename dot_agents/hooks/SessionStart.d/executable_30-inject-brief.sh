#!/usr/bin/env bash
# SessionStart: inject the assembled recovery brief. Fires on startup, resume,
# clear, and (in Claude Code) post-compaction (source=compact). Emits nothing
# when this session has no captured notebook content (e.g. a fresh startup).
# The sentinel-wrapped block is forwarded to context by run-hook.sh.
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
