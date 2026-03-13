import stripAnsi from "strip-ansi";
import { config } from "../config.js";

/**
 * Clean terminal output for Telegram display.
 * Strips ANSI codes, collapses spinner lines, trims whitespace.
 */
export function cleanOutput(raw: string): string {
  let text = stripAnsi(raw);

  // Remove carriage return lines (spinner overwrites)
  // \r without \n means the line is being overwritten — remove everything from \r to end of that segment
  text = text.replace(/\r(?!\n)[^\n]*/g, "");

  // Collapse multiple blank lines
  text = text.replace(/\n{3,}/g, "\n\n");

  return text.trim();
}

/**
 * Chunk text into Telegram-safe messages (max 4096 chars).
 * Tries to split on newlines.
 */
export function chunkMessage(text: string): string[] {
  const max = config.maxMessageLength;
  if (text.length <= max) return [text];

  const chunks: string[] = [];
  let remaining = text;

  while (remaining.length > 0) {
    if (remaining.length <= max) {
      chunks.push(remaining);
      break;
    }

    // Find last newline before max
    let splitAt = remaining.lastIndexOf("\n", max);
    if (splitAt <= 0) splitAt = max;

    chunks.push(remaining.slice(0, splitAt));
    remaining = remaining.slice(splitAt).trimStart();
  }

  return chunks;
}
