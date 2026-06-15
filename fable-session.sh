#!/bin/bash
# Fable session manager — sibling of claude-session.sh (cs) and codex-session.sh (cx).
#
# Launches Claude with the Fable model (`claude --model claude-fable-5`) inside the
# shared devcontainer. Sessions get a "~fable" suffix so they coexist with Claude
# (cs) and Codex (cx) sessions in the same tmux server without colliding.
#
# In the planner→implementer workflow, Fable is the PLANNER: pass a shared notebook
# topic as the 3rd arg and it binds to /home/tam/repos/.shared/notebook/<topic>.md,
# which cs/cx implementer sessions read from. See notebook-context.sh.
#
# Usage (all subcommands delegate to claude-session.sh):
#   ./fable-session.sh <project> [topic]            Start/attach to a Fable session
#   ./fable-session.sh list                         List active ~fable sessions
#   ./fable-session.sh kill <session-name>          Kill a session
#   ./fable-session.sh branch <project> <branch>    Worktree session on a branch
#
# Examples:
#   ./fable-session.sh polymarket                 → session: polymarket~fable
#   ./fable-session.sh polymarket auth-refactor   → session: polymarket/auth-refactor~fable
#                                                    bound to notebook topic "auth-refactor"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export CS_MODEL="claude-fable-5"
export CS_SUFFIX="~fable"

exec "$SCRIPT_DIR/claude-session.sh" "$@"
