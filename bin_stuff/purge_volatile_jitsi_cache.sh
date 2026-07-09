#!/usr/bin/env bash
# ==============================================================================
# Script Name : purge_volatile_jitsi_cache.sh
# Description : Standalone cleanup utility to rotate and purge volatile web
#               caches (Local Storage & Session Storage) inside Angalia's
#               public Jitsi Chromium profile context. Prevents Jitsi from
#               injecting sticky, obsolete WebRTC device selections.
# Environment : Linux Mint v22.1 (Angalia Kiosk / XFCE)
# ==============================================================================
#
# HISTORICAL DIAGNOSTIC LOG & RUNTIME TELEMETRY REFERENCE
# ------------------------------------------------------------------------------
# The following workflow was utilized to discover, isolate, and verify the 
# Jitsi LocalStorage caching anomaly that forced audio streams away from the 
# GEMBIRD USB speakers (Sink 59) over to the disconnected internal line-out (Sink 60):
#
# 1. Initialize background execution loop with dedicated standard I/O redirection:
#    $ date +"%Y.%m.%d %T >>>>> starting"; DISPLAY=:0 ~/bin/start_public_video.sh SchFrry102VisitSA 1 > /home/angalia-hub/log/public_video_launch.log 2>&1 &
#
# 2. Tail runtime initialization trace and Flatpak sandbox policy flags:
#    $ tail -f ~/log/public_video_launch.log
#
# 3. Baseline check of open PulseAudio/PipeWire media output links prior to connection:
#    $ pactl list sink-inputs
#
# 4. [[ local chrome join meet.jit.si meeting from workstation machine ]]
#
# 5. Verify dynamic WebRTC stream splitting after call peer establishment:
#    $ pactl list sink-inputs
#
# 6. Real-time monitoring loop tracking volume, mute parameters, and stream target drift:
#    $ watch -n 0.5 "pactl list sink-inputs | grep -E 'Sink Input|Sink:|Volume|Mute'"
#
# 7. [[ hangup local chrome jitsi meeting ]]
#
# 8. Trigger local termination handlers:
#    $ ~/bin/stop_public_video.sh
#
# 9. Extract filtered console and WebRTC API device constraints from browser execution log:
#    $ grep -Ei 'audio|sink|pulse|device|permission|media' ~/log/publicjitsichrome.log
#
# ==============================================================================

set -euo pipefail

# --- Configuration Paths ---
PROFILE_DIR="${HOME}/.config/chromium-kiosk-public-jitsi/Default"
LOCAL_STORAGE_DIR="${PROFILE_DIR}/Local Storage"
SESSION_STORAGE_DIR="${PROFILE_DIR}/Session Storage"

BACKUP_LOCAL_DIR="${PROFILE_DIR}/Local_Storage_BACKUP"
BACKUP_SESSION_DIR="${PROFILE_DIR}/Session_Storage_BACKUP"

echo "$(date +'%Y.%m.%d %T') [INFO] Starting volatile Jitsi cache purge sequence..."
echo "[INFO] see comments in script for historical diagnostic commands"

# --- Guard Clause: Ensure Chromium is stopped before altering database files ---
if pgrep -f "org.chromium.Chromium" > /dev/null || pgrep -f "chrome" > /dev/null; then
    echo "$(date +'%Y.%m.%d %T') [ERROR] Chromium is currently running. Close browser before executing cleanup." >&2
    exit 1
fi

# --- Phase 1: Rotational Safe Backup ---
echo "$(date +'%Y.%m.%d %T') [INFO] Rotating historical cache layers..."

if [ -d "$LOCAL_STORAGE_DIR" ]; then
    rm -rf "$BACKUP_LOCAL_DIR"
    cp -r "$LOCAL_STORAGE_DIR" "$BACKUP_LOCAL_DIR"
    echo " -> Local Storage backup updated at: $BACKUP_LOCAL_DIR"
fi

if [ -d "$SESSION_STORAGE_DIR" ]; then
    rm -rf "$BACKUP_SESSION_DIR"
    cp -r "$SESSION_STORAGE_DIR" "$BACKUP_SESSION_DIR"
    echo " -> Session Storage backup updated at: $BACKUP_SESSION_DIR"
fi

# --- Phase 2: Destructive Volatile Purge ---
echo "$(date +'%Y.%m.%d %T') [INFO] Cleansing active runtime storage pools..."

rm -rf "$LOCAL_STORAGE_DIR"
rm -rf "$SESSION_STORAGE_DIR"

echo "$(date +'%Y.%m.%d %T') [SUCCESS] Cache purged. Next execution will fallback cleanly to system defaults."

