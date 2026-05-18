# Claude Dev Container Aliases
# Add to your ~/.bashrc or ~/.zshrc:
#   source /path/to/.devcontainer/aliases.sh

# Derive paths from this script's location (portable across machines)
_DEVCONTAINER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Show help on interactive login
if [[ $- == *i* ]]; then
    echo ""
    echo -e "\033[0;36m╔════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[0;36m║\033[0m  \033[0;32mClaude Dev Container\033[0m                                      \033[0;36m║\033[0m"
    echo -e "\033[0;36m╠════════════════════════════════════════════════════════════╣\033[0m"
    echo -e "\033[0;36m║\033[0m                                                            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m  \033[1;33mSessions:\033[0m                                                 \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cs <project>            Start/attach session            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cs <project> <feature>  Session with feature name       \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cs-list                 List active sessions            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cs-kill <name>          Kill a session                  \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cs-remote <project>     Start remote control session    \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m                                                            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m  \033[1;33mBranch Worktrees:\033[0m                                         \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cs-branch <proj> <br>   Session on specific branch      \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cs-branches <proj>      List worktrees                  \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cs-branch-rm <proj> <br> Remove worktree                \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m                                                            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m  \033[1;33mCodex Sessions (sibling of cs):\033[0m                           \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cx <project> [feature]  Start/attach Codex session      \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cx-list                 List active Codex sessions      \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cx-kill <name>          Kill a Codex session            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cx-branch <proj> <br>   Codex session on branch         \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m                                                            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m  \033[1;33mTinyClaw (Multi-Agent):\033[0m                                    \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    tc-status               Agent system status             \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    tc-start / tc-stop      Start/stop TinyClaw             \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    tc-agents               List agents                     \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    tc-teams                List teams                      \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    tc-office               Start web portal (:3000)        \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    tc-approve <code>       Approve Telegram sender         \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m                                                            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m  \033[1;33mContainer:\033[0m                                                \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    claude-build            Build container image           \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    claude-up               Start container                 \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    claude-down             Stop container                  \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    claude-restart          Restart container               \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    claude-status           Check container status          \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    claude-logs             View container logs             \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    claude-shell            Shell into container            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m                                                            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m  \033[1;33mDetach:\033[0m  Ctrl+A, D  or  F12                               \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m                                                            \033[0;36m║\033[0m"
    echo -e "\033[0;36m╚════════════════════════════════════════════════════════════╝\033[0m"
    echo ""
fi

# Session management
alias claude-session="$_DEVCONTAINER_DIR/claude-session.sh"
alias cs="$_DEVCONTAINER_DIR/claude-session.sh"
alias cs-list="$_DEVCONTAINER_DIR/claude-session.sh list"
alias cs-kill="$_DEVCONTAINER_DIR/claude-session.sh kill"

# Remote control session
alias cs-remote="$_DEVCONTAINER_DIR/claude-session.sh remote"

# Branch worktree sessions
alias cs-branch="$_DEVCONTAINER_DIR/claude-session.sh branch"
alias cs-branches="$_DEVCONTAINER_DIR/claude-session.sh branches"
alias cs-branch-rm="$_DEVCONTAINER_DIR/claude-session.sh branch-rm"

# Codex CLI sessions (sibling of cs — sessions get a ~codex suffix)
alias codex-session="$_DEVCONTAINER_DIR/codex-session.sh"
alias cx="$_DEVCONTAINER_DIR/codex-session.sh"
alias cx-list="$_DEVCONTAINER_DIR/codex-session.sh list"
alias cx-kill="$_DEVCONTAINER_DIR/codex-session.sh kill"
alias cx-branch="$_DEVCONTAINER_DIR/codex-session.sh branch"
alias cx-branches="$_DEVCONTAINER_DIR/codex-session.sh branches"
alias cx-branch-rm="$_DEVCONTAINER_DIR/codex-session.sh branch-rm"

# Container management
alias claude-build="cd '$_DEVCONTAINER_DIR' && docker compose build"
alias claude-up="cd '$_DEVCONTAINER_DIR' && docker compose up -d"
alias claude-down="cd '$_DEVCONTAINER_DIR' && docker compose down"
alias claude-restart="cd '$_DEVCONTAINER_DIR' && docker compose down && docker compose up -d"
alias claude-logs='docker logs -f claude-devcontainer'
alias claude-shell='docker exec -it claude-devcontainer zsh'

# Quick status
alias claude-status='docker ps --filter name=claude-devcontainer --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'

# TinyClaw multi-agent management
alias tc='docker exec -it claude-devcontainer tinyclaw'
alias tc-start='docker exec -it claude-devcontainer tinyclaw start'
alias tc-stop='docker exec -it claude-devcontainer tinyclaw stop'
alias tc-restart='docker exec -it claude-devcontainer tinyclaw restart'
alias tc-status='docker exec -it claude-devcontainer tinyclaw status'
alias tc-logs='docker exec -it claude-devcontainer tinyclaw logs'
alias tc-attach='docker exec -it claude-devcontainer tinyclaw attach'
alias tc-office='docker exec -it claude-devcontainer tinyclaw office'
alias tc-agents='docker exec claude-devcontainer tinyclaw agent list'
alias tc-teams='docker exec claude-devcontainer tinyclaw team list'
alias tc-approve='docker exec claude-devcontainer tinyclaw pairing approve'
alias tc-pairing='docker exec claude-devcontainer tinyclaw pairing pending'
