import { execSync, exec as execCb } from "node:child_process";
import { config } from "./config.js";

const CN = config.containerName;

/**
 * Run a command inside the devcontainer synchronously.
 * Returns stdout as a string.
 */
export function dockerExec(cmd: string, timeout = 10_000): string {
  return execSync(`docker exec ${CN} ${cmd}`, {
    timeout,
    encoding: "utf-8",
  }).trim();
}

/**
 * Run a command inside the devcontainer, non-interactive (no -it).
 * For commands that create sessions but we don't attach.
 */
export function dockerExecDetached(cmd: string): string {
  return execSync(`docker exec -d ${CN} ${cmd}`, {
    encoding: "utf-8",
  }).trim();
}

/**
 * Run a host-level command (e.g. docker compose).
 */
export function hostExec(cmd: string, timeout = 15_000): string {
  return execSync(cmd, { timeout, encoding: "utf-8" }).trim();
}

/**
 * Check if the devcontainer is running.
 */
export function isContainerRunning(): boolean {
  try {
    const out = hostExec(
      `docker ps --filter name=^${CN}$ --format '{{.Names}}'`
    );
    return out.includes(CN);
  } catch {
    return false;
  }
}

/**
 * List tmux sessions inside the container.
 */
export function listTmuxSessions(): string[] {
  try {
    const out = dockerExec(`tmux list-sessions -F '#{session_name}'`);
    return out
      .split("\n")
      .map((s) => s.trim())
      .filter(Boolean);
  } catch {
    return [];
  }
}

/**
 * Check if a tmux session exists.
 */
export function tmuxSessionExists(name: string): boolean {
  try {
    dockerExec(`tmux has-session -t '${name}'`);
    return true;
  } catch {
    return false;
  }
}
