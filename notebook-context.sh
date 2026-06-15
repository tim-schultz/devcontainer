#!/bin/bash
# SessionStart hook — makes every Claude/Fable session aware of the shared notebook.
#
# Registered in ~/.claude/settings.json under hooks.SessionStart. Claude Code runs it
# at session start/resume, passing event JSON on stdin; for SessionStart, whatever this
# script prints to stdout is injected into the model's context.
#
# It does two things:
#   1. Prints an index of all shared notebook topics (so any session sees sibling work).
#   2. If the session was launched with a topic (NB_TOPIC, set by cs/cx/fb when a 3rd
#      arg is given), prints that topic's file and role-specific instructions.
#
# Role is inferred from the session model: Fable ⇒ PLANNER, anything else ⇒ IMPLEMENTER.
# (Codex ignores Claude hooks; codex-session.sh injects an equivalent bootstrap prompt.)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_DIR="$(dirname "$SCRIPT_DIR")"
NB_DIR="$REPOS_DIR/.shared/notebook"
NB_CLI="$SCRIPT_DIR/notebook.sh"

# --- Parse the model from the hook's stdin JSON (jq if present, else grep). ---
payload="$(cat)"
if command -v jq >/dev/null 2>&1; then
    model="$(printf '%s' "$payload" | jq -r '.model // empty' 2>/dev/null)"
fi
if [ -z "$model" ]; then
    model="$(printf '%s' "$payload" | grep -o '"model"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')"
fi

case "$model" in
    *fable*) role="PLANNER" ;;
    *)       role="IMPLEMENTER" ;;
esac

# Nothing to say if the notebook has never been used and no topic is bound.
topic="${NB_TOPIC:-}"
if [ ! -d "$NB_DIR" ] && [ -z "$topic" ]; then
    exit 0
fi

echo "## Shared notebook"
echo
echo "Coordination files live in \`$NB_DIR/\` — one markdown file per topic, keyed by"
echo "the identifier passed as the 3rd arg to cs/cx/fb. Flow: Fable plans, Claude/Codex implement."
echo

# --- Topic index (reuses \`nb index\`: tab-separated topic/status/goal). ---
if [ -d "$NB_DIR" ]; then
    index="$("$NB_CLI" index 2>/dev/null)"
    if [ -n "$index" ]; then
        echo "Active topics:"
        printf '%s\n' "$index" | while IFS=$'\t' read -r t s g; do
            echo "- **$t** — _${s}_ — ${g}"
        done
        echo
    fi
fi

# --- Active topic binding + role instructions. ---
if [ -n "$topic" ]; then
    file="$NB_DIR/${topic}.md"
    echo "### This session is bound to topic: \`$topic\`  (role: $role)"
    echo "File: \`$file\`"
    echo
    if [ "$role" = "PLANNER" ]; then
        cat <<EOF
You are the **PLANNER** (Fable). Own this topic file:
- Write/maintain the **Goal** and **Plan** sections. Do not write implementation code.
- When the plan is ready to hand off, set \`status: ready\` and fill \`implementer:\`
  (\`claude\` or \`codex\`) in the frontmatter.
- Keep the plan the single source of truth; resolve **Open questions** here.
EOF
    else
        cat <<EOF
You are an **IMPLEMENTER** ($model). Work against this topic file:
- Read the **Plan** before changing code; if \`status\` is still \`planning\`, the plan
  may be incomplete — flag it rather than guessing.
- Append progress to the **Implementation log**; raise blockers in **Open questions**.
- Move \`status\` along as you go (\`in-progress\` → \`review\` → \`done\`).
EOF
    fi
    echo
    if [ -e "$file" ]; then
        echo "Current contents:"
        echo
        echo '```markdown'
        cat "$file"
        echo '```'
    else
        echo "_This topic file does not exist yet._"
        if [ "$role" = "PLANNER" ]; then
            echo "Create it from the template: \`$NB_CLI new $topic \"<goal>\"\`, then write the plan."
        else
            echo "The planner hasn't written it yet — coordinate before implementing."
        fi
    fi
fi

exit 0
