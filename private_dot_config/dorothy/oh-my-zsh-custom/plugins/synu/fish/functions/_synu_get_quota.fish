# SPDX-FileCopyrightText: Amolith <amolith@secluded.site>
#
# SPDX-License-Identifier: Unlicense

# Private function to fetch quota from Synthetic API
function _synu_get_quota
    # Check if API key is set
    if not set -q SYNTHETIC_API_KEY
        echo "Error: SYNTHETIC_API_KEY environment variable not set" >&2
        echo "Set it with: set -gx SYNTHETIC_API_KEY your_api_key" >&2
        return 1
    end

    # Fetch quota from API with fresh request (no caching)
    # Use -f to fail silently on HTTP errors, outputting nothing
    set -l response (curl -s -f -H "Authorization: Bearer $SYNTHETIC_API_KEY" \
        "https://api.synthetic.new/v2/quotas" 2>/dev/null)

    # Check if curl failed or response is empty
    if test $status -ne 0 -o -z "$response"
        return 1
    end

    # Parse JSON response safely with jq
    # Use fallback to 0 if field is missing/empty
    set -l requests (echo "$response" | jq -r '.subscription.requests // 0')
    set -l limit (echo "$response" | jq -r '.subscription.limit // 0')

    # Return the values as space-separated string
    echo "$requests $limit"
end
