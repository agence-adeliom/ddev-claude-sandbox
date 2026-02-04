#!/bin/bash
#ddev-generated
# Script to add a domain to the disallowlist
# Usage: url-disallowlist-add.sh <domain>

URLLIST_FILE="$CLAUDE_PROJECT_DIR/.ddev/claude/url-list.json"

DOMAIN="$1"

if [ -z "$DOMAIN" ]; then
    echo "Usage: url-disallowlist-add.sh <domain>" >&2
    exit 1
fi

# Initialize url-list file if it doesn't exist
if [ ! -f "$URLLIST_FILE" ]; then
    echo '{"allowlist": [], "disallowlist": []}' > "$URLLIST_FILE"
fi

# Check if domain is already in disallowlist
DOMAIN_DISALLOWED=$(jq -r --arg domain "$DOMAIN" '.disallowlist | map(select(. == $domain)) | length > 0' "$URLLIST_FILE")

if [ "$DOMAIN_DISALLOWED" = "true" ]; then
    echo "Domain '$DOMAIN' is already in disallowlist"
    exit 0
fi

# Remove from allowlist if present
jq --arg domain "$DOMAIN" '.allowlist -= [$domain]' "$URLLIST_FILE" > "${URLLIST_FILE}.tmp"
mv "${URLLIST_FILE}.tmp" "$URLLIST_FILE"

# Add domain to disallowlist
jq --arg domain "$DOMAIN" '.disallowlist += [$domain] | .disallowlist |= unique' "$URLLIST_FILE" > "${URLLIST_FILE}.tmp"
mv "${URLLIST_FILE}.tmp" "$URLLIST_FILE"

echo "Added domain '$DOMAIN' to disallowlist"
exit 0
