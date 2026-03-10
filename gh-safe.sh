#!/bin/bash
# GitHub CLI wrapper that blocks operations that modify remote repositories

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

FULL_CMD="$*"

# Blocked gh commands that modify remote state
BLOCKED_PATTERNS=(
    "pr merge"
    "pr create"
    "pr close"
    "pr reopen"
    "pr edit"
    "release create"
    "release delete"
    "release edit"
    "repo delete"
    "repo create"
    "repo edit"
    "repo rename"
    "issue create"
    "issue close"
    "issue reopen"
    "issue delete"
    "issue edit"
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
    if [[ "$FULL_CMD" == "$pattern"* ]]; then
        echo -e "${RED}BLOCKED:${NC} 'gh $pattern' is not allowed in this container."
        echo -e "${YELLOW}Reason:${NC} Remote-modifying operations are restricted for safety."
        echo -e "To perform this action, exit the container and run from your host machine."
        exit 1
    fi
done

# If not blocked, pass through to real gh
exec /usr/bin/gh "$@"
