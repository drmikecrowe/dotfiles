# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

# Private function to fetch quota from Synthetic API

_synu_get_quota() {
    # Check if API key is set
    if [[ -z "${SYNTHETIC_API_KEY}" ]]; then
        print -u2 "Error: SYNTHETIC_API_KEY environment variable not set"
        print -u2 "Set it with: export SYNTHETIC_API_KEY=your_api_key"
        return 1
    fi

    # Fetch quota from API with fresh request (no caching)
    local response
    response=$(curl -s -f -H "Authorization: Bearer ${SYNTHETIC_API_KEY}" \
        "https://api.synthetic.new/v2/quotas" 2>/dev/null)

    # Check if curl failed or response is empty
    if [[ $? -ne 0 || -z "${response}" ]]; then
        return 1
    fi

    # Parse JSON response safely with jq
    # Use fallback to 0 if field is missing/empty
    local requests limit
    requests=$(echo "${response}" | jq -r '.subscription.requests // 0')
    limit=$(echo "${response}" | jq -r '.subscription.limit // 0')

    # Return the values as space-separated string
    echo "${requests} ${limit}"
}
