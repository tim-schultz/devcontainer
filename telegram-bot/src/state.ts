/**
 * Per-user state machine for session attachment.
 *
 * IDLE     → no active relay, slash commands only
 * ATTACHED → all text messages forwarded to tmux session
 */

export type UserState =
  | { mode: "IDLE" }
  | { mode: "ATTACHED"; sessionName: string };

const states = new Map<number, UserState>();

export function getUserState(userId: number): UserState {
  return states.get(userId) ?? { mode: "IDLE" };
}

export function setAttached(userId: number, sessionName: string) {
  states.set(userId, { mode: "ATTACHED", sessionName });
}

export function setIdle(userId: number) {
  states.set(userId, { mode: "IDLE" });
}
