<!--
SPDX-FileCopyrightText: Amolith <amolith@secluded.site>

SPDX-License-Identifier: Unlicense
-->

# AGENTS.md - Developer Guide for synu

This document helps AI agents work effectively with the synu codebase.

## Project Overview

**synu** is a wrapper for AI agents that tracks quota usage for [Synthetic](https://synthetic.new) API calls. It provides:

- Transparent quota tracking before/after agent execution
- Agent-specific configuration system (model routing, API endpoints)
- Persistent model preferences via cache file
- Interactive model selection with `gum`
- Passthrough mode for agents without special configuration

### Architecture

Both shell implementations follow the same structure:

```
fish/                                 zsh/
└─ functions/                         ├─ synu.plugin.zsh (entry point)
   ├─ synu.fish (main wrapper)        └─ functions/
   ├─ _synu_get_quota.fish               ├─ synu.zsh (main wrapper)
   ├─ _synu_cache.fish                   ├─ _synu_get_quota.zsh
   └─ _synu_agents/                      ├─ _synu_cache.zsh
       ├─ claude.fish                    └─ _synu_agents/
       ├─ opencode.fish                      ├─ claude.zsh
       ├─ aider.fish                         ├─ opencode.zsh
       ├─ llxprt.fish                        ├─ aider.zsh
       └─ qwen.fish                          ├─ llxprt.zsh
                                             └─ qwen.zsh
```

**Control Flow:**

1. Parse arguments (check for interactive mode, agent name)
2. Load agent definition from `fish/functions/_synu_agents/<agent>.fish` if it exists
3. Parse agent-specific flags using `argparse` with `--ignore-unknown` for passthrough
4. Configure agent environment (if agent has `_configure` function)
5. Fetch initial quota from Synthetic API
6. Execute agent with remaining arguments (plus any `_args` output)
7. Clean up environment variables (if agent has `_env_vars` function)
8. Fetch final quota and calculate/display session usage

**Data Flow:**

- Quota API → `_synu_get_quota` → space-separated "requests limit" string
- Agent flags → `argparse` → `_flag_*` variables → agent `_configure` function
- Cache file → `_synu_cache_get` → default model values
- Interactive mode → `gum` + Synthetic API → model IDs → recursive `synu` call with flags

## File Structure

```
├── fish/
│   ├── functions/
│   │   ├── synu.fish              # Main wrapper function
│   │   ├── _synu_get_quota.fish   # Private: Fetch quota from API
│   │   ├── _synu_cache.fish       # Private: Model preference cache
│   │   └── _synu_agents/
│   └── completions/
│       └── synu.fish              # Fish completions
├── zsh/
│   ├── synu.plugin.zsh            # Zsh plugin entry point
│   ├── functions/
│   │   ├── synu.zsh               # Main wrapper function
│   │   ├── _synu_get_quota.zsh    # Private: Fetch quota from API
│   │   ├── _synu_cache.zsh        # Private: Model preference cache
│   │   └── _synu_agents/
│   └── completions/
│       └── _synu.zsh              # Zsh completions
```

## Essential Commands

This is a shell library with no build system. Key commands:

### Testing In one line

```
fish -c 'set fish_function_path fish/functions fish/functions/_synu_agents \$fish_function_path; synu'
zsh -c 'source zsh/synu.plugin.zsh; synu'
```

### Installation Testing

```fish
# Install via fundle (in a clean fish instance)
fundle plugin 'synu' --url 'https://git.secluded.site/synu' --path 'fish'
fundle install
fundle init
```

## Important patterns

- Agents without definitions work as passthrough (no special config)
- Use `argparse --ignore-unknown` in main wrapper so agent-native flags pass through
- Interactive functions return flags that trigger recursive `synu` call
- Configure functions receive flags already parsed from `_flag_*` variables
- Environment variables listed in `_env_vars` are automatically unset after agent exits
- Use `_synu_cache_get`/`_synu_cache_set` for persistent model preferences

### Understanding Model Configuration Flow

**Example: Claude with flag override**

1. User runs: `synu claude --large hf:some/model "prompt"`
2. `synu.fish` loads `fish/functions/_synu_agents/claude.fish`
3. Calls `_synu_agent_claude_flags` to get flag spec
4. Parses with `argparse --ignore-unknown` → sets `_flag_large`
5. Rebuilds flags for configure: `--large=hf:some/model`
6. Calls `_synu_agent_claude_configure --large=hf:some/model`
7. Configure sets opus/sonnet/subagent models from flag
8. Exports `ANTHROPIC_*` environment variables
9. Executes `command claude "prompt"` with those environment variables
10. Claude Code sees Synthetic models via env vars and uses them
11. After exit, env vars are cleaned up via `_env_vars`

**Example: OpenCode with CLI args**

1. User runs: `synu opencode "prompt"`
2. `synu.fish` loads `fish/functions/_synu_agents/opencode.fish`
3. `_configure` sets `_synu_opencode_selected_model` from cache/fallback
4. `_args` returns: `--model synthetic/hf:MiniMaxAI/MiniMax-M2`
5. Executes: `command opencode -m "synthetic/hf:..." "prompt"`
