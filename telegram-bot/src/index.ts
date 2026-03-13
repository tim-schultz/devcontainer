import { Bot } from "grammy";
import { config, validateConfig } from "./config.js";
import { getUserState } from "./state.js";
import { sendInput } from "./relay/session-relay.js";
import { escapeForCodeBlock } from "./safe-send.js";

// Commands
import { handleList, handleStartSession, handleKill, handleDetach, handleScreenshot } from "./commands/session.js";
import { handleBranch, handleBranches, handleBranchRemove } from "./commands/branch.js";
import { handleStatus, handleLogs, handleUp, handleRestart, handleDown } from "./commands/container.js";

validateConfig();

const bot = new Bot(config.botToken);

// --- Auth middleware ---
bot.use(async (ctx, next) => {
  const userId = ctx.from?.id;
  if (!userId || !config.allowedUserIds.includes(userId)) {
    return; // silently ignore unauthorized users
  }
  return next();
});

// --- Helper to send messages (used by relay) ---
async function sendMessage(chatId: number, text: string) {
  const escaped = escapeForCodeBlock(text);
  try {
    await bot.api.sendMessage(chatId, "```\n" + escaped + "\n```", {
      parse_mode: "Markdown",
    });
  } catch {
    // Markdown still failed, send plain text
    await bot.api.sendMessage(chatId, text);
  }
}

// --- Slash commands ---

// Session management
bot.command("cs", (ctx) => handleStartSession(ctx, sendMessage));
bot.command("cs_list", handleList);
bot.command("cs_kill", handleKill);
bot.command("cs_remote", async (ctx) => {
  // Remote sessions work the same as regular for the relay
  // (the tmux session runs `claude remote-control` instead)
  const text = ctx.message?.text ?? "";
  const parts = text.split(/\s+/).slice(1);
  const project = parts[0];
  const feature = parts[1];
  if (!project) return ctx.reply("Usage: /cs_remote <project> [feature]");

  // Override the message text to pass through to handleStartSession
  // but with the remote session naming
  const sessionName = feature
    ? `${project}/${feature}~rc`
    : `${project}~rc`;

  const { isContainerRunning } = await import("./exec.js");
  const { dockerExecDetached, tmuxSessionExists } = await import("./exec.js");
  const { setAttached } = await import("./state.js");
  const { startRelay, capturePaneSnapshot } = await import("./relay/session-relay.js");
  const { safeSend, codeBlock } = await import("./safe-send.js");

  if (!isContainerRunning()) return ctx.reply("Container is not running.");

  const userId = ctx.from!.id;
  const chatId = ctx.chat!.id;
  const dir = `${config.reposDir}/${project}`;

  if (tmuxSessionExists(sessionName)) {
    setAttached(userId, sessionName);
    startRelay(sessionName, chatId, userId, sendMessage);
    const snapshot = capturePaneSnapshot(sessionName);
    await ctx.reply(`Attached to remote session '${sessionName}'.`);
    if (snapshot) {
      await safeSend(ctx, codeBlock(snapshot.slice(-2000)));
    }
    return;
  }

  dockerExecDetached(
    `tmux new-session -d -s '${sessionName}' -c '${dir}' 'claude && claude remote-control; zsh'`
  );
  await new Promise((r) => setTimeout(r, 3000));
  setAttached(userId, sessionName);
  startRelay(sessionName, chatId, userId, sendMessage);
  return ctx.reply(
    `Remote session '${sessionName}' created.\nUse /detach to disconnect.`
  );
});

// Branch worktrees
bot.command("cs_branch", (ctx) => handleBranch(ctx, sendMessage));
bot.command("cs_branches", handleBranches);
bot.command("cs_branch_rm", handleBranchRemove);

// Container management
bot.command("claude_status", handleStatus);
bot.command("claude_logs", handleLogs);
bot.command("claude_up", handleUp);
bot.command("claude_down", handleDown);
bot.command("claude_restart", handleRestart);

// Session interaction
bot.command("detach", handleDetach);
bot.command("screenshot", handleScreenshot);

// Help
bot.command("start", (ctx) =>
  ctx.reply(
    [
      "Claude Dev Container Controller",
      "",
      "Sessions:",
      "  /cs <project> [feature] - Start/attach session",
      "  /cs_list - List active sessions",
      "  /cs_kill <name> - Kill a session",
      "  /cs_remote <project> - Remote control session",
      "",
      "Branch Worktrees:",
      "  /cs_branch <proj> <branch> - Session on branch",
      "  /cs_branches <proj> - List worktrees",
      "  /cs_branch_rm <proj> <branch> - Remove worktree",
      "",
      "Container:",
      "  /claude_status - Container status",
      "  /claude_logs - View logs",
      "  /claude_up - Start container",
      "  /claude_down - Stop container",
      "  /claude_restart - Restart container",
      "",
      "Interaction:",
      "  /detach - Disconnect from session",
      "  /screenshot <session> - Capture pane",
      "",
      "When attached to a session, all text messages are",
      "forwarded to the Claude session as input.",
    ].join("\n")
  )
);

// --- Text message handler (relay input when attached) ---
bot.on("message:text", async (ctx) => {
  const userId = ctx.from.id;
  const state = getUserState(userId);

  if (state.mode !== "ATTACHED") {
    return ctx.reply(
      "Not attached to any session. Use /cs <project> to start one, or /start for help."
    );
  }

  const text = ctx.message.text;

  try {
    sendInput(state.sessionName, text);
  } catch (err) {
    return ctx.reply(`Failed to send input: ${err}`);
  }
});

// --- Error handler ---
bot.catch((err) => {
  console.error("Bot error:", err.message);
});

// --- Start ---
console.log("Starting Claude Dev Container Telegram bot...");
console.log(`Allowed users: ${config.allowedUserIds.join(", ")}`);
bot.start();
console.log("Bot is running.");
