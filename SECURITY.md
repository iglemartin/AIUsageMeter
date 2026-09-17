# Security Policy

This widget edits your Claude Code settings and runs as your status line, so security
reports are very welcome.

## Supported versions

Only the latest release receives fixes.

## Reporting a vulnerability

Please **do not open a public issue**. Instead, use one of these private channels:

- GitHub: **Security → Report a vulnerability** on this repository
  (private vulnerability reporting).
- Email: <martin.igle@gmail.com>

Include the steps to reproduce and the impact you observed. You can expect a first
answer within a few days.

## What the widget touches

- **No credentials, no network.** The widget never reads your Claude token and makes no
  network calls. Usage data comes from the `rate_limits` field that Claude Code passes to
  its [status line](https://code.claude.com/docs/en/statusline).
- `~/.claude/settings.json` is only modified when you click **Connect** or **Disconnect**:
  the write is atomic, keeps every other setting and leaves a private backup
  (`settings.json.widgetbak`, mode `600`).
- If you had a status line, its command is stored in
  `~/.config/ai-usage-meter/` (private directory) and run by the bridge with the same
  input, so it keeps working; **Disconnect** restores it.
- The cache `~/.cache/ai-usage-meter/usage.json` (private directory, mode `600`) only
  holds the usage percentages, reset times and the time of the reading.
