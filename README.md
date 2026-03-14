# Claude Dev Container

Persistent Claude Code sessions in a Docker container. Run multiple Claude instances across any project directory.

Works on Linux and macOS.

## Prerequisites

- Docker and Docker Compose
- Git
- Claude Code API key (set up via `claude` CLI on first run)

## Quick Start

```bash
# Clone and enter
git clone <repo-url>
cd .devcontainer

# First-time setup (detects your OS, home dir, memory)
./setup.sh

# Add aliases to your shell
echo "source $(pwd)/aliases.sh" >> ~/.bashrc  # or ~/.zshrc
source aliases.sh

# Build and start
claude-build
claude-up

# Start a session
cs my-project
```

## What `setup.sh` Does

Generates a `.env` file (git-ignored) with machine-specific values:

| Variable | Example (Linux) | Example (macOS) |
|----------|-----------------|-----------------|
| `HOST_HOME` | `/home/alice` | `/Users/alice` |
| `REPOS_DIR` | `/home/alice/repos` | `/Users/alice/repos` |
| `CONTAINER_MEM` | `28g` | `12g` |
| `DOCKER_SOCK` | `/var/run/docker.sock` | `~/.docker/run/docker.sock` |

Re-run `./setup.sh` any time you move the repo or change machines.

## Commands

### Session Management

| Command | Description |
|---------|-------------|
| `cs <project>` | Start/attach to project session |
| `cs <project> <feature>` | Start/attach to project/feature session |
| `cs-list` | List all active sessions |
| `cs-kill <name>` | Kill a session |
| `cs-remote <project>` | Start remote control session |

### Branch Worktrees

| Command | Description |
|---------|-------------|
| `cs-branch <proj> <branch>` | Session on specific branch |
| `cs-branches <proj>` | List worktrees |
| `cs-branch-rm <proj> <branch>` | Remove worktree |

### TinyClaw (Multi-Agent)

| Command | Description |
|---------|-------------|
| `tc-status` | Agent system status |
| `tc-start` / `tc-stop` | Start/stop TinyClaw |
| `tc-agents` | List agents |
| `tc-teams` | List teams |
| `tc-office` | Start web portal (:3100) |
| `tc-approve <code>` | Approve Telegram sender |

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
cs my-project

# Work on a specific feature
cs my-project api-refactor

# Work on a branch (creates git worktree)
cs-branch my-project feature-xyz

# Check what's running
cs-list

# Kill a session when done
cs-kill my-project/api-refactor
```

## Inside a Session

- **Detach** (keep running): `Ctrl+A`, `D` or `F12`
- **Scroll**: Mouse/trackpad works, or `Ctrl+B`, `[` for copy mode
- **Exit copy mode**: `q` or `Esc`
- **Search in scroll**: `/` then type search term

## Architecture

```
┌─────────────────────────────────────────────────────┐
│  claude-devcontainer                                │
│                                                     │
│  tmux sessions:                                     │
│    - my-project                                     │
│    - my-project/api-refactor                        │
│    - other-project/data-pipeline                    │
│                                                     │
│  $REPOS_DIR  ← mounted from host                   │
│  ~/.claude/  ← shared with host machine             │
│  ~/.tinyclaw/ ← persisted in Docker volume          │
└─────────────────────────────────────────────────────┘
```

- All sessions share one container
- Your `~/.claude` config is shared with the container
- Claude Code runs with `--dangerously-skip-permissions`
- Sessions persist across SSH disconnects
- Git push/PR creation blocked inside container (safety wrappers)

## Persistence

| What | Persisted? |
|------|------------|
| Code files | Yes (mounted from host) |
| Claude config/history | Yes (shared with host `~/.claude`) |
| Bash history | Yes (Docker volume) |
| TinyClaw settings | Yes (Docker volume) |
| tmux sessions | Yes (until container stops) |

## Telegram Setup (Optional)

To enable TinyClaw's Telegram channel:

```bash
# Create the env file
echo "TELEGRAM_BOT_TOKEN=your-token-here" > telegram-bot/.env

# Rebuild to pick up the token
claude-restart
```

## Rebuilding

After changing Dockerfile or docker-compose.yml:

```bash
claude-down
claude-build
claude-up
```

Sessions will be lost on rebuild — reattach to recreate them.

## Files

```
.devcontainer/
├── setup.sh             # First-time setup (generates .env)
├── Dockerfile           # Container definition
├── docker-compose.yml   # Container orchestration
├── claude-session.sh    # Session manager script
├── aliases.sh           # Shell aliases (source in ~/.bashrc)
├── container-entrypoint.sh  # Container boot script
├── tinyclaw-setup.sh    # TinyClaw config generator
├── git-safe.sh          # Git push blocker
├── gh-safe.sh           # GitHub CLI safety wrapper
├── tmux.conf            # Mouse scrolling config
├── motd.sh              # Login message (optional)
├── .env                 # Machine-specific config (git-ignored)
└── telegram-bot/.env    # Telegram token (git-ignored)
```
