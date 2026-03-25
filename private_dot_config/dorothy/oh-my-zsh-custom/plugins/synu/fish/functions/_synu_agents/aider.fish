# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

# Aider agent definition for synu
# Provides model configuration for routing through Synthetic API
# Aider accepts model via CLI flags and API config via environment variables

# Source cache functions
source (status dirname)/../_synu_cache.fish

# Fallback defaults (used when no cache entry exists)
set -g _synu_aider_fallback_model "hf:zai-org/GLM-4.7"
set -g _synu_aider_fallback_editor_model "hf:deepseek-ai/MiniMax-M2"

function _synu_aider_default --description "Get default model: _synu_aider_default slot"
    set -l slot $argv[1]
    set -l cached (_synu_cache_get aider $slot)
    if test $status -eq 0
        echo $cached
    else
        set -l var_name _synu_aider_fallback_$slot
        echo $$var_name
    end
end

function _synu_agent_aider_flags --description "Return argparse-compatible flag specification"
    # Note: no short flags to avoid collision with aider's -m (--message) and -e (--env-file)
    echo "model="
    echo "editor-model="
end

function _synu_agent_aider_env_vars --description "Return list of environment variables set by configure"
    echo OPENAI_API_BASE
    echo OPENAI_API_KEY
end

function _synu_agent_aider_configure --description "Configure Aider environment variables and model selection"
    # Parse flags passed from main synu
    # Note: no short flags to avoid collision with aider's -m (--message) and -e (--env-file)
    argparse 'model=' 'editor-model=' -- $argv
    or return 1

    # Start with defaults (from cache or fallback)
    set -g _synu_aider_selected_model (_synu_aider_default model)
    set -g _synu_aider_selected_editor_model (_synu_aider_default editor_model)

    # Apply overrides if provided
    if set -q _flag_model
        set -g _synu_aider_selected_model $_flag_model
    end
    if set -q _flag_editor_model
        set -g _synu_aider_selected_editor_model $_flag_editor_model
    end

    # Export environment variables for Aider
    set -gx OPENAI_API_BASE "https://api.synthetic.new/openai/v1"
    set -gx OPENAI_API_KEY $SYNTHETIC_API_KEY
end

function _synu_agent_aider_args --description "Return CLI arguments to pass to aider"
    # Always return --model
    echo --model
    echo "openai/$_synu_aider_selected_model"
    
    # Return --editor-model if set
    if test -n "$_synu_aider_selected_editor_model"
        echo --editor-model
        echo "openai/$_synu_aider_selected_editor_model"
    end
end

function _synu_agent_aider_interactive --description "Interactive model selection using gum"
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

    # Ask if editor model should be set
    set -l use_editor_model (gum choose --limit 1 \
        --header "Aider has two modes. Set editor model?" \
        "No (single model mode)" "Yes (architect + editor mode)")
    or return 1

    # Build flags array
    set -l flags

    # Get current models for display
    set -l current_model_id (_synu_aider_default model)
    set -l current_model_name (echo $models_json | \
        jq -r --arg id "$current_model_id" '.data[] | select(.id == $id) | .name // "unknown"')
    set -l current_editor_id (_synu_aider_default editor_model)
    set -l current_editor_name (echo $models_json | \
        jq -r --arg id "$current_editor_id" '.data[] | select(.id == $id) | .name // "unknown"')

    # Select main model
    set -l model_name (printf "%s\n" $model_names | \
        gum filter --limit 1 --header "Select main model for Aider (current: $current_model_id)" \
        --placeholder "Filter models...")
    or return 1

    set -l model_id (echo $models_json | \
        jq -r --arg name "$model_name" '.data[] | select(.name == $name) | .id')

    if test -z "$model_id"
        echo "Error: Could not find model ID" >&2
        return 1
    end

    set flags $flags --model=$model_id

    # Select editor model if requested
    if test "$use_editor_model" = "Yes (architect + editor mode)"
        set -l editor_model_name (printf "%s\n" $model_names | \
            gum filter --limit 1 --header "Select editor model for Aider (current: $current_editor_id)" \
            --placeholder "Filter models...")
        or return 1

        set -l editor_model_id (echo $models_json | \
            jq -r --arg name "$editor_model_name" '.data[] | select(.name == $name) | .id')

        if test -z "$editor_model_id"
            echo "Error: Could not find editor model ID" >&2
            return 1
        end

        set flags $flags --editor-model=$editor_model_id
    end

    # Offer to save as defaults
    if gum confirm "Save as default for 'aider'?"
        for flag in $flags
            # Parse --key=value format
            set -l parts (string match -r -- '^--([^=]+)=(.+)$' $flag)
            if test -n "$parts[2]"
                set -l key $parts[2]
                set -l value $parts[3]
                # Replace hyphens with underscores for cache keys
                set key (string replace -a '-' '_' $key)
                _synu_cache_set aider $key $value
            end
        end
    end

    # Output flags for caller to use
    printf '%s\n' $flags
end
