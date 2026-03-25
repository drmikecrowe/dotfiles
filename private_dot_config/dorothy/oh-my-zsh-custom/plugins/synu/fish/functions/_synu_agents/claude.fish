# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

# Claude Code agent definition for synu
# Provides model configuration for routing through Synthetic API

# Source cache functions
source (status dirname)/../_synu_cache.fish

# Fallback defaults (used when no cache entry exists)
set -g _synu_claude_fallback_opus "hf:moonshotai/Kimi-K2-Thinking"
set -g _synu_claude_fallback_sonnet "hf:zai-org/GLM-4.7"
set -g _synu_claude_fallback_haiku "hf:deepseek-ai/MiniMax-M2"
set -g _synu_claude_fallback_agent "hf:zai-org/GLM-4.7"

function _synu_claude_default --description "Get default model: _synu_claude_default slot"
    set -l slot $argv[1]
    set -l cached (_synu_cache_get claude $slot)
    if test $status -eq 0
        echo $cached
    else
        set -l var_name _synu_claude_fallback_$slot
        echo $$var_name
    end
end

function _synu_agent_claude_flags --description "Return argparse-compatible flag specification"
    echo "H/heavy="
    echo "M/medium="
    echo "l/light="
    echo "o/opus="
    echo "s/sonnet="
    echo "k/haiku="
    echo "a/agent="
end

function _synu_agent_claude_env_vars --description "Return list of environment variables set by configure"
    echo ANTHROPIC_BASE_URL
    echo ANTHROPIC_AUTH_TOKEN
    echo ANTHROPIC_DEFAULT_OPUS_MODEL
    echo ANTHROPIC_DEFAULT_SONNET_MODEL
    echo ANTHROPIC_DEFAULT_HAIKU_MODEL
    echo CLAUDE_CODE_SUBAGENT_MODEL
    echo CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC
end

function _synu_agent_claude_configure --description "Configure Claude Code environment variables"
    # Parse flags passed from main synu
    argparse 'H/heavy=' 'M/medium=' 'l/light=' 'o/opus=' 's/sonnet=' 'k/haiku=' 'a/agent=' -- $argv
    or return 1

    # Start with defaults (from cache or fallback)
    set -l opus_model (_synu_claude_default opus)
    set -l sonnet_model (_synu_claude_default sonnet)
    set -l haiku_model (_synu_claude_default haiku)
    set -l subagent_model (_synu_claude_default agent)

    # Apply group overrides
    if set -q _flag_heavy
        set opus_model $_flag_heavy
    end

    if set -q _flag_medium
        set sonnet_model $_flag_medium
        set subagent_model $_flag_medium
    end

    if set -q _flag_light
        set haiku_model $_flag_light
    end

    # Apply specific overrides (take precedence over groups)
    if set -q _flag_opus
        set opus_model $_flag_opus
    end
    if set -q _flag_sonnet
        set sonnet_model $_flag_sonnet
    end
    if set -q _flag_haiku
        set haiku_model $_flag_haiku
    end
    if set -q _flag_agent
        set subagent_model $_flag_agent
    end

    # Export environment variables for Claude Code
    set -gx ANTHROPIC_BASE_URL "https://api.synthetic.new/anthropic"
    set -gx ANTHROPIC_AUTH_TOKEN $SYNTHETIC_API_KEY
    set -gx ANTHROPIC_DEFAULT_OPUS_MODEL $opus_model
    set -gx ANTHROPIC_DEFAULT_SONNET_MODEL $sonnet_model
    set -gx ANTHROPIC_DEFAULT_HAIKU_MODEL $haiku_model
    set -gx CLAUDE_CODE_SUBAGENT_MODEL $subagent_model
    set -gx CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1
end

function _synu_agent_claude_interactive --description "Interactive model selection using gum"
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

    # Get current models for display
    set -l current_opus_id (_synu_claude_default opus)
    set -l current_sonnet_id (_synu_claude_default sonnet)
    set -l current_haiku_id (_synu_claude_default haiku)
    set -l current_agent_id (_synu_claude_default agent)
    set -l current_opus_name (echo $models_json | \
        jq -r --arg id "$current_opus_id" '.data[] | select(.id == $id) | .name // "unknown"')
    set -l current_sonnet_name (echo $models_json | \
        jq -r --arg id "$current_sonnet_id" '.data[] | select(.id == $id) | .name // "unknown"')
    set -l current_haiku_name (echo $models_json | \
        jq -r --arg id "$current_haiku_id" '.data[] | select(.id == $id) | .name // "unknown"')
    set -l current_agent_name (echo $models_json | \
        jq -r --arg id "$current_agent_id" '.data[] | select(.id == $id) | .name // "unknown"')

    # Prompt for groups vs individual
    set -l mode (gum choose --limit 1 --header "How do you want to select models?" \
        "Groups" "Individual models")
    or return 1

    # Build flags array
    set -l flags

    if test "$mode" = "Groups"
        # Select which groups to override
        set -l groups (gum choose --no-limit \
            --header "Which group(s) do you want to override?" \
            "Heavy (Opus)" "Medium (Sonnet, Sub-agent)" "Light (Haiku)")
        or return 1

        for group in $groups
            if test "$group" = "Heavy (Opus)"
                set -l model_name (printf "%s\n" $model_names | \
                    gum filter --limit 1 --header "Select model for Heavy group (opus: $current_opus_id)" \
                    --placeholder "Filter models...")
                or return 1
                set -l model_id (echo $models_json | \
                    jq -r --arg name "$model_name" '.data[] | select(.name == $name) | .id')
                if test -n "$model_id"
                    set flags $flags --heavy=$model_id
                end
            else if test "$group" = "Medium (Sonnet, Sub-agent)"
                set -l model_name (printf "%s\n" $model_names | \
                    gum filter --limit 1 --header "Select model for Medium group (sonnet: $current_sonnet_id, agent: $current_agent_id)" \
                    --placeholder "Filter models...")
                or return 1
                set -l model_id (echo $models_json | \
                    jq -r --arg name "$model_name" '.data[] | select(.name == $name) | .id')
                if test -n "$model_id"
                    set flags $flags --medium=$model_id
                end
            else if test "$group" = "Light (Haiku)"
                set -l model_name (printf "%s\n" $model_names | \
                    gum filter --limit 1 --header "Select model for Light group (haiku: $current_haiku_id)" \
                    --placeholder "Filter models...")
                or return 1
                set -l model_id (echo $models_json | \
                    jq -r --arg name "$model_name" '.data[] | select(.name == $name) | .id')
                if test -n "$model_id"
                    set flags $flags --light=$model_id
                end
            end
        end
    else
        # Select which individual models to override
        set -l models (gum choose --no-limit \
            --header "Which model(s) do you want to override?" \
            "Opus" "Sonnet" "Haiku" "Sub-agent")
        or return 1

        for model_type in $models
            switch $model_type
                case "Opus"
                    set -l model_name (printf "%s\n" $model_names | \
                        gum filter --limit 1 --header "Select Opus model (current: $current_opus_id)" \
                        --placeholder "Filter models...")
                    or return 1
                    set -l model_id (echo $models_json | \
                        jq -r --arg name "$model_name" '.data[] | select(.name == $name) | .id')
                    if test -n "$model_id"
                        set flags $flags --opus=$model_id
                    end
                case "Sonnet"
                    set -l model_name (printf "%s\n" $model_names | \
                        gum filter --limit 1 --header "Select Sonnet model (current: $current_sonnet_id)" \
                        --placeholder "Filter models...")
                    or return 1
                    set -l model_id (echo $models_json | \
                        jq -r --arg name "$model_name" '.data[] | select(.name == $name) | .id')
                    if test -n "$model_id"
                        set flags $flags --sonnet=$model_id
                    end
                case "Haiku"
                    set -l model_name (printf "%s\n" $model_names | \
                        gum filter --limit 1 --header "Select Haiku model (current: $current_haiku_id)" \
                        --placeholder "Filter models...")
                    or return 1
                    set -l model_id (echo $models_json | \
                        jq -r --arg name "$model_name" '.data[] | select(.name == $name) | .id')
                    if test -n "$model_id"
                        set flags $flags --haiku=$model_id
                    end
                case "Sub-agent"
                    set -l model_name (printf "%s\n" $model_names | \
                        gum filter --limit 1 --header "Select Sub-agent model (current: $current_agent_id)" \
                        --placeholder "Filter models...")
                    or return 1
                    set -l model_id (echo $models_json | \
                        jq -r --arg name "$model_name" '.data[] | select(.name == $name) | .id')
                    if test -n "$model_id"
                        set flags $flags --agent=$model_id
                    end
            end
        end
    end

    # Offer to save as defaults
    if test (count $flags) -gt 0
        if gum confirm "Save as default for 'claude'?"
            for flag in $flags
                # Parse --key=value format
                set -l parts (string match -r -- '^--([^=]+)=(.+)$' $flag)
                if test -n "$parts[2]"
                    set -l key $parts[2]
                    set -l value $parts[3]
                    # Expand group flags to individual slots
                    switch $key
                        case heavy
                            _synu_cache_set claude opus $value
                        case medium
                            _synu_cache_set claude sonnet $value
                            _synu_cache_set claude agent $value
                        case light
                            _synu_cache_set claude haiku $value
                        case '*'
                            _synu_cache_set claude $key $value
                    end
                end
            end
        end
    end

    # Output flags for caller to use (one per line for proper array capture)
    printf '%s\n' $flags
end
