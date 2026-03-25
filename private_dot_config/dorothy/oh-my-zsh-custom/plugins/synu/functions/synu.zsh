# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

# Universal agent wrapper with Synthetic API quota tracking

synu() {
    emulate -L zsh
    setopt extended_glob

    # If no arguments, just print the quota
    if [[ $# -lt 1 ]]; then
        local quota
        quota=$(_synu_get_quota)
        if [[ $? -ne 0 ]]; then
            print -u2 "Error: Could not fetch quota"
            return 1
        fi
        local requests=${quota%% *}
        local limit=${quota##* }
        local remaining=$(( limit - requests ))
        local percent_used=$(( requests * 100.0 / limit ))
        local percent_int remaining_fmt
        printf -v percent_int "%.0f" "${percent_used}"
        printf -v remaining_fmt "%.2f" "${remaining}"

        printf "Usage: "
        if (( percent_int < 33 )); then
            print -Pn "%K{green}%F{black}"
        elif (( percent_int < 67 )); then
            print -Pn "%K{yellow}%F{black}"
        else
            print -Pn "%K{red}%F{black}"
        fi
        printf " %s%% " "${percent_int}"
        print -Pn "%k%f"
        printf " (%s/%s remaining)\n" "${remaining_fmt}" "${limit}"
        return 0
    fi

    # Check for interactive mode: synu i <agent> [args...]
    if [[ "$1" == "i" ]]; then
        if [[ $# -lt 2 ]]; then
            print -u2 "Error: Interactive mode requires an agent name"
            print -u2 "Usage: synu i <agent> [args...]"
            return 1
        fi

        local agent=$2
        shift 2
        local -a agent_args=("$@")

        # Source agent definition if it exists
        local agent_file="${SYNU_PLUGIN_DIR}/functions/_synu_agents/${agent}.zsh"
        if [[ -f "${agent_file}" ]]; then
            source "${agent_file}"
        fi

        # Check for interactive function
        if ! (( $+functions[_synu_agent_${agent}_interactive] )); then
            print -u2 "Error: Agent '${agent}' does not support interactive mode"
            return 1
        fi

        # Get flags from interactive selection
        local -a interactive_flags
        interactive_flags=("${(@f)$(_synu_agent_${agent}_interactive)}")
        local interactive_status=$?
        if [[ ${interactive_status} -ne 0 ]]; then
            return ${interactive_status}
        fi


        # Recursively call synu with selected flags
        synu "${agent}" ${interactive_flags[@]} ${agent_args[@]}
        return $?
    fi

    # Extract agent name (first argument) and remaining args
    local agent=$1
    shift
    local -a agent_args=("$@")

    # Source agent definition if it exists
    local agent_file="${SYNU_PLUGIN_DIR}/functions/_synu_agents/${agent}.zsh"
    if [[ -f "${agent_file}" ]]; then
        source "${agent_file}"
    fi

    # Check if agent has a configuration function
    if (( $+functions[_synu_agent_${agent}_configure] )); then
        # Get flag specification
        local -a flag_spec
        if (( $+functions[_synu_agent_${agent}_flags] )); then
            flag_spec=($(_synu_agent_${agent}_flags))
        fi

        # Manually extract synu-specific flags while preserving agent flags
        local -a parsed_flags=()
        local -a remaining_args=()
        local -A flag_values=()

        # Known synu flags across all agents (short and long forms)
        local -a known_short=(L l o s H a m e)
        local -a known_long=(large light opus sonnet haiku agent model editor-model)

        local i=1
        while (( i <= ${#agent_args} )); do
            local arg="${agent_args[i]}"
            local consumed=0

            # Check for --flag=value format
            if [[ "${arg}" == --*=* ]]; then
                local flag_name="${arg%%=*}"
                flag_name="${flag_name#--}"
                local flag_value="${arg#*=}"

                if [[ " ${known_long[*]} " == *" ${flag_name} "* ]]; then
                    flag_values[${flag_name}]="${flag_value}"
                    parsed_flags+=(--${flag_name}="${flag_value}")
                    consumed=1
                fi
            # Check for --flag value format
            elif [[ "${arg}" == --* ]]; then
                local flag_name="${arg#--}"

                if [[ " ${known_long[*]} " == *" ${flag_name} "* ]]; then
                    (( i++ ))
                    if (( i <= ${#agent_args} )); then
                        flag_values[${flag_name}]="${agent_args[i]}"
                        parsed_flags+=(--${flag_name}="${agent_args[i]}")
                    fi
                    consumed=1
                fi
            # Check for -f value format (short flags)
            elif [[ "${arg}" == -? ]]; then
                local flag_char="${arg#-}"

                if [[ " ${known_short[*]} " == *" ${flag_char} "* ]]; then
                    (( i++ ))
                    if (( i <= ${#agent_args} )); then
                        # Map short to long for storage
                        local long_name
                        case "${flag_char}" in
                            L) long_name="large" ;;
                            l) long_name="light" ;;
                            o) long_name="opus" ;;
                            s) long_name="sonnet" ;;
                            H) long_name="haiku" ;;
                            a) long_name="agent" ;;
                            m) long_name="model" ;;
                            e) long_name="editor-model" ;;
                        esac
                        flag_values[${long_name}]="${agent_args[i]}"
                        parsed_flags+=(--${long_name}="${agent_args[i]}")
                    fi
                    consumed=1
                fi
            fi

            if (( ! consumed )); then
                remaining_args+=("${arg}")
            fi
            (( i++ ))
        done

        agent_args=("${remaining_args[@]}")

        # Configure the agent environment
        _synu_agent_${agent}_configure ${parsed_flags[@]}
        if [[ $? -ne 0 ]]; then
            return 1
        fi
    fi

    # Check if agent provides extra CLI arguments (for agents that don't use env vars)
    local -a extra_args=()
    if (( $+functions[_synu_agent_${agent}_args] )); then
        extra_args=($(_synu_agent_${agent}_args))
    fi

    # Fetch quota before agent execution
    local quota_before
    quota_before=$(_synu_get_quota)
    if [[ $? -ne 0 ]]; then
        # If quota fetch fails, still execute the agent but warn
        print -u2 "Warning: Could not fetch quota before execution"
        quota_before="0 0"
    fi

    # Parse pre-execution quota values
    local requests_before=${quota_before%% *}
    local limit=${quota_before##* }

    # Execute the agent with all arguments passed through unchanged
    # Use 'command' to bypass function recursion and call the actual binary
    # extra_args contains agent-specific CLI flags (e.g., -m for opencode)
    command ${agent} ${extra_args[@]} ${agent_args[@]}
    local exit_status=$?

    # Clean up environment variables set by agent
    if (( $+functions[_synu_agent_${agent}_env_vars] )); then
        local var
        for var in $(_synu_agent_${agent}_env_vars); do
            unset "${var}"
        done
    fi

    # Fetch quota after agent execution
    local quota_after
    quota_after=$(_synu_get_quota)
    if [[ $? -ne 0 ]]; then
        # If quota fetch fails, still exit but warn
        print -u2 "Warning: Could not fetch quota after execution"
        return ${exit_status}
    fi

    # Parse post-execution quota values
    local requests_after=${quota_after%% *}
    # Note: limit is the same before and after, using pre-execution value

    # Calculate session usage: final_requests - initial_requests
    local session_usage=$(( requests_after - requests_before ))

    # Calculate remaining quota: limit - requests_after
    local remaining=$(( limit - requests_after ))

    # Calculate percentage used: (requests_after * 100) / limit
    local percent_used=$(( requests_after * 100.0 / limit ))
    local percent_int remaining_fmt session_fmt
    printf -v percent_int "%.0f" "${percent_used}"
    printf -v remaining_fmt "%.2f" "${remaining}"
    printf -v session_fmt "%.1f" "${session_usage}"

    # Display session usage and remaining quota with color
    # Force a newline first for proper separation from agent output
    printf "\n"
    printf "Session: %s requests\n" "${session_fmt}"
    printf "Overall: "

    # Determine color based on usage percentage
    # Green: <33%, Yellow: 33-66%, Red: >66%
    if (( percent_int < 33 )); then
        print -Pn "%K{green}%F{black}"
    elif (( percent_int < 67 )); then
        print -Pn "%K{yellow}%F{black}"
    else
        print -Pn "%K{red}%F{black}"
    fi
    printf " %s%% " "${percent_int}"
    print -Pn "%k%f"
    printf " (%s/%s remaining)\n" "${remaining_fmt}" "${limit}"

    return ${exit_status}
}
