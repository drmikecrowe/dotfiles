#!/usr/bin/env bash
# Serena auto-activate for Claude Code sessions.
# Activates the Serena project matching the current working directory.
# Only runs when .serena/project.yml exists in the repo root.

set -euo pipefail

# Find repo root (worktree-aware)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Only activate if Serena config exists
[ -f "$REPO_ROOT/.serena/project.yml" ] || exit 0

# Check Serena is reachable (must POST with Accept header — GET returns 406)
curl -sf --connect-timeout 2 -X POST http://127.0.0.1:8765/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"health-check","version":"1.0"}},"id":1}' > /dev/null 2>&1 || {
  echo "Serena not running — skipping project activation"
  exit 0
}

# MCP Streamable HTTP: initialize → get session ID → call activate_project
INIT_RESPONSE=$(curl -sD /tmp/serena-headers.$$ \
  -X POST http://127.0.0.1:8765/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"claude-code-hook","version":"1.0"}},"id":1}' \
  2>/dev/null) || exit 0

SESSION_ID=$(grep -i "mcp-session-id" /tmp/serena-headers.$$ 2>/dev/null | sed 's/[^:]*: //' | tr -d '\r\n')
rm -f /tmp/serena-headers.$$

[ -z "$SESSION_ID" ] && exit 0

# Send initialized notification
curl -sf -X POST http://127.0.0.1:8765/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' > /dev/null 2>&1 || true

# Activate the project at repo root path
RESULT=$(curl -sf -X POST http://127.0.0.1:8765/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SESSION_ID" \
  -d "{\"jsonrpc\":\"2.0\",\"method\":\"tools/call\",\"params\":{\"name\":\"activate_project\",\"arguments\":{\"project\":\"$REPO_ROOT\"}},\"id\":2}" \
  2>/dev/null) || true

# Parse SSE data line if present, otherwise raw JSON
ACTIVATED=$(echo "$RESULT" | sed -n 's/^data: //p' | head -1)
if [ -n "$ACTIVATED" ]; then
  PROJECT_NAME=$(echo "$ACTIVATED" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',{}).get('content',[{}])[0].get('text','unknown'))" 2>/dev/null || echo "unknown")
  echo "Serena activated: $PROJECT_NAME"
else
  echo "Serena activation sent for: $REPO_ROOT"
fi
