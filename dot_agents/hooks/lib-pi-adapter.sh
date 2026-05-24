#!/usr/bin/env bash
# ~/.agents/hooks/lib-pi-adapter.sh — normalize pi hook payloads to match
# what the notebook scripts expect (written for Claude Code payloads).
#
# Pi sends:
#   - { text, source } on UserPromptSubmit (not .prompt)
#   - { toolName } on PostToolUse (not .tool_name)
#   - NO session_id or transcript_path on most events
#   - cwd only on SessionStart, git events, milestone/unit events
#   - GSD_HOOK_EVENT env var on every dispatch
#   - Hook child process cwd IS the project dir
#
# This lib derives the missing fields and patches the JSON so existing
# notebook scripts (capture-intent, notebook-tick, notebook-unit) work
# without per-script rewrites.
#
# Usage in a .d/ script:
#   source "$(dirname "$0")/../lib-pi-adapter.sh"
#   PAYLOAD=$(pi_adapt)          # reads stdin, outputs normalized JSON
#   # ... rest of script unchanged ...

set -uo pipefail

# ── Session ID derivation ──────────────────────────────────────────────────
# Pi doesn't send session_id. We generate one on SessionStart and stash it
# in a runtime marker file keyed by project slug. Subsequent hooks in the
# same session/project read from there. New SessionStart overwrites it
# (new session = new ID).

_pi_session_marker() {
    local slug
    slug=$(printf '%s' "$PWD" | sed 's#/#-#g; s/^-//')
    printf '%s/%s' "$HOME/.agents/runtime/notebook" ".session-${slug}"
}

# Returns the current session ID, generating one if needed.
pi_session_id() {
    local marker
    marker=$(_pi_session_marker)

    # If marker exists and is recent (under 24h), reuse it
    if [ -f "$marker" ]; then
        local age
        age=$(( $(date +%s) - $(stat -c %Y "$marker" 2>/dev/null || echo 0) ))
        if [ "$age" -lt 86400 ]; then
            cat "$marker"
            return
        fi
    fi

    # Generate a new one: timestamp-based, short, readable
    local sid
    sid=$(date +%Y%m%d-%H%M%S)-$$_$(printf '%04x' $$)
    mkdir -p "$(dirname "$marker")"
    echo "$sid" > "$marker"
    echo "$sid"
}

# Stash session ID on SessionStart (called explicitly, not in pi_adapt)
pi_session_start() {
    local marker
    marker=$(_pi_session_marker)
    local sid
    sid=$(date +%Y%m%d-%H%M%S)-$$_$(printf '%x' $$ 2>/dev/null | tail -c 4)
    mkdir -p "$(dirname "$marker")"
    echo "$sid" > "$marker"
    echo "$sid"
}

# ── Transcript discovery ───────────────────────────────────────────────────
# Pi doesn't send transcript_path. It stores session transcripts somewhere
# in its runtime dir. For now, return empty — the summarizer will be a no-op
# until we wire the real path. This is the "skip for prototype" piece.
pi_transcript_path() {
    # TODO: discover pi's actual session file location.
    # SessionEnd payload has { sessionFile } — but we don't have it mid-session.
    # For now, try the obvious location:
    local candidate="$HOME/.gsd/runtime/transcript.jsonl"
    [ -f "$candidate" ] && { echo "$candidate"; return; }
    echo ""
}

# ── Payload normalization ──────────────────────────────────────────────────
# Reads JSON from stdin, patches missing fields, writes to stdout.
# Field mappings:
#   .text       → .prompt  (UserPromptSubmit)
#   .toolName   → .tool_name  (PostToolUse)
#   + inject .session_id, .cwd, .transcript_path
#
# All additions are additive — existing fields are never overwritten.

pi_adapt() {
    local raw
    raw=$(cat)

    # Build a patch JSON with derived fields
    local sid cwd transcript
    sid=$(pi_session_id)
    cwd="$PWD"
    transcript=$(pi_transcript_path)

    local patch
    patch=$(printf '{"session_id":"%s","cwd":"%s","transcript_path":"%s"}' "$sid" "$cwd" "$transcript")

    # Merge: patch fills in missing keys, never overwrites existing
    local merged
    merged=$(jq -s '.[0] * .[1]' <(echo "$patch") <(echo "$raw") 2>/dev/null || echo "$raw")

    # Rename fields if pi variant present but notebook variant missing
    # .text → .prompt
    local has_prompt has_text
    has_prompt=$(echo "$merged" | jq 'has("prompt")' 2>/dev/null)
    has_text=$(echo "$merged" | jq 'has("text")' 2>/dev/null)
    if [ "$has_text" = "true" ] && [ "$has_prompt" = "false" ]; then
        merged=$(echo "$merged" | jq '. + {prompt: .text}' 2>/dev/null || echo "$merged")
    fi

    # .toolName → .tool_name
    local has_tool_name has_toolName
    has_tool_name=$(echo "$merged" | jq 'has("tool_name")' 2>/dev/null)
    has_toolName=$(echo "$merged" | jq 'has("toolName")' 2>/dev/null)
    if [ "$has_toolName" = "true" ] && [ "$has_tool_name" = "false" ]; then
        merged=$(echo "$merged" | jq '. + {tool_name: .toolName}' 2>/dev/null || echo "$merged")
    fi

    echo "$merged"
}
