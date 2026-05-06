#!/usr/bin/env bash
# {{COMMAND_NAME}} — {{ONE_LINE_PURPOSE}}
# {{OPTIONAL_USAGE_BLOCK}}

set -euo pipefail

# ── helpers ───────────────────────────────────────────────────────────────────
log()  { echo "[$(date -Iseconds)] $*"; }
fail() { echo "ERROR: $*" >&2; exit 1; }

usage() {
  cat <<'EOF'
{{COMMAND_NAME}} — {{ONE_LINE_PURPOSE}}

Usage:
  {{COMMAND_NAME}} [options]

Options:
  -h    show this help
EOF
}

# ── arg parsing ───────────────────────────────────────────────────────────────
while getopts "h" opt; do
  case "$opt" in
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done
shift $((OPTIND - 1))

# ── dependency checks ─────────────────────────────────────────────────────────
# command -v jq >/dev/null || fail "jq required (apt install jq / brew install jq)"

# ── main ──────────────────────────────────────────────────────────────────────
{{MAIN_LOGIC}}
