#!/bin/bash
#
# Starts the Kipangaratiba web and worker processes.

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

# Define log file paths
LOG_DIR="/home/daudi/log"
WEB_LOG_FILE="$LOG_DIR/kipangaratiba_thin.log"
WORKER_LOG_FILE="$LOG_DIR/kipangaratiba_sidekiq.log"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# --- Start Thin Web Server ---
nohup bundle exec thin -R config.ru -a 0.0.0.0 -p 8090 start >> "$WEB_LOG_FILE" 2>&1 &
WEB_PID=$!

# --- Start Sidekiq Worker Process ---
nohup bundle exec sidekiq -r ./sidekiq_boot.rb >> "$WORKER_LOG_FILE" 2>&1 &
WORKER_PID=$!

echo "Kipangaratiba started."
echo "  Web Server PID:    $WEB_PID (Log: $WEB_LOG_FILE)"
echo "  Worker Server PID: $WORKER_PID (Log: $WORKER_LOG_FILE)"
