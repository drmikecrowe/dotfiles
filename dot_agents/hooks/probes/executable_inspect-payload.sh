#!/usr/bin/env bash
# inspect-payload.sh — Universal hook payload probe
# Captures stdin payload, env vars, and runtime context for cross-runtime mapping.
# Outputs nothing to stdout (safe for strict-stdout runtimes like Gemini).
#
# Usage:
#   1. Wire this script into settings.json for each event you want to probe.
#   2. Trigger the event (tool call, compact, session start, etc.)
#   3. Check ~/.agents/hooks/probes/captures/ for JSON capture files.
#   4. After probing, remove the hook entries.

set -euo pipefail

PROBE_DIR="$HOME/.agents/hooks/probes/captures"
mkdir -p "$PROBE_DIR"

# Read stdin (hook payload)
STDIN_PAYLOAD=""
if ! STDIN_PAYLOAD=$(cat 2>/dev/null); then
  STDIN_PAYLOAD=""
fi

# Determine runtime from env vars (order matters — most specific first)
RUNTIME="unknown"
if [ -n "${GSD_HOOK_EVENT:-}" ]; then
  # GSD sets this explicitly via spawn env — highest priority
  RUNTIME="gsd-pi"
elif [ -n "${GEMINI_PROJECT_DIR:-}" ]; then
  RUNTIME="gemini"
elif [ -n "${CLAUDE_PROJECT_DIR:-}" ] || [ -n "${CLAUDE_AGENT_SDK_VERSION:-}" ]; then
  # Claude Code sets CLAUDE_PROJECT_DIR; also detect via SDK version
  RUNTIME="claude-code"
elif [ -n "${AOE_INSTANCE_ID:-}" ]; then
  # AOE runs inside Claude Code sessions — lowest priority
  RUNTIME="aoe"
fi

# Derive event name from multiple possible sources
EVENT_NAME="${GSD_HOOK_EVENT:-}"
if [ -z "$EVENT_NAME" ]; then
  # Try to extract from stdin payload
  EVENT_NAME=$(printf '%s' "$STDIN_PAYLOAD" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('hook_event_name', d.get('hookEventName', d.get('event', ''))))
except: pass
" 2>/dev/null || true)
fi

# Timestamp for filename
TS=$(date '+%Y%m%d-%H%M%S-%N')

# Build capture object
CAPTURE=$(python3 -c "
import json, os, sys

stdin_payload = sys.stdin.read().strip() if not sys.stdin.isatty() else ''

# Parse stdin if JSON
stdin_parsed = None
if stdin_payload:
    try:
        stdin_parsed = json.loads(stdin_payload)
    except:
        stdin_parsed = None

# Collect relevant env vars (agent/hook related)
env_vars = {}
for key, val in sorted(os.environ.items()):
    k_upper = key.upper()
    if any(k_upper.startswith(p) for p in [
        'CLAUDE', 'GEMINI', 'GSD_', 'PI_', 'AOE_', 'CURSOR', 'CLINE',
        'CODEX', 'ANTHROPIC', 'NODE', 'HOME', 'SHELL', 'PATH'
    ]):
        # Truncate long values (paths etc) but keep enough for identification
        if len(val) > 200:
            env_vars[key] = val[:200] + '...[truncated]'
        else:
            env_vars[key] = val

result = {
    'runtime': os.environ.get('RUNTIME_DETECT', '$RUNTIME'),
    'event': '$EVENT_NAME',
    'timestamp': '$TS',
    'stdin_raw': stdin_payload[:5000] if stdin_payload else '',
    'stdin_parsed_keys': list(stdin_parsed.keys()) if isinstance(stdin_parsed, dict) else None,
    'stdin_parsed': stdin_parsed,
    'env_vars': env_vars,
    'cwd': os.getcwd(),
    'pid': os.getpid(),
    'ppid': os.getppid(),
}

print(json.dumps(result, indent=2, default=str))
" <<< "$STDIN_PAYLOAD" 2>/dev/null)

# Write capture file
EVENT_SAFE=$(printf '%s' "${EVENT_NAME:-unknown}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')
CAPTURE_FILE="${PROBE_DIR}/${TS}_${RUNTIME}_${EVENT_SAFE}.json"

printf '%s\n' "$CAPTURE" > "$CAPTURE_FILE"

# Also append a one-line summary to the index
INDEX_LINE=$(printf '{"ts":"%s","runtime":"%s","event":"%s","file":"%s","stdin_keys":%s}' \
  "$TS" "$RUNTIME" "${EVENT_NAME:-unknown}" \
  "$(basename "$CAPTURE_FILE")" \
  "$(printf '%s' "$STDIN_PAYLOAD" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(json.dumps(list(d.keys())))
except:
    print('null')
" 2>/dev/null || echo 'null')")

printf '%s\n' "$INDEX_LINE" >> "${PROBE_DIR}/index.jsonl"

# Exit clean — no stdout output
exit 0
