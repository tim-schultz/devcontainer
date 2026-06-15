#!/bin/bash
# Codex CLI session manager (sibling of claude-session.sh)
#
# Sessions get a "~codex" suffix so they coexist with Claude sessions
# in the same container without colliding.
#
# Usage:
#   ./codex-session.sh <project> [feature]            Start/attach to session
#   ./codex-session.sh list                           List all Codex sessions
#   ./codex-session.sh kill <session-name>            Kill a session
#   ./codex-session.sh branch <project> <branch>      Worktree session on a branch
#   ./codex-session.sh branches <project>             List worktrees for a project
#   ./codex-session.sh branch-rm <project> <branch>   Remove a worktree session
#
# Examples:
#   ./codex-session.sh polymarket           → session: polymarket~codex
#   ./codex-session.sh polymarket api-fix   → session: polymarket/api-fix~codex
#   ./codex-session.sh list

# Shared container with Claude — both CLIs are installed inside it
CONTAINER_NAME="claude-devcontainer"

# Suffix that distinguishes Codex sessions from Claude sessions in tmux
SESSION_SUFFIX="~codex"

# Launch command — full-yolo to match `claude --dangerously-skip-permissions`.
# Safe inside this container because the container itself is the sandbox.
CODEX_CMD="codex --dangerously-bypass-approvals-and-sandbox"

# Derive paths from script location (portable across machines)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_DIR="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

# Env prefix that binds a session to a shared notebook topic. Codex does not fire
# Claude's SessionStart hook, so the topic also drives a bootstrap prompt (below);
# NB_TOPIC is exported for parity and any topic-aware tooling Codex may run.
topic_env() {
    local topic="$1"
    [ -n "$topic" ] && printf "NB_TOPIC='%s' " "$topic"
}

# Build the Codex launch command for an optional notebook topic. With a topic, an
# initial prompt tells Codex (the IMPLEMENTER) to read the shared file first and
# coordinate through it; without one, the plain interactive command is used.
codex_launch() {
    local topic="$1"
    if [ -n "$topic" ]; then
        local nbfile="$REPOS_DIR/.shared/notebook/${topic}.md"
        printf '%s "Before doing anything else, read the shared notebook topic file at %s (if it does not exist yet, the planner has not written it — say so). You are the IMPLEMENTER for topic %s: follow the plan there, append progress to the Implementation log section, and keep the status frontmatter current. Coordinate with other sessions only through that file."' \
            "$CODEX_CMD" "$nbfile" "'$topic'"
    else
        printf '%s' "$CODEX_CMD"
    fi
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
    echo -e "${BLUE}Active Codex sessions:${NC}"
    echo ""
    local found=0
    while IFS= read -r line; do
        session_name=$(echo "$line" | cut -d: -f1)
        if [[ "$session_name" == *"$SESSION_SUFFIX" ]]; then
            created=$(echo "$line" | grep -o '(created [^)]*)')
            echo -e "  ${GREEN}$session_name${NC}  $created"
            found=1
        fi
    done < <(docker exec $CONTAINER_NAME tmux list-sessions 2>/dev/null)
    if [ "$found" -eq 0 ]; then
        echo -e "  ${YELLOW}No active sessions${NC}"
    fi
    echo ""
    echo "Attach with: cx <project> [feature]"
}

kill_session() {
    local session_name=$1
    # Allow user to omit the suffix
    if [[ "$session_name" != *"$SESSION_SUFFIX" ]]; then
        session_name="${session_name}${SESSION_SUFFIX}"
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

    # Build session name with codex suffix
    if [ -n "$feature" ]; then
        SESSION_NAME="${project}/${feature}${SESSION_SUFFIX}"
    else
        SESSION_NAME="${project}${SESSION_SUFFIX}"
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
        docker exec -it $CONTAINER_NAME tmux new-session -s "$SESSION_NAME" -c "$REPOS_DIR/$project" "$(topic_env "$feature")$(codex_launch "$feature"); zsh"
    fi
}

# Create or attach to a worktree session for a specific branch
start_worktree_session() {
    local project=$1
    local branch=$2

    if [ -z "$branch" ]; then
        echo "Usage: cx-branch <project> <branch>"
        exit 1
    fi

    SESSION_NAME="${project}@${branch}${SESSION_SUFFIX}"
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
        docker exec -it $CONTAINER_NAME tmux new-session -s "$SESSION_NAME" -c "$WORKTREE_DIR" "$CODEX_CMD; zsh"
    fi
}

# List worktrees for a project (shared with Claude — same git tree)
list_worktrees() {
    local project=$1
    PROJECT_DIR="$REPOS_DIR/${project}"

    ensure_container

    if [ -z "$project" ]; then
        echo "Usage: cx-branches <project>"
        exit 1
    fi

    echo -e "${BLUE}Worktrees for $project:${NC}"
    echo ""
    docker exec $CONTAINER_NAME git -C "$PROJECT_DIR" worktree list 2>/dev/null || echo "No worktrees found"
}

# Remove a worktree (only kills the codex session for that branch — leaves the
# worktree itself in place if a Claude session is still using it)
remove_worktree() {
    local project=$1
    local branch=$2

    if [ -z "$branch" ]; then
        echo "Usage: cx-branch-rm <project> <branch>"
        exit 1
    fi

    WORKTREE_DIR="$REPOS_DIR/${project}-${branch}"
    PROJECT_DIR="$REPOS_DIR/${project}"
    SESSION_NAME="${project}@${branch}${SESSION_SUFFIX}"
    CLAUDE_SESSION="${project}@${branch}"

    ensure_container

    # Kill codex tmux session if exists
    if docker exec $CONTAINER_NAME tmux has-session -t "=$SESSION_NAME" 2>/dev/null; then
        echo -e "${YELLOW}Killing session: $SESSION_NAME${NC}"
        docker exec $CONTAINER_NAME tmux kill-session -t "=$SESSION_NAME"
    fi

    # If a Claude session is still attached to this worktree, leave the worktree
    # in place — let cs-branch-rm handle the actual removal.
    if docker exec $CONTAINER_NAME tmux has-session -t "=$CLAUDE_SESSION" 2>/dev/null; then
        echo -e "${YELLOW}Claude session $CLAUDE_SESSION still attached — leaving worktree in place${NC}"
        echo "Run cs-branch-rm $project $branch to remove the worktree."
        return
    fi

    if docker exec $CONTAINER_NAME test -d "$WORKTREE_DIR"; then
        echo -e "${YELLOW}Removing worktree: $WORKTREE_DIR${NC}"
        docker exec $CONTAINER_NAME git -C "$PROJECT_DIR" worktree remove "$WORKTREE_DIR" --force
        echo -e "${GREEN}Worktree removed${NC}"
    else
        echo -e "${YELLOW}Worktree not found: $WORKTREE_DIR${NC}"
    fi
}

# Parse arguments
case "$1" in
    list|ls)
        list_sessions
        ;;
    kill|rm)
        if [ -z "$2" ]; then
            echo "Usage: cx-kill <session-name>"
            exit 1
        fi
        kill_session "$2"
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
        echo "Codex CLI Session Manager"
        echo ""
        echo "Usage:"
        echo "  cx <project> [feature]                Start/attach to session"
        echo "  cx-list                               List all Codex sessions"
        echo "  cx-kill <session-name>                Kill a session"
        echo ""
        echo "Branch Worktrees:"
        echo "  cx-branch <project> <branch>          Start session on branch"
        echo "  cx-branches <project>                 List worktrees"
        echo "  cx-branch-rm <project> <branch>       Remove worktree"
        ;;
    "")
        echo "Usage: cx <project> [feature]"
        echo "       cx-branch <project> <branch>"
        echo "       cx-list"
        echo "       cx --help"
        exit 1
        ;;
    *)
        start_or_attach "$1" "$2"
        ;;
esac
