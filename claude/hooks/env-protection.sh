#!/bin/bash
#ddev-generated
# PreToolUse hook: Block access to protected environment files

PROTECTED_PATTERNS="__PROTECTED_FILES__"

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')

is_protected() {
    local path="$1"
    local basename=$(basename "$path" 2>/dev/null)

    IFS=',' read -ra PATTERNS <<< "$PROTECTED_PATTERNS"
    for pattern in "${PATTERNS[@]}"; do
        pattern=$(echo "$pattern" | xargs)
        if [[ "$basename" == $pattern ]] || [[ "$path" == *"$pattern"* ]]; then
            return 0
        fi
    done
    return 1
}

case "$TOOL_NAME" in
    "Read")
        FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
        if is_protected "$FILE_PATH"; then
            jq -n '{
                hookSpecificOutput: {
                    hookEventName: "PreToolUse",
                    permissionDecision: "block",
                    permissionDecisionReason: "Protected file. Use `ddev agent-env <command>` to run with secrets."
                }
            }'
            exit 0
        fi
        ;;
    "Bash")
        COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
        READ_COMMANDS="cat|head|tail|less|more|grep|awk|sed"

        IFS=',' read -ra PATTERNS <<< "$PROTECTED_PATTERNS"
        for pattern in "${PATTERNS[@]}"; do
            pattern=$(echo "$pattern" | xargs)
            if echo "$COMMAND" | grep -qE "($READ_COMMANDS).*$pattern"; then
                jq -n '{
                    hookSpecificOutput: {
                        hookEventName: "PreToolUse",
                        permissionDecision: "block",
                        permissionDecisionReason: "Cannot read protected files. Use `ddev agent-env <command>`."
                    }
                }'
                exit 0
            fi
        done
        ;;
esac

exit 0
