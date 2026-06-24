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
# plasmashell, where PATH may not include nvm/node).

set -u

CRED="${HOME}/.claude/.credentials.json"
CLIENT_ID="9d1c250a-e61b-44d9-88ed-5944d1962f5e"
USAGE_URL="https://api.anthropic.com/api/oauth/usage"
TOKEN_URL="https://api.anthropic.com/v1/oauth/token"
ALLOW_REFRESH="${1:-1}"

# locate curl and jq (prefer /usr/bin, fall back to PATH)
CURL="$(command -v /usr/bin/curl || command -v curl || true)"
JQ="$(command -v /usr/bin/jq || command -v jq || true)"

emit_err() { printf '{"error":"%s"}\n' "$1"; exit 0; }

[ -n "$CURL" ] || emit_err "no_curl"
[ -n "$JQ" ] || emit_err "no_jq"
[ -r "$CRED" ] || emit_err "no_credentials"

AT="$("$JQ" -r '.claudeAiOauth.accessToken // empty' "$CRED" 2>/dev/null)"
RT="$("$JQ" -r '.claudeAiOauth.refreshToken // empty' "$CRED" 2>/dev/null)"
EXP="$("$JQ" -r '.claudeAiOauth.expiresAt // 0' "$CRED" 2>/dev/null)"
[ -n "$AT" ] || emit_err "no_token"

NOW="$(( $(date +%s) * 1000 ))"

# Refresh? Only if allowed, there is a refresh token and < 60s of validity left.
case "$EXP" in
    ''|*[!0-9]*) EXP=0 ;;
esac
if [ "$ALLOW_REFRESH" = "1" ] && [ -n "$RT" ] && [ "$EXP" -gt 0 ] && [ "$NOW" -ge "$(( EXP - 60000 ))" ]; then
    REQ="$("$JQ" -n --arg rt "$RT" --arg cid "$CLIENT_ID" \
        '{grant_type:"refresh_token", refresh_token:$rt, client_id:$cid}')"
    RESP="$("$CURL" -s -m 15 -X POST "$TOKEN_URL" \
        -H "Content-Type: application/json" -d "$REQ")"
    NEW_AT="$(printf '%s' "$RESP" | "$JQ" -r '.access_token // empty' 2>/dev/null)"
    if [ -n "$NEW_AT" ]; then
        NEW_RT="$(printf '%s' "$RESP" | "$JQ" -r '.refresh_token // empty' 2>/dev/null)"
        EXPIN="$(printf '%s' "$RESP" | "$JQ" -r '.expires_in // 3600' 2>/dev/null)"
        case "$EXPIN" in ''|*[!0-9]*) EXPIN=3600 ;; esac
        [ -n "$NEW_RT" ] || NEW_RT="$RT"
        NEW_EXP="$(( NOW + EXPIN * 1000 ))"
        # backup + atomic write, preserving the rest of the JSON
        cp -f "$CRED" "${CRED}.widgetbak" 2>/dev/null
        TMP="$(mktemp "${HOME}/.claude/.cred.XXXXXX" 2>/dev/null)"
        if [ -n "$TMP" ] && "$JQ" \
                --arg at "$NEW_AT" --arg rt "$NEW_RT" --argjson exp "$NEW_EXP" \
                '.claudeAiOauth.accessToken=$at
                 | .claudeAiOauth.refreshToken=$rt
                 | .claudeAiOauth.expiresAt=$exp' \
                "$CRED" > "$TMP" 2>/dev/null; then
            chmod 600 "$TMP" 2>/dev/null
            mv -f "$TMP" "$CRED"
            AT="$NEW_AT"
        else
            [ -n "$TMP" ] && rm -f "$TMP"
        fi
    fi
fi

RESP="$("$CURL" -s -m 15 "$USAGE_URL" \
    -H "Authorization: Bearer ${AT}" \
    -H "anthropic-beta: oauth-2025-04-20" \
    -H "anthropic-version: 2023-06-01")"

if printf '%s' "$RESP" | "$JQ" -e '.five_hour' >/dev/null 2>&1; then
    printf '%s\n' "$RESP"
else
    MSG="$(printf '%s' "$RESP" | "$JQ" -r '(.error.type // .error // "request_failed")' 2>/dev/null)"
    [ -n "$MSG" ] || MSG="request_failed"
    emit_err "$MSG"
fi
