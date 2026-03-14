#!/bin/bash
# Claude Dev Container - Login Message
# Add to ~/.bashrc: source /path/to/.devcontainer/motd.sh

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}Claude Dev Container${NC}                                      ${CYAN}║${NC}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}                                                            ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${YELLOW}Sessions:${NC}                                                 ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    cs <project>            Start/attach session            ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    cs <project> <feature>  Session with feature name       ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    cs-list                 List active sessions            ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    cs-kill <name>          Kill a session                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                            ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${YELLOW}Container:${NC}                                                ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    claude-build            Build container                 ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    claude-up               Start container                 ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    claude-down             Stop container                  ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    claude-restart          Restart container               ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    claude-status           Check if running                ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                            ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${YELLOW}Inside session:${NC}                                           ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    Ctrl+B, D               Detach (keep running)           ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}    Scroll                  Mouse/trackpad works            ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                                                            ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Show container status
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^claude-devcontainer$"; then
    SESSIONS=$(docker exec claude-devcontainer tmux list-sessions 2>/dev/null | wc -l)
    echo -e "  Container: ${GREEN}running${NC}  |  Sessions: ${GREEN}${SESSIONS}${NC}"
    if [ "$SESSIONS" -gt 0 ]; then
        echo -e "  Active: $(docker exec claude-devcontainer tmux list-sessions -F '#{session_name}' 2>/dev/null | tr '\n' ' ')"
    fi
else
    echo -e "  Container: ${YELLOW}stopped${NC}  |  Run: claude-up"
fi
echo ""
