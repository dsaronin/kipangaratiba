#!/bin/bash

# Find and kill all processes (bwrap, chrome, etc.)
# associated with the public video kiosk by matching
# the unique user-data-dir string in their command.
pkill -f "user-data-dir=${HOME}/.config/chromium-kiosk-public-jitsi"

