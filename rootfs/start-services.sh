#!/bin/bash
set -e

echo "[INFO] Starting CUPS Print Server with Management Interface"

# Configuration handling
if command -v bashio >/dev/null 2>&1; then
    CUPS_USERNAME=$(bashio::config "cups_username" "print")
    CUPS_PASSWORD=$(bashio::config "cups_password" "print")
    echo "[INFO] Configuration loaded from Home Assistant"
else
    CUPS_USERNAME="${CUPS_USERNAME:-print}"
    CUPS_PASSWORD="${CUPS_PASSWORD:-print}"
    echo "[INFO] Using default configuration"
fi

# Ensure required directories exist
mkdir -p /var/run/dbus /var/run/avahi-daemon /var/log/supervisor

# Use addon_config directly (mounted by Home Assistant)
ln -sf /addon_config/cups /etc/cups

# Setup user
echo "[INFO] Setting up user: $CUPS_USERNAME"
if ! id "$CUPS_USERNAME" >/dev/null 2>&1; then
    useradd --groups=sudo,lp,lpadmin --create-home --home-dir="/home/$CUPS_USERNAME" --shell=/bin/bash "$CUPS_USERNAME"
fi
echo "$CUPS_USERNAME:$CUPS_PASSWORD" | chpasswd

# Start base services
echo "[INFO] Starting dbus..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork

echo "[INFO] Starting avahi..."
mkdir -p /var/run/avahi-daemon
avahi-daemon --daemonize

# Wait for avahi socket
while [ ! -e /var/run/avahi-daemon/socket ]; do
    sleep 1
done

echo "[INFO] Starting CUPS daemon..."
cupsd

# Make sure the management API script is executable
chmod +x /usr/bin/cups-management-api.py

# Start supervisor which will manage remaining services
echo "[INFO] Starting additional services via supervisor..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/services.conf
