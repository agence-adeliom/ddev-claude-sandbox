#!/bin/bash
#ddev-generated
# PreToolUse hook: Check if URL/domain is in allowlist/disallowlist before allowing curl or WebFetch

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
        # Handles: curl URL, curl "URL", curl 'URL', curl -X GET URL, etc.
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

# If no URL found, let it pass through normally
if [ -z "$URL" ] || [ -z "$DOMAIN" ]; then
    exit 0
fi

# Initialize url-list file if it doesn't exist
if [ ! -f "$URLLIST_FILE" ]; then
    echo '{"allowlist": [], "disallowlist": []}' > "$URLLIST_FILE"
fi

# Check disallowlist first
DOMAIN_DISALLOWED=$(jq -r --arg domain "$DOMAIN" '.disallowlist | map(select(. == $domain)) | length > 0' "$URLLIST_FILE")

if [ "$DOMAIN_DISALLOWED" = "true" ]; then
    # Domain is disallowed - auto-deny
    jq -n --arg domain "$DOMAIN" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: ("Domain is disallowed: " + $domain + ". This domain was previously refused. You can still use WebFetch/curl for OTHER domains.")
        }
    }'
    exit 0
fi

# Check allowlist
DOMAIN_ALLOWED=$(jq -r --arg domain "$DOMAIN" '.allowlist | map(select(. == $domain)) | length > 0' "$URLLIST_FILE")

if [ "$DOMAIN_ALLOWED" = "true" ]; then
    # Domain is allowed - auto-approve
    jq -n '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "allow",
            permissionDecisionReason: "Domain is in allowlist"
        }
    }'
else
    # Not in any list - ask for permission
    # If approved: PostToolUse hook will add to allowlist
    # If refused: user should tell Claude to disallow this domain
    jq -n --arg domain "$DOMAIN" '{
        hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "ask",
            permissionDecisionReason: ("New domain: " + $domain + ". If approved, it will be added to allowlist. If refused, ask user if they want to disallow it. Note: refusing this domain does NOT prevent using WebFetch for other domains.")
        }
    }'
fi
