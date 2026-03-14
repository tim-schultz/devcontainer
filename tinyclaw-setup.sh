#!/usr/bin/env bash
# Non-interactive TinyClaw configuration generator
# Generates ~/.tinyclaw/settings.json on first boot
set -e

# HOME is set by docker-compose environment
SETTINGS_FILE="$HOME/.tinyclaw/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    echo "TinyClaw settings already exist at $SETTINGS_FILE"
    exit 0
fi

echo "Generating TinyClaw settings..."

mkdir -p "$HOME/.tinyclaw"

# REPOS_DIR is set by docker-compose environment
REPOS="${REPOS_DIR:-$HOME/repos}"

# Read Telegram bot token from the .env file (not from container env, to avoid leaking to other processes)
TELEGRAM_TOKEN=""
ENV_FILE="$REPOS/.devcontainer/telegram-bot/.env"
if [ -f "$ENV_FILE" ]; then
    TELEGRAM_TOKEN=$(grep -E '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '[:space:]')
fi

# Build channels config based on available tokens
if [ -n "$TELEGRAM_TOKEN" ]; then
    CHANNELS_ENABLED='["telegram"]'
    TELEGRAM_CONFIG="\"telegram\": { \"bot_token\": \"$TELEGRAM_TOKEN\" }"
else
    CHANNELS_ENABLED='[]'
    TELEGRAM_CONFIG="\"telegram\": {}"
fi

cat > "$SETTINGS_FILE" <<EOF
{
  "channels": {
    "enabled": $CHANNELS_ENABLED,
    $TELEGRAM_CONFIG
  },
  "workspace": {
    "path": "$REPOS",
    "name": "repos"
  },
  "agents": {
    "default": {
      "name": "Default Agent",
      "provider": "anthropic",
      "model": "sonnet",
      "working_directory": "$REPOS/default",
      "system_prompt": "You are a routing agent in a devcontainer at $REPOS. All projects are already set up — do NOT attempt to install, configure, or scaffold anything. On first message, run 'ls $REPOS' to see available projects. Wait for the user to tell you which project to work on. Keep responses brief.\n\nIMPORTANT: Your HOME is $HOME (NOT /home/node). Never write files to /home/node.\n\nShared files: Use $REPOS/.shared/ for any files that need to be visible to other agents or the user. Plans go in $REPOS/.shared/plans/. Project-specific files stay in the project directory under $REPOS/<project>/."
    }
  },
  "teams": {},
  "models": {
    "anthropic": {}
  },
  "monitoring": {
    "heartbeat_interval": 3600
  }
}
EOF

echo "TinyClaw settings written to $SETTINGS_FILE"

if [ -z "$TELEGRAM_TOKEN" ]; then
    echo "WARNING: TELEGRAM_BOT_TOKEN not set. Telegram channel disabled."
    echo "Set it in your host environment and restart, or run 'tinyclaw setup' inside the container."
fi
