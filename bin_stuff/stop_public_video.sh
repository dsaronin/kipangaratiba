#!/bin/bash

echo "stop_public_video.sh starting to kill all chromium processes..."

# Define the unique strings
PUBLIC_JITSI_DIR="user-data-dir=/home/angalia-hub/.config/chromium-kiosk-public-jitsi"
CRASHPAD_DB="/home/angalia-hub/.var/app/org.chromium.Chromium/config/chromium/Crash Reports"

# 1. Send the polite SIGTERM signal. This will kill all the
#    healthy child (renderer/gpu) processes.
pkill -f "${PUBLIC_JITSI_DIR}"

# 2. Wait 1 second to give them time to die.
sleep 1

# 3. Send the forceful SIGKILL signal. This will kill the
#    hung parent 'bwrap' and 'chrome' processes (5641, 5642)
#    that ignored the polite signal.
pkill -9 -f "${PUBLIC_JITSI_DIR}"

# 4. Clean up the orphaned crashpad handlers (5650, 5652)
#    by matching their unique database path.
pkill -f "${CRASHPAD_DB}"

echo "...stop_public_video.sh ending."
