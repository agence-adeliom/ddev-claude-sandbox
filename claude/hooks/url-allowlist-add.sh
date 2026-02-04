#!/bin/bash
#ddev-generated
# PostToolUse hook: Add domain to allowlist after successful execution

URLLIST_FILE="$CLAUDE_PROJECT_DIR/.ddev/claude/url-list.json"

# Read input from stdin
INPUT=$(cat)

# Get tool name and extract URL
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')

extract_url() {
    local url=""

    if [ "$TOOL_NAME" = "WebFetch" ]; then
        url=$(echo "$INPUT" | jq -r '.tool_input.url // empty')
    elif [ "$TOOL_NAME" = "Bash" ]; then
        local command=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
        # Extract URL from curl command
        url=$(echo "$command" | grep -oE 'https?://[^"'"'"'\s]+' | head -1)
    fi

    echo "$url"
}

extract_domain() {
    local url="$1"
    # Extract domain from URL (protocol://domain/path -> domain)
    echo "$url" | sed -E 's|^https?://||' | sed -E 's|/.*||' | sed -E 's|:.*||'
}

# Extract URL and domain
URL=$(extract_url)
DOMAIN=$(extract_domain "$URL")

# If no URL found, nothing to do
if [ -z "$URL" ] || [ -z "$DOMAIN" ]; then
    exit 0
fi

# Initialize url-list file if it doesn't exist
if [ ! -f "$URLLIST_FILE" ]; then
    echo '{"allowlist": [], "disallowlist": []}' > "$URLLIST_FILE"
fi

# Check if domain is already in allowlist
DOMAIN_ALLOWED=$(jq -r --arg domain "$DOMAIN" '.allowlist | map(select(. == $domain)) | length > 0' "$URLLIST_FILE")

if [ "$DOMAIN_ALLOWED" = "false" ]; then
    # Add domain to allowlist
    jq --arg domain "$DOMAIN" '.allowlist += [$domain] | .allowlist |= unique' "$URLLIST_FILE" > "${URLLIST_FILE}.tmp"
    mv "${URLLIST_FILE}.tmp" "$URLLIST_FILE"

    # Output confirmation (will be shown in debug mode)
    echo "Added domain '$DOMAIN' to allowlist" >&2
fi

exit 0
