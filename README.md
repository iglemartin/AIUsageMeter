<div align="center">

# AI Usage Meter — Widget for KDE Plasma 6

**See how much of your Claude (Pro/Max) account is left without leaving the panel.**

Shows the % used of the **5-hour** and **weekly (7-day)** limits, plus the time until the
next reset. It docks into any bar, just like the clock or the weather.

[![Plasma 6](https://img.shields.io/badge/KDE%20Plasma-6-1d99f3?logo=kde&logoColor=white)](https://kde.org/plasma-desktop/)
[![Qt 6](https://img.shields.io/badge/Qt-6-41cd52?logo=qt&logoColor=white)](https://www.qt.io/)
[![License: MIT](https://img.shields.io/badge/License-MIT-D97757.svg)](LICENSE)
[![Linux](https://img.shields.io/badge/Linux-only-FCC624?logo=linux&logoColor=black)](#requirements)

</div>

> [!NOTE]
> Unofficial / not affiliated with Anthropic. The widget never touches your Claude
> credentials: it reads the usage data that Claude Code itself hands to its
> [status line](https://code.claude.com/docs/en/statusline).

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
- [Support](#support)

## What it shows

- **In the panel (compact):** a **horizontal progress bar** (media-player style) with the %
  used and the **time until the next reset** next to it (e.g. `46% · 3h04`), in an **orange accent**
  (`#D97757`). The container sizes to its content, with no leftover space.
  You can also pick a **ring** and, optionally, the green → amber → red traffic light based on
  thresholds.
- **On click (popup):** the two windows (5 h and 7 days) with a ring, % free, a countdown to
  the reset, a refresh button and the time of the last reading.
- **Right-click:** "Refresh now", toggle 5 h / weekly, "About AI Usage Meter…" and "Configure…".

## How it gets the data

Claude Code passes session data to its **status line** script, and for Pro/Max subscribers
that data includes the **5-hour and 7-day rate limits** (`rate_limits.*.used_percentage` and
`resets_at`), as [documented by Anthropic](https://code.claude.com/docs/en/statusline#rate-limit-usage).

```
Claude Code ──stdin──▶ statusline.sh ──writes──▶ ~/.cache/ai-usage-meter/usage.json
                            │                                   │
                            ▼                                   ▼
                  your status line (unchanged)       widget (helper.sh read)
```

1. **Connect once:** click **Connect to Claude Code** in the popup or in the settings. This sets
   `statusLine` in `~/.claude/settings.json` to the widget's `statusline.sh` (atomic write,
   backup at `settings.json.widgetbak`, every other setting kept).
2. **If you already had a status line,** it keeps showing: `statusline.sh` runs your previous
   command with the same data. **Disconnect** restores it exactly as it was. Without a previous
   one, a short default line is shown (`[Opus] · 5h 23% · 7d 41%`).
3. The widget re-reads the cached file every few seconds.

> [!IMPORTANT]
> Readings update **while you use Claude Code** (Claude Code only sends `rate_limits` after the
> first response of a session). The popup shows how old the last reading is. When a window's
> reset time passes, the widget shows it at 0 % until the next reading.

> [!TIP]
> On **Pro/Max** plans the limit is expressed as a **% of utilization**, not as a fixed
> number of tokens; that's why "available" is shown as *% free + time until reset*.

## Privacy

- **No credentials and no network access:** the widget doesn't read your Claude token or call
  any API. It only uses data Claude Code already gives to status lines.
- The cache (`~/.cache/ai-usage-meter/usage.json`, mode `600`) only holds the two
  percentages, their reset times and the time of the reading.
- No telemetry, no analytics, no intermediate servers.

Found a security issue? Please report it privately — see [SECURITY.md](SECURITY.md).

## Requirements

- **KDE Plasma 6** (tested on 6.6) / Qt 6.
- **`jq`** — present on most distros. On Fedora: `sudo dnf install jq`.
- **Claude Code** signed in with a **Pro or Max** plan (other plans don't report rate limits).

## Installation

```sh
git clone https://github.com/iglemartin/AIUsageMeter.git
cd AIUsageMeter
./install.sh
```

Then: right-click the panel → **Add or Manage Widgets…** → search for **"AI Usage Meter"** and
drag it onto the bar. Finally, click **Connect to Claude Code** in the widget's popup.

<details>
<summary>Manual installation</summary>

```sh
chmod +x org.miglesias.aiusagemeter/contents/code/*.sh
kpackagetool6 --type Plasma/Applet --install org.miglesias.aiusagemeter
```

To update after editing the code:

```sh
kpackagetool6 --type Plasma/Applet --upgrade org.miglesias.aiusagemeter
systemctl --user restart plasma-plasmashell.service   # restart the Plasma shell
```

</details>

<details>
<summary>Uninstall</summary>

First click **Disconnect** in the widget settings (this restores your previous status line),
then:

```sh
kpackagetool6 --type Plasma/Applet --remove org.miglesias.aiusagemeter
rm -rf ~/.cache/ai-usage-meter ~/.config/ai-usage-meter
```

</details>

## Configuration

Right-click the widget → **Configure…**

| Option | Default | Description |
|---|---|---|
| Claude Code | — | Connect / disconnect the status line bridge. |
| Re-read every | 30 s | How often the widget re-reads the local cache (5–3600 s). |
| Indicator style | Horizontal bar | Bar or ring in the panel. |
| Show in panel | 5-hour limit | Which window the indicator reflects (5 h / weekly). |
| Show bar | on | Show/hide the progress bar (bar style only). |
| Show percentage | on | Show/hide the `%` (bar and ring). |
| Show time until reset | on | Show/hide the `· 3h04` (bar style only). |
| Displayed value | % used | Switch to % remaining. |
| Use alert colors | off | Green/amber/red traffic light instead of the default orange. |
| Warning (amber) | 70 % | Amber threshold (if alert colors are enabled). |
| Critical (red) | 90 % | Red threshold (if alert colors are enabled). |
| Font | System default | Font family for the panel and the popup. |
| Panel text size | Automatic | Size in points of the panel text (`Automatic` fits it to the panel height). |
| Bold | on | Bold text in the panel. |

## Project structure

```
org.miglesias.aiusagemeter/
├── metadata.json
└── contents/
    ├── code/statusline.sh     # Claude Code status line bridge: caches rate_limits
    ├── code/helper.sh         # read cache / connect / disconnect (edits settings.json)
    ├── code/links.js          # author contact and donation links
    ├── config/{main.xml,config.qml}
    └── ui/
        ├── main.qml            # plasmoid: compact (ring/bar) + popup + context menu
        ├── UsageRing.qml       # progress ring (Canvas)
        ├── UsageBar.qml        # horizontal progress bar
        ├── UsageCard.qml       # per-window card in the popup
        ├── AboutDialog.qml     # "About" window (data from metadata.json)
        └── configGeneral.qml   # settings page
```

## Development and testing

```sh
C=org.miglesias.aiusagemeter/contents/code
sh $C/helper.sh status        # is the bridge set as Claude Code's status line?
sh $C/helper.sh read | jq .   # what the widget sees

# feed the bridge sample status line data (in a throwaway HOME)
export T="$(mktemp -d)"
echo '{"model":{"display_name":"Opus"},"rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1789700000}}}' \
  | HOME="$T" sh $C/statusline.sh
cat "$T/.cache/ai-usage-meter/usage.json"
```

Contributions are welcome: open an issue or a PR.

## License

[MIT](LICENSE) © [iglemartin](https://github.com/iglemartin) · <martin.igle@gmail.com>

## Support

If you find the widget useful, you can [buy me a coffee ☕](https://buymeacoffee.com/iglemartin). There is also a link in the widget's **About** window and in its settings.
