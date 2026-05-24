#!/usr/bin/env bash
# SessionStart: seed the pi session ID so subsequent hooks can find it.
# Also creates the notebook session dir early so intent capture always has
# somewhere to write.
set -uo pipefail
source "$(dirname "$0")/../lib-notebook.sh"
source "$(dirname "$0")/../lib-pi-adapter.sh"

# Generate + stash a session ID for this project
SID=$(pi_session_start)
CWD="$PWD"
DIR=$(nb_session_dir "$SID" "$CWD") || exit 0
mkdir -p "$DIR" 2>/dev/null || true

# Initialize the turns counter
[ -f "$DIR/.turns" ] || echo 0 > "$DIR/.turns"
exit 0
