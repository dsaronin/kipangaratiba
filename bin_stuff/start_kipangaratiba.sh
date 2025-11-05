#!/bin/bash
#
# Starts the Kipangaratiba web and worker processes.
# Includes a check to wait for Redis to be available.
# Includes [ScriptPID:$$] tagging for diagnostics.

# Source RVM to enable RVM commands and environment
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"

# Navigate to the application directory
# (Adjust path if this script is not on 'jabari' for 'daudi')
cd "/home/angalia-hub/projects/kipangaratiba" || { echo "Failed to change directory" >&2; exit 1; }

# Use the specific Ruby version and gemset
rvm use ruby-3.2.2@kipangaratiba

# Set environment variables for the application
export RACK_ENV="production"
export SINATRA_ENV="production"
export DEBUG_ENV="false"
export TZ="America/Los_Angeles" # Set time zone for consistent logging

# Define log file paths and port
LOG_DIR="/home/angalia-hub/log"
WORKER_LOG_FILE="$LOG_DIR/kipangaratiba_sidekiq.log"
KIPANGA_PORT="8090" # Port used by the Puma web server
PUMA_LOG_FILE="$LOG_DIR/kipangaratiba_puma.log"
PUMA_PID_FILE="/home/angalia-hub/log/kipangaratiba_puma.pid" # Must match config/puma.rb

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# --- Log Rotation ---
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Function to rotate a single log file
rotate_log_file() {
    local LOG_FILE="$1"
    if [ -f "$LOG_FILE" ]; then
        local LOG_BASENAME="${LOG_FILE%.*}"
        local LOG_EXTENSION=".${LOG_FILE##*.}"
        local ARCHIVE_NAME="${LOG_BASENAME}-${TIMESTAMP}${LOG_EXTENSION}"
        mv "$LOG_FILE" "$ARCHIVE_NAME"
    fi
}

# Rotate both log files
rotate_log_file "$PUMA_LOG_FILE"
rotate_log_file "$WORKER_LOG_FILE"

# --- Wait for Redis ---
# This loop prevents the app from launching before its Redis dependency is ready.
echo "[ScriptPID:$$] ---" >> "$PUMA_LOG_FILE"
echo "[ $(date +"%Y-%m-%d %H:%M:%S %Z") ] [ScriptPID:$$] KIPANGA DIAGNOSTIC: Waiting for Redis..." >> "$PUMA_LOG_FILE"
REDIS_WAIT_MAX=30 # Wait a maximum of 30 * 2 = 60 seconds
REDIS_WAIT_COUNT=0
# Loop until `redis-cli ping` returns a "PONG"
while ! redis-cli ping | grep -q "PONG"; do
    if [ $REDIS_WAIT_COUNT -ge $REDIS_WAIT_MAX ]; then
        echo "[ $(date +"%Y-%m-%d %H:%M:%S %Z") ] [ScriptPID:$$] KIPANGA ERROR: Redis not responding after 60 seconds. Aborting." >> "$PUMA_LOG_FILE"
        exit 1
    fi
    echo "[ $(date +"%Y-%m-%d %H:%M:%S %Z") ] [ScriptPID:$$] KIPANGA INFO: Redis not up, retrying in 2s... (Attempt $((REDIS_WAIT_COUNT+1))/$REDIS_WAIT_MAX)" >> "$PUMA_LOG_FILE"
    sleep 2
    REDIS_WAIT_COUNT=$((REDIS_WAIT_COUNT+1))
done
echo "[ $(date +"%Y-%m-%d %H:%M:%S %Z") ] [ScriptPID:$$] KIPANGA DIAGNOSTIC: Redis is up! Proceeding with launch." >> "$PUMA_LOG_FILE"

# --- PID Lock Check (Web) ---
# This check prevents a double-launch of the puma server.
if [ -f "$PUMA_PID_FILE" ]; then
    OLD_PID=$(cat "$PUMA_PID_FILE")
    # Check if the process ID from the file is still running
    if ps -p "$OLD_PID" > /dev/null; then
        echo "[ $(date +"%Y-%m-%d %H:%M:%S %Z") ] [ScriptPID:$$] KIPANGA ERROR: Puma server is already running with PID $OLD_PID (from $PUMA_PID_FILE). Aborting." >> "$PUMA_LOG_FILE"
        exit 1 # Abort script
    else
        # The process is not running, so the PID file is stale (from a crash/reboot)
        echo "[ $(date +"%Y-%m-%d %H:%M:%S %Z") ] [ScriptPID:$$] KIPANGA WARN: Found stale PID file for $OLD_PID. Removing $PUMA_PID_FILE." >> "$PUMA_LOG_FILE"
        rm "$PUMA_PID_FILE"
    fi
fi

# --- Port Status Check BEFORE Start ---
TIMESTAMP_PRE=$(date +"%Y-%m-%d %H:%M:%S %Z")
echo "[ScriptPID:$$] ---" >> "$PUMA_LOG_FILE"
echo "[ $TIMESTAMP_PRE ] [ScriptPID:$$] KIPANGA DIAGNOSTIC: Checking port $KIPANGA_PORT status BEFORE launch." >> "$PUMA_LOG_FILE"
echo "[ScriptPID:$$] --- netstat -tln | grep $KIPANGA_PORT (Should be empty) ---" >> "$PUMA_LOG_FILE"
netstat -tln | grep $KIPANGA_PORT >> "$PUMA_LOG_FILE" 2>&1
echo "[ScriptPID:$$] --- lsof -i :$KIPANGA_PORT (Should be empty) ---" >> "$PUMA_LOG_FILE"
lsof -i :$KIPANGA_PORT >> "$PUMA_LOG_FILE" 2>&1
echo "[ScriptPID:$$] ---" >> "$PUMA_LOG_FILE"


# --- Start Puma Web Server ---
# The -C flag points to the config file and handles its own PID file and logging.
nohup bundle exec puma -C config/puma.rb >> "$PUMA_LOG_FILE" 2>&1 &

# --- Start Sidekiq Worker Process ---
# (flock removed as requested)
nohup bundle exec sidekiq -r ./sidekiq_boot.rb >> "$WORKER_LOG_FILE" 2>&1 &
WORKER_PID=$!


# Wait for the Puma server to attempt to bind to the port
sleep 5


# --- Port Status Check AFTER Start ---
TIMESTAMP_POST=$(date +"%Y-%m-%d %H:%M:%S %Z")
echo "[ScriptPID:$$] ---" >> "$PUMA_LOG_FILE"
echo "[ $TIMESTAMP_POST ] [ScriptPID:$$] KIPANGA DIAGNOSTIC: Checking port $KIPANGA_PORT status AFTER launch." >> "$PUMA_LOG_FILE"
echo "[ScriptPID:$$] --- netstat -tln | grep $KIPANGA_PORT (Should show LISTEN) ---" >> "$PUMA_LOG_FILE"
netstat -tln | grep $KIPANGA_PORT >> "$PUMA_LOG_FILE" 2>&1
echo "[ScriptPID:$$] --- lsof -i :$KIPANGA_PORT (Should show ruby/puma process) ---" >> "$PUMA_LOG_FILE"
lsof -i :$KIPANGA_PORT >> "$PUMA_LOG_FILE" 2>&1
echo "[ScriptPID:$$] ---" >> "$PUMA_LOG_FILE"


# Final console output
echo "Kipangaratiba started."
echo "  Puma Web Server: (Log: $PUMA_LOG_FILE, PID File: $PUMA_PID_FILE)"
echo "  Worker Server PID: $WORKER_PID (Log: $WORKER_LOG_FILE)"
