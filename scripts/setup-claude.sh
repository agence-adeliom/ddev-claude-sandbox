#!/bin/bash
#ddev-generated
# Configure Claude Code with security hooks

set -e

DDEV_DIR="/var/www/html/.ddev"
HOOKS_SOURCE="$DDEV_DIR/claude/hooks"
SCRIPTS_DIR="$DDEV_DIR/scripts"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_CREDENTIALS_FILE="$CLAUDE_DIR/.credentials.json"
PERSISTED_CREDENTIALS_FILE="$DDEV_DIR/claude/credentials.json"
CLAUDE_CONFIG_FILE="$HOME/.claude.json"
PERSISTED_CONFIG_FILE="$DDEV_DIR/claude/claude.json"

# Add ~/.local/bin to PATH
mkdir -p ~/.local/bin
if ! grep -q '.local/bin' ~/.bashrc 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi
export PATH="$HOME/.local/bin:$PATH"

# Function to setup Claude hooks
setup_claude_hooks() {
    local SETTINGS_FILE="$CLAUDE_DIR/settings.json"

    mkdir -p "$CLAUDE_DIR/hooks"

    # Copy and configure hooks based on features enabled
    if [ "${CLAUDE_URL_ALLOWLIST_ENABLED:-true}" = "true" ]; then
        cp "$HOOKS_SOURCE/url-allowlist-check.sh" "$CLAUDE_DIR/hooks/"
        cp "$HOOKS_SOURCE/url-allowlist-add.sh" "$CLAUDE_DIR/hooks/"
        cp "$HOOKS_SOURCE/url-disallowlist-add.sh" "$CLAUDE_DIR/hooks/"
        chmod +x "$CLAUDE_DIR/hooks/url-allowlist-"*.sh
        chmod +x "$CLAUDE_DIR/hooks/url-disallowlist-add.sh"
    fi

    if [ "${CLAUDE_ENV_PROTECTION_ENABLED:-true}" = "true" ]; then
        sed "s|__PROTECTED_FILES__|${CLAUDE_PROTECTED_FILES:-.env.local,.env.*.local}|g" \
            "$HOOKS_SOURCE/env-protection.sh" > "$CLAUDE_DIR/hooks/env-protection.sh"
        chmod +x "$CLAUDE_DIR/hooks/env-protection.sh"
    fi

    # Generate settings.json
    php "$SCRIPTS_DIR/generate-claude-settings.php" \
        --url-allowlist="${CLAUDE_URL_ALLOWLIST_ENABLED:-true}" \
        --env-protection="${CLAUDE_ENV_PROTECTION_ENABLED:-true}" \
        --output="$SETTINGS_FILE"
}

echo "Setting up Claude Code..."

# Symlink binary
ln -sf /opt/claude/bin/claude ~/.local/bin/claude

# Ensure ~/.claude directory exists (uses default location, not tracked by git)
mkdir -p "$CLAUDE_DIR"
mkdir -p "$DDEV_DIR/claude"

# Persist credentials across container restarts via project volume
if [ -f "$CLAUDE_CREDENTIALS_FILE" ] && [ ! -L "$CLAUDE_CREDENTIALS_FILE" ]; then
    mv "$CLAUDE_CREDENTIALS_FILE" "$PERSISTED_CREDENTIALS_FILE"
fi
ln -sf "$PERSISTED_CREDENTIALS_FILE" "$CLAUDE_CREDENTIALS_FILE"

# Persist Claude config across container restarts via project volume
if [ -f "$CLAUDE_CONFIG_FILE" ] && [ ! -L "$CLAUDE_CONFIG_FILE" ]; then
    mv "$CLAUDE_CONFIG_FILE" "$PERSISTED_CONFIG_FILE"
fi
ln -sf "$PERSISTED_CONFIG_FILE" "$CLAUDE_CONFIG_FILE"

# Set native install method
~/.local/bin/claude config set --global installMethod native 2>/dev/null || true

# Setup hooks
setup_claude_hooks

echo "Claude Code ready"
