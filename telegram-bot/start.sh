#!/bin/bash
# DEPRECATED: This custom Telegram bot has been replaced by TinyClaw's built-in Telegram channel.
# Use 'tc-start' to start TinyClaw (includes Telegram support).
# This script is kept for reference only.
echo "DEPRECATED: Use TinyClaw instead. Run 'tc-start' or 'tinyclaw start' inside the container."
echo "See: .devcontainer/PLAN-tinyclaw-integration.md"
exit 1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load .env if exists
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
fi

if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
    echo "Error: TELEGRAM_BOT_TOKEN not set"
    echo "Copy .env.example to .env and configure it"
    exit 1
fi

echo "Starting Claude Telegram Controller..."
exec npx tsx src/index.ts
