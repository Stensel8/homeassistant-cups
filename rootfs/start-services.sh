#!/bin/bash
set -e

DEBUG=${DEBUG:-true}

log_debug() {
    [[ "$DEBUG" == "true" ]] && echo "[DEBUG] $1"
}

log_info() {
    echo "[INFO] $1"
}

log_warning() {
    echo "[WARNING] $1"
}

log_error() {
    echo "[ERROR] $1"
}

log_info "Starting CUPS Print Server for Home Assistant"

# Ensure lpadmin group exists
if ! getent group lpadmin >/dev/null; then
    log_debug "Creating lpadmin group"
    groupadd lpadmin
fi

# Read configuration from Home Assistant or use defaults
if command -v bashio >/dev/null 2>&1 && bashio::supervisor.ping; then
    log_info "Loading configuration from Home Assistant..."
    CUPS_USERNAME=$(bashio::config 'cupsusername')
    CUPS_PASSWORD=$(bashio::config 'cupspassword')
    CUPS_PORT=$(bashio::config 'cupsport')
    SSL_ENABLED=$(bashio::config 'sslenabled')
    ALLOW_REMOTE_ADMIN=$(bashio::config 'allowremoteadmin')
    log_info "Configuration loaded - Username: ${CUPS_USERNAME}, Port: ${CUPS_PORT}"
else
    log_warning "Not running in Home Assistant, using environment defaults"
    CUPS_USERNAME="${CUPS_USERNAME:-admin}"
    CUPS_PASSWORD="${CUPS_PASSWORD:-admin}"
    CUPS_PORT="${CUPS_PORT:-631}"
    SSL_ENABLED="${SSL_ENABLED:-true}"
    ALLOW_REMOTE_ADMIN="${ALLOW_REMOTE_ADMIN:-true}"
fi

# Setup directories
log_debug "Setting up CUPS directories..."
for dir in /etc/cups /var/log/cups /var/run/cups /var/cache/cups /var/spool/cups; do
    mkdir -p "$dir"
    chmod 755 "$dir"
done

# Copy persistent config if available
if [ -d /config/cups ]; then
    log_info "Using persistent CUPS configuration"
    cp -f /config/cups/* /etc/cups/ 2>/dev/null || true
else
    log_debug "No persistent config found, using defaults"
fi

# Create or update CUPS user
log_debug "Setting up user: ${CUPS_USERNAME}"
if ! id "$CUPS_USERNAME" >/dev/null 2>&1; then
    useradd --groups=lpadmin --create-home --shell=/bin/bash "$CUPS_USERNAME"
    log_info "Created user: ${CUPS_USERNAME}"
fi

echo "$CUPS_USERNAME:$CUPS_PASSWORD" | chpasswd
log_debug "Password set for user: ${CUPS_USERNAME}"

# Set config permissions
chmod 644 /etc/cups/cupsd.conf 2>/dev/null || true

# Generate SSL certificates if needed
if [ ! -f /etc/cups/ssl/server.crt ] || [ ! -f /etc/cups/ssl/server.key ]; then
    log_info "Generating SSL certificates..."
    /generate-ssl.sh
else
    log_debug "SSL certificates already exist"
fi

# Validate CUPS configuration
log_debug "Validating CUPS configuration..."
if ! cupsd -t 2>/tmp/cups-validate.err; then
    log_error "cupsd.conf validation failed:"
    cat /tmp/cups-validate.err
    exit 1
fi

# Start CUPS daemon
log_info "Starting CUPS daemon..."
cupsd -f &
CUPSD_PID=$!
log_debug "CUPS daemon PID: $CUPSD_PID"

# Wait for CUPS to be ready
log_info "Waiting for CUPS to become ready..."
for i in {10..1}; do
    if curl -k -s --max-time 3 https://localhost:631/ >/dev/null 2>&1; then
        log_info "CUPS is ready!"
        break
    fi
    log_debug "Waiting... ($i seconds left)"
    sleep 1
    if [ $i -eq 1 ]; then
        log_error "CUPS failed to start within 10 seconds"
        [ -f /var/log/cups/error_log ] && tail -20 /var/log/cups/error_log
        exit 1
    fi
done

# Network diagnostics (always run after CUPS starts)
log_info "═══════════════════════════════════════════════"
log_info "Network Diagnostics:"
log_info "═══════════════════════════════════════════════"

log_info "Container IP addresses:"
ip addr show | grep "inet " || true

log_info "Listening ports:"
netstat -tuln | grep 631 || ss -tuln | grep 631 || true

log_info "Testing local CUPS access:"
curl -k -I https://localhost:631/ 2>&1 | head -5 || true

CONTAINER_IP=$(ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1 || echo "unknown")
if [ "$CONTAINER_IP" != "unknown" ]; then
    log_info "Testing external CUPS access (via container IP: $CONTAINER_IP):"
    curl -k -I https://$CONTAINER_IP:631/ 2>&1 | head -5 || true
fi

# Start Avahi for AirPrint discovery
log_info "═══════════════════════════════════════════════"
log_info "Starting D-Bus and Avahi..."
mkdir -p /var/run/dbus
dbus-daemon --system --fork
avahi-daemon --daemonize

log_info "═══════════════════════════════════════════════"
log_info "CUPS Print Server is running!"
log_info "Web Interface: https://[homeassistant-ip]:631"
log_info "Username: ${CUPS_USERNAME}"
log_info "═══════════════════════════════════════════════"

# Keep container alive
wait $CUPSD_PID
