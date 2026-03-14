#!/usr/bin/env bash
# Container entrypoint: configure TinyClaw on first boot, auto-start, keep alive
set -e

# Ensure PATH includes user-installed binaries (tinyclaw, claude, etc.)
export PATH="/home/tam/.local/bin:/home/tam/.cargo/bin:/usr/local/share/npm-global/bin:/usr/local/go/bin:/home/tam/go/bin:$PATH"
export HOME=/home/tam

echo "=== Container starting ==="

# First boot: generate TinyClaw settings if they don't exist
if [ ! -f /home/tam/.tinyclaw/settings.json ]; then
    echo "First boot detected — running TinyClaw setup..."
    /home/tam/tinyclaw-setup.sh
fi

# Start TinyClaw in the background (creates its own tmux session)
# Only start if channels are configured (at least one token available)
CHANNELS_COUNT=$(jq -r '.channels.enabled | length' /home/tam/.tinyclaw/settings.json 2>/dev/null || echo "0")
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
