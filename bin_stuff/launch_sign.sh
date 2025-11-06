#!/bin/bash
VERSION="0.5"

# Default values
DEFAULT_ROOM_NAME="SchFrry102VisitSA"
DEFAULT_PROJECT_PATH="/home/daudi/projects"
DEFAULT_SLEEP_TIME="13.5"

# Initialize variables with defaults
MEETING_ROOM_NAME="$DEFAULT_ROOM_NAME"
PROJECTPATH="$DEFAULT_PROJECT_PATH"
SLEEP_TIME="$DEFAULT_SLEEP_TIME"

# Parse command-line options
while getopts ":r:p:t:" opt; do
  case $opt in
    r) MEETING_ROOM_NAME="$OPTARG"
       ;;
    p) PROJECTPATH="$OPTARG"
       ;;
    t) SLEEP_TIME="$OPTARG"
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

# Use a temp file inside the user's HOME directory
# This ensures it's covered by the --filesystem=home flag
TMP_DIR="${HOME}/tmp"
TMP_FILE="${TMP_DIR}/meeting-notice.html"

# --- 2. Create Temp Directory ---
# Ensure the tmp directory exists
mkdir -p "$TMP_DIR"

# --- 2.5. Log Variables ---
echo "--- Configuration ---"
echo "Room Name:    $MEETING_ROOM_NAME"
echo "Project Path: $PROJECTPATH"
echo "Sleep Time:   $SLEEP_TIME minutes"
echo "Image Path:   $IMAGE_PATH"
echo "Temp File:    $TMP_FILE"
echo "---------------------"

# --- 3. Check for Template ---
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found at $TEMPLATE_FILE" >&2
    exit 1
fi

# --- 4. Use sed to substitute placeholders ---
# We use '|' as the sed delimiter to avoid conflicts with '/' in the file path.
sed \
  -e "s|__MEETING_ROOM_NAME__|${MEETING_ROOM_NAME}|g" \
  -e "s|__IMAGE_FILEPATH__|${IMAGE_PATH}|g" \
  "$TEMPLATE_FILE" > "$TMP_FILE"

echo "Generated $TMP_FILE for room: $MEETING_ROOM_NAME"

# --- 5. Launch Chromium in Kiosk Mode ---
# Launch in the background and store its Process ID (PID)
echo "Launching Chromium in kiosk mode..."
flatpak run org.chromium.Chromium --filesystem=home --kiosk "file://${TMP_FILE}" &
CHROMIUM_PID=$!

echo "Chromium running with PID: $CHROMIUM_PID (Note: This is the launcher PID)"

# --- 6. Sleep for specified minutes ---
# 'm' suffix is a valid duration for the sleep command
echo "Sleeping for ${SLEEP_TIME} minutes..."
sleep ${SLEEP_TIME}m

# --- 7. Close the Chromium Window ---
# UPDATED: Use pkill -f to find and kill the process by its command line,
# as the initial PID is often just a launcher.
echo "Time up. Closing Chromium instance displaying ${TMP_FILE}..."
if pkill -f "file://${TMP_FILE}"; then
    echo "Chromium closed."
else
    echo "Could not find Chromium process for file://${TMP_FILE}. It might have already closed."
fi

# --- 8. Cleanup ---
# Optional: remove the temporary file
# rm "$TMP_FILE"
# echo "Cleanup complete."

# --- 9. Exit ---
echo "launch_sign.sh script"


