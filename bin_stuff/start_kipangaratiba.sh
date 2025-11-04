#!/bin/bash
#
# Starts the Kipangaratiba web and worker processes.
# Uses flock on each process to prevent double-launch.

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
export TZ="America/Los_Angeles"

# Define log file paths
LOG_DIR="/home/angalia-hub/log"
WEB_LOG_FILE="$LOG_DIR/kipangaratiba_thin.log"
WORKER_LOG_FILE="$LOG_DIR/kipangaratiba_sidekiq.log"

# Define lock file paths
WEB_LOCK_FILE="$LOG_DIR/kipangaratiba.web.lock"
WORKER_LOCK_FILE="$LOG_DIR/kipangaratiba.worker.lock"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# --- Start Thin Web Server ---
# nohup wraps flock, which holds the lock and runs the server.
# The lock is held as long as the 'bundle exec thin' process is running.
nohup flock -n "$WEB_LOCK_FILE" bundle exec thin -R config.ru -a 0.0.0.0 -p 8090 start >> "$WEB_LOG_FILE" 2>&1 &
WEB_PID=$!

# --- Start Sidekiq Worker Process ---
# Apply the same lock-and-run logic to the sidekiq worker.
nohup flock -n "$WORKER_LOCK_FILE" bundle exec sidekiq -r ./sidekiq_boot.rb >> "$WORKER_LOG_FILE" 2>&1 &
WORKER_PID=$!

echo "Kipangaratiba started."
echo "  Web Server PID:    $WEB_PID (Log: $WEB_LOG_FILE)"
echo "  Worker Server PID: $WORKER_PID (Log: $WORKER_LOG_FILE)"
