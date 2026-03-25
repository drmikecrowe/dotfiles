# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

function synu --description "Universal agent wrapper with Synthetic API quota tracking"
    # If no arguments, just print the quota
    if test (count $argv) -lt 1
        set -l quota (_synu_get_quota)
        if test $status -ne 0
            echo "Error: Could not fetch quota" >&2
            return 1
        end
        set -l requests (echo "$quota" | cut -d' ' -f1)
        set -l limit (echo "$quota" | cut -d' ' -f2)
        set -l remaining (math "$limit - $requests")
        set -l percent_used (math -s0 "$requests * 100 / $limit")
        printf "Usage: "
        if test $percent_used -lt 33
            set_color -b green black
        else if test $percent_used -lt 67
            set_color -b yellow black
        else
            set_color -b red black
        end
        printf " %s%% " $percent_used
        set_color normal
        printf " (%s/%s remaining)\n" $remaining $limit
        return 0
    end

    # Check for interactive mode: synu i <agent> [args...]
    if test "$argv[1]" = "i"
        if test (count $argv) -lt 2
            echo "Error: Interactive mode requires an agent name" >&2
            echo "Usage: synu i <agent> [args...]" >&2
            return 1
        end

        set -l agent $argv[2]
        set -l agent_args $argv[3..-1]

        # Source agent definition if it exists
        set -l agent_file (status dirname)/_synu_agents/$agent.fish
        if test -f "$agent_file"
            source $agent_file
        end

        # Check for interactive function
        if not functions -q _synu_agent_{$agent}_interactive
            echo "Error: Agent '$agent' does not support interactive mode" >&2
            return 1
        end

        # Get flags from interactive selection
        set -l interactive_flags (_synu_agent_{$agent}_interactive)
        set -l interactive_status $status
        if test $interactive_status -ne 0
            return $interactive_status
        end

        # Recursively call synu with selected flags
        synu $agent $interactive_flags $agent_args
        return $status
    end

    # Extract agent name (first argument) and remaining args
    set -l agent $argv[1]
    set -l agent_args $argv[2..-1]

    # Source agent definition if it exists
    set -l agent_file (status dirname)/_synu_agents/$agent.fish
    if test -f "$agent_file"
        source $agent_file
    end

    # Check if agent has a configuration function
    if functions -q _synu_agent_{$agent}_configure
        # Get flag specification
        set -l flag_spec (_synu_agent_{$agent}_flags)

        # Parse flags using agent's spec, ignoring unknown flags for passthrough
        # We need to capture which flags were set to pass to configure
        set -l parsed_args
        if test -n "$flag_spec"
            # Parse with --ignore-unknown so agent-native flags pass through
            # @fish-lsp-disable-next-line 4004
            argparse --ignore-unknown $flag_spec -- $agent_args
            or return 1

            # argv now contains non-flag args after argparse
            set agent_args $argv

            # Rebuild the flag arguments to pass to configure
            # Check each possible flag and add if set
            for flag in L/large l/light o/opus s/sonnet H/haiku a/agent m/model
                set -l long_flag (string split '/' $flag)[2]
                set -l var_name _flag_$long_flag
                if set -q $var_name
                    set parsed_args $parsed_args --$long_flag=$$var_name
                end
            end
        end

        # Configure the agent environment
        _synu_agent_{$agent}_configure $parsed_args
        or return 1
    end

    # Check if agent provides extra CLI arguments (for agents that don't use env vars)
    set -l extra_args
    if functions -q _synu_agent_{$agent}_args
        set extra_args (_synu_agent_{$agent}_args)
    end

    # Fetch quota before agent execution
    set -l quota_before (_synu_get_quota)
    if test $status -ne 0
        # If quota fetch fails, still execute the agent but warn
        echo "Warning: Could not fetch quota before execution" >&2
        # Set default values if quota fetch fails
        set -l quota_before "0 0"
    end

    # Parse pre-execution quota values
    set -l requests_before (echo "$quota_before" | cut -d' ' -f1)
    set -l limit (echo "$quota_before" | cut -d' ' -f2)

    # Execute the agent with all arguments passed through unchanged
    # Use 'command' to bypass function recursion and call the actual binary
    # extra_args contains agent-specific CLI flags (e.g., -m for opencode)
    command $agent $extra_args $agent_args
    set -l exit_status $status

    # Clean up environment variables set by agent
    if functions -q _synu_agent_{$agent}_env_vars
        for var in (_synu_agent_{$agent}_env_vars)
            set -e $var
        end
    end

    # Fetch quota after agent execution
    set -l quota_after (_synu_get_quota)
    if test $status -ne 0
        # If quota fetch fails, still exit but warn
        echo "Warning: Could not fetch quota after execution" >&2
        return $exit_status
    end

    # Parse post-execution quota values
    set -l requests_after (echo "$quota_after" | cut -d' ' -f1)
    # Note: limit is the same before and after, using pre-execution value

    # Calculate session usage: final_requests - initial_requests
    set -l session_usage (math "$requests_after - $requests_before")

    # Calculate remaining quota: limit - requests_after
    set -l remaining (math "$limit - $requests_after")

    # Calculate percentage used: (requests_after * 100) / limit
    set -l percent_used (math -s0 "$requests_after * 100 / $limit")

    # Display session usage and remaining quota with color
    # Force a newline first for proper separation from agent output
    printf "\n"
    printf "Session: %s requests\n" $session_usage
    printf "Overall: "

    # Determine color based on usage percentage
    # Green: <33%, Yellow: 33-66%, Red: >66%
    if test $percent_used -lt 33
        set_color -b green black
    else if test $percent_used -lt 67
        set_color -b yellow black
    else
        set_color -b red black
    end
    printf " %s%% " $percent_used
    set_color normal
    printf " (%s/%s remaining)\n" $remaining $limit

    return $exit_status
end
