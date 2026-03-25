#compdef synu

# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

# Completion for synu - Universal agent wrapper with Synthetic API quota tracking

local curcontext="$curcontext" state line
typeset -A opt_args

local -a agents=(
    'claude:Claude Code agent'
    'opencode:OpenCode agent'
    'aider:Aider agent'
    'llxprt:llxprt agent'
    'qwen:Qwen Code agent'
    'crush:Crush agent (passthrough)'
    'amp:Amp agent (passthrough)'
    'octo:Octo agent (passthrough)'
    'codex:Codex agent (passthrough)'
)

local -a first_args=(
    'i:Interactive model selection'
    ${agents[@]}
)

_arguments -C \
    '1: :->first' \
    '2: :->second' \
    '*:: :->args' && return 0

case $state in
    first)
        _describe -t commands 'synu commands' first_args
        ;;
    second)
        if [[ "$words[2]" == "i" ]]; then
            _describe -t agents 'agents' agents
        else
            # After agent name, provide agent-specific options
            case "$words[2]" in
                claude)
                    _arguments \
                        '-L[Override Opus, Sonnet, and Sub-agent models]:model:' \
                        '--large[Override Opus, Sonnet, and Sub-agent models]:model:' \
                        '-l[Override Haiku model]:model:' \
                        '--light[Override Haiku model]:model:' \
                        '-o[Override Opus model]:model:' \
                        '--opus[Override Opus model]:model:' \
                        '-s[Override Sonnet model]:model:' \
                        '--sonnet[Override Sonnet model]:model:' \
                        '-H[Override Haiku model]:model:' \
                        '--haiku[Override Haiku model]:model:' \
                        '-a[Override Sub-agent model]:model:' \
                        '--agent[Override Sub-agent model]:model:' \
                        '*::claude arguments:_command_names -e'
                    ;;
                opencode)
                    _arguments \
                        '-m[Override model]:model:' \
                        '--model[Override model]:model:' \
                        '*::opencode arguments:_command_names -e'
                    ;;
                aider)
                    # Note: no short flags to avoid collision with aider's -m (--message) and -e (--env-file)
                    _arguments \
                        '--model[Main model]:model:' \
                        '--editor-model[Editor model (enables architect + editor mode)]:model:' \
                        '*::aider arguments:_command_names -e'
                    ;;
                llxprt)
                    _arguments \
                        '-m[Override model]:model:' \
                        '--model[Override model]:model:' \
                        '*::llxprt arguments:_command_names -e'
                    ;;
                qwen)
                    _arguments \
                        '-m[Override model]:model:' \
                        '--model[Override model]:model:' \
                        '*::qwen arguments:_command_names -e'
                    ;;
                *)
                    # Passthrough agents - no special options
                    _command_names -e
                    ;;
            esac
        fi
        ;;
    args)
        # After "i agent", provide agent-specific options
        if [[ "$words[2]" == "i" ]]; then
            case "$words[3]" in
                claude)
                    _arguments \
                        '-L[Override Opus, Sonnet, and Sub-agent models]:model:' \
                        '--large[Override Opus, Sonnet, and Sub-agent models]:model:' \
                        '-l[Override Haiku model]:model:' \
                        '--light[Override Haiku model]:model:' \
                        '-o[Override Opus model]:model:' \
                        '--opus[Override Opus model]:model:' \
                        '-s[Override Sonnet model]:model:' \
                        '--sonnet[Override Sonnet model]:model:' \
                        '-H[Override Haiku model]:model:' \
                        '--haiku[Override Haiku model]:model:' \
                        '-a[Override Sub-agent model]:model:' \
                        '--agent[Override Sub-agent model]:model:' \
                        '*::claude arguments:_command_names -e'
                    ;;
                opencode|llxprt|qwen)
                    _arguments \
                        '-m[Override model]:model:' \
                        '--model[Override model]:model:' \
                        '*::arguments:_command_names -e'
                    ;;
                aider)
                    # Note: no short flags to avoid collision with aider's -m (--message) and -e (--env-file)
                    _arguments \
                        '--model[Main model]:model:' \
                        '--editor-model[Editor model]:model:' \
                        '*::aider arguments:_command_names -e'
                    ;;
            esac
        fi
        ;;
esac
