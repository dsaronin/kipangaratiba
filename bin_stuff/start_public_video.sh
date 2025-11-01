#!/bin/bash

# --- Configuration ---
DEFAULT_ROOM="SchFrry102VisitSA"

# --- Process Arguments ---
# $1: Room Name (optional, defaults to DEFAULT_ROOM)
ROOM_NAME="${1:-$DEFAULT_ROOM}"

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
