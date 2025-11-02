#!/bin/bash

# --- Configuration ---
DEFAULT_ROOM="SchFrry102VisitSA"

# --- Process Arguments ---
# $1: Room Name (optional, defaults to DEFAULT_ROOM)
ROOM_NAME="${1:-$DEFAULT_ROOM}"

# --- NEW: Run the 13.5-minute countdown sign ---

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
echo "Starting 13.5 minute countdown sign for room: $ROOM_NAME on path $PROJECTPATH"
~/bin/launch_sign.sh -r "$ROOM_NAME" -p "$PROJECTPATH"
echo "Countdown sign finished. Launching Jitsi..."
# --------------------------------------------------

# --- Build URL ---
# Build the URL with all parameters in the hash
BASE_URL="https://meet.jit.si/${ROOM_NAME}"
HASH_PARAMS=(
    "config.startWithAudioMuted=false"
    "config.startWithVideoMuted=false"
)

# Join parameters with '&'
JOINED_PARAMS=$(printf "&%s" "${HASH_PARAMS[@]}")
# Remove the leading '&'
FULL_URL="${BASE_URL}#${JOINED_PARAMS:1}"


# --- Launch ---
flatpak run org.chromium.Chromium \
--kiosk \
--start-fullscreen \
--no-first-run \
--no-default-browser-check \
--disable-infobars \
--disable-translate \
--user-data-dir=${HOME}/.config/chromium-kiosk-public-jitsi \
--app="${FULL_URL}" &



