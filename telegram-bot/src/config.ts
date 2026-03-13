export const config = {
  botToken: process.env.TELEGRAM_BOT_TOKEN ?? "",
  allowedUserIds: (process.env.TELEGRAM_ALLOWED_USERS ?? "")
    .split(",")
    .map((id) => Number(id.trim()))
    .filter(Boolean),
  containerName: process.env.CONTAINER_NAME ?? "claude-devcontainer",
  reposDir: process.env.REPOS_DIR ?? "/home/tam/repos",
  pollIntervalMs: 1500,
  outputDebounceMs: 800,
  maxMessageLength: 4096,
};

export function validateConfig() {
  if (!config.botToken) {
    throw new Error("TELEGRAM_BOT_TOKEN is required");
  }
  if (config.allowedUserIds.length === 0) {
    throw new Error(
      "TELEGRAM_ALLOWED_USERS is required (comma-separated Telegram user IDs)"
    );
  }
}
