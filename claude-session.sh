#!/bin/bash
# Claude Code session manager
#
# Usage:
#   ./claude-session.sh <project> [feature]     Start/attach to session
#   ./claude-session.sh remote <project> [feature]  Start remote control session
#   ./claude-session.sh list                    List all sessions
#   ./claude-session.sh kill <session-name>     Kill a session
#
# Examples:
#   ./claude-session.sh long-running-agents           → session: long-running-agents
#   ./claude-session.sh long-running-agents api-fix   → session: long-running-agents/api-fix
#   ./claude-session.sh polymarket data-pipeline      → session: polymarket/data-pipeline
#   ./claude-session.sh list
#   ./claude-session.sh kill long-running-agents/api-fix

CONTAINER_NAME="claude-devcontainer"

# Derive paths from script location (portable across machines)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

# Optional overrides (set by sibling launchers like fable-session.sh):
#   CS_MODEL   — passed as `claude --model <CS_MODEL>` (empty = default model)
#   CS_SUFFIX  — appended to every tmux session name so variants coexist (e.g. ~fable)
# Defaults keep plain `cs` behavior unchanged.
CS_MODEL="${CS_MODEL:-}"
CS_SUFFIX="${CS_SUFFIX:-}"

if [ -n "$CS_MODEL" ]; then
    LAUNCH_CMD="claude --model $CS_MODEL --dangerously-skip-permissions"
else
    LAUNCH_CMD="claude --dangerously-skip-permissions"
fi

# Build the env prefix that binds a session to a shared notebook topic.
# The notebook-context.sh SessionStart hook reads $NB_TOPIC to surface the
# shared file and the session's role. No topic → no prefix (behavior unchanged).
topic_env() {
    local topic="$1"
    [ -n "$topic" ] && printf "NB_TOPIC='%s' " "$topic"
}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ensure_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}Starting container...${NC}"
        docker compose -f "$COMPOSE_FILE" up -d
        sleep 2
    fi
}

list_sessions() {
    ensure_container
    # When launched as a suffixed variant (e.g. fb → ~fable), only show that
    # variant's sessions. Plain `cs` (no suffix) shows the unsuffixed Claude
    # sessions and hides ~codex/~fable siblings.
    if [ -n "$CS_SUFFIX" ]; then
        echo -e "${BLUE}Active Claude sessions (${CS_SUFFIX}):${NC}"
    else
        echo -e "${BLUE}Active Claude sessions:${NC}"
    fi
    echo ""
    local found=0
    while IFS= read -r line; do
        session_name=$(echo "$line" | cut -d: -f1)
        if [ -n "$CS_SUFFIX" ]; then
            # Show only sessions carrying this suffix
            [[ "$session_name" == *"$CS_SUFFIX"* ]] || continue
        else
            # Plain cs: hide sibling launchers' suffixed sessions
            [[ "$session_name" == *"~codex"* || "$session_name" == *"~fable"* ]] && continue
        fi
        created=$(echo "$line" | grep -o '(created [^)]*)')
        echo -e "  ${GREEN}$session_name${NC}  $created"
        found=1
    done < <(docker exec $CONTAINER_NAME tmux list-sessions 2>/dev/null)
    if [ "$found" -eq 0 ]; then
        echo -e "  ${YELLOW}No active sessions${NC}"
    fi
    echo ""
    echo "Attach with: cs <project> [topic]"
}

kill_session() {
    local session_name=$1
    # For suffixed variants (e.g. fb), allow the user to omit the suffix
    if [ -n "$CS_SUFFIX" ] && [[ "$session_name" != *"$CS_SUFFIX"* ]]; then
        session_name="${session_name}${CS_SUFFIX}"
    fi
    ensure_container
    if docker exec $CONTAINER_NAME tmux has-session -t "=$session_name" 2>/dev/null; then
        docker exec $CONTAINER_NAME tmux kill-session -t "=$session_name"
        echo -e "${GREEN}Killed session: $session_name${NC}"
    else
        echo -e "${YELLOW}Session not found: $session_name${NC}"
    fi
}

start_or_attach() {
    local project=$1
    local feature=$2

    # Build session name
    if [ -n "$feature" ]; then
        SESSION_NAME="${project}/${feature}${CS_SUFFIX}"
    else
        SESSION_NAME="${project}${CS_SUFFIX}"
    fi

    ensure_container

    # Check if project directory exists
    if ! docker exec $CONTAINER_NAME test -d "$REPOS_DIR/$project"; then
        echo -e "${YELLOW}Warning: $REPOS_DIR/$project does not exist${NC}"
        echo "Available projects:"
        docker exec $CONTAINER_NAME ls "$REPOS_DIR" | head -20
        exit 1
    fi

    # Check if tmux session exists
    if docker exec $CONTAINER_NAME tmux has-session -t "=$SESSION_NAME" 2>/dev/null; then
        echo -e "${GREEN}Attaching to existing session: $SESSION_NAME${NC}"
        docker exec -it $CONTAINER_NAME tmux attach -t "=$SESSION_NAME"
    else
        echo -e "${GREEN}Creating new session: $SESSION_NAME${NC}"
        echo -e "${BLUE}Project: $REPOS_DIR/$project${NC}"
        [ -n "$feature" ] && echo -e "${BLUE}Notebook topic: $feature${NC}"
        docker exec -it $CONTAINER_NAME tmux new-session -s "$SESSION_NAME" -c "$REPOS_DIR/$project" "$(topic_env "$feature")${LAUNCH_CMD}; zsh"
    fi
}

# Create or attach to a worktree session for a specific branch
start_worktree_session() {
    local project=$1
    local branch=$2

    if [ -z "$branch" ]; then
        echo "Usage: cs-branch <project> <branch>"
        exit 1
    fi

    SESSION_NAME="${project}@${branch}${CS_SUFFIX}"
    WORKTREE_DIR="$REPOS_DIR/${project}-${branch}"
    PROJECT_DIR="$REPOS_DIR/${project}"

    ensure_container

    # Check if main project exists
    if ! docker exec $CONTAINER_NAME test -d "$PROJECT_DIR/.git"; then
        echo -e "${YELLOW}Error: $PROJECT_DIR is not a git repository${NC}"
        exit 1
    fi

    # Create worktree if it doesn't exist
    if ! docker exec $CONTAINER_NAME test -d "$WORKTREE_DIR"; then
        echo -e "${BLUE}Creating worktree for branch: $branch${NC}"

        # Check if branch exists
        if ! docker exec $CONTAINER_NAME git -C "$PROJECT_DIR" rev-parse --verify "$branch" >/dev/null 2>&1; then
            echo -e "${YELLOW}Branch '$branch' doesn't exist. Create it? (y/n)${NC}"
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                docker exec $CONTAINER_NAME git -C "$PROJECT_DIR" worktree add -b "$branch" "$WORKTREE_DIR"
            else
                exit 1
            fi
        else
            docker exec $CONTAINER_NAME git -C "$PROJECT_DIR" worktree add "$WORKTREE_DIR" "$branch"
        fi
    fi

    # Check if tmux session exists
    if docker exec $CONTAINER_NAME tmux has-session -t "=$SESSION_NAME" 2>/dev/null; then
        echo -e "${GREEN}Attaching to existing session: $SESSION_NAME${NC}"
        docker exec -it $CONTAINER_NAME tmux attach -t "=$SESSION_NAME"
    else
        echo -e "${GREEN}Creating new session: $SESSION_NAME${NC}"
        echo -e "${BLUE}Worktree: $WORKTREE_DIR${NC}"
        echo -e "${BLUE}Branch: $branch${NC}"
        docker exec -it $CONTAINER_NAME tmux new-session -s "$SESSION_NAME" -c "$WORKTREE_DIR" "${LAUNCH_CMD}; zsh"
    fi
}

# List worktrees for a project
list_worktrees() {
    local project=$1
    PROJECT_DIR="$REPOS_DIR/${project}"

    ensure_container

    if [ -z "$project" ]; then
        echo "Usage: cs-branches <project>"
        exit 1
    fi

    echo -e "${BLUE}Worktrees for $project:${NC}"
    echo ""
    docker exec $CONTAINER_NAME git -C "$PROJECT_DIR" worktree list 2>/dev/null || echo "No worktrees found"
}

# Remove a worktree
remove_worktree() {
    local project=$1
    local branch=$2

    if [ -z "$branch" ]; then
        echo "Usage: cs-branch-rm <project> <branch>"
        exit 1
    fi

    WORKTREE_DIR="$REPOS_DIR/${project}-${branch}"
    PROJECT_DIR="$REPOS_DIR/${project}"
    SESSION_NAME="${project}@${branch}${CS_SUFFIX}"

    ensure_container

    # Kill tmux session if exists
    if docker exec $CONTAINER_NAME tmux has-session -t "=$SESSION_NAME" 2>/dev/null; then
        echo -e "${YELLOW}Killing session: $SESSION_NAME${NC}"
        docker exec $CONTAINER_NAME tmux kill-session -t "=$SESSION_NAME"
    fi

    # Remove worktree
    if docker exec $CONTAINER_NAME test -d "$WORKTREE_DIR"; then
        echo -e "${YELLOW}Removing worktree: $WORKTREE_DIR${NC}"
        docker exec $CONTAINER_NAME git -C "$PROJECT_DIR" worktree remove "$WORKTREE_DIR" --force
        echo -e "${GREEN}Worktree removed${NC}"
    else
        echo -e "${YELLOW}Worktree not found: $WORKTREE_DIR${NC}"
    fi
}

start_remote() {
    local project=$1
    local feature=$2

    # Build session name with ~rc suffix to distinguish from regular sessions
    if [ -n "$feature" ]; then
        SESSION_NAME="${project}/${feature}${CS_SUFFIX}~rc"
    else
        SESSION_NAME="${project}${CS_SUFFIX}~rc"
    fi

    ensure_container

    # Check if project directory exists
    if ! docker exec $CONTAINER_NAME test -d "$REPOS_DIR/$project"; then
        echo -e "${YELLOW}Warning: $REPOS_DIR/$project does not exist${NC}"
        echo "Available projects:"
        docker exec $CONTAINER_NAME ls "$REPOS_DIR" | head -20
        exit 1
    fi

    # Check if tmux session exists
    if docker exec $CONTAINER_NAME tmux has-session -t "=$SESSION_NAME" 2>/dev/null; then
        echo -e "${GREEN}Attaching to existing session: $SESSION_NAME${NC}"
        docker exec -it $CONTAINER_NAME tmux attach -t "=$SESSION_NAME"
    else
        echo -e "${GREEN}Creating new remote control session: $SESSION_NAME${NC}"
        echo -e "${BLUE}Project: $REPOS_DIR/$project${NC}"
        [ -n "$feature" ] && echo -e "${BLUE}Feature: $feature${NC}"
        echo -e "${YELLOW}If this is the first time, accept the trust dialog then /exit — remote control will start automatically.${NC}"
        # Remote flow runs bare `claude` first (for the trust dialog), only adding --model.
        local remote_first="claude"
        [ -n "$CS_MODEL" ] && remote_first="claude --model $CS_MODEL"
        docker exec -it $CONTAINER_NAME tmux new-session -s "$SESSION_NAME" -c "$REPOS_DIR/$project" "$(topic_env "$feature")${remote_first} && claude remote-control; zsh"
    fi
}

# Parse arguments
case "$1" in
    list|ls)
        list_sessions
        ;;
    kill|rm)
        if [ -z "$2" ]; then
            echo "Usage: cs-kill <session-name>"
            exit 1
        fi
        kill_session "$2"
        ;;
    remote|rc)
        if [ -z "$2" ]; then
            echo "Usage: cs-remote <project> [feature]"
            exit 1
        fi
        start_remote "$2" "$3"
        ;;
    branch|br)
        start_worktree_session "$2" "$3"
        ;;
    branches|brs)
        list_worktrees "$2"
        ;;
    branch-rm|br-rm)
        remove_worktree "$2" "$3"
        ;;
    -h|--help|help)
        echo "Claude Code Session Manager"
        echo ""
        echo "Usage:"
        echo "  cs <project> [feature]                Start/attach to session"
        echo "  cs-remote <project> [feature]         Start remote control session"
        echo "  cs-list                               List all sessions"
        echo "  cs-kill <session-name>                Kill a session"
        echo ""
        echo "Branch Worktrees:"
        echo "  cs-branch <project> <branch>          Start session on branch"
        echo "  cs-branches <project>                 List worktrees"
        echo "  cs-branch-rm <project> <branch>       Remove worktree"
        ;;
    "")
        echo "Usage: cs <project> [feature]"
        echo "       cs-remote <project> [feature]"
        echo "       cs-branch <project> <branch>"
        echo "       cs-list"
        echo "       cs --help"
        exit 1
        ;;
    *)
        start_or_attach "$1" "$2"
        ;;
esac
