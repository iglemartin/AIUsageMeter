<div align="center">

# Claude Usage — Widget for KDE Plasma 6

**See how much of your Claude (Pro/Max) account is left without leaving the panel.**

Shows the % used of the **5-hour** and **weekly (7-day)** limits, plus the time until the
next reset. It docks into any bar, just like the clock or the weather.

[![Plasma 6](https://img.shields.io/badge/KDE%20Plasma-6-1d99f3?logo=kde&logoColor=white)](https://kde.org/plasma-desktop/)
[![Qt 6](https://img.shields.io/badge/Qt-6-41cd52?logo=qt&logoColor=white)](https://www.qt.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-D97757.svg)](LICENSE)
[![Linux](https://img.shields.io/badge/Linux-only-FCC624?logo=linux&logoColor=black)](#requirements)

</div>

> [!NOTE]
> Unofficial / not affiliated with Anthropic. This is a personal project that uses the same
> endpoint as Claude Code's `/usage` command, with **your own** account.

---

## Table of contents

- [What it shows](#what-it-shows)
- [How it gets the data](#how-it-gets-the-data)
- [Privacy](#privacy)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Project structure](#project-structure)
- [Development and testing](#development-and-testing)
- [License](#license)

## What it shows

- **In the panel (compact):** a **horizontal progress bar** (media-player style) with the %
  used and the **time until the next reset** next to it (e.g. `46% · 3h04`), in **Claude's
  signature orange** (`#D97757`). The container sizes to its content, with no leftover space.
  You can also pick a **ring** and, optionally, the green → amber → red traffic light based on
  thresholds.
- **On click (popup):** the two windows (5 h and 7 days) with a ring, % free, a countdown to
  the reset, a refresh button and the time of the last reading.
- **Right-click:** "Refresh now", toggle 5 h / weekly, and "Configure…".

## How it gets the data

It reads your OAuth token from `~/.claude/.credentials.json` (the one Claude Code creates
when you sign in) and queries Anthropic's official usage endpoint:

```http
GET https://api.anthropic.com/api/oauth/usage
```

It's the same data shown by Claude Code's `/usage` command.

> [!TIP]
> On **Pro/Max** plans the limit is expressed as a **% of utilization**, not as a fixed
> number of tokens; that's why "available" is shown as *% free + time until reset*.

### Token renewal

If the token has expired and the option is enabled (the default), the widget renews it using
the `refreshToken` against `https://api.anthropic.com/v1/oauth/token` and **rewrites
`~/.claude/.credentials.json` atomically**, leaving a backup at
`~/.claude/.credentials.json.widgetbak` and preserving the rest of the file. That way the
widget and Claude Code always share the same token. You can disable it in the settings
(read-only mode): in that case, when the token expires you'll see a notice and the widget
recovers on its own the next time you use Claude Code.

## Privacy

- **Nothing leaves your machine** except the authenticated call to the Anthropic API, made
  with **your own** credential.
- The token is **never** copied into the repo or logged: it's read at runtime from
  `~/.claude/.credentials.json`, which is not part of this project.
- No telemetry, no analytics, no intermediate servers.

## Requirements

- **KDE Plasma 6** (tested on 6.6) / Qt 6.
- **`curl`** and **`jq`** — present on most distros. On Fedora: `sudo dnf install jq`.
- Having signed in at least once with **Claude Code** (so that `~/.claude/.credentials.json` exists).

## Installation

```sh
git clone https://github.com/iglemartin/ClaudeUsageWidget.git
cd ClaudeUsageWidget
./install.sh
```

Then: right-click the panel → **Add or Manage Widgets…** → search for **"Claude Usage"** and
drag it onto the bar.

<details>
<summary>Manual installation</summary>

```sh
chmod +x org.miglesias.claudeusage/contents/code/usage.sh
kpackagetool6 --type Plasma/Applet --install org.miglesias.claudeusage
```

To update after editing the code:

```sh
kpackagetool6 --type Plasma/Applet --upgrade org.miglesias.claudeusage
kquitapp6 plasmashell && kstart plasmashell   # restart the Plasma shell
```

</details>

<details>
<summary>Uninstall</summary>

```sh
kpackagetool6 --type Plasma/Applet --remove org.miglesias.claudeusage
```

</details>

## Configuration

Right-click the widget → **Configure…**

| Option | Default | Description |
|---|---|---|
| Refresh every | 300 s | Polling interval (30–3600 s). The endpoint has a strict rate limit; don't lower it too much. |
| Indicator style | Horizontal bar | Bar or ring in the panel. |
| Show in panel | 5-hour limit | Which window the indicator reflects (5 h / weekly). |
| Show bar | on | Show/hide the progress bar (bar style only). |
| Show percentage | on | Show/hide the `%` (bar and ring). |
| Show time until reset | on | Show/hide the `· 3h04` (bar style only). |
| Displayed value | % used | Switch to % remaining. |
| Use alert colors | off | Green/amber/red traffic light instead of Claude orange. |
| Warning (amber) | 70 % | Amber threshold (if alert colors are enabled). |
| Critical (red) | 90 % | Red threshold (if alert colors are enabled). |
| Renew the token | on | Renew and rewrite credentials on expiry. |

## Project structure

```
org.miglesias.claudeusage/
├── metadata.json
└── contents/
    ├── code/usage.sh          # reads token, refreshes if needed, queries /usage → JSON
    ├── config/{main.xml,config.qml}
    └── ui/
        ├── main.qml            # plasmoid: compact (ring/bar) + popup + context menu
        ├── UsageRing.qml       # progress ring (Canvas)
        ├── UsageBar.qml        # horizontal progress bar
        ├── UsageCard.qml       # per-window card in the popup
        └── configGeneral.qml   # settings page
```

## Development and testing

Run the data script on its own, without touching your credentials:

```sh
# read-only mode (does not refresh or rewrite the token)
sh org.miglesias.claudeusage/contents/code/usage.sh 0 | jq .
```

Contributions are welcome: open an issue or a PR.

## License

[MIT](LICENSE) © [iglemartin](https://github.com/iglemartin)
