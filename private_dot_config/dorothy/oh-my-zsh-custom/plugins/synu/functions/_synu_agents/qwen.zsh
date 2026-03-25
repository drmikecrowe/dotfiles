# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

# Qwen Code agent definition for synu
# Provides model configuration for routing through Synthetic API
# Qwen Code only accepts configuration via environment variables

# Fallback default (used when no cache entry exists)
typeset -g _SYNU_QWEN_FALLBACK_MODEL="hf:zai-org/GLM-4.7"

_synu_qwen_default() {
    local cached
    cached=$(_synu_cache_get qwen model)
    if [[ $? -eq 0 ]]; then
        echo "${cached}"
    else
        echo "${_SYNU_QWEN_FALLBACK_MODEL}"
    fi
}

_synu_agent_qwen_flags() {
    echo "m/model="
}

_synu_agent_qwen_env_vars() {
    echo OPENAI_API_KEY
    echo OPENAI_BASE_URL
    echo OPENAI_MODEL
}

_synu_agent_qwen_configure() {
    local -A opts

    # Parse flags passed from main synu
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --model=*) opts[model]="${1#*=}" ;;
        esac
        shift
    done

    # Start with default (from cache or fallback)
    local model=$(_synu_qwen_default)

    # Apply override if provided
    [[ -n "${opts[model]}" ]] && model="${opts[model]}"

    # Export environment variables for Qwen Code
    export OPENAI_API_KEY="${SYNTHETIC_API_KEY}"
    export OPENAI_BASE_URL="https://api.synthetic.new/openai/v1"
    export OPENAI_MODEL="${model}"
}

_synu_agent_qwen_interactive() {
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

    # Get current model for display
    local current_id=$(_synu_qwen_default)
    local current_name=$(echo "${models_json}" | \
        jq -r --arg id "${current_id}" '.data[] | select(.id == $id) | .name // "unknown"')

    # Select model
    local model_name
    model_name=$(printf "%s\n" "${model_names[@]}" | \
        gum filter --limit 1 --header "Select model for Qwen Code (current: ${current_name})" \
        --placeholder "Filter models...")
    [[ $? -ne 0 ]] && return 1

    local model_id
    model_id=$(echo "${models_json}" | \
        jq -r --arg name "${model_name}" '.data[] | select(.name == $name) | .id')

    if [[ -z "${model_id}" ]]; then
        print -u2 "Error: Could not find model ID"
        return 1
    fi

    # Build flags
    local flags="--model=${model_id}"

    # Offer to save as default
    if gum confirm "Save as default for 'qwen'?"; then
        _synu_cache_set qwen model "${model_id}"
    fi

    # Output flags for caller to use
    printf '%s\n' "${flags}"
}
