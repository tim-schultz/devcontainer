#!/bin/bash
# Git wrapper that blocks operations that modify remote repositories
# Place in PATH before /usr/bin/git

BLOCKED_COMMANDS=(
    "push"
    "push --force"
    "push -f"
    "push --force-with-lease"
)

BLOCKED_GH_COMMANDS=(
    "pr merge"
    "pr create"
    "pr close"
    "pr reopen"
    "release create"
    "release delete"
    "repo delete"
    "repo create"
)

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get the full command
FULL_CMD="$*"

# Check for blocked git commands
for blocked in "${BLOCKED_COMMANDS[@]}"; do
    if [[ "$FULL_CMD" == "$blocked"* ]]; then
        echo -e "${RED}BLOCKED:${NC} 'git $blocked' is not allowed in this container."
        echo -e "${YELLOW}Reason:${NC} Remote-modifying operations are restricted for safety."
        echo -e "To push changes, exit the container and run from your host machine."
        exit 1
    fi
done

# If not blocked, pass through to real git
exec /usr/bin/git "$@"
