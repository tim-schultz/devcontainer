import { Context } from "grammy";
import { Api } from "grammy";

/**
 * Send a message safely, falling back to plain text if markdown fails.
 */
export async function safeSend(ctx: Context, text: string) {
  try {
    await ctx.reply(text, { parse_mode: "Markdown" });
  } catch {
    // Markdown failed, send as plain text
    await ctx.reply(stripMarkdown(text));
  }
}

/**
 * Send a message via bot API safely with markdown fallback.
 */
export async function safeSendApi(
  api: Api,
  chatId: number,
  text: string
) {
  try {
    await api.sendMessage(chatId, text, { parse_mode: "Markdown" });
  } catch {
    await api.sendMessage(chatId, stripMarkdown(text));
  }
}

/**
 * Escape text for use inside a Telegram markdown code block.
 * Replaces backticks with single quotes to prevent broken formatting.
 */
export function escapeForCodeBlock(text: string): string {
  return text.replace(/`/g, "'");
}

/**
 * Wrap text in a code block, escaping any internal backticks.
 */
export function codeBlock(text: string): string {
  return "```\n" + escapeForCodeBlock(text) + "\n```";
}

function stripMarkdown(text: string): string {
  return text.replace(/```/g, "").replace(/`/g, "'");
}
