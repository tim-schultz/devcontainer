import { execSync, spawn } from "node:child_process";
import { createReadStream, existsSync, writeFileSync, unlinkSync } from "node:fs";
import { createInterface } from "node:readline";
import { config } from "../config.js";
import { cleanOutput, chunkMessage } from "./output-parser.js";

const CN = config.containerName;

interface RelayHandle {
  sessionName: string;
  stop: () => void;
}

const activeRelays = new Map<number, RelayHandle>();

/**
 * Send text input to a tmux session (types it as if the user typed it).
 */
export function sendInput(sessionName: string, text: string) {
  // Escape single quotes for shell safety
  const escaped = text.replace(/'/g, "'\\''");
  // Use -l (literal) so text isn't interpreted as tmux key names
  // Send C-m separately — 'Enter' doesn't submit in Claude Code
  execSync(
    `docker exec ${CN} tmux send-keys -t '${sessionName}' -l '${escaped}'`,
    { timeout: 5000 }
  );
  execSync(
    `docker exec ${CN} tmux send-keys -t '${sessionName}' C-m`,
    { timeout: 5000 }
  );
}

/**
 * Start relaying output from a tmux session to a Telegram chat.
 * Uses tmux pipe-pane (Approach C) to stream output to a file,
 * then tails that file and sends new content to Telegram.
 */
export function startRelay(
  sessionName: string,
  chatId: number,
  userId: number,
  sendMessage: (chatId: number, text: string) => Promise<void>
): RelayHandle {
  // Stop existing relay for this user
  stopRelay(userId);

  const logFile = `/tmp/claude-relay-${sessionName.replace(/\//g, "-")}.log`;

  // Create empty log file inside container
  try {
    execSync(`docker exec ${CN} bash -c 'true > ${logFile}'`, { timeout: 5000 });
  } catch {
    // File might not exist yet, create it
    execSync(`docker exec ${CN} touch ${logFile}`, { timeout: 5000 });
  }

  // Start pipe-pane: pipe all pane output to the log file
  try {
    execSync(
      `docker exec ${CN} tmux pipe-pane -t '${sessionName}' 'cat >> ${logFile}'`,
      { timeout: 5000 }
    );
  } catch (err) {
    throw new Error(`Failed to start pipe-pane: ${err}`);
  }

  // Tail the log file from inside the container and stream to us
  const tail = spawn("docker", [
    "exec",
    CN,
    "tail",
    "-f",
    "-n",
    "0", // don't replay existing content
    logFile,
  ]);

  let buffer = "";
  let debounceTimer: ReturnType<typeof setTimeout> | null = null;
  let stopped = false;

  const flushBuffer = async () => {
    if (buffer.length === 0 || stopped) return;

    const cleaned = cleanOutput(buffer);
    buffer = "";

    if (!cleaned) return;

    const chunks = chunkMessage(cleaned);
    for (const chunk of chunks) {
      try {
        await sendMessage(chatId, chunk);
      } catch (err) {
        console.error(`Failed to send relay message: ${err}`);
      }
    }
  };

  tail.stdout.on("data", (data: Buffer) => {
    if (stopped) return;
    buffer += data.toString();

    // Debounce: wait for output to settle before sending
    if (debounceTimer) clearTimeout(debounceTimer);
    debounceTimer = setTimeout(flushBuffer, config.outputDebounceMs);
  });

  tail.stderr.on("data", (data: Buffer) => {
    console.error(`tail stderr: ${data.toString()}`);
  });

  tail.on("close", () => {
    if (!stopped) {
      flushBuffer();
    }
  });

  const handle: RelayHandle = {
    sessionName,
    stop: () => {
      stopped = true;
      if (debounceTimer) clearTimeout(debounceTimer);

      // Kill the tail process
      tail.kill("SIGTERM");

      // Stop pipe-pane
      try {
        execSync(
          `docker exec ${CN} tmux pipe-pane -t '${sessionName}'`,
          { timeout: 5000 }
        );
      } catch {
        // Session might already be dead
      }

      // Clean up log file
      try {
        execSync(`docker exec ${CN} rm -f ${logFile}`, { timeout: 5000 });
      } catch {
        // Best effort
      }

      activeRelays.delete(userId);
    },
  };

  activeRelays.set(userId, handle);
  return handle;
}

/**
 * Stop relay for a user if one is active.
 */
export function stopRelay(userId: number) {
  const existing = activeRelays.get(userId);
  if (existing) {
    existing.stop();
  }
}

/**
 * Get the active relay for a user.
 */
export function getRelay(userId: number): RelayHandle | undefined {
  return activeRelays.get(userId);
}

/**
 * Capture a snapshot of the current pane content (fallback).
 */
export function capturePaneSnapshot(sessionName: string): string {
  try {
    const raw = execSync(
      `docker exec ${CN} tmux capture-pane -t '${sessionName}' -p -S -50`,
      { timeout: 5000, encoding: "utf-8" }
    );
    return cleanOutput(raw);
  } catch {
    return "(unable to capture pane)";
  }
}
