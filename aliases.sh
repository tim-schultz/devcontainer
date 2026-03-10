# Claude Dev Container Aliases
# Add to your ~/.bashrc or ~/.zshrc:
#   source /home/tam/repos/.devcontainer/aliases.sh

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
alias claude-session='/home/tam/repos/.devcontainer/claude-session.sh'
alias cs='/home/tam/repos/.devcontainer/claude-session.sh'
alias cs-list='/home/tam/repos/.devcontainer/claude-session.sh list'
alias cs-kill='/home/tam/repos/.devcontainer/claude-session.sh kill'

# Remote control session
alias cs-remote='/home/tam/repos/.devcontainer/claude-session.sh remote'

# Branch worktree sessions
alias cs-branch='/home/tam/repos/.devcontainer/claude-session.sh branch'
alias cs-branches='/home/tam/repos/.devcontainer/claude-session.sh branches'
alias cs-branch-rm='/home/tam/repos/.devcontainer/claude-session.sh branch-rm'

# Container management
alias claude-build='cd /home/tam/repos/.devcontainer && docker compose build'
alias claude-up='cd /home/tam/repos/.devcontainer && docker compose up -d'
alias claude-down='cd /home/tam/repos/.devcontainer && docker compose down'
alias claude-restart='cd /home/tam/repos/.devcontainer && docker compose down && docker compose up -d'
alias claude-logs='docker logs -f claude-devcontainer'
alias claude-shell='docker exec -it claude-devcontainer zsh'

# Quick status
alias claude-status='docker ps --filter name=claude-devcontainer --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
