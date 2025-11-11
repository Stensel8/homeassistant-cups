#!/bin/bash
set -e

echo "[DEBUG] Starting CUPS container initialization..."

# Ensure lpadmin group exists
if ! getent group lpadmin >/dev/null; then
    echo "[DEBUG] Creating missing group: lpadmin"
    groupadd lpadmin
    echo "[INFO] Created missing group: lpadmin"
else
    echo "[DEBUG] lpadmin group already exists"
fi

echo "[INFO] Starting CUPS v2 Print Server"

# Configuration handling
if command -v bashio >/dev/null 2>&1; then
    CUPS_USERNAME=$(bashio::config "cupsusername" "print")
    CUPS_PASSWORD=$(bashio::config "cupspassword" "print")
    echo "[INFO] Configuration loaded from Home Assistant"
else
    CUPS_USERNAME="${CUPS_USERNAME:-print}"
    CUPS_PASSWORD="${CUPS_PASSWORD:-print}"
    echo "[INFO] Using environment variables"
fi

echo "[DEBUG] CUPS_USERNAME: $CUPS_USERNAME"

# Ensure required directories exist and are writable
echo "[DEBUG] Setting up required directories..."
for dir in /etc/cups /var/log/cups /var/run/cups /var/cache/cups /var/spool/cups; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "[DEBUG] Created directory: $dir"
    else
        echo "[DEBUG] Directory already exists: $dir"
    fi
    chmod 755 "$dir"
done

# Setup CUPS v2 configuration
if [ -d /config/cups ]; then
    echo "[INFO] Using persistent CUPS configuration from /config/cups"
    cp -f /config/cups/* /etc/cups/ 2>/dev/null || true
    echo "[DEBUG] Copied config files from /config/cups"
elif [ -d /addon_config/cups ]; then
    echo "[INFO] Using addon_config CUPS configuration from /addon_config/cups"
    cp -f /addon_config/cups/* /etc/cups/ 2>/dev/null || true
    echo "[DEBUG] Copied config files from /addon_config/cups"
else
    echo "[WARNING] No persistent CUPS config found, using defaults"
fi

# Setup user
echo "[DEBUG] Setting up user: $CUPS_USERNAME"
if ! id "$CUPS_USERNAME" >/dev/null 2>&1; then
    useradd --groups=sudo,lp,lpadmin --create-home --home-dir="/home/$CUPS_USERNAME" --shell=/bin/bash "$CUPS_USERNAME"
    echo "[DEBUG] Created user: $CUPS_USERNAME"
else
    echo "[DEBUG] User already exists: $CUPS_USERNAME"
fi
echo "$CUPS_USERNAME:$CUPS_PASSWORD" | chpasswd
echo "[DEBUG] Set password for user: $CUPS_USERNAME"

# Set permissions for config files
chmod 644 /etc/cups/cupsd.conf 2>/dev/null || true
echo "[DEBUG] Set permissions on cupsd.conf"

# Generate SSL certificates if not present
if [ ! -f /etc/cups/ssl/server.crt ] || [ ! -f /etc/cups/ssl/server.key ]; then
    echo "[INFO] Generating SSL certificates..."
    if [ -f /generate-ssl.sh ]; then
        /generate-ssl.sh
        echo "[DEBUG] SSL certificate generation completed"
    else
        echo "[ERROR] /generate-ssl.sh missing"
        exit 1
    fi
else
    echo "[DEBUG] SSL certificates already exist"
fi

# Validate CUPS config
echo "[DEBUG] Validating CUPS configuration..."
if ! cupsd -t 2>/tmp/cups-validate.err; then
    echo "[ERROR] cupsd.conf invalid:"
    cat /tmp/cups-validate.err
    exit 1
else
    echo "[DEBUG] CUPS configuration validation passed"
fi

echo "[INFO] Starting CUPS daemon..."
if command -v cupsd >/dev/null 2>&1; then
    cupsd -f &
    CUPSD_PID=$!
    echo "[DEBUG] CUPS daemon started with PID: $CUPSD_PID"
else
    echo "[ERROR] cupsd not found. CUPS daemon cannot be started."
    exit 1
fi

# Wait for CUPS to be ready
echo "[INFO] Waiting for CUPS to be ready..."
timeout=10
while [ $timeout -gt 0 ]; do
    echo "[DEBUG] Checking CUPS readiness (timeout: $timeout)..."
    if curl -k -s --max-time 3 https://localhost:631/ >/dev/null 2>&1; then
        echo "[INFO] CUPS is ready and responding"
        break
    else
        echo "[DEBUG] CUPS not ready yet, waiting..."
    fi
    sleep 1
    timeout=$((timeout-1))
done

if [ $timeout -eq 0 ]; then
    echo "[ERROR] CUPS did not respond within 10 seconds"
    if [ -f /var/log/cups/error_log ]; then
        echo "[CUPS ERROR LOG]:"
        tail -20 /var/log/cups/error_log
    fi
    exit 1
fi

echo "[INFO] CUPS is running with host networking - no proxy needed"

# Start supervisor for HA integration (only if bashio available)
if command -v bashio >/dev/null 2>&1; then
    echo "[INFO] Starting Home Assistant integration services..."
    exec /usr/bin/supervisord -c /etc/supervisor/conf.d/services.conf
else
    echo "[INFO] Running in standalone mode"
    echo "[INFO] Starting D-Bus..."
    mkdir -p /var/run/dbus
    dbus-daemon --system --fork
    echo "[INFO] Starting Avahi daemon..."
    avahi-daemon --daemonize
    echo "[INFO] CUPS Web Interface: https://localhost:631"
    echo "[INFO] Username: print"
    # Keep the container running
    wait $CUPSD_PID
fi

