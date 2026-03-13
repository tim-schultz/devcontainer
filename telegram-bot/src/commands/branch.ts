import { Context } from "grammy";
import {
  dockerExec,
  dockerExecDetached,
  isContainerRunning,
  tmuxSessionExists,
} from "../exec.js";
import { setAttached } from "../state.js";
import { startRelay, capturePaneSnapshot } from "../relay/session-relay.js";
import { config } from "../config.js";
import { safeSend, codeBlock } from "../safe-send.js";

/**
 * /cs_branch <project> <branch> - Create worktree session on specific branch
 */
export async function handleBranch(
  ctx: Context,
  sendMessage: (chatId: number, text: string) => Promise<void>
) {
  const text = ctx.message?.text ?? "";
  const parts = text.split(/\s+/).slice(1);
  const project = parts[0];
  const branch = parts[1];

  if (!project || !branch) {
    return ctx.reply("Usage: /cs_branch <project> <branch>");
  }

  if (!isContainerRunning()) {
    return ctx.reply("Container is not running.");
  }

  const sessionName = `${project}@${branch}`;
  const worktreeDir = `${config.reposDir}/${project}-${branch}`;
  const projectDir = `${config.reposDir}/${project}`;
  const userId = ctx.from!.id;
  const chatId = ctx.chat!.id;

  // Check main project is a git repo
  try {
    dockerExec(`test -d '${projectDir}/.git'`);
  } catch {
    return ctx.reply(`${projectDir} is not a git repository.`);
  }

  // Create worktree if needed
  try {
    dockerExec(`test -d '${worktreeDir}'`);
  } catch {
    try {
      dockerExec(
        `git -C '${projectDir}' rev-parse --verify '${branch}'`
      );
      dockerExec(
        `git -C '${projectDir}' worktree add '${worktreeDir}' '${branch}'`
      );
    } catch {
      dockerExec(
        `git -C '${projectDir}' worktree add -b '${branch}' '${worktreeDir}'`
      );
    }
    await ctx.reply(`Created worktree for branch '${branch}'.`);
  }

  // Create or attach session
  if (tmuxSessionExists(sessionName)) {
    setAttached(userId, sessionName);
    startRelay(sessionName, chatId, userId, sendMessage);
    const snapshot = capturePaneSnapshot(sessionName);
    await ctx.reply(`Attached to '${sessionName}'.`);
    if (snapshot) {
      await safeSend(ctx, codeBlock(snapshot.slice(-2000)));
    }
    return;
  }

  dockerExecDetached(
    `tmux new-session -d -s '${sessionName}' -c '${worktreeDir}' 'claude --dangerously-skip-permissions; zsh'`
  );
  await new Promise((r) => setTimeout(r, 2000));

  setAttached(userId, sessionName);
  startRelay(sessionName, chatId, userId, sendMessage);
  return ctx.reply(
    `Session '${sessionName}' created on branch '${branch}'.\nUse /detach to disconnect.`
  );
}

/**
 * /cs_branches <project> - List worktrees
 */
export async function handleBranches(ctx: Context) {
  const text = ctx.message?.text ?? "";
  const project = text.split(/\s+/)[1];

  if (!project) {
    return ctx.reply("Usage: /cs_branches <project>");
  }

  if (!isContainerRunning()) {
    return ctx.reply("Container is not running.");
  }

  try {
    const out = dockerExec(
      `git -C '${config.reposDir}/${project}' worktree list`
    );
    await ctx.reply(`Worktrees for '${project}':`);
    return safeSend(ctx, codeBlock(out));
  } catch {
    return ctx.reply("No worktrees found or project is not a git repo.");
  }
}

/**
 * /cs_branch_rm <project> <branch> - Remove worktree and kill session
 */
export async function handleBranchRemove(ctx: Context) {
  const text = ctx.message?.text ?? "";
  const parts = text.split(/\s+/).slice(1);
  const project = parts[0];
  const branch = parts[1];

  if (!project || !branch) {
    return ctx.reply("Usage: /cs_branch_rm <project> <branch>");
  }

  if (!isContainerRunning()) {
    return ctx.reply("Container is not running.");
  }

  const sessionName = `${project}@${branch}`;
  const worktreeDir = `${config.reposDir}/${project}-${branch}`;
  const projectDir = `${config.reposDir}/${project}`;

  if (tmuxSessionExists(sessionName)) {
    dockerExec(`tmux kill-session -t '${sessionName}'`);
    await ctx.reply(`Killed session '${sessionName}'.`);
  }

  try {
    dockerExec(`test -d '${worktreeDir}'`);
    dockerExec(
      `git -C '${projectDir}' worktree remove '${worktreeDir}' --force`
    );
    return ctx.reply(`Worktree '${worktreeDir}' removed.`);
  } catch {
    return ctx.reply("Worktree not found.");
  }
}
