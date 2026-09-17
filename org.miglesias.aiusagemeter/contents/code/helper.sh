#!/bin/sh
# helper.sh — AI Usage Meter widget helper. Always prints one JSON object.
#
#   helper.sh read        usage cached by statusline.sh, plus the connection state
#   helper.sh status      {"connected": true|false}
#   helper.sh connect     set statusline.sh as Claude Code's status line
#   helper.sh disconnect  restore the previous status line
#
# connect/disconnect edit ~/.claude/settings.json atomically, keeping every other
# setting, with a private backup (settings.json.widgetbak). A status line that was
# already configured is not lost: statusline.sh keeps running it and disconnect
# puts it back.

set -u

CODE_DIR="$(cd "$(dirname "$0")" && pwd)"
BRIDGE="${CODE_DIR}/statusline.sh"
# identifies our command inside settings.json
MARKER="/contents/code/statusline.sh"

SETTINGS="${HOME}/.claude/settings.json"
CACHE="${HOME}/.cache/ai-usage-meter/usage.json"
STATE_DIR="${HOME}/.config/ai-usage-meter"
CHAIN_FILE="${STATE_DIR}/statusline-chain"
PREV_FILE="${STATE_DIR}/previous-statusline.json"

JQ="$(command -v /usr/bin/jq || command -v jq || true)"

emit_err() {
    printf '{"error":"%s"}\n' "$1"
    exit 0
}

[ -n "$JQ" ] || emit_err "no_jq"

is_connected() {
    [ -r "$SETTINGS" ] && "$JQ" -e --arg m "$MARKER" \
        '(.statusLine.command // "") | type == "string" and contains($m)' \
        "$SETTINGS" >/dev/null 2>&1
}

connected_json() {
    if is_connected; then echo true; else echo false; fi
}

# settings.json content, or {} when it does not exist yet
current_settings() {
    if [ -e "$SETTINGS" ]; then
        "$JQ" -e 'if type == "object" then . else error end' "$SETTINGS" 2>/dev/null
    else
        echo '{}'
    fi
}

# atomic write of settings.json from stdin, keeping a private backup
write_settings() {
    mkdir -p "$(dirname "$SETTINGS")" || return 1
    TMP="$(mktemp "$(dirname "$SETTINGS")/.settings.XXXXXX")" || return 1
    if ! cat > "$TMP" || ! "$JQ" -e 'type == "object"' "$TMP" >/dev/null 2>&1; then
        rm -f "$TMP"
        return 1
    fi
    if [ -e "$SETTINGS" ]; then
        (umask 077 && cp -f "$SETTINGS" "${SETTINGS}.widgetbak") 2>/dev/null
        chmod 600 "${SETTINGS}.widgetbak" 2>/dev/null
        chmod --reference="$SETTINGS" "$TMP" 2>/dev/null
    else
        chmod 644 "$TMP"
    fi
    mv -f "$TMP" "$SETTINGS"
}

cmd_read() {
    C="$(connected_json)"
    if [ ! -r "$CACHE" ]; then
        if [ "$C" = true ]; then emit_err "no_data"; else emit_err "not_connected"; fi
    fi
    "$JQ" -c --argjson c "$C" '. + {connected: $c}' "$CACHE" 2>/dev/null \
        || emit_err "parse"
}

cmd_connect() {
    if is_connected; then
        echo '{"connected":true}'
        return
    fi
    case "$BRIDGE" in
        *\'*) emit_err "bad_path" ;;   # cannot be single-quoted safely
    esac
    S="$(current_settings)" || emit_err "invalid_settings"

    # remember the previous status line (restored by disconnect, chained meanwhile)
    (umask 077 && mkdir -p "$STATE_DIR") || emit_err "write_failed"
    printf '%s' "$S" | "$JQ" -c '.statusLine // null' > "$PREV_FILE" || emit_err "write_failed"
    PREV_CMD="$(printf '%s' "$S" | "$JQ" -r '
        if (.statusLine.type // "") == "command" then (.statusLine.command // "") else "" end')"
    if [ -n "$PREV_CMD" ]; then
        printf '%s\n' "$PREV_CMD" > "$CHAIN_FILE" || emit_err "write_failed"
    else
        rm -f "$CHAIN_FILE"
    fi

    printf '%s' "$S" | "$JQ" --arg cmd "sh '${BRIDGE}'" \
        '.statusLine = ((.statusLine // {}) + {type: "command", command: $cmd})' \
        | write_settings || emit_err "write_failed"
    echo "{\"connected\":$(connected_json)}"
}

cmd_disconnect() {
    if ! is_connected; then
        echo '{"connected":false}'
        return
    fi
    S="$(current_settings)" || emit_err "invalid_settings"
    PREV="null"
    if [ -r "$PREV_FILE" ] && "$JQ" -e . "$PREV_FILE" >/dev/null 2>&1; then
        PREV="$("$JQ" -c . "$PREV_FILE")"
    fi
    printf '%s' "$S" | "$JQ" --argjson prev "$PREV" \
        'if $prev == null then del(.statusLine) else .statusLine = $prev end' \
        | write_settings || emit_err "write_failed"
    rm -f "$CHAIN_FILE" "$PREV_FILE"
    echo "{\"connected\":$(connected_json)}"
}

case "${1:-read}" in
    read) cmd_read ;;
    status) echo "{\"connected\":$(connected_json)}" ;;
    connect) cmd_connect ;;
    disconnect) cmd_disconnect ;;
    *) emit_err "bad_command" ;;
esac
