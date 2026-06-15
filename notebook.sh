#!/bin/bash
# Shared notebook CLI (`nb`) — coordination files for the planner→implementer flow.
#
# A "topic" is a shared identifier passed to any session launcher (cs/cx/fb) as the
# 3rd arg. Each topic maps to one flat markdown file under .shared/notebook/, which
# a Fable PLANNER session writes and Claude/Codex IMPLEMENTER sessions read + update.
# The notebook-context.sh SessionStart hook surfaces these files into sessions
# automatically; this CLI is for creating/inspecting them by hand.
#
# Usage:
#   nb list                     Index of all topics (topic · status · goal)
#   nb new <topic> [goal...]    Create a topic file from the template
#   nb show <topic>             Print a topic file
#   nb status <topic> <state>   Set the status frontmatter (planning|ready|
#                               in-progress|review|done)
#   nb path <topic>             Print the absolute path to a topic file

# Derive paths from script location (portable across machines)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_DIR="$(dirname "$SCRIPT_DIR")"
NB_DIR="$REPOS_DIR/.shared/notebook"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

nb_file() { echo "$NB_DIR/${1}.md"; }

# Read a single frontmatter field (first match between the leading --- fences).
frontmatter() {
    local file="$1" key="$2"
    awk -v k="$key" '
        NR==1 && $0=="---" { infm=1; next }
        infm && $0=="---" { exit }
        infm && $0 ~ "^"k":" { sub("^"k":[[:space:]]*",""); print; exit }
    ' "$file"
}

# First non-empty, non-comment line under the "## Goal" heading.
goal_line() {
    awk '
        /^##[[:space:]]+Goal/ { ingoal=1; next }
        ingoal && /^##[[:space:]]/ { exit }
        ingoal && NF { print; exit }
    ' "$1"
}

# Plain index: one "topic\tstatus\tgoal" line per topic. No header/color so the
# SessionStart hook can embed it verbatim. Used by both `nb list` and the hook.
render_index() {
    [ -d "$NB_DIR" ] || return 0
    local f topic status goal
    for f in "$NB_DIR"/*.md; do
        [ -e "$f" ] || continue
        topic="$(basename "$f" .md)"
        status="$(frontmatter "$f" status)"
        goal="$(goal_line "$f")"
        printf '%s\t%s\t%s\n' "$topic" "${status:-?}" "${goal:-—}"
    done
}

cmd_list() {
    echo -e "${BLUE}Shared notebook topics:${NC}  ($NB_DIR)"
    echo ""
    local any=0
    while IFS=$'\t' read -r topic status goal; do
        any=1
        printf "  ${GREEN}%-28s${NC} ${YELLOW}%-12s${NC} %s\n" "$topic" "$status" "$goal"
    done < <(render_index)
    [ "$any" -eq 0 ] && echo -e "  ${YELLOW}No topics yet${NC} — create one with: nb new <topic> [goal]"
    echo ""
}

cmd_new() {
    local topic="$1"; shift
    local goal="$*"
    if [ -z "$topic" ]; then echo "Usage: nb new <topic> [goal...]"; exit 1; fi
    mkdir -p "$NB_DIR"
    local file; file="$(nb_file "$topic")"
    if [ -e "$file" ]; then
        echo -e "${YELLOW}Topic already exists:${NC} $file"
        exit 1
    fi
    cat > "$file" <<EOF
---
topic: $topic
status: planning
planner: fable
implementer:
updated: $(date +%F)
---

## Goal

${goal:-_(planner: state the one-line goal here)_}

## Plan

_Fable writes and maintains the implementation plan here._

## Implementation log

_Implementers (Claude / Codex) append progress entries here._

## Open questions

EOF
    echo -e "${GREEN}Created${NC} $file"
}

cmd_show() {
    local file; file="$(nb_file "$1")"
    if [ ! -e "$file" ]; then echo -e "${YELLOW}No such topic:${NC} $1"; exit 1; fi
    cat "$file"
}

cmd_status() {
    local topic="$1" state="$2"
    local file; file="$(nb_file "$topic")"
    if [ -z "$state" ]; then echo "Usage: nb status <topic> <state>"; exit 1; fi
    if [ ! -e "$file" ]; then echo -e "${YELLOW}No such topic:${NC} $topic"; exit 1; fi
    # Update status + updated date inside the frontmatter block (first --- … ---).
    awk -v st="$state" -v dt="$(date +%F)" '
        NR==1 && $0=="---" { infm=1; print; next }
        infm && $0=="---" { infm=0; print; next }
        infm && /^status:/ { print "status: " st; next }
        infm && /^updated:/ { print "updated: " dt; next }
        { print }
    ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
    echo -e "${GREEN}$topic${NC} → status: ${YELLOW}$state${NC}"
}

case "$1" in
    list|ls|"")      cmd_list ;;
    index)           render_index ;;   # machine-readable, used by the hook
    new|create)      shift; cmd_new "$@" ;;
    show|cat)        cmd_show "$2" ;;
    status|set)      cmd_status "$2" "$3" ;;
    path)            nb_file "$2" ;;
    -h|--help|help)
        sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
        ;;
    *)
        echo "Unknown command: $1"
        echo "Try: nb list | nb new <topic> [goal] | nb show <topic> | nb status <topic> <state>"
        exit 1
        ;;
esac
