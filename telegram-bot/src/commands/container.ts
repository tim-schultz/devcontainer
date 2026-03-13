import { Context } from "grammy";
import { hostExec, isContainerRunning } from "../exec.js";
import { safeSend, codeBlock } from "../safe-send.js";

const COMPOSE_FILE = "/home/tam/repos/.devcontainer/docker-compose.yml";

/**
 * /claude_status - Show container status
 */
export async function handleStatus(ctx: Context) {
  try {
    const out = hostExec(
      `docker ps --filter name=claude-devcontainer --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'`
    );
    if (!out || !out.includes("claude")) {
      return ctx.reply("Container is not running.");
    }
    return safeSend(ctx, codeBlock(out));
  } catch {
    return ctx.reply("Container is not running.");
  }
}

/**
 * /claude_logs - Show last 50 lines of container logs
 */
export async function handleLogs(ctx: Context) {
  if (!isContainerRunning()) {
    return ctx.reply("Container is not running.");
  }

  try {
    const out = hostExec("docker logs --tail=50 claude-devcontainer", 15000);
    const trimmed = out.slice(-3500);
    return safeSend(ctx, codeBlock(trimmed));
  } catch (err) {
    return ctx.reply(`Failed to get logs: ${err}`);
  }
}

/**
 * /claude_up - Start the container
 */
export async function handleUp(ctx: Context) {
  if (isContainerRunning()) {
    return ctx.reply("Container is already running.");
  }

  await ctx.reply("Starting container...");
  try {
    hostExec(`docker compose -f ${COMPOSE_FILE} up -d`, 30000);
    return ctx.reply("Container started.");
  } catch (err) {
    return ctx.reply(`Failed to start: ${err}`);
  }
}

/**
 * /claude_restart - Restart the container
 */
export async function handleRestart(ctx: Context) {
  await ctx.reply("Restarting container...");
  try {
    hostExec(`docker compose -f ${COMPOSE_FILE} restart`, 30000);
    return ctx.reply("Container restarted.");
  } catch (err) {
    return ctx.reply(`Failed to restart: ${err}`);
  }
}

/**
 * /claude_down - Stop the container
 */
export async function handleDown(ctx: Context) {
  await ctx.reply("Stopping container...");
  try {
    hostExec(`docker compose -f ${COMPOSE_FILE} down`, 30000);
    return ctx.reply("Container stopped.");
  } catch (err) {
    return ctx.reply(`Failed to stop: ${err}`);
  }
}
