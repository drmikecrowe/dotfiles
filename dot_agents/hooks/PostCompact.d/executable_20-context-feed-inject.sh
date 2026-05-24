#!/usr/bin/env bash
# context-feed-inject: emit the recovery brief after compaction.
# Triggered by PostCompact.
set -uo pipefail

[ -n "${AGENTS_SUMMARIZER:-}" ] && exit 0
export CONTEXT_FEED_LOG="${CONTEXT_FEED_LOG:-info}"

exec python3 "$HOME/.agents/bin/context_feed/__main__.py" inject-brief
