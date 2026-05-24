#!/usr/bin/env bash
# context-feed-assemble: build the recovery brief before compaction.
# Triggered by PreCompact. Deterministic concatenation, no LLM.
set -uo pipefail

[ -n "${AGENTS_SUMMARIZER:-}" ] && exit 0
export CONTEXT_FEED_LOG="${CONTEXT_FEED_LOG:-info}"

exec python3 "$HOME/.agents/bin/context_feed/__main__.py" assemble-brief
