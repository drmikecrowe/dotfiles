#!/usr/bin/env bash
# read-captures.sh — Summarize probe captures
#
# Usage:
#   read-captures.sh              — show all captures
#   read-captures.sh gsd-pi       — filter by runtime
#   read-captures.sh --detail     — show full payloads
#   read-captures.sh --clean      — delete all captures

set -euo pipefail

CAPTURE_DIR="$HOME/.agents/hooks/probes/captures"
INDEX="$CAPTURE_DIR/index.jsonl"

if [ ! -f "$INDEX" ]; then
  echo "No captures found. Wire probes and trigger events first."
  exit 0
fi

case "${1:-}" in
  --clean)
    rm -rf "$CAPTURE_DIR"
    mkdir -p "$CAPTURE_DIR"
    echo "Captures cleaned."
    exit 0
    ;;
  --detail)
    FILTER="${2:-}"
    for f in "$CAPTURE_DIR"/*.json; do
      [ -f "$f" ] || continue
      if [ -n "$FILTER" ] && ! basename "$f" | grep -qi "$FILTER"; then
        continue
      fi
      echo "════════════════════════════════════════"
      python3 -c "
import json
with open('$f') as fh:
    d = json.load(fh)
print(f'Runtime: {d[\"runtime\"]}')
print(f'Event:   {d[\"event\"]}')
print(f'Time:    {d[\"timestamp\"]}')
print(f'CWD:     {d[\"cwd\"]}')
print(f'PID:     {d[\"pid\"]} (PPID: {d[\"ppid\"]})')
print()
print('--- stdin payload ---')
if d.get('stdin_parsed'):
    print(json.dumps(d['stdin_parsed'], indent=2))
else:
    print(d.get('stdin_raw', '(empty)'))
print()
print('--- env vars (runtime-specific) ---')
for k, v in sorted(d.get('env_vars', {}).items()):
    if any(k.upper().startswith(p) for p in ['GSD_', 'PI_', 'CLAUDE', 'GEMINI', 'CURSOR', 'CLINE', 'CODEX', 'AOE_']):
        print(f'  {k}={v}')
" "$(basename "$f")"
    done
    ;;
  *)
    FILTER="${1:-}"
    python3 -c "
import json, sys

with open('$INDEX') as f:
    lines = f.readlines()

if '$FILTER':
    lines = [l for l in lines if '$FILTER'.lower() in l.lower()]

print(f'Total captures: {len(lines)}')
print()
print(f'{\"Runtime\":<14} {\"Event\":<18} {\"Stdin Keys\":<40} File')
print('─' * 100)

for line in lines:
    d = json.loads(line.strip())
    keys = d.get('stdin_keys') or []
    keys_str = ', '.join(str(k) for k in keys) if keys else '(empty)'
    print(f'{d[\"runtime\"]:<14} {d[\"event\"]:<18} {keys_str:<40} {d[\"file\"]}')
"
    ;;
esac
