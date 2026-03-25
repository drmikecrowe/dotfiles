# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

# Aider agent definition for synu
# Provides model configuration for routing through Synthetic API
# Aider accepts model via CLI flags and API config via environment variables

# Fallback defaults (used when no cache entry exists)
typeset -g _SYNU_AIDER_FALLBACK_MODEL="hf:zai-org/GLM-4.7"
typeset -g _SYNU_AIDER_FALLBACK_EDITOR_MODEL="hf:deepseek-ai/MiniMax-M2"

_synu_aider_default() {
    local slot=$1
    local cached
    cached=$(_synu_cache_get aider "${slot}")
    if [[ $? -eq 0 ]]; then
        echo "${cached}"
    else
        local var_name="_SYNU_AIDER_FALLBACK_${(U)slot//-/_}"
        echo "${(P)var_name}"
    fi
}

_synu_agent_aider_flags() {
    # Note: no short flags to avoid collision with aider's -m (--message) and -e (--env-file)
    echo "model="
    echo "editor-model="
}

_synu_agent_aider_env_vars() {
    echo OPENAI_API_BASE
    echo OPENAI_API_KEY
}

_synu_agent_aider_configure() {
    local -A opts

    # Parse flags passed from main synu
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --model=*) opts[model]="${1#*=}" ;;
            --editor-model=*) opts[editor_model]="${1#*=}" ;;
        esac
        shift
    done

    # Start with defaults (from cache or fallback)
    typeset -g _SYNU_AIDER_SELECTED_MODEL=$(_synu_aider_default model)
    typeset -g _SYNU_AIDER_SELECTED_EDITOR_MODEL=$(_synu_aider_default editor_model)

    # Apply overrides if provided
    [[ -n "${opts[model]}" ]] && typeset -g _SYNU_AIDER_SELECTED_MODEL="${opts[model]}"
    [[ -n "${opts[editor_model]}" ]] && typeset -g _SYNU_AIDER_SELECTED_EDITOR_MODEL="${opts[editor_model]}"

    # Export environment variables for Aider
    export OPENAI_API_BASE="https://api.synthetic.new/openai/v1"
    export OPENAI_API_KEY="${SYNTHETIC_API_KEY}"
}

_synu_agent_aider_args() {
    # Always return --model
    echo --model
    echo "openai/${_SYNU_AIDER_SELECTED_MODEL}"

    # Return --editor-model if set
    if [[ -n "${_SYNU_AIDER_SELECTED_EDITOR_MODEL}" ]]; then
        echo --editor-model
        echo "openai/${_SYNU_AIDER_SELECTED_EDITOR_MODEL}"
    fi
}

_synu_agent_aider_interactive() {
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

    # Ask if editor model should be set
    local use_editor_model
    use_editor_model=$(gum choose --limit 1 \
        --header "Aider has two modes. Set editor model?" \
        "No (single model mode)" "Yes (architect + editor mode)")
    [[ $? -ne 0 ]] && return 1

    # Build flags array
    local -a flags=()

    # Get current models for display
    local current_model_id=$(_synu_aider_default model)
    local current_model_name=$(echo "${models_json}" | \
        jq -r --arg id "${current_model_id}" '.data[] | select(.id == $id) | .name // "unknown"')
    local current_editor_id=$(_synu_aider_default editor_model)
    local current_editor_name=$(echo "${models_json}" | \
        jq -r --arg id "${current_editor_id}" '.data[] | select(.id == $id) | .name // "unknown"')

    # Select main model
    local model_name
    model_name=$(printf "%s\n" "${model_names[@]}" | \
        gum filter --limit 1 --header "Select main model for Aider (current: ${current_model_name})" \
        --placeholder "Filter models...")
    [[ $? -ne 0 ]] && return 1

    local model_id
    model_id=$(echo "${models_json}" | \
        jq -r --arg name "${model_name}" '.data[] | select(.name == $name) | .id')

    if [[ -z "${model_id}" ]]; then
        print -u2 "Error: Could not find model ID"
        return 1
    fi

    flags+=(--model="${model_id}")

    # Select editor model if requested
    if [[ "${use_editor_model}" == "Yes (architect + editor mode)" ]]; then
        local editor_model_name
        editor_model_name=$(printf "%s\n" "${model_names[@]}" | \
            gum filter --limit 1 --header "Select editor model for Aider (current: ${current_editor_name})" \
            --placeholder "Filter models...")
        [[ $? -ne 0 ]] && return 1

        local editor_model_id
        editor_model_id=$(echo "${models_json}" | \
            jq -r --arg name "${editor_model_name}" '.data[] | select(.name == $name) | .id')

        if [[ -z "${editor_model_id}" ]]; then
            print -u2 "Error: Could not find editor model ID"
            return 1
        fi

        flags+=(--editor-model="${editor_model_id}")
    fi

    # Offer to save as defaults
    if gum confirm "Save as default for 'aider'?"; then
        local flag
        for flag in "${flags[@]}"; do
            local key="${flag%%=*}"
            key="${key#--}"
            local value="${flag#*=}"
            # Replace hyphens with underscores for cache keys
            key="${key//-/_}"
            _synu_cache_set aider "${key}" "${value}"
        done
    fi

    # Output flags for caller to use
    printf '%s\n' "${flags[@]}"
}
