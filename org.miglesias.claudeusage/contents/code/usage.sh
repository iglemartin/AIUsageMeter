#!/bin/sh
# usage.sh — Claude Usage widget helper.
#
# Reads the OAuth token from ~/.claude/.credentials.json, refreshes it if it has
# expired (when allowed), queries the Anthropic usage endpoint and prints its
# JSON verbatim to stdout. On any problem it prints {"error":"..."} and exits
# with code 0 (the widget decides what to show).
#
# Usage:  usage.sh [allow_refresh]
#           allow_refresh = 1 (default) allows refreshing and rewriting
#                             ~/.claude/.credentials.json atomically.
#                         = 0 read-only mode, never touches the file.
#
# Only depends on /bin/sh, curl and jq (absolute paths so it works inside
# plasmashell, where PATH may not include nvm/node). flock is used when present.
#
# Security: tokens never appear on a command line (visible to other users via
# ps); they reach curl through stdin and jq through the environment.

set -u

CRED="${HOME}/.claude/.credentials.json"
LOCK="${XDG_RUNTIME_DIR:-${HOME}/.claude}/claude-usage-widget.lock"
CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"
USAGE_URL="https://api.anthropic.com/api/oauth/usage"
TOKEN_URL="https://api.anthropic.com/v1/oauth/token"
ALLOW_REFRESH="${1:-1}"

# locate the tools (prefer /usr/bin, fall back to PATH)
CURL="$(command -v /usr/bin/curl || command -v curl || true)"
JQ="$(command -v /usr/bin/jq || command -v jq || true)"
FLOCK="$(command -v /usr/bin/flock || command -v flock || true)"

# Prints {"error":"<code>"} and exits. The code may come from the server, so it
# is reduced to a safe charset to always produce valid JSON.
emit_err() {
    code="$(printf '%s' "$1" | tr -cd 'A-Za-z0-9_.-' | cut -c1-64)"
    [ -n "$code" ] || code="request_failed"
    printf '{"error":"%s"}\n' "$code"
    exit 0
}

# curl ignoring ~/.curlrc (-q must be the first argument), HTTPS only
http() {
    "$CURL" -q -s -m 15 --proto =https "$@"
}

read_creds() {
    AT="$("$JQ" -r '.claudeAiOauth.accessToken // empty' "$CRED" 2>/dev/null)"
    RT="$("$JQ" -r '.claudeAiOauth.refreshToken // empty' "$CRED" 2>/dev/null)"
    EXP="$("$JQ" -r '.claudeAiOauth.expiresAt // 0' "$CRED" 2>/dev/null)"
    case "$EXP" in
        ''|*[!0-9]*) EXP=0 ;;
    esac
}

now_ms() {
    echo "$(( $(date +%s) * 1000 ))"
}

# Only refresh once the token has actually expired: Claude Code refreshes its
# own token ahead of time, so this avoids both rotating it at the same moment.
is_expired() {
    [ "$EXP" -gt 0 ] && [ "$(now_ms)" -ge "$EXP" ]
}

refresh_token() {
    # serialize with other widget instances (e.g. one per panel)
    if [ -n "$FLOCK" ] && touch "$LOCK" 2>/dev/null && [ -w "$LOCK" ]; then
        exec 9>"$LOCK"
        "$FLOCK" -w 30 9 || return 0
    fi

    # someone else may have refreshed while we waited for the lock
    read_creds
    is_expired || return 0
    [ -n "$RT" ] || return 0
    OLD_AT="$AT"

    RESP="$(RT="$RT" CID="$CLIENT_ID" "$JQ" -n \
                '{grant_type:"refresh_token", refresh_token:env.RT, client_id:env.CID}' \
            | http -X POST "$TOKEN_URL" \
                -H "Content-Type: application/json" --data-binary @-)"
    NEW_AT="$(printf '%s' "$RESP" | "$JQ" -r '.access_token // empty' 2>/dev/null)"
    [ -n "$NEW_AT" ] || return 0
    NEW_RT="$(printf '%s' "$RESP" | "$JQ" -r '.refresh_token // empty' 2>/dev/null)"
    EXPIN="$(printf '%s' "$RESP" | "$JQ" -r '.expires_in // 3600' 2>/dev/null)"
    case "$EXPIN" in ''|*[!0-9]*) EXPIN=3600 ;; esac
    [ -n "$NEW_RT" ] || NEW_RT="$RT"
    NEW_EXP="$(( $(now_ms) + EXPIN * 1000 ))"

    # If the file changed during the request (Claude Code wrote a new token),
    # keep its version instead of overwriting it.
    read_creds
    if [ "$AT" != "$OLD_AT" ]; then
        return 0
    fi

    # private backup + atomic write, preserving the rest of the JSON
    (umask 077 && cp -f "$CRED" "${CRED}.widgetbak") 2>/dev/null
    chmod 600 "${CRED}.widgetbak" 2>/dev/null
    TMP="$(mktemp "${HOME}/.claude/.cred.XXXXXX" 2>/dev/null)"
    if [ -n "$TMP" ] && NEW_AT="$NEW_AT" NEW_RT="$NEW_RT" "$JQ" \
            --argjson exp "$NEW_EXP" \
            '.claudeAiOauth.accessToken=env.NEW_AT
             | .claudeAiOauth.refreshToken=env.NEW_RT
             | .claudeAiOauth.expiresAt=$exp' \
            "$CRED" > "$TMP" 2>/dev/null; then
        chmod 600 "$TMP" 2>/dev/null
        mv -f "$TMP" "$CRED"
        AT="$NEW_AT"
    else
        [ -n "$TMP" ] && rm -f "$TMP"
    fi
}

[ -n "$CURL" ] || emit_err "no_curl"
[ -n "$JQ" ] || emit_err "no_jq"
[ -r "$CRED" ] || emit_err "no_credentials"

read_creds
[ -n "$AT" ] || emit_err "no_token"

if [ "$ALLOW_REFRESH" = "1" ] && [ -n "$RT" ] && is_expired; then
    refresh_token
fi

# the Authorization header goes through stdin, not argv
RESP="$(printf 'Authorization: Bearer %s\n' "$AT" \
        | http "$USAGE_URL" \
            -H @- \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "anthropic-version: 2023-06-01")"

if printf '%s' "$RESP" | "$JQ" -e '.five_hour' >/dev/null 2>&1; then
    printf '%s\n' "$RESP"
else
    MSG="$(printf '%s' "$RESP" | "$JQ" -r '(.error.type // .error // "request_failed")' 2>/dev/null)"
    emit_err "${MSG:-request_failed}"
fi
