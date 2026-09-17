# Security Policy

This widget handles your Claude OAuth token (read from `~/.claude/.credentials.json`),
so security reports are very welcome.

## Supported versions

Only the latest release receives fixes.

## Reporting a vulnerability

Please **do not open a public issue**. Instead, use one of these private channels:

- GitHub: **Security → Report a vulnerability** on this repository
  (private vulnerability reporting).
- Email: <martin.igle@gmail.com>

Include the steps to reproduce and the impact you observed. You can expect a first
answer within a few days.

## How the widget handles your token

- The token is read at runtime and is never stored in the repository or logged.
- Tokens are never passed on a command line (where other local users could see them
  with `ps`): they reach `curl` through stdin and `jq` through the environment.
- Network calls go only to `https://api.anthropic.com` (HTTPS enforced; `~/.curlrc`
  is ignored).
- When token renewal is enabled, `~/.claude/.credentials.json` is rewritten
  atomically with mode `600`, preserving the rest of the file, and a private backup
  (`.credentials.json.widgetbak`, mode `600`) is kept. Renewal only happens once the
  token has expired, and is skipped if another program updated the file meanwhile.
- Renewal can be disabled in the settings (read-only mode).
