# TinyClaw Integration Plan

## Architecture

- TinyClaw installs inside the existing devcontainer (prerequisites already met: Node 24, tmux, jq, bash, Claude Code)
- Coexists with `claude-session.sh` — no tmux naming conflicts (different naming schemes)
- Replaces the custom `telegram-bot/` with TinyClaw's built-in Telegram channel
- TinyOffice web portal exposed for dashboard/chat/task management

## Implementation Phases

### Phase 1: Dockerfile — Install TinyClaw

Add after Claude Code install block:

```dockerfile
USER root
RUN git clone --depth 1 https://github.com/TinyAGI/tinyclaw.git /opt/tinyclaw && \
    chown -R node:node /opt/tinyclaw
USER node
RUN cd /opt/tinyclaw && npm install && \
    ./scripts/install.sh && \
    mkdir -p /home/tam/.tinyclaw
```

`/opt/tinyclaw` chosen so it won't be overwritten by volume mounts. Add a `TINYCLAW_CACHE_BUST` arg for update control.

### Phase 2: docker-compose.yml — Persistence + Ports

```yaml
volumes:
  - tinyclaw-data:/home/tam/.tinyclaw    # settings, SQLite queue, sender data

ports:
  - "127.0.0.1:3000:3000"    # TinyOffice web portal (localhost only)
  - "127.0.0.1:3777:3777"    # TinyClaw API (localhost only)

environment:
  - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN:-}
```

New named volume: `tinyclaw-data`

### Phase 3: Setup Script — `tinyclaw-setup.sh`

Non-interactive config generator (run inside container on first boot):

- Generates `~/.tinyclaw/settings.json` with workspace path `/home/tam/repos`
- Configures Telegram channel with bot token from env
- Creates a default agent
- Disables Discord/WhatsApp unless requested

### Phase 4: Aliases — Replace Telegram, Add TinyClaw

Remove `claude-telegram` alias. Add:

```bash
alias tc-start='docker exec claude-devcontainer tinyclaw start'
alias tc-stop='docker exec claude-devcontainer tinyclaw stop'
alias tc-status='docker exec claude-devcontainer tinyclaw status'
alias tc-logs='docker exec claude-devcontainer tinyclaw logs'
alias tc-attach='docker exec -it claude-devcontainer tinyclaw attach'
alias tc-office='docker exec claude-devcontainer tinyclaw office'
alias tc-agents='docker exec claude-devcontainer tinyclaw agent list'
alias tc-teams='docker exec claude-devcontainer tinyclaw team list'
alias tc-approve='docker exec claude-devcontainer tinyclaw pairing approve'
```

Update the help banner to include TinyClaw section.

### Phase 5: Deprecate telegram-bot/

Keep `telegram-bot/` temporarily for reference. Remove after TinyClaw Telegram is confirmed working.

**Capability gap:** The custom bot had container management commands (`/claude_up`, `/claude_down`). TinyClaw agents can't manage their own container. If needed, keep a minimal host-side script for this.

## Security Analysis

### Already Handled

| Concern | Status |
|---|---|
| Git/GH safety wrappers | `/usr/local/bin/git` and `/usr/local/bin/gh` intercept all git/gh calls, including from TinyClaw agents |
| Sender pairing | TinyClaw requires explicit approval of new Telegram senders (better than hardcoded allowed users) |
| Bot token storage | Lives in `~/.tinyclaw/settings.json` inside a named Docker volume — not in any git-tracked file |

### Mitigations Applied

| Risk | Mitigation |
|---|---|
| Network exposure (TinyOffice/API) | Bind to `127.0.0.1` only — not `0.0.0.0` |
| Agent cross-contamination | Each agent assigned a specific `working_directory`; git wrappers prevent dangerous remote ops |
| Docker socket abuse | `--dangerously-skip-permissions` IS used — agents CAN run docker commands without prompting. Mitigated by: agents only trigger via approved senders, and system prompt instructs agents to stay in their workspace. Consider iptables rules or a docker socket proxy for tighter control. |

### CONFIRMED: `--dangerously-skip-permissions` is hardcoded

**Source:** `packages/core/src/invoke.ts:229` — `const claudeArgs = ['--dangerously-skip-permissions'];`

TinyClaw hardcodes this flag for ALL Claude/Anthropic agent invocations. This means autonomous agents have full unrestricted access. The git-safe.sh and gh-safe.sh wrappers are the **only** guardrails preventing dangerous remote operations.

**Codex provider** also uses `--dangerously-bypass-approvals-and-sandbox` (invoke.ts:144).

**Impact:** Acceptable for our setup because:
1. git/gh wrappers block push, force-push, PR creation, etc.
2. Sender pairing controls who can trigger agents
3. Ports bound to localhost only
4. Container has no access to host filesystem outside mounted volumes

**If we want tighter control later**, we could:
- Add wrapper scripts for `docker`, `rm -rf`, `curl` (outbound data exfil prevention)
- Use iptables rules (container already has NET_ADMIN) to restrict outbound network access
- Patch invoke.ts to remove the flag (but agents may hang on permission prompts)

### Resolved Questions

1. **How does TinyClaw invoke Claude Code?** — Via `child_process.spawn('claude', [...args])` in `packages/core/src/invoke.ts`. Uses `--dangerously-skip-permissions`, `--system-prompt`, `-c` (continue), `-p` (pipe message). Each invocation is a one-shot process, not long-running.

2. **Auto-start on container boot?** — YES. TinyClaw has no built-in auto-start, so we'll add an entrypoint script. Idle overhead is minimal (channel listener + queue processor + heartbeat in tmux). Agents only spawn when messages arrive.

3. **Which channels?** — Telegram only to start. Configured via `settings.json` `channels.enabled` array.

4. **Memory per agent** — Agents are NOT long-running processes. Each message spawns a `claude` CLI process that runs to completion and exits. ~200-500MB per concurrent invocation. With 28GB container limit, we can safely run 4-6 agents processing simultaneously plus interactive sessions.

5. **Inter-agent communication** — Agents communicate via bracket tags in responses: `[@teammate: message]`. The queue processor in `packages/teams/src/routing.ts` parses these and enqueues follow-up messages. Also supports fan-out (`[@a,b: msg]`) and chatroom broadcasts (`[#team: msg]`).

## Implementation Order

1. Dockerfile modifications
2. docker-compose.yml modifications
3. tinyclaw-setup.sh (new)
4. aliases.sh update
5. Build + test: `claude-build && claude-up && claude-shell`
6. First run: `tinyclaw setup` or run setup script
7. Configure Telegram + approve sender
8. Test coexistence with `cs <project>`
9. Deprecate telegram-bot/

## Verification Steps

Run these after each phase to confirm the integration is working. Each step includes the command and its expected output. Stop and investigate if any check fails.

### V1: Post-Build — TinyClaw Installed Correctly

```bash
# 1.1 Binary is on PATH
docker exec claude-devcontainer which tinyclaw
# EXPECT: /home/tam/.local/bin/tinyclaw (or similar — must resolve)

# 1.2 Source code exists and wasn't clobbered by volume mounts
docker exec claude-devcontainer ls /opt/tinyclaw/package.json
# EXPECT: /opt/tinyclaw/package.json (no "No such file" error)

# 1.3 Node modules installed
docker exec claude-devcontainer test -d /opt/tinyclaw/node_modules && echo "OK" || echo "FAIL"
# EXPECT: OK

# 1.4 Config directory exists
docker exec claude-devcontainer test -d /home/tam/.tinyclaw && echo "OK" || echo "FAIL"
# EXPECT: OK

# 1.5 Version check (confirms tinyclaw is executable)
docker exec claude-devcontainer tinyclaw --version 2>/dev/null || docker exec claude-devcontainer tinyclaw help | head -3
# EXPECT: version string or help output — NOT "command not found"
```

### V2: Post-Compose — Volumes and Ports

```bash
# 2.1 TinyClaw data volume mounted
docker exec claude-devcontainer mount | grep tinyclaw
# EXPECT: a line showing the tinyclaw-data volume mounted at /home/tam/.tinyclaw

# 2.2 Ports bound to localhost only
docker port claude-devcontainer
# EXPECT: 3000/tcp -> 127.0.0.1:3000 and 3777/tcp -> 127.0.0.1:3777

# 2.3 Ports NOT accessible from external interfaces
# From another machine on the network (or use curl with --interface):
curl --connect-timeout 3 http://<host-external-ip>:3000 2>&1
# EXPECT: connection refused or timeout — NOT a response

# 2.4 Telegram bot token passed to container
docker exec claude-devcontainer printenv TELEGRAM_BOT_TOKEN
# EXPECT: your token value (or empty if not set yet — but the variable should exist)

# 2.5 Existing volumes still work (repos, claude config)
docker exec claude-devcontainer ls /home/tam/repos/.devcontainer/Dockerfile
docker exec claude-devcontainer ls /home/tam/.claude/
# EXPECT: both list files without error
```

### V3: Post-Setup — Config Valid

```bash
# 3.1 Settings file exists and is valid JSON
docker exec claude-devcontainer cat /home/tam/.tinyclaw/settings.json | jq .
# EXPECT: pretty-printed JSON without parse errors

# 3.2 Workspace points to /home/tam/repos
docker exec claude-devcontainer cat /home/tam/.tinyclaw/settings.json | jq '.workspace.path'
# EXPECT: "/home/tam/repos"

# 3.3 Telegram channel is enabled
docker exec claude-devcontainer cat /home/tam/.tinyclaw/settings.json | jq '.channels.enabled'
# EXPECT: array containing "telegram"

# 3.4 At least one agent configured
docker exec claude-devcontainer cat /home/tam/.tinyclaw/settings.json | jq '.agents | keys'
# EXPECT: non-empty array like ["default"]
```

### V4: Runtime — TinyClaw Starts and Agents Work

```bash
# 4.1 TinyClaw starts without errors
docker exec claude-devcontainer tinyclaw start
# EXPECT: success message, no crash

# 4.2 Status shows running processes
docker exec claude-devcontainer tinyclaw status
# EXPECT: shows queue processor, heartbeat, and channel(s) as running

# 4.3 Tmux sessions created by TinyClaw
docker exec claude-devcontainer tmux list-sessions
# EXPECT: TinyClaw session(s) listed alongside any existing claude-session sessions

# 4.4 Agent can receive and process a message
docker exec claude-devcontainer tinyclaw send "hello, are you there?"
# EXPECT: message accepted/queued — check logs for processing:
docker exec claude-devcontainer tinyclaw logs queue | tail -20
# EXPECT: log entry showing message received, routed to agent, and processed (or processing)

# 4.5 Queue database exists and is functional
docker exec claude-devcontainer test -f /home/tam/.tinyclaw/tinyclaw.db && echo "OK" || echo "FAIL"
# EXPECT: OK
```

### V5: Security — Safety Wrappers Active for Agents

```bash
# 5.1 Git wrapper is first in PATH for all users
docker exec claude-devcontainer which git
# EXPECT: /usr/local/bin/git (the wrapper, NOT /usr/bin/git)

# 5.2 GH wrapper is first in PATH
docker exec claude-devcontainer which gh
# EXPECT: /usr/local/bin/gh (the wrapper, NOT /usr/bin/gh)

# 5.3 Git push is blocked (simulated test)
docker exec claude-devcontainer git push --dry-run 2>&1 || true
# EXPECT: blocked/rejected by git-safe.sh wrapper — NOT a normal git error

# 5.4 Ports not exposed on 0.0.0.0
docker port claude-devcontainer 2>/dev/null | grep -v 127.0.0.1
# EXPECT: empty output (no lines — all ports bound to 127.0.0.1)

# 5.5 Verify TinyClaw does NOT use --dangerously-skip-permissions
docker exec claude-devcontainer grep -r "dangerously-skip-permissions" /opt/tinyclaw/
# EXPECT: no matches, OR only in docs/comments — NOT in actual invocation code
# IF FOUND in invocation code: STOP — this is a security risk. Patch before proceeding.

# 5.6 Sender pairing is enforced (no pre-approved senders)
docker exec claude-devcontainer tinyclaw pairing approved
# EXPECT: empty list on fresh install — senders must be explicitly approved
```

### V6: Coexistence — claude-session.sh Still Works

```bash
# 6.1 Interactive session still launches
# (from host)
./claude-session.sh list
# EXPECT: lists sessions (both TinyClaw and claude-session ones) without error

# 6.2 Create a test interactive session
docker exec -it claude-devcontainer tmux new-session -d -s coexist-test -c /home/tam/repos
docker exec claude-devcontainer tmux has-session -t coexist-test && echo "OK" || echo "FAIL"
# EXPECT: OK

# 6.3 TinyClaw still running after interactive session created
docker exec claude-devcontainer tinyclaw status
# EXPECT: still shows running — no interference

# 6.4 Clean up test session
docker exec claude-devcontainer tmux kill-session -t coexist-test
```

### V7: Persistence — Survives Container Restart

```bash
# 7.1 Stop and restart the container
docker compose -f /home/tam/repos/.devcontainer/docker-compose.yml down
docker compose -f /home/tam/repos/.devcontainer/docker-compose.yml up -d
sleep 3

# 7.2 Settings survived restart
docker exec claude-devcontainer cat /home/tam/.tinyclaw/settings.json | jq '.workspace.path'
# EXPECT: "/home/tam/repos" — same as before restart

# 7.3 SQLite queue survived restart
docker exec claude-devcontainer test -f /home/tam/.tinyclaw/tinyclaw.db && echo "OK" || echo "FAIL"
# EXPECT: OK

# 7.4 Approved senders survived restart
docker exec claude-devcontainer tinyclaw pairing approved
# EXPECT: same list as before restart (if any were approved)

# 7.5 TinyClaw can start again cleanly
docker exec claude-devcontainer tinyclaw start
docker exec claude-devcontainer tinyclaw status
# EXPECT: starts and shows running without errors
```

### V8: Telegram Channel — End-to-End

```bash
# 8.1 Send a message to the bot from Telegram
# → Bot should respond with a pairing code (first time)

# 8.2 Approve the sender
docker exec claude-devcontainer tinyclaw pairing pending
# EXPECT: shows your Telegram user with a pairing code
docker exec claude-devcontainer tinyclaw pairing approve <code>
# EXPECT: success message

# 8.3 Send another message from Telegram
# EXPECT: message is processed by the agent and a response arrives in Telegram

# 8.4 Route to specific agent
# Send "@<agent-id> hello" from Telegram
# EXPECT: routed to that specific agent, response in Telegram

# 8.5 Route to team
# Send "@<team-id> hello" from Telegram
# EXPECT: routed through team leader, response in Telegram
```

### V9: Inter-Agent Communication — Teams Work

```bash
# 9.1 Create a test team with two agents
docker exec claude-devcontainer tinyclaw agent add  # create agent-a
docker exec claude-devcontainer tinyclaw agent add  # create agent-b
docker exec claude-devcontainer tinyclaw team add   # create test-team with agent-a as leader
docker exec claude-devcontainer tinyclaw team add-agent test-team agent-b

# 9.2 Verify team config
docker exec claude-devcontainer tinyclaw team show test-team
# EXPECT: shows leader and members

# 9.3 Send message to team
docker exec claude-devcontainer tinyclaw send "@test-team coordinate a hello"
# EXPECT: leader receives message, can delegate to agent-b

# 9.4 Check chatroom for team interaction
docker exec claude-devcontainer tinyclaw chatroom test-team
# or via API:
curl http://127.0.0.1:3777/api/chatroom/test-team?limit=10
# EXPECT: messages showing inter-agent routing
```
