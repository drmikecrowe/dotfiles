# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

# Cache management for synu model preferences
# File format: agent.slot = model_id (one per line, # comments allowed)

typeset -g _SYNU_CACHE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/synu/models.conf"

_synu_cache_get() {
    local agent=$1
    local slot=$2
    local key="${agent}.${slot}"

    if [[ ! -f "${_SYNU_CACHE_FILE}" ]]; then
        return 1
    fi

    # Match "key = value" or "key=value", ignoring comments and whitespace
    local line value
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "${line}" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line}" ]] && continue

        if [[ "${line}" =~ ^${key}[[:space:]]*=[[:space:]]*(.+)$ ]]; then
            value="${match[1]}"
            # Trim whitespace
            echo "${value## }"
            return 0
        fi
    done < "${_SYNU_CACHE_FILE}"

    return 1
}

_synu_cache_set() {
    local agent=$1
    local slot=$2
    local value=$3
    local key="${agent}.${slot}"

    # Ensure directory exists
    mkdir -p "${_SYNU_CACHE_FILE:h}"

    if [[ ! -f "${_SYNU_CACHE_FILE}" ]]; then
        # Create new file with header
        cat > "${_SYNU_CACHE_FILE}" <<'EOF'
# synu model preferences
# Format: agent.slot = model_id

EOF
    fi

    # Check if key already exists
    if grep -q "^${key}[[:space:]]*=" "${_SYNU_CACHE_FILE}" 2>/dev/null; then
        # Replace existing line
        local tmp=$(mktemp)
        sed "s|^${key}[[:space:]]*=.*|${key} = ${value}|" "${_SYNU_CACHE_FILE}" > "${tmp}"
        mv "${tmp}" "${_SYNU_CACHE_FILE}"
    else
        # Append new line
        echo "${key} = ${value}" >> "${_SYNU_CACHE_FILE}"
    fi
}
