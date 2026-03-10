# Claude Dev Container

Persistent Claude Code sessions in a Docker container. Run multiple Claude instances across any project in `/home/tam/repos/`.

## Quick Start

```bash
# First time setup
cd /home/tam/repos/.devcontainer
docker-compose build
docker-compose up -d

# Add aliases (one time)
echo 'source /home/tam/repos/.devcontainer/aliases.sh' >> ~/.bashrc
source ~/.bashrc

# Start a session
cs long-running-agents
```

## Commands

### Session Management

| Command | Description |
|---------|-------------|
| `cs <project>` | Start/attach to project session |
| `cs <project> <feature>` | Start/attach to project/feature session |
| `cs-list` | List all active sessions |
| `cs-kill <name>` | Kill a session |

### Container Management

| Command | Description |
|---------|-------------|
| `claude-build` | Build the container |
| `claude-up` | Start the container |
| `claude-down` | Stop the container |
| `claude-restart` | Restart the container |
| `claude-status` | Check container status |
| `claude-shell` | Open shell in container |
| `claude-logs` | View container logs |

## Examples

```bash
# Work on a project
cs long-running-agents

# Work on a specific feature
cs long-running-agents api-refactor
cs polymarket data-pipeline

# Check what's running
cs-list
# Output:
#   long-running-agents/api-refactor  (created Sat Dec 28)
#   polymarket/data-pipeline          (created Sat Dec 28)

# Reattach to a session
cs long-running-agents api-refactor

# Kill a session when done
cs-kill long-running-agents/api-refactor
```

## Inside a Session

- **Detach** (keep running): `Ctrl+B`, then `D`
- **Scroll**: Mouse/trackpad works, or `Ctrl+B`, `[` for copy mode
- **Exit copy mode**: `q` or `Esc`
- **Search in scroll**: `/` then type search term

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  claude-devcontainer                                │
│                                                     │
│  tmux sessions:                                     │
│    - long-running-agents                            │
│    - long-running-agents/api-refactor               │
│    - polymarket/data-pipeline                       │
│                                                     │
│  /workspace/ ← /home/tam/repos mounted here         │
│  ~/.claude/  ← shared with host machine             │
└─────────────────────────────────────────────────────┘
```

- All sessions share one container
- Your `~/.claude` config is shared with the container
- Claude Code runs with `--dangerously-skip-permissions`
- Sessions persist across SSH disconnects

## Persistence

| What | Persisted? |
|------|------------|
| Code files | Yes (mounted from host) |
| Claude config/history | Yes (shared with host `~/.claude`) |
| Bash history | Yes (Docker volume) |
| tmux sessions | Yes (until container stops) |

## Rebuilding

After changing Dockerfile or docker-compose.yml:

```bash
claude-down
claude-build
claude-up
```

Sessions will be lost on rebuild - reattach to recreate them.

## Files

```
.devcontainer/
├── Dockerfile           # Container definition
├── docker-compose.yml   # Container orchestration
├── claude-session.sh    # Session manager script
├── aliases.sh           # Bash aliases
├── tmux.conf            # Mouse scrolling config
└── README.md            # This file
```
