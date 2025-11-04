#!/bin/bash
#
# Starts the Kipangaratiba web and worker processes.
# Uses flock on each process to prevent double-launch.
# Includes a check to wait for Redis to be available.

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
WEB_LOG_FILE="$LOG_DIR/kipangaratiba_thin.log"
WORKER_LOG_FILE="$LOG_DIR/kipangaratiba_sidekiq.log"
KIPANGA_PORT="8090" # Port used by the Thin web server

# Define lock file paths
WEB_LOCK_FILE="$LOG_DIR/kipangaratiba.web.lock"
WORKER_LOCK_FILE="$LOG_DIR/kipangaratiba.worker.lock"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"


# --- Wait for Redis ---
# This loop prevents the app from launching before its Redis dependency is ready.
echo "---" >> "$WEB_LOG_FILE"
echo "[ $(date +"%Y-%m-%d %H:%M:%S %Z") ] KIPANGA DIAGNOSTIC: Waiting for Redis..." >> "$WEB_LOG_FILE"
REDIS_WAIT_MAX=30 # Wait a maximum of 30 * 2 = 60 seconds
REDIS_WAIT_COUNT=0
# Loop until `redis-cli ping` returns a "PONG"
while ! redis-cli ping | grep -q "PONG"; do
    if [ $REDIS_WAIT_COUNT -ge $REDIS_WAIT_MAX ]; then
        echo "[ $(date +"%Y-%m-%d %H:%M:%S %Z") ] KIPANGA ERROR: Redis not responding after 60 seconds. Aborting." >> "$WEB_LOG_FILE"
        exit 1
    fi
    echo "[ $(date +"%Y-%m-%d %H:%M:%S %Z") ] KIPANGA INFO: Redis not up, retrying in 2s... (Attempt $((REDIS_WAIT_COUNT+1))/$REDIS_WAIT_MAX)" >> "$WEB_LOG_FILE"
    sleep 2
    REDIS_WAIT_COUNT=$((REDIS_WAIT_COUNT+1))
done
echo "[ $(date +"%Y-%m-%d %H:%M:%S %Z") ] KIPANGA DIAGNOSTIC: Redis is up! Proceeding with launch." >> "$WEB_LOG_FILE"


# --- Port Status Check BEFORE Start ---
TIMESTAMP_PRE=$(date +"%Y-%m-%d %H:%M:%S %Z")
echo "---" >> "$WEB_LOG_FILE"
echo "[ $TIMESTAMP_PRE ] KIPANGA DIAGNOSTIC: Checking port $KIPANGA_PORT status BEFORE launch." >> "$WEB_LOG_FILE"
echo "--- netstat -tln | grep $KIPANGA_PORT (Should be empty) ---" >> "$WEB_LOG_FILE"
netstat -tln | grep $KIPANGA_PORT >> "$WEB_LOG_FILE" 2>&1
echo "--- lsof -i :$KIPANGA_PORT (Should be empty) ---" >> "$WEB_LOG_FILE"
lsof -i :$KIPANGA_PORT >> "$WEB_LOG_FILE" 2>&1
echo "---" >> "$WEB_LOG_FILE"


# --- Start Thin Web Server ---
# nohup wraps flock, which holds the lock and runs the server.
# The lock is held as long as the 'bundle exec thin' process is running.
nohup flock -n "$WEB_LOCK_FILE" bundle exec thin -R config.ru -a 0.0.0.0 -p $KIPANGA_PORT start >> "$WEB_LOG_FILE" 2>&1 &
WEB_PID=$!


# --- Start Sidekiq Worker Process ---
# Apply the same lock-and-run logic to the sidekiq worker.
nohup flock -n "$WORKER_LOCK_FILE" bundle exec sidekiq -r ./sidekiq_boot.rb >> "$WORKER_LOG_FILE" 2>&1 &
WORKER_PID=$!


# Wait for the Thin server to attempt to bind to the port
sleep 5


# --- Port Status Check AFTER Start ---
TIMESTAMP_POST=$(date +"%Y-%m-%d %H:%M:%S %Z")
echo "---" >> "$WEB_LOG_FILE"
echo "[ $TIMESTAMP_POST ] KIPANGA DIAGNOSTIC: Checking port $KIPANGA_PORT status AFTER launch." >> "$WEB_LOG_FILE"
echo "--- netstat -tln | grep $KIPANGA_PORT (Should show LISTEN) ---" >> "$WEB_LOG_FILE"
netstat -tln | grep $KIPANGA_PORT >> "$WEB_LOG_FILE" 2>&1
echo "--- lsof -i :$KIPANGA_PORT (Should show ruby/thin process) ---" >> "$WEB_LOG_FILE"
lsof -i :$KIPANGA_PORT >> "$WEB_LOG_FILE" 2>&1
echo "---" >> "$WEB_LOG_FILE"


# Final console output
echo "Kipangaratiba started."
echo "  Web Server PID:     $WEB_PID (Log: $WEB_LOG_FILE)"
echo "  Worker Server PID: $WORKER_PID (Log: $WORKER_LOG_FILE)"


