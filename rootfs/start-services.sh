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
    echo "[INFO] Using environment variables"
fi

# Ensure required directories exist
mkdir -p /var/run/dbus /var/run/avahi-daemon /var/log/supervisor /var/log/cups

# Setup CUPS configuration
if [ -d /config/cups ]; then
    echo "[INFO] Using persistent CUPS configuration"
    cp -f /config/cups/* /etc/cups/ 2>/dev/null || true
elif [ -d /addon_config/cups ]; then
    echo "[INFO] Using addon_config CUPS configuration"
    cp -f /addon_config/cups/* /etc/cups/ 2>/dev/null || true
else
    echo "[WARNING] No persistent CUPS config found, using defaults"
fi

# Setup user
echo "[INFO] Setting up user: $CUPS_USERNAME"
if ! id "$CUPS_USERNAME" >/dev/null 2>&1; then
    useradd --groups=sudo,lp,lpadmin --create-home --home-dir="/home/$CUPS_USERNAME" --shell=/bin/bash "$CUPS_USERNAME"
fi
echo "$CUPS_USERNAME:$CUPS_PASSWORD" | chpasswd

# Generate SSL certificates if not present
if [ ! -f /etc/cups/ssl/server.crt ] || [ ! -f /etc/cups/ssl/server.key ]; then
    echo "[INFO] Generating SSL certificates..."
    /generate-ssl.sh
fi

# Start base services with proper error checking
echo "[INFO] Starting dbus..."
mkdir -p /var/run/dbus
if ! dbus-daemon --system --fork; then
    echo "[ERROR] Failed to start dbus"
    exit 1
fi

echo "[INFO] Starting avahi..."
mkdir -p /var/run/avahi-daemon
if ! avahi-daemon --daemonize; then
    echo "[ERROR] Failed to start avahi"
    exit 1
fi

# Wait for avahi socket with timeout
echo "[INFO] Waiting for avahi socket..."
timeout="${AVAHI_SOCKET_TIMEOUT:-10}"
while [ ! -e /var/run/avahi-daemon/socket ] && [ $timeout -gt 0 ]; do
    sleep 1
    timeout=$((timeout-1))
done

echo "[INFO] Starting CUPS daemon..."
if ! cupsd; then
    echo "[ERROR] Failed to start CUPS daemon"
    exit 1
fi

# Wait for CUPS to be ready
echo "[INFO] Waiting for CUPS to be ready..."
timeout=$CUPS_TIMEOUT
while [ $timeout -gt 0 ]; do
    # Use a custom CA certificate if provided, otherwise default to system CAs
    if [ -n "$CUPS_CA_CERT" ] && [ -f "$CUPS_CA_CERT" ]; then
        CURL_CA_OPT="--cacert $CUPS_CA_CERT"
    else
        CURL_CA_OPT=""
    fi
    if curl $CURL_CA_OPT -s --max-time 3 https://localhost:631/ >/dev/null 2>&1; then
        echo "[INFO] CUPS is ready"
        break
    fi
    sleep 2
    timeout=$((timeout-2))
done

# Start management API
echo "[INFO] Starting management API..."
python3 /usr/bin/cups-management-api.py &
API_PID=$!

# Wait for API to be ready
timeout=20
while [ $timeout -gt 0 ]; do
    if curl -s --max-time 3 http://localhost:8080/ >/dev/null 2>&1; then
        echo "[INFO] Management API is ready"
        break
    fi
    sleep 2
    timeout=$((timeout-2))
done

# Start supervisor for HA integration (only if bashio available)
if command -v bashio >/dev/null 2>&1; then
    echo "[INFO] Starting Home Assistant integration services..."
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/services.conf
else
    echo "[INFO] Running in standalone mode"
    echo "[INFO] CUPS Interface: https://localhost:631"
    echo "[INFO] Management Interface: http://localhost:8080"
    # Keep the container running
    wait $API_PID
fi
