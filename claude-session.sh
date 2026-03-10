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

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ensure_container() {
    if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        echo -e "${YELLOW}Starting container...${NC}"
        docker compose -f /home/tam/repos/.devcontainer/docker-compose.yml up -d
        sleep 2
    fi
}

list_sessions() {
    ensure_container
    echo -e "${BLUE}Active Claude sessions:${NC}"
    echo ""
    docker exec $CONTAINER_NAME tmux list-sessions 2>/dev/null | while read line; do
        session_name=$(echo "$line" | cut -d: -f1)
        created=$(echo "$line" | grep -o '(created [^)]*)')
        echo -e "  ${GREEN}$session_name${NC}  $created"
    done
    if [ $? -ne 0 ] || [ -z "$(docker exec $CONTAINER_NAME tmux list-sessions 2>/dev/null)" ]; then
        echo -e "  ${YELLOW}No active sessions${NC}"
    fi
    echo ""
    echo "Attach with: ./claude-session.sh <project> [feature]"
}

kill_session() {
    local session_name=$1
    ensure_container
    if docker exec $CONTAINER_NAME tmux has-session -t "$session_name" 2>/dev/null; then
        docker exec $CONTAINER_NAME tmux kill-session -t "$session_name"
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
        SESSION_NAME="${project}/${feature}"
    else
        SESSION_NAME="$project"
    fi

    ensure_container

    # Check if project directory exists
    if ! docker exec $CONTAINER_NAME test -d "/home/tam/repos/$project"; then
        echo -e "${YELLOW}Warning: /home/tam/repos/$project does not exist${NC}"
        echo "Available projects:"
        docker exec $CONTAINER_NAME ls /home/tam/repos | head -20
        exit 1
    fi

    # Check if tmux session exists
    if docker exec $CONTAINER_NAME tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${GREEN}Attaching to existing session: $SESSION_NAME${NC}"
        docker exec -it $CONTAINER_NAME tmux attach -t "$SESSION_NAME"
    else
        echo -e "${GREEN}Creating new session: $SESSION_NAME${NC}"
        echo -e "${BLUE}Project: /home/tam/repos/$project${NC}"
        [ -n "$feature" ] && echo -e "${BLUE}Feature: $feature${NC}"
        docker exec -it $CONTAINER_NAME tmux new-session -s "$SESSION_NAME" -c "/home/tam/repos/$project" "claude --dangerously-skip-permissions; zsh"
    fi
}

# Create or attach to a worktree session for a specific branch
start_worktree_session() {
    local project=$1
    local branch=$2

    if [ -z "$branch" ]; then
        echo "Usage: ./claude-session.sh branch <project> <branch>"
        exit 1
    fi

    SESSION_NAME="${project}@${branch}"
    WORKTREE_DIR="/home/tam/repos/${project}-${branch}"
    PROJECT_DIR="/home/tam/repos/${project}"

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
    if docker exec $CONTAINER_NAME tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${GREEN}Attaching to existing session: $SESSION_NAME${NC}"
        docker exec -it $CONTAINER_NAME tmux attach -t "$SESSION_NAME"
    else
        echo -e "${GREEN}Creating new session: $SESSION_NAME${NC}"
        echo -e "${BLUE}Worktree: $WORKTREE_DIR${NC}"
        echo -e "${BLUE}Branch: $branch${NC}"
        docker exec -it $CONTAINER_NAME tmux new-session -s "$SESSION_NAME" -c "$WORKTREE_DIR" "claude --dangerously-skip-permissions; zsh"
    fi
}

# List worktrees for a project
list_worktrees() {
    local project=$1
    PROJECT_DIR="/home/tam/repos/${project}"

    ensure_container

    if [ -z "$project" ]; then
        echo "Usage: ./claude-session.sh branches <project>"
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
        echo "Usage: ./claude-session.sh branch-rm <project> <branch>"
        exit 1
    fi

    WORKTREE_DIR="/home/tam/repos/${project}-${branch}"
    PROJECT_DIR="/home/tam/repos/${project}"
    SESSION_NAME="${project}@${branch}"

    ensure_container

    # Kill tmux session if exists
    if docker exec $CONTAINER_NAME tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${YELLOW}Killing session: $SESSION_NAME${NC}"
        docker exec $CONTAINER_NAME tmux kill-session -t "$SESSION_NAME"
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
        SESSION_NAME="${project}/${feature}~rc"
    else
        SESSION_NAME="${project}~rc"
    fi

    ensure_container

    # Check if project directory exists
    if ! docker exec $CONTAINER_NAME test -d "/home/tam/repos/$project"; then
        echo -e "${YELLOW}Warning: /home/tam/repos/$project does not exist${NC}"
        echo "Available projects:"
        docker exec $CONTAINER_NAME ls /home/tam/repos | head -20
        exit 1
    fi

    # Check if tmux session exists
    if docker exec $CONTAINER_NAME tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo -e "${GREEN}Attaching to existing session: $SESSION_NAME${NC}"
        docker exec -it $CONTAINER_NAME tmux attach -t "$SESSION_NAME"
    else
        echo -e "${GREEN}Creating new remote control session: $SESSION_NAME${NC}"
        echo -e "${BLUE}Project: /home/tam/repos/$project${NC}"
        [ -n "$feature" ] && echo -e "${BLUE}Feature: $feature${NC}"
        echo -e "${YELLOW}If this is the first time, accept the trust dialog then /exit — remote control will start automatically.${NC}"
        docker exec -it $CONTAINER_NAME tmux new-session -s "$SESSION_NAME" -c "/home/tam/repos/$project" "claude && claude remote-control; zsh"
    fi
}

# Parse arguments
case "$1" in
    list|ls)
        list_sessions
        ;;
    kill|rm)
        if [ -z "$2" ]; then
            echo "Usage: ./claude-session.sh kill <session-name>"
            exit 1
        fi
        kill_session "$2"
        ;;
    remote|rc)
        if [ -z "$2" ]; then
            echo "Usage: ./claude-session.sh remote <project> [feature]"
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
        echo "  ./claude-session.sh <project> [feature]      Start/attach to session"
        echo "  ./claude-session.sh remote <project> [feature]  Start remote control session"
        echo "  ./claude-session.sh list                     List all sessions"
        echo "  ./claude-session.sh kill <session-name>      Kill a session"
        echo ""
        echo "Branch Worktrees:"
        echo "  ./claude-session.sh branch <project> <branch>    Start session on branch"
        echo "  ./claude-session.sh branches <project>           List worktrees"
        echo "  ./claude-session.sh branch-rm <project> <branch> Remove worktree"
        echo ""
        echo "Examples:"
        echo "  ./claude-session.sh long-running-agents"
        echo "  ./claude-session.sh long-running-agents api-fix"
        echo "  ./claude-session.sh remote myproject"
        echo "  ./claude-session.sh branch myproject feature-xyz"
        echo "  ./claude-session.sh branches myproject"
        echo "  ./claude-session.sh branch-rm myproject feature-xyz"
        ;;
    "")
        echo "Usage: ./claude-session.sh <project> [feature]"
        echo "       ./claude-session.sh remote <project> [feature]"
        echo "       ./claude-session.sh branch <project> <branch>"
        echo "       ./claude-session.sh list"
        echo "       ./claude-session.sh --help"
        exit 1
        ;;
    *)
        start_or_attach "$1" "$2"
        ;;
esac
