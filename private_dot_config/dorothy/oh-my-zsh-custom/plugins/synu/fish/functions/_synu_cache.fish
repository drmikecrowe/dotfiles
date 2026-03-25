# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

# Cache management for synu model preferences
# File format: agent.slot = model_id (one per line, # comments allowed)

set -g _synu_cache_file (set -q XDG_CONFIG_HOME; and echo "$XDG_CONFIG_HOME"; or echo "$HOME/.config")"/synu/models.conf"

function _synu_cache_get --description "Get a cached value: _synu_cache_get agent slot"
    set -l agent $argv[1]
    set -l slot $argv[2]
    set -l key "$agent.$slot"

    if not test -f "$_synu_cache_file"
        return 1
    end

    # Match "key = value" or "key=value", ignoring comments and whitespace
    set -l match (string match -r "^$key\\s*=\\s*(.+)" < "$_synu_cache_file")
    if test -n "$match[2]"
        string trim "$match[2]"
        return 0
    end
    return 1
end

function _synu_cache_set --description "Set a cached value: _synu_cache_set agent slot value"
    set -l agent $argv[1]
    set -l slot $argv[2]
    set -l value $argv[3]
    set -l key "$agent.$slot"

    # Ensure directory exists
    mkdir -p (dirname "$_synu_cache_file")

    if not test -f "$_synu_cache_file"
        # Create new file with header
        echo "# synu model preferences" > "$_synu_cache_file"
        echo "# Format: agent.slot = model_id" >> "$_synu_cache_file"
        echo "" >> "$_synu_cache_file"
    end

    # Check if key already exists
    if string match -rq "^$key\\s*=" < "$_synu_cache_file"
        # Replace existing line
        set -l tmp (mktemp)
        string replace -r "^$key\\s*=.*" "$key = $value" < "$_synu_cache_file" > "$tmp"
        mv "$tmp" "$_synu_cache_file"
    else
        # Append new line
        echo "$key = $value" >> "$_synu_cache_file"
    end
end
