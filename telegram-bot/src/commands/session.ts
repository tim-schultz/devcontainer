import { Context } from "grammy";
import {
  dockerExec,
  dockerExecDetached,
  isContainerRunning,
  listTmuxSessions,
  tmuxSessionExists,
} from "../exec.js";
import { setAttached, setIdle } from "../state.js";
import { startRelay, stopRelay, capturePaneSnapshot } from "../relay/session-relay.js";
import { config } from "../config.js";
import { safeSend, codeBlock, escapeForCodeBlock } from "../safe-send.js";

/**
 * /cs_list - List all active tmux sessions
 */
export async function handleList(ctx: Context) {
  if (!isContainerRunning()) {
    return ctx.reply("Container is not running.");
  }

  const sessions = listTmuxSessions();
  if (sessions.length === 0) {
    return ctx.reply("No active sessions.");
  }

  const lines = sessions.map((s) => `  - ${s}`);
  return ctx.reply(`Active sessions:\n${lines.join("\n")}`);
}

/**
 * /cs <project> [feature] - Create or attach to a session
 */
export async function handleStartSession(
  ctx: Context,
  sendMessage: (chatId: number, text: string) => Promise<void>
) {
  const text = ctx.message?.text ?? "";
  const parts = text.split(/\s+/).slice(1); // skip /cs
  const project = parts[0];
  const feature = parts[1];

  if (!project) {
    return ctx.reply("Usage: /cs <project> [feature]");
  }

  if (!isContainerRunning()) {
    return ctx.reply("Container is not running. Use /claude_up to start it.");
  }

  // Check project dir exists
  try {
    dockerExec(`test -d '${config.reposDir}/${project}'`);
  } catch {
    const projects = dockerExec(`ls ${config.reposDir}`);
    return ctx.reply(`Project '${project}' not found.\n\nAvailable:\n${projects}`);
  }

  const sessionName = feature ? `${project}/${feature}` : project;
  const userId = ctx.from!.id;
  const chatId = ctx.chat!.id;

  if (tmuxSessionExists(sessionName)) {
    // Session exists, just attach relay
    setAttached(userId, sessionName);
    startRelay(sessionName, chatId, userId, sendMessage);

    // Send current pane snapshot
    const snapshot = capturePaneSnapshot(sessionName);
    await ctx.reply(`Attached to existing session '${sessionName}'.\nUse /detach to disconnect.`);
    if (snapshot) {
      await safeSend(ctx, codeBlock(snapshot.slice(-2000)));
    }
  } else {
    // Create new session (detached, since we can't interact via TTY)
    const dir = `${config.reposDir}/${project}`;
    dockerExecDetached(
      `tmux new-session -d -s '${sessionName}' -c '${dir}' 'claude --dangerously-skip-permissions; zsh'`
    );

    // Give Claude a moment to start
    await new Promise((r) => setTimeout(r, 2000));

    setAttached(userId, sessionName);
    startRelay(sessionName, chatId, userId, sendMessage);

    await ctx.reply(
      `Session '${sessionName}' created and attached.\nSend messages to interact with Claude.\nUse /detach to disconnect.`
    );
  }
}

/**
 * /cs_kill <session-name> - Kill a session
 */
export async function handleKill(ctx: Context) {
  const text = ctx.message?.text ?? "";
  const sessionName = text.split(/\s+/).slice(1).join(" ");

  if (!sessionName) {
    return ctx.reply("Usage: /cs_kill <session-name>");
  }

  if (!isContainerRunning()) {
    return ctx.reply("Container is not running.");
  }

  if (!tmuxSessionExists(sessionName)) {
    return ctx.reply(`Session '${sessionName}' not found.`);
  }

  try {
    dockerExec(`tmux kill-session -t '${sessionName}'`);
    const userId = ctx.from!.id;
    stopRelay(userId);
    setIdle(userId);
    return ctx.reply(`Session '${sessionName}' killed.`);
  } catch (err) {
    return ctx.reply(`Failed to kill session: ${err}`);
  }
}

/**
 * /detach - Detach from current session (stop relay)
 */
export async function handleDetach(ctx: Context) {
  const userId = ctx.from!.id;
  stopRelay(userId);
  setIdle(userId);
  return ctx.reply("Detached from session.");
}

/**
 * /screenshot - Capture current pane content
 */
export async function handleScreenshot(ctx: Context) {
  const text = ctx.message?.text ?? "";
  const sessionName = text.split(/\s+/).slice(1).join(" ");

  if (!sessionName) {
    return ctx.reply("Usage: /screenshot <session-name>");
  }

  if (!tmuxSessionExists(sessionName)) {
    return ctx.reply(`Session '${sessionName}' not found.`);
  }

  const snapshot = capturePaneSnapshot(sessionName);
  return safeSend(ctx, codeBlock(snapshot.slice(-3500)));
}
