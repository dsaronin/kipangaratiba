#!/bin/bash
# Title: Remote Kiosk Reboot Watchdog Script
# Description: Checks a countdown flag every 5 minutes. If the flag
# reaches zero, the system initiates action (reboot or test notification).
# Designed for resilience using 'nohup'.
#
# Sample Invocation (Verbose Mode, Test Mode, 4-hour initial timer, clean background start):
# nohup $HOME/bin/reboot_watchdog.sh -v -t 48 < /dev/null > $HOME/log/reboot_watchdog.log 2>&1 &

# --- Configuration (User-Defined Paths & Defaults) ---
# Parent directory: $HOME
# Script name: reboot_watchdog.sh
FLAG_FILE="$HOME/reboot_counter.txt"
LOG_DIR="$HOME/log"
LOG_FILE="$LOG_DIR/reboot_watchdog.log"
CHECK_INTERVAL_SECONDS=300 # 5 minutes (300 seconds)

# Control Flags
DEFAULT_INITIAL_COUNT=6    # Default intervals (5-min), results in 30 minutes
VERBOSE=0                  # Set to 1 if the -v flag is passed
TEST_MODE=0                # Set to 1 if the -t flag is passed
WATCHDOG_VERSION="1.2"
# --- End Configuration ---

# Capture the script's Process ID (PID) once
WATCHDOG_PID=$$

# Function to safely log messages
# $1: The log message content
# $2: Severity (MAIN, WARN, ERROR, INFO)
log() {
    local message="$1"
    local severity="$2"
    local severity_abbr
    
    case "$severity" in
        "MAIN") severity_abbr="M";;
        "WARN") severity_abbr="W";;
        "ERROR") severity_abbr="E";;
        "INFO") severity_abbr="I";;
        *) severity_abbr="?";;
    esac

    # Only log INFO messages if VERBOSE is enabled
    if [[ "$severity" == "INFO" && "$VERBOSE" -eq 0 ]]; then
        return
    fi
    
    # Standardized logging format: ABBR, [YYYY-MM-DDT HH:MM:SS #PID] LEVEL -- : MESSAGE
    echo "$severity_abbr, [$(date +'%Y-%m-%dT%H:%M:%S') #$WATCHDOG_PID] $severity -- : $message" >> "$LOG_FILE"
}

# Function to find and export DBUS_SESSION_BUS_ADDRESS for notify-send
# This function is crucial for allowing notify-send to work within a nohup environment
export_dbus_session() {
    # Find PIDs of all running dbus-daemon processes for the current user
    local dbus_pids=$(pgrep -u $(whoami) -d ' ' dbus-daemon)
    
    if [ -z "$dbus_pids" ]; then
        return 1 # No dbus-daemon found
    fi

    # Iterate through PIDs to find one that has the DBUS_SESSION_BUS_ADDRESS variable
    for pid in $dbus_pids; do
        # Use awk to find the DBUS_SESSION_BUS_ADDRESS in the /proc/<pid>/environ file
        # The environment variables are null-separated; use tr to convert nulls to newlines for awk
        local dbus_address=$(cat /proc/$pid/environ 2>/dev/null | tr '\0' '\n' | awk -F= '/^DBUS_SESSION_BUS_ADDRESS/ {print $0; exit}')
        
        if [ -n "$dbus_address" ]; then
            export "$dbus_address"
            return 0 # Success
        fi
    done

    return 1 # Variable not found in any dbus-daemon environment
}


# Function to perform the final action (Reboot or Test Notification)
# $1: The reason for the action
perform_action() {
    local reason="$1"
    
    if [ "$TEST_MODE" -eq 1 ]; then
        local test_mode_label="WATCHDOG TEST MODE"
        local action_message="ACTION: $test_mode_label. Trigger: $reason."
        
        log "Executing TEST ACTION: $action_message" "MAIN"
        
        # Use notify-send in synchronous mode to display the message
        # Check if notify-send is available and X server display is accessible
        if command -v notify-send >/dev/null && [ -n "$DISPLAY" ]; then
            
            # Attempt to set the DBus session address
            if export_dbus_session; then
                # Success: DBUS_SESSION_BUS_ADDRESS is now exported
                : # No logging needed for success
            else
                log "Could not determine DBUS_SESSION_BUS_ADDRESS. Notification may fail." "WARN"
            fi
            
            notify-send -u critical -w "WATCHDOG ALERT" "$action_message"
            log "Display notification sent successfully." "INFO"
        else
            log "Could not execute notify-send (not found or \$DISPLAY not set). Check log for trigger." "WARN"
        fi
        
    else
        local live_mode_label="LIVE REBOOT"
        local action_message="ACTION: $live_mode_label. Trigger: $reason."
        
        log "Executing LIVE REBOOT ACTION: $action_message" "MAIN"
        # Using the absolute path for the reboot command
        sudo /sbin/reboot 
    fi
    
    # Script exits after performing the action, regardless of test mode
    sleep 5 
    exit 0
}

# --- Initialization and Setup ---

# Parse command line options
INITIAL_COUNT="$DEFAULT_INITIAL_COUNT"
while getopts "vt" opt; do
    case ${opt} in
        v ) 
            VERBOSE=1
            ;;
        t ) 
            TEST_MODE=1
            ;;
        \? ) 
            echo "Usage: $0 [-v] [-t] [initial_count]" >&2
            exit 1
            ;;
    esac
done
shift $((OPTIND - 1))

# Check for custom initial count argument
if [[ "$1" =~ ^[0-9]+$ ]]; then
    INITIAL_COUNT="$1"
fi

# 1. Ensure the log directory exists
mkdir -p "$LOG_DIR"

# 2. Ensure the log file exists and is writable
if ! touch "$LOG_FILE" 2>/dev/null; then
    echo "[$(date +'%Y-%m-%dT%H:%M:%S')] ERROR: Cannot write to log file $LOG_FILE. Exiting." >&2
    exit 1
fi

# 3. Write initial count to the flag file upon script launch
echo "$INITIAL_COUNT" > "$FLAG_FILE"
log "Watchdog (v$WATCHDOG_VERSION) started. Initial count set to $INITIAL_COUNT intervals (approx. $((INITIAL_COUNT * 5)) minutes)." "WARN"
if [ "$TEST_MODE" -eq 1 ]; then
    log "Test mode active: Reboot will be replaced by desktop notification." "WARN"
fi

# --- Main Loop ---
while true; do
    
    # Wait first to ensure N cycles = N * 5 minutes of waiting
    sleep "$CHECK_INTERVAL_SECONDS"

    # 1. Check if the flag file exists
    if [ ! -f "$FLAG_FILE" ]; then
        log "Flag file $FLAG_FILE not found. Re-initializing with 1." "WARN"
        echo "1" > "$FLAG_FILE"
    fi

    # 2. Read the current countdown value (after sleeping)
    CURRENT_COUNT=$(cat "$FLAG_FILE" 2>/dev/null)
    
    # 3. Input validation: Ensure it is an integer (positive, zero, or negative).
    if ! [[ "$CURRENT_COUNT" =~ ^-?[0-9]+$ ]]; then
        log "Invalid value '$CURRENT_COUNT' found in flag file. Resetting to 1." "INFO"
        CURRENT_COUNT=1
    fi

    log "Read current count: $CURRENT_COUNT." "INFO"

    # 4. Evaluate Control Signals and Action
    
    # A. Check for Force Exit Signal (Negative)
    if [ "$CURRENT_COUNT" -lt 0 ]; then
        log "External signal (count < 0) received. Forced exit without action." "MAIN"
        exit 0
    fi
    
    # B. Check for Immediate Action Signal (Zero)
    if [ "$CURRENT_COUNT" -eq 0 ]; then
        log "Immediate action signal (count = 0) received. Initiating action." "WARN"
        perform_action "External signal (count=0) received."
        # perform_action exits the script
    fi
    
    # If control signals are not met, proceed with decrement and natural expiration check

    # 5. Decrement the counter
    NEW_COUNT=$((CURRENT_COUNT - 1))

    # 6. Evaluate Natural Expiration (NEW_COUNT reaches 0)
    if [ "$NEW_COUNT" -eq 0 ]; then
        # Condition: Countdown naturally reached zero. Execute action.
        log "Countdown expired naturally (0 reached). Initiating action." "WARN"
        echo "0" > "$FLAG_FILE" # Ensure file shows 0
        perform_action "Countdown expired naturally."
        # perform_action exits the script
    else
        # 7. Standard countdown: Save the new, decremented value
        echo "$NEW_COUNT" > "$FLAG_FILE"
        log "Flag decremented to $NEW_COUNT. System will act in approx. $((NEW_COUNT * 5)) minutes." "INFO"
    fi

    # The sleep command is now at the start of the loop
done
