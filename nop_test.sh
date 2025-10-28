#!/bin/bash
# $1 = Message to display (optional)

# Set a default message if $1 is not provided
MESSAGE=${1:-"NOP: Hello world!"}

# Send a desktop notification.
# The -w (wait) flag ensures the script waits until the
# notification is dismissed or times out.
# This confirms the script is running in the correct graphical environment.
notify-send -w -t 300000 "Kipangaratiba" "$MESSAGE"

