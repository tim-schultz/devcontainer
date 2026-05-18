#!/usr/bin/env bash
# Container entrypoint: configure TinyClaw on first boot, auto-start, keep alive
set -e

# HOME is set by docker-compose environment
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/share/npm-global/bin:/usr/local/go/bin:$HOME/go/bin:$PATH"

echo "=== Container starting (HOME=$HOME) ==="

# Ensure codex skill is installed (idempotent — skip if already present)
if [ ! -d "$HOME/.claude/skills/codex" ]; then
    echo "Installing codex skill..."
    SKILLS_TMP=$(mktemp -d)
    if git clone --depth 1 https://github.com/skills-directory/skill-codex.git "$SKILLS_TMP" 2>/dev/null \
        || git clone --depth 1 git@github.com:skills-directory/skill-codex.git "$SKILLS_TMP" 2>/dev/null; then
        mkdir -p "$HOME/.claude/skills"
        cp -r "$SKILLS_TMP/plugins/skill-codex/skills/codex" "$HOME/.claude/skills/codex"
        echo "codex skill installed at $HOME/.claude/skills/codex"
    else
        echo "WARNING: failed to clone skill-codex — codex skill not installed"
    fi
    rm -rf "$SKILLS_TMP"
fi

# First boot: generate TinyClaw settings if they don't exist
if [ ! -f "$HOME/.tinyclaw/settings.json" ]; then
    echo "First boot detected — running TinyClaw setup..."
    "$HOME/tinyclaw-setup.sh"
fi

# Start TinyClaw in the background (creates its own tmux session)
# Only start if channels are configured (at least one token available)
CHANNELS_COUNT=$(jq -r '.channels.enabled | length' "$HOME/.tinyclaw/settings.json" 2>/dev/null || echo "0")
if [ "$CHANNELS_COUNT" -gt 0 ]; then
    echo "Starting TinyClaw daemon..."
    # Small delay to let tmux server initialize
    sleep 1
    tinyclaw start || echo "WARNING: TinyClaw failed to start. Run 'tinyclaw start' manually."
else
    echo "No TinyClaw channels configured — skipping auto-start."
    echo "Run 'tinyclaw setup' inside the container to configure."
fi

echo "=== Container ready ==="

# Keep container alive
exec tail -f /dev/null
