#!/bin/sh
# Installs (or upgrades) the "Claude Usage" plasmoid for the current user.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
PKG="$DIR/org.miglesias.claudeusage"
ID="org.miglesias.claudeusage"

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "Error: kpackagetool6 not found (is Plasma 6 installed?)." >&2
    exit 1
fi

chmod +x "$PKG/contents/code/usage.sh"

if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -qx "$ID"; then
    echo "Upgrading $ID…"
    kpackagetool6 --type Plasma/Applet --upgrade "$PKG"
else
    echo "Installing $ID…"
    kpackagetool6 --type Plasma/Applet --install "$PKG"
fi

echo
echo "Done. To see it:"
echo "  • Right-click the panel → 'Add or Manage Widgets…' → search for 'Claude Usage'."
echo "  • If it was already installed, restart the shell:  kquitapp6 plasmashell && kstart plasmashell"
