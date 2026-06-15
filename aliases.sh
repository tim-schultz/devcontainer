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
    echo -e "\033[0;36m║\033[0m    cx <project> [topic]    Start/attach Codex session      \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cx-list                 List active Codex sessions      \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cx-kill <name>          Kill a Codex session            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    cx-branch <proj> <br>   Codex session on branch         \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m                                                            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m  \033[1;33mFable Sessions (planner — claude-fable-5):\033[0m                \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    fb <project> [topic]    Start/attach Fable session      \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    fb-list                 List active Fable sessions      \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    fb-kill <name>          Kill a Fable session            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m                                                            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m  \033[1;33mShared Notebook (links planner ↔ implementer):\033[0m            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    Pass a [topic] to fb/cs/cx → shared file per topic.     \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    nb-list                 List notebook topics            \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    nb-new <topic> [goal]   Create a topic file             \033[0;36m║\033[0m"
    echo -e "\033[0;36m║\033[0m    nb-show / nb-status      Show / set topic status         \033[0;36m║\033[0m"
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

# Fable sessions (sibling of cs — claude --model claude-fable-5, ~fable suffix)
alias fable-session="$_DEVCONTAINER_DIR/fable-session.sh"
alias fb="$_DEVCONTAINER_DIR/fable-session.sh"
alias fb-list="$_DEVCONTAINER_DIR/fable-session.sh list"
alias fb-kill="$_DEVCONTAINER_DIR/fable-session.sh kill"
alias fb-branch="$_DEVCONTAINER_DIR/fable-session.sh branch"
alias fb-branches="$_DEVCONTAINER_DIR/fable-session.sh branches"
alias fb-branch-rm="$_DEVCONTAINER_DIR/fable-session.sh branch-rm"

# Shared notebook (topic files that link planner ↔ implementer sessions)
alias nb="$_DEVCONTAINER_DIR/notebook.sh"
alias nb-list="$_DEVCONTAINER_DIR/notebook.sh list"
alias nb-new="$_DEVCONTAINER_DIR/notebook.sh new"
alias nb-show="$_DEVCONTAINER_DIR/notebook.sh show"
alias nb-status="$_DEVCONTAINER_DIR/notebook.sh status"

# Container management
# CLAUDE_CACHE_BUST=$(date +%s) forces the Claude Code install layer to re-run,
# so every build pulls the latest version while the rest of the image stays cached.
alias claude-build="cd '$_DEVCONTAINER_DIR' && CLAUDE_CACHE_BUST=\$(date +%s) docker compose build"
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
