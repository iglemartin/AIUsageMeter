#!/bin/sh
# statusline.sh — Claude Code status line bridge for the AI Usage Meter widget.
#
# Claude Code runs this script as its status line and passes the session data as
# JSON on stdin (https://code.claude.com/docs/en/statusline). The script saves the
# documented `rate_limits` fields to a small cache file that the widget reads, then
# prints the status line: the output of the previous status line command if there
# was one (see helper.sh connect), or a short default line otherwise.
#
# No tokens and no network: only the data Claude Code already hands to status lines.

set -u

CACHE_DIR="${HOME}/.cache/ai-usage-meter"
CACHE="${CACHE_DIR}/usage.json"
CHAIN_FILE="${HOME}/.config/ai-usage-meter/statusline-chain"

JQ="$(command -v /usr/bin/jq || command -v jq || true)"

INPUT="$(cat)"

save_rate_limits() {
    [ -n "$JQ" ] || return 0
    (umask 077 && mkdir -p "$CACHE_DIR") 2>/dev/null || return 0

    OLD="$CACHE"
    "$JQ" -e 'type == "object"' "$OLD" >/dev/null 2>&1 || OLD=/dev/null

    # Merge the windows present now into the previous reading: Claude Code omits
    # rate_limits before the first API response and drops a window once it resets.
    NEW="$(printf '%s' "$INPUT" | "$JQ" -c \
        --slurpfile old "$OLD" --argjson now "$(date +%s)" '
        ((.rate_limits // {}) | {five_hour, seven_day}
            | with_entries(select(.value.used_percentage != null))) as $rl
        | if ($rl | length) == 0 then empty
          else (($old[0] // {}) + $rl + {updated_at: $now}) end' 2>/dev/null)"
    [ -n "$NEW" ] || return 0

    TMP="$(mktemp "${CACHE_DIR}/.usage.XXXXXX" 2>/dev/null)" || return 0
    if printf '%s\n' "$NEW" > "$TMP"; then
        mv -f "$TMP" "$CACHE"
    else
        rm -f "$TMP"
    fi
}

default_line() {
    [ -n "$JQ" ] || return 0
    printf '%s' "$INPUT" | "$JQ" -r '
        def pct: if . == null then empty else (. | round | tostring) + "%" end;
        [ "[" + (.model.display_name // "Claude") + "]",
          ((.rate_limits.five_hour.used_percentage | pct) | "5h " + .),
          ((.rate_limits.seven_day.used_percentage | pct) | "7d " + .)
        ] | join(" · ")' 2>/dev/null
}

save_rate_limits

if [ -s "$CHAIN_FILE" ]; then
    # hand the same data to the status line the user had before
    # (with bash when available: the command may use bash syntax)
    SH="$(command -v bash || echo sh)"
    printf '%s' "$INPUT" | "$SH" -c "$(cat "$CHAIN_FILE")"
    exit $?
fi

default_line
