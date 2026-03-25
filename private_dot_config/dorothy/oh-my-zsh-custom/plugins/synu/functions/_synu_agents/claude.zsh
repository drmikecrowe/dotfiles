# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

# Claude Code agent definition for synu
# Provides model configuration for routing through Synthetic API

# Fallback defaults (used when no cache entry exists)
typeset -g _SYNU_CLAUDE_FALLBACK_OPUS="hf:moonshotai/Kimi-K2-Thinking"
typeset -g _SYNU_CLAUDE_FALLBACK_SONNET="hf:zai-org/GLM-4.7"
typeset -g _SYNU_CLAUDE_FALLBACK_HAIKU="hf:deepseek-ai/MiniMax-M2"
typeset -g _SYNU_CLAUDE_FALLBACK_AGENT="hf:zai-org/GLM-4.7"

_synu_claude_default() {
    local slot=$1
    local cached
    cached=$(_synu_cache_get claude "${slot}")
    if [[ $? -eq 0 ]]; then
        echo "${cached}"
    else
        local var_name="_SYNU_CLAUDE_FALLBACK_${(U)slot}"
        echo "${(P)var_name}"
    fi
}

_synu_agent_claude_flags() {
    echo "H/heavy="
    echo "M/medium="
    echo "l/light="
    echo "o/opus="
    echo "s/sonnet="
    echo "k/haiku="
    echo "a/agent="
}

_synu_agent_claude_env_vars() {
    echo ANTHROPIC_BASE_URL
    echo ANTHROPIC_AUTH_TOKEN
    echo ANTHROPIC_DEFAULT_OPUS_MODEL
    echo ANTHROPIC_DEFAULT_SONNET_MODEL
    echo ANTHROPIC_DEFAULT_HAIKU_MODEL
    echo CLAUDE_CODE_SUBAGENT_MODEL
    echo CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
}

_synu_agent_claude_configure() {
    local -A opts
    local -a args

    # Parse flags passed from main synu
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --heavy=*) opts[heavy]="${1#*=}" ;;
            --medium=*) opts[medium]="${1#*=}" ;;
            --light=*) opts[light]="${1#*=}" ;;
            --opus=*) opts[opus]="${1#*=}" ;;
            --sonnet=*) opts[sonnet]="${1#*=}" ;;
            --haiku=*) opts[haiku]="${1#*=}" ;;
            --agent=*) opts[agent]="${1#*=}" ;;
            *) args+=("$1") ;;
        esac
        shift
    done

    # Start with defaults (from cache or fallback)
    local opus_model=$(_synu_claude_default opus)
    local sonnet_model=$(_synu_claude_default sonnet)
    local haiku_model=$(_synu_claude_default haiku)
    local subagent_model=$(_synu_claude_default agent)

    # Apply group overrides
    if [[ -n "${opts[heavy]}" ]]; then
        opus_model="${opts[heavy]}"
    fi

    if [[ -n "${opts[medium]}" ]]; then
        sonnet_model="${opts[medium]}"
        subagent_model="${opts[medium]}"
    fi

    if [[ -n "${opts[light]}" ]]; then
        haiku_model="${opts[light]}"
    fi

    # Apply specific overrides (take precedence over groups)
    [[ -n "${opts[opus]}" ]] && opus_model="${opts[opus]}"
    [[ -n "${opts[sonnet]}" ]] && sonnet_model="${opts[sonnet]}"
    [[ -n "${opts[haiku]}" ]] && haiku_model="${opts[haiku]}"
    [[ -n "${opts[agent]}" ]] && subagent_model="${opts[agent]}"

    # Export environment variables for Claude Code
    export ANTHROPIC_BASE_URL="https://api.synthetic.new/anthropic"
    export ANTHROPIC_AUTH_TOKEN="${SYNTHETIC_API_KEY}"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="${opus_model}"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="${sonnet_model}"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="${haiku_model}"
    export CLAUDE_CODE_SUBAGENT_MODEL="${subagent_model}"
    export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
}

_synu_agent_claude_interactive() {
    # Check for gum
    if ! (( $+commands[gum] )); then
        print -u2 "Error: gum is required for interactive mode. Install: https://github.com/charmbracelet/gum"
        return 1
    fi

    # Fetch available models
    local models_json
    models_json=$(gum spin --spinner dot --title "Fetching models..." -- \
        curl -s -H "Authorization: Bearer ${SYNTHETIC_API_KEY}" \
        "https://api.synthetic.new/openai/v1/models")
    [[ $? -ne 0 ]] && return 1

    local -a model_names
    model_names=("${(@f)$(echo "${models_json}" | jq -r '.data[].name')}")
    [[ $? -ne 0 ]] && return 1

    # Get current models for display
    local current_opus_id=$(_synu_claude_default opus)
    local current_sonnet_id=$(_synu_claude_default sonnet)
    local current_haiku_id=$(_synu_claude_default haiku)
    local current_agent_id=$(_synu_claude_default agent)

    local current_opus_name=$(echo "${models_json}" | \
        jq -r --arg id "${current_opus_id}" '.data[] | select(.id == $id) | .name // "unknown"')
    local current_sonnet_name=$(echo "${models_json}" | \
        jq -r --arg id "${current_sonnet_id}" '.data[] | select(.id == $id) | .name // "unknown"')
    local current_haiku_name=$(echo "${models_json}" | \
        jq -r --arg id "${current_haiku_id}" '.data[] | select(.id == $id) | .name // "unknown"')
    local current_agent_name=$(echo "${models_json}" | \
        jq -r --arg id "${current_agent_id}" '.data[] | select(.id == $id) | .name // "unknown"')

    # Prompt for groups vs individual
    local mode
    mode=$(gum choose --limit 1 --header "How do you want to select models?" \
        "Groups" "Individual models")
    [[ $? -ne 0 ]] && return 1

    # Build flags array
    local -a flags=()

    if [[ "${mode}" == "Groups" ]]; then
        # Select which groups to override
        local -a groups
        groups=("${(@f)$(gum choose --no-limit \
            --header "Which group(s) do you want to override?" \
            "Heavy (Opus)" "Medium (Sonnet, Sub-agent)" "Light (Haiku)")}")
        [[ $? -ne 0 ]] && return 1

        local group
        for group in "${groups[@]}"; do
            if [[ "${group}" == "Heavy (Opus)" ]]; then
                local model_name
                model_name=$(printf "%s\n" "${model_names[@]}" | \
                    gum filter --limit 1 --header "Select model for Heavy group (opus: ${current_opus_name})" \
                    --placeholder "Filter models...")
                [[ $? -ne 0 ]] && return 1

                local model_id
                model_id=$(echo "${models_json}" | \
                    jq -r --arg name "${model_name}" '.data[] | select(.name == $name) | .id')
                [[ -n "${model_id}" ]] && flags+=(--heavy="${model_id}")

            elif [[ "${group}" == "Medium (Sonnet, Sub-agent)" ]]; then
                local model_name
                model_name=$(printf "%s\n" "${model_names[@]}" | \
                    gum filter --limit 1 --header "Select model for Medium group (sonnet: ${current_sonnet_name}, agent: ${current_agent_name})" \
                    --placeholder "Filter models...")
                [[ $? -ne 0 ]] && return 1

                local model_id
                model_id=$(echo "${models_json}" | \
                    jq -r --arg name "${model_name}" '.data[] | select(.name == $name) | .id')
                [[ -n "${model_id}" ]] && flags+=(--medium="${model_id}")

            elif [[ "${group}" == "Light (Haiku)" ]]; then
                local model_name
                model_name=$(printf "%s\n" "${model_names[@]}" | \
                    gum filter --limit 1 --header "Select model for Light group (haiku: ${current_haiku_name})" \
                    --placeholder "Filter models...")
                [[ $? -ne 0 ]] && return 1

                local model_id
                model_id=$(echo "${models_json}" | \
                    jq -r --arg name "${model_name}" '.data[] | select(.name == $name) | .id')
                [[ -n "${model_id}" ]] && flags+=(--light="${model_id}")
            fi
        done
    else
        # Select which individual models to override
        local -a models
        models=("${(@f)$(gum choose --no-limit \
            --header "Which model(s) do you want to override?" \
            "Opus" "Sonnet" "Haiku" "Sub-agent")}")
        [[ $? -ne 0 ]] && return 1

        local model_type
        for model_type in "${models[@]}"; do
            case "${model_type}" in
                "Opus")
                    local model_name
                    model_name=$(printf "%s\n" "${model_names[@]}" | \
                        gum filter --limit 1 --header "Select Opus model (current: ${current_opus_name})" \
                        --placeholder "Filter models...")
                    [[ $? -ne 0 ]] && return 1

                    local model_id
                    model_id=$(echo "${models_json}" | \
                        jq -r --arg name "${model_name}" '.data[] | select(.name == $name) | .id')
                    [[ -n "${model_id}" ]] && flags+=(--opus="${model_id}")
                    ;;
                "Sonnet")
                    local model_name
                    model_name=$(printf "%s\n" "${model_names[@]}" | \
                        gum filter --limit 1 --header "Select Sonnet model (current: ${current_sonnet_name})" \
                        --placeholder "Filter models...")
                    [[ $? -ne 0 ]] && return 1

                    local model_id
                    model_id=$(echo "${models_json}" | \
                        jq -r --arg name "${model_name}" '.data[] | select(.name == $name) | .id')
                    [[ -n "${model_id}" ]] && flags+=(--sonnet="${model_id}")
                    ;;
                "Haiku")
                    local model_name
                    model_name=$(printf "%s\n" "${model_names[@]}" | \
                        gum filter --limit 1 --header "Select Haiku model (current: ${current_haiku_name})" \
                        --placeholder "Filter models...")
                    [[ $? -ne 0 ]] && return 1

                    local model_id
                    model_id=$(echo "${models_json}" | \
                        jq -r --arg name "${model_name}" '.data[] | select(.name == $name) | .id')
                    [[ -n "${model_id}" ]] && flags+=(--haiku="${model_id}")
                    ;;
                "Sub-agent")
                    local model_name
                    model_name=$(printf "%s\n" "${model_names[@]}" | \
                        gum filter --limit 1 --header "Select Sub-agent model (current: ${current_agent_name})" \
                        --placeholder "Filter models...")
                    [[ $? -ne 0 ]] && return 1

                    local model_id
                    model_id=$(echo "${models_json}" | \
                        jq -r --arg name "${model_name}" '.data[] | select(.name == $name) | .id')
                    [[ -n "${model_id}" ]] && flags+=(--agent="${model_id}")
                    ;;
            esac
        done
    fi

    # Offer to save as defaults
    if (( ${#flags} > 0 )); then
        if gum confirm "Save as default for 'claude'?"; then
            local flag
            for flag in "${flags[@]}"; do
                # Parse --key=value format
                local key="${flag%%=*}"
                key="${key#--}"
                local value="${flag#*=}"

                # Expand group flags to individual slots
                case "${key}" in
                    heavy)
                        _synu_cache_set claude opus "${value}"
                        ;;
                    medium)
                        _synu_cache_set claude sonnet "${value}"
                        _synu_cache_set claude agent "${value}"
                        ;;
                    light)
                        _synu_cache_set claude haiku "${value}"
                        ;;
                    *)
                        _synu_cache_set claude "${key}" "${value}"
                        ;;
                esac
            done
        fi
    fi

    # Output flags for caller to use (one per line for proper array capture)
    printf '%s\n' "${flags[@]}"
}
