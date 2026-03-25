# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

# OpenCode agent definition for synu
# Provides model configuration for routing through Synthetic API
# OpenCode only accepts model via -m flag, not environment variables

# Source cache functions
source (status dirname)/../_synu_cache.fish

# Fallback default (used when no cache entry exists)
set -g _synu_opencode_fallback_model "hf:zai-org/GLM-4.6"

function _synu_opencode_default --description "Get default model"
    set -l cached (_synu_cache_get opencode model)
    if test $status -eq 0
        echo $cached
    else
        echo $_synu_opencode_fallback_model
    end
end

function _synu_agent_opencode_flags --description "Return argparse-compatible flag specification"
    echo "m/model="
end

function _synu_agent_opencode_configure --description "Configure OpenCode model selection"
    # Parse flags passed from main synu
    argparse 'm/model=' -- $argv
    or return 1

    # Start with default (from cache or fallback)
    set -g _synu_opencode_selected_model (_synu_opencode_default)

    # Apply override if provided
    if set -q _flag_model
        set -g _synu_opencode_selected_model $_flag_model
    end
end

function _synu_agent_opencode_args --description "Return CLI arguments to pass to opencode"
    # Return -m flag with selected model, prefixed with synthetic/ for provider routing
    echo -m
    echo "synthetic/$_synu_opencode_selected_model"
end

function _synu_agent_opencode_interactive --description "Interactive model selection using gum"
    # Check for gum
    if not command -q gum
        echo "Error: gum is required for interactive mode. Install: https://github.com/charmbracelet/gum" >&2
        return 1
    end

    # Fetch available models
    set -l models_json (gum spin --spinner dot --title "Fetching models..." -- \
        curl -s -H "Authorization: Bearer $SYNTHETIC_API_KEY" \
        "https://api.synthetic.new/openai/v1/models")
    or return 1

    set -l model_names (echo $models_json | jq -r '.data[].name')
    or return 1

    # Get current model for display
    set -l current_id (_synu_opencode_default)
    set -l current_name (echo $models_json | \
        jq -r --arg id "$current_id" '.data[] | select(.id == $id) | .name // "unknown"')

    # Select model
    set -l model_name (printf "%s\n" $model_names | \
        gum filter --limit 1 --header "Select model for OpenCode (current: $current_id)" \
        --placeholder "Filter models...")
    or return 1

    set -l model_id (echo $models_json | \
        jq -r --arg name "$model_name" '.data[] | select(.name == $name) | .id')

    if test -z "$model_id"
        echo "Error: Could not find model ID" >&2
        return 1
    end

    # Build flags
    set -l flags --model=$model_id

    # Offer to save as default
    if gum confirm "Save as default for 'opencode'?"
        _synu_cache_set opencode model $model_id
    end

    # Output flags for caller to use
    printf '%s\n' $flags
end
