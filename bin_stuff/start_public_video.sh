#!/bin/bash

# --- Configuration ---
DEFAULT_ROOM="SchFrry102VisitSA"

# --- Process Arguments ---
# $1: Room Name (optional, defaults to DEFAULT_ROOM)
ROOM_NAME="${1:-$DEFAULT_ROOM}"
SLEEP_TIME="${2:-}"

# --- Run the countdown sign ---

# Determine PROJECTPATH based on hostname
if [ "$(hostname)" == "jabari" ]; then
    PROJECTPATH="/home/daudi/projectspace"
else
    PROJECTPATH="/home/angalia-hub/projects"
fi

# We call launch_sign.sh and pass the room name and project path.
# We do NOT use '&' here, so this script will pause
# and wait for launch_sign.sh to complete (13.5 mins)
# before proceeding to the Jitsi launch.
echo "Starting ${SLEEP_TIME:-13.5} minute countdown sign for room: $ROOM_NAME on path $PROJECTPATH"
~/bin/launch_sign.sh -r "$ROOM_NAME" -p "$PROJECTPATH" ${SLEEP_TIME:+-t "$SLEEP_TIME"}
echo "Countdown sign finished. Launching Jitsi..."
# --------------------------------------------------

# --- Build URL ---
# Build the URL with all parameters in the hash
BASE_URL="https://meet.jit.si/${ROOM_NAME}"
HASH_PARAMS=()
#    "config.prejoinPageEnabled=false"
#    "config.startWithAudioMuted=false"
#    "config.startWithVideoMuted=false"

# Join parameters with '&'
JOINED_PARAMS=$(printf "&%s" "${HASH_PARAMS[@]}")
# Remove the leading '&'
FULL_URL="${BASE_URL}#${JOINED_PARAMS:1}"

# --- Launch ---
flatpak run \
--filesystem="${HOME}/log" \
--env=CHROME_LOG_FILE="${HOME}/log/publicjitsichrome.log" \
org.chromium.Chromium \
--kiosk \
--start-fullscreen \
--disable-popup-blocking \
--disable-infobars \
--no-first-run \
--no-default-browser-check \
--disable-translate \
--use-fake-ui-for-media-stream \
--force-wave-audio \
--test-type \
--enable-logging \
--log-level=0 \
--user-data-dir=${HOME}/.config/chromium-kiosk-public-jitsi \
"${FULL_URL}" &

