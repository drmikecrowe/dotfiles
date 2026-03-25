# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

# Provide basic usage information for the wrapper itself
# Suggest known agents and interactive mode for the first argument
complete -c synu -n "not __fish_seen_subcommand_from i claude opencode aider llxprt qwen crush amp octo codex" \
    -a "i" -d "Interactive model selection"
complete -c synu -n "not __fish_seen_subcommand_from i claude opencode aider llxprt qwen crush amp octo codex" \
    -a "claude opencode aider llxprt qwen crush amp octo codex" -d "AI agent to wrap"

# After "i" subcommand, suggest agents
complete -c synu -n "__fish_seen_subcommand_from i; and not __fish_seen_subcommand_from claude opencode aider llxprt qwen crush amp octo codex" \
    -a "claude opencode aider llxprt qwen crush amp octo codex" -d "AI agent"

# Claude-specific flags (when claude is the agent)
complete -c synu -n "__fish_seen_subcommand_from claude" \
    -s L -l large -r -d "Override Opus, Sonnet, and Sub-agent models"
complete -c synu -n "__fish_seen_subcommand_from claude" \
    -s l -l light -r -d "Override Haiku model"
complete -c synu -n "__fish_seen_subcommand_from claude" \
    -s o -l opus -r -d "Override Opus model"
complete -c synu -n "__fish_seen_subcommand_from claude" \
    -s s -l sonnet -r -d "Override Sonnet model"
complete -c synu -n "__fish_seen_subcommand_from claude" \
    -s H -l haiku -r -d "Override Haiku model"
complete -c synu -n "__fish_seen_subcommand_from claude" \
    -s a -l agent -r -d "Override Sub-agent model"

# Inherit claude completions for claude subcommand
complete -c synu -n "__fish_seen_subcommand_from claude" -w claude

# OpenCode-specific flags (when opencode is the agent)
complete -c synu -n "__fish_seen_subcommand_from opencode" \
    -s m -l model -r -d "Override model"

# Aider-specific flags (when aider is the agent)
# Note: no short flags to avoid collision with aider's -m (--message) and -e (--env-file)
complete -c synu -n "__fish_seen_subcommand_from aider" \
    -l model -r -d "Main model"
complete -c synu -n "__fish_seen_subcommand_from aider" \
    -l editor-model -r -d "Editor model (enables architect + editor mode)"

# llxprt-specific flags (when llxprt is the agent)
complete -c synu -n "__fish_seen_subcommand_from llxprt" \
    -s m -l model -r -d "Override model"

# Qwen Code-specific flags (when qwen is the agent)
complete -c synu -n "__fish_seen_subcommand_from qwen" \
    -s m -l model -r -d "Override model"
