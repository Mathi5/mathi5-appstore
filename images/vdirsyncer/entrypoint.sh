#!/bin/sh
# Entrypoint for the vdirsyncer container.
#
# Responsibilities:
#   1. Generate the vdirsyncer config file from the environment variables.
#   2. Run `discover` once, which is what triggers the Google OAuth flow and
#      writes the token file.
#   3. Loop on `sync` so the pairs stay in sync on a schedule.
#
# A vdirsyncer pair syncs exactly TWO storages. To mirror Google Calendar onto
# a CalDAV server, the pair is simply google_calendar <-> caldav — no local
# filesystem in between. Your phone then talks to the CalDAV server directly.
#
# The config and the Google token both live in /config, which is bind-mounted
# from the host, so the authorization survives a container rebuild.

set -eu

CONFIG_DIR="${VDIRSYNCER_CONFIG_DIR:-/config}"
CONFIG_FILE="${CONFIG_DIR}/config"
TOKEN_FILE="${CONFIG_DIR}/google_token"
INTERVAL="${VDIRSYNCER_INTERVAL:-3600}"
STATUS_PATH="${VDIRSYNCER_STATUS_PATH:-/data/status}"

log() { echo "[vdirsyncer] $*"; }

mkdir -p "$CONFIG_DIR" "$STATUS_PATH"

# Escape a value for the INI format. vdirsyncer parses its config with
# configparser, which treats a bare % as an interpolation marker.
ini_escape() {
    printf '%s' "$1" | sed -e 's/%/%%/g'
}

CLIENT_ID=$(ini_escape "${VDIRSYNCER_GOOGLE_CLIENT_ID:-}")
CLIENT_SECRET=$(ini_escape "${VDIRSYNCER_GOOGLE_CLIENT_SECRET:-}")

write_config() {
    : > "$CONFIG_FILE"

    {
        echo "[general]"
        echo "status_path = \"$(ini_escape "$STATUS_PATH")/\""
        echo ""
    } >> "$CONFIG_FILE"

    # --- Calendar pair: Google Calendar <-> CalDAV server ---
    if [ -n "${VDIRSYNCER_CALDAV_URL:-}" ]; then
        {
            echo "[pair calendar]"
            echo "a = \"calendar_google\""
            echo "b = \"calendar_caldav\""
            echo "collections = [\"from a\", \"from b\"]"
            echo "metadata = [\"displayname\", \"color\"]"
            echo ""
            echo "[storage calendar_google]"
            echo "type = \"google_calendar\""
            echo "token_file = \"$(ini_escape "$TOKEN_FILE")\""
            echo "client_id = \"$CLIENT_ID\""
            echo "client_secret = \"$CLIENT_SECRET\""
            echo ""
            echo "[storage calendar_caldav]"
            echo "type = \"caldav\""
            echo "url = \"$(ini_escape "$VDIRSYNCER_CALDAV_URL")\""
            echo "username = \"$(ini_escape "${VDIRSYNCER_CALDAV_USERNAME:-}")\""
            echo "password = \"$(ini_escape "${VDIRSYNCER_CALDAV_PASSWORD:-}")\""
            echo ""
        } >> "$CONFIG_FILE"
    fi

    # --- Contacts pair: Google Contacts <-> CardDAV server ---
    if [ -n "${VDIRSYNCER_CARDDAV_URL:-}" ]; then
        {
            echo "[pair contacts]"
            echo "a = \"contacts_google\""
            echo "b = \"contacts_carddav\""
            echo "collections = [\"from a\", \"from b\"]"
            echo "metadata = [\"displayname\"]"
            echo ""
            echo "[storage contacts_google]"
            echo "type = \"google_contacts\""
            echo "token_file = \"$(ini_escape "$TOKEN_FILE")\""
            echo "client_id = \"$CLIENT_ID\""
            echo "client_secret = \"$CLIENT_SECRET\""
            echo ""
            echo "[storage contacts_carddav]"
            echo "type = \"carddav\""
            echo "url = \"$(ini_escape "$VDIRSYNCER_CARDDAV_URL")\""
            echo "username = \"$(ini_escape "${VDIRSYNCER_CARDDAV_USERNAME:-}")\""
            echo "password = \"$(ini_escape "${VDIRSYNCER_CARDDAV_PASSWORD:-}")\""
            echo ""
        } >> "$CONFIG_FILE"
    fi

    log "Config written to $CONFIG_FILE"
}

pair_names() {
    PAIRS=""
    [ -n "${VDIRSYNCER_CALDAV_URL:-}" ] && PAIRS="$PAIRS calendar"
    [ -n "${VDIRSYNCER_CARDDAV_URL:-}" ] && PAIRS="$PAIRS contacts"
    printf '%s' "$PAIRS"
}

case "${1:-sync}" in
    discover)
        write_config
        PAIRS=$(pair_names)
        if [ -z "$PAIRS" ]; then
            log "No pair configured: set the CalDAV URL and/or the CardDAV URL."
            exit 1
        fi
        log "Running discovery. This is where the Google OAuth flow happens."
        log ""
        log "  If the token file does not exist yet, vdirsyncer prints a Google"
        log "  authorization URL below. The Google redirect lands on"
        log "  http://127.0.0.1:<port> ON THE CONTAINER, so the browser that"
        log "  completes the sign-in must reach it through a tunnel."
        log ""
        log "  1. Copy the URL and open it in your browser."
        log "  2. The URL contains a port — forward it, e.g.:"
        log "       ssh -L <port>:127.0.0.1:<port> <user>@<runtipi-host>"
        log "  3. Authorize. The token is written to $TOKEN_FILE and the flow"
        log "     never repeats."
        log ""
        vdirsyncer -c "$CONFIG_FILE" discover $PAIRS 2>&1 | tee /tmp/discover.log || true
        # The port appears in the redirect_uri of the printed authorization URL.
        PORT=$(grep -o '127\.0\.0\.1%3A[0-9]\+' /tmp/discover.log | head -1 | cut -d: -f2 || true)
        if [ -n "$PORT" ]; then
            log ""
            log ">>> Forward this port to complete the sign-in:"
            log ">>> ssh -L ${PORT}:127.0.0.1:${PORT} <user>@<runtipi-host>"
        fi
        if [ -f "$TOKEN_FILE" ]; then
            log ""
            log "Token file present — Google is already authorized."
        fi
        exit 0
        ;;
    sync)
        write_config
        PAIRS=$(pair_names)
        if [ -z "$PAIRS" ]; then
            log "No pair configured: set the CalDAV URL and/or the CardDAV URL."
            exit 1
        fi
        if [ ! -f "$TOKEN_FILE" ]; then
            log "No Google token yet. Run the 'discover' command first to authorize."
            log "See the app description for the tunnel step."
            exit 1
        fi
        log "Initial sync pass."
        vdirsyncer -c "$CONFIG_FILE" sync $PAIRS || log "Initial sync failed; retrying next pass."
        log "Entering the sync loop (every ${INTERVAL}s)."
        while true; do
            sleep "$INTERVAL"
            log "Sync pass."
            vdirsyncer -c "$CONFIG_FILE" sync $PAIRS || log "Sync failed; retrying next pass."
        done
        ;;
    *)
        exec vdirsyncer -c "$CONFIG_FILE" "$@"
        ;;
esac
