#!/bin/bash

# Default values
DEFAULT_ROOM_NAME="SchFrry102VisitSA"
DEFAULT_PROJECT_PATH="/home/daudi/projects"

# Initialize variables with defaults
MEETING_ROOM_NAME="$DEFAULT_ROOM_NAME"
PROJECTPATH="$DEFAULT_PROJECT_PATH"

# Parse command-line options
while getopts ":r:p:" opt; do
  case $opt in
    r) MEETING_ROOM_NAME="$OPTARG"
       ;;
    p) PROJECTPATH="$OPTARG"
       ;;
    \?) echo "Invalid option: -$OPTARG" >&2
       exit 1
       ;;
    :) echo "Option -$OPTARG requires an argument." >&2
       exit 1
       ;;
  esac
done

# --- 1. Define Paths ---
IMAGE_PATH="file://${PROJECTPATH}/kipangaratiba/public/images/cardinal-fgd.png"
TEMPLATE_FILE="${PROJECTPATH}/kipangaratiba/bin_stuff/meeting-notice.html"
TMP_FILE="/home/daudi/tmp/meeting-notice.html"

# --- 2. Check for Template ---
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found at $TEMPLATE_FILE" >&2
    exit 1
fi

# --- 3. Use sed to substitute placeholders ---
# We use '|' as the sed delimiter to avoid conflicts with '/' in the file path.
sed \
  -e "s|__MEETING_ROOM_NAME__|${MEETING_ROOM_NAME}|g" \
  -e "s|__IMAGE_FILEPATH__|${IMAGE_PATH}|g" \
  "$TEMPLATE_FILE" > "$TMP_FILE"

echo "Generated $TMP_FILE for room: $MEETING_ROOM_NAME"

# --- 4. Launch Chromium in Kiosk Mode ---
# Launch in the background and store its Process ID (PID)
echo "Launching Chromium in kiosk mode..."
flatpak run org.chromium.Chromium --filesystem=home --kiosk "file://${TMP_FILE}" &
CHROMIUM_PID=$!

echo "Chromium running with PID: $CHROMIUM_PID (Note: This is the launcher PID)"

# --- 5. Sleep for 13.5 minutes ---
# '13.5m' is a valid duration for the sleep command
echo "Sleeping for 13.5 minutes..."
sleep 13.5m

# --- 6. Close the Chromium Window ---
# UPDATED: Use pkill -f to find and kill the process by its command line,
# as the initial PID is often just a launcher.
echo "Time up. Closing Chromium instance displaying ${TMP_FILE}..."
if pkill -f "file://${TMP_FILE}"; then
    echo "Chromium closed."
else
    echo "Could not find Chromium process for file://${TMP_FILE}. It might have already closed."
fi

# --- 7. Cleanup ---
# Optional: remove the temporary file
# rm "$TMP_FILE"
# echo "Cleanup complete."

# --- 8. Exit ---
exit 0


