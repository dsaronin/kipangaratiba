#!/bin/bash
# Title: Remote Kiosk Reboot Watchdog Script (v1.3 - Root Daemon)
# Description: Runs continuously in the background via root cron.
# Monitors /home/daudi/.watchdog_timer every 5 minutes.
# If a positive integer is found, it decrements it safely. 
# If it reaches 0, it initiates a system reboot.

# --- Configuration (Hardcoded Absolute Paths for Root Security) ---
FLAG_FILE="/home/daudi/.watchdog_timer"
TMP_FLAG_FILE="/home/daudi/.watchdog_timer.tmp"
LOG_DIR="/home/daudi/log"
LOG_FILE="$LOG_DIR/reboot_watchdog.log"
CHECK_INTERVAL_SECONDS=300 # 5 minutes
WATCHDOG_VERSION="1.3"
WATCHDOG_PID=$$
# --- End Configuration ---

# Ensure log directory exists and is owned by the standard user
/bin/mkdir -p "$LOG_DIR"
/bin/chown daudi:daudi "$LOG_DIR" 2>/dev/null

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

    # Standardized logging format: ABBR, [YYYY-MM-DDT HH:MM:SS #PID] LEVEL -- : MESSAGE
    /bin/echo "$severity_abbr, [$(/bin/date +'%Y-%m-%dT%H:%M:%S') #$WATCHDOG_PID] $severity -- : $message" >> "$LOG_FILE"
    /bin/chown daudi:daudi "$LOG_FILE" 2>/dev/null
}

log "Watchdog (v$WATCHDOG_VERSION) root daemon started." "INFO"

# --- Main Loop ---
while true; do
    
    /bin/sleep "$CHECK_INTERVAL_SECONDS"

    # 1. Existence Check: If file is absent, timer is off. Loop again.
    if [ ! -e "$FLAG_FILE" ]; then
        continue
    fi

    # 2. Symlink Attack Prevention: Ensure the file is not a malicious link.
    if [ -L "$FLAG_FILE" ]; then
        log "ERROR: Flag file is a symlink! Potential attack detected. Disarming by removing link." "ERROR"
        /bin/rm -f "$FLAG_FILE"
        continue
    fi

    # 3. Read and strictly validate content (extract only positive integers or zero).
    CURRENT_COUNT=$(/bin/cat "$FLAG_FILE" 2>/dev/null | /bin/grep -Eo '^[0-9]+$')

    # 4. Ignore empty files or files containing invalid characters.
    if [ -z "$CURRENT_COUNT" ]; then
        continue
    fi

    # 5. Timer is disarmed when value is 0. Loop again.
    if [ "$CURRENT_COUNT" -eq 0 ]; then
        continue
    fi

    # 6. Timer is active (>0). Decrement the counter.
    NEW_COUNT=$((CURRENT_COUNT - 1))

    # 7. Safe atomic write: Write to a temporary file, set user ownership, then move.
    # This guarantees root does not accidentally follow a symlink injected mid-cycle.
    /bin/echo "$NEW_COUNT" > "$TMP_FLAG_FILE"
    /bin/chown daudi:daudi "$TMP_FLAG_FILE" 2>/dev/null
    /bin/mv "$TMP_FLAG_FILE" "$FLAG_FILE"

    log "Timer active. Flag decremented to $NEW_COUNT. Approx $((NEW_COUNT * 5)) minutes remaining." "INFO"

    # 8. Evaluate Natural Expiration (NEW_COUNT reaches 0)
    if [ "$NEW_COUNT" -eq 0 ]; then
        log "Countdown expired (0 reached). Initiating LIVE REBOOT." "MAIN"
        /sbin/reboot
    fi

done

