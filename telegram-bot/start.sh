#!/bin/bash
# Start the Claude Dev Container Telegram bot
# Runs on the host machine (not inside the container)

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
