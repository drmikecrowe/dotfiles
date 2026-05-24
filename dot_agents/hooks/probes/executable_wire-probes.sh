#!/usr/bin/env bash
# wire-probes.sh — Inject inspect-payload probes into a runtime's settings.json
#
# Usage:
#   wire-probes.sh install [gsd|claude|gemini]  — add probe hooks
#   wire-probes.sh remove [gsd|claude|gemini]    — remove probe hooks
#
# Probes are added BEFORE existing hooks so they fire first and don't interfere.
# Each probe entry includes a "PROBE_MARKER" comment for clean removal.

set -euo pipefail

RUNTIME="${2:-gsd}"
ACTION="${1:-install}"

PROBE_CMD="$HOME/.agents/hooks/probes/inspect-payload.sh"

# Determine settings file and event names based on runtime
case "$RUNTIME" in
  gsd)
    SETTINGS_FILE="$HOME/.gsd/agent/settings.json"
    EVENTS=("SessionStart" "PreToolUse" "PostToolUse" "PreCompact" "PostCompact" "Stop")
    TIMEOUT=10000  # ms
    ;;
  claude)
    SETTINGS_FILE="$HOME/.claude/settings.json"
    EVENTS=("SessionStart" "PreToolUse" "PostToolUse" "PreCompact" "PostCompact" "Stop")
    TIMEOUT=10  # seconds
    ;;
  gemini)
    SETTINGS_FILE="$HOME/.gemini/settings.json"
    EVENTS=("SessionStart" "BeforeTool" "AfterTool" "PreCompress" "Stop")
    TIMEOUT=10000  # ms
    ;;
  *)
    echo "Unknown runtime: $RUNTIME (use gsd, claude, or gemini)"
    exit 1
    ;;
esac

if [ ! -f "$SETTINGS_FILE" ]; then
  echo "Settings file not found: $SETTINGS_FILE"
  exit 1
fi

if [ "$ACTION" = "install" ]; then
  echo "Installing probes into $SETTINGS_FILE for runtime: $RUNTIME"
  
  python3 << PYEOF
import json, sys

with open("$SETTINGS_FILE", "r") as f:
    settings = json.load(f)

if "hooks" not in settings:
    settings["hooks"] = {}

probe_cmd = "$PROBE_CMD"
changed = False

for event in $EVENTS:
    if event not in settings["hooks"]:
        settings["hooks"][event] = []
    
    # Check if probe already installed
    existing = settings["hooks"][event]
    already_installed = any(
        isinstance(e, dict) and e.get("command", "").find("inspect-payload") >= 0
        for e in existing
    )
    
    if already_installed:
        print(f"  {event}: already installed, skipping")
        continue
    
    # Build probe entry matching runtime's schema
    if "$RUNTIME" == "gsd":
        probe_entry = {
            "command": probe_cmd,
            "timeout": $TIMEOUT,
            "_probe": True
        }
    elif "$RUNTIME" == "claude":
        probe_entry = {
            "hooks": [{
                "type": "command",
                "command": probe_cmd,
                "timeout": $TIMEOUT,
                "_probe": True
            }]
        }
    elif "$RUNTIME" == "gemini":
        probe_entry = {
            "hooks": [{
                "type": "command",
                "command": probe_cmd,
                "timeout": $TIMEOUT,
                "_probe": True
            }]
        }
    
    # Prepend (fire before real hooks)
    settings["hooks"][event] = [probe_entry] + existing
    print(f"  {event}: probe installed")
    changed = True

if changed:
    with open("$SETTINGS_FILE", "w") as f:
        json.dump(settings, f, indent=2)
    print(f"\nProbes installed. Trigger events and check:")
    print(f"  {PROBE_DIR}/captures/")
else:
    print("\nNo changes needed.")
PYEOF

elif [ "$ACTION" = "remove" ]; then
  echo "Removing probes from $SETTINGS_FILE for runtime: $RUNTIME"
  
  python3 << PYEOF
import json

with open("$SETTINGS_FILE", "r") as f:
    settings = json.load(f)

hooks = settings.get("hooks", {})
changed = False

for event, entries in hooks.items():
    if not isinstance(entries, list):
        continue
    
    original_len = len(entries)
    
    # Filter out probe entries (detect by inspect-payload in command)
    filtered = []
    for entry in entries:
        if isinstance(entry, dict):
            cmd = entry.get("command", "")
            # Check nested hooks (Claude/Gemini format)
            nested = entry.get("hooks", [])
            if isinstance(nested, list) and any(
                isinstance(n, dict) and "inspect-payload" in n.get("command", "")
                for n in nested
            ):
                continue
            if "inspect-payload" in cmd:
                continue
        filtered.append(entry)
    
    if len(filtered) < original_len:
        settings["hooks"][event] = filtered
        print(f"  {event}: removed {original_len - len(filtered)} probe(s)")
        changed = True

if changed:
    with open("$SETTINGS_FILE", "w") as f:
        json.dump(settings, f, indent=2)
    print("\nProbes removed.")
else:
    print("\nNo probes found to remove.")
PYEOF

else
  echo "Usage: $0 [install|remove] [gsd|claude|gemini]"
  exit 1
fi
