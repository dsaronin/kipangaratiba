#!/bin/bash
# Script for reconnecting OpenVPN on angalia
# expected to be run as cron every 20 minutes

VPN_CONNECTION_NAME="malagarasi-client"

if ! nmcli c show --active | grep -q "$VPN_CONNECTION_NAME"; then
    echo "$(date): VPN connection '$VPN_CONNECTION_NAME' is down. Attempting to reconnect..."
    nmcli c up "$VPN_CONNECTION_NAME"
fi
