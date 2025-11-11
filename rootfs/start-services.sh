#!/bin/bash

# Exit on error, but we'll handle errors manually for better logging
set -o pipefail

# Set TERM to prevent warnings
export TERM=xterm-256color

# Enable debug mode
DEBUG=${DEBUG:-true}

# Logging functions
log_debug() {
    [[ "$DEBUG" == "true" ]] && echo "[DEBUG] $(date '+%H:%M:%S') - $1"
}

log_info() {
    echo "[INFO] $(date '+%H:%M:%S') - $1"
}

log_warning() {
    echo "[WARNING] $(date '+%H:%M:%S') - $1"
}

log_error() {
    echo "[ERROR] $(date '+%H:%M:%S') - $1"
}

log_fatal() {
    echo "[FATAL] $(date '+%H:%M:%S') - $1"
    echo "[FATAL] Container will exit in 30 seconds for debugging..."
    sleep 30
    exit 1
}

# Trap errors and show which line failed
trap 'log_error "Script failed at line $LINENO with exit code $?"' ERR

# Try to clear screen (suppress errors if TERM not set)
clear 2>/dev/null || true

echo "════════════════════════════════════════════════════════════"
echo "   CUPS Print Server for Home Assistant - Starting...       "
echo "   Version: 1.3.1                                           "
echo "════════════════════════════════════════════════════════════"
echo ""

log_info "Starting CUPS Print Server for Home Assistant"
log_debug "Shell: $SHELL, User: $(whoami), PID: $$"

# Check if required commands exist
log_debug "Checking required commands..."
for cmd in curl groupadd useradd cupsd netstat; do
    if ! command -v $cmd >/dev/null 2>&1; then
        log_fatal "Required command '$cmd' not found! Docker build may have failed."
    fi
    log_debug "✓ Found: $cmd"
done

# Ensure lpadmin group exists
log_debug "Checking lpadmin group..."
if ! getent group lpadmin >/dev/null 2>&1; then
    log_info "Creating lpadmin group..."
    if ! groupadd lpadmin; then
        log_fatal "Failed to create lpadmin group"
    fi
else
    log_debug "✓ lpadmin group exists"
fi

# Read configuration from Home Assistant or use defaults
log_info "Loading configuration..."
if command -v bashio >/dev/null 2>&1; then
    log_debug "✓ Bashio found"
    if bashio::supervisor.ping 2>/dev/null; then
        log_info "Connected to Home Assistant Supervisor"
        CUPS_USERNAME=$(bashio::config 'cupsusername' 2>/dev/null || echo "admin")
        CUPS_PASSWORD=$(bashio::config 'cupspassword' 2>/dev/null || echo "admin")
        CUPS_PORT=$(bashio::config 'cupsport' 2>/dev/null || echo "631")
        SSL_ENABLED=$(bashio::config 'sslenabled' 2>/dev/null || echo "true")
        ALLOW_REMOTE_ADMIN=$(bashio::config 'allowremoteadmin' 2>/dev/null || echo "true")
        log_info "Configuration loaded from HA - User: ${CUPS_USERNAME}, Port: ${CUPS_PORT}"
    else
        log_warning "Bashio found but supervisor not reachable, using defaults"
        CUPS_USERNAME="${CUPS_USERNAME:-admin}"
        CUPS_PASSWORD="${CUPS_PASSWORD:-admin}"
        CUPS_PORT="${CUPS_PORT:-631}"
        SSL_ENABLED="${SSL_ENABLED:-true}"
        ALLOW_REMOTE_ADMIN="${ALLOW_REMOTE_ADMIN:-true}"
    fi
else
    log_warning "Bashio not found - using environment/default values"
    CUPS_USERNAME="${CUPS_USERNAME:-admin}"
    CUPS_PASSWORD="${CUPS_PASSWORD:-admin}"
    CUPS_PORT="${CUPS_PORT:-631}"
    SSL_ENABLED="${SSL_ENABLED:-true}"
    ALLOW_REMOTE_ADMIN="${ALLOW_REMOTE_ADMIN:-true}"
fi

log_debug "Config: User=$CUPS_USERNAME, Port=$CUPS_PORT, SSL=$SSL_ENABLED"

# Setup directories
log_info "Setting up CUPS directories..."
for dir in /etc/cups /var/log/cups /var/run/cups /var/cache/cups /var/spool/cups; do
    if ! mkdir -p "$dir" 2>/dev/null; then
        log_fatal "Failed to create directory: $dir"
    fi
    chmod 755 "$dir" || log_warning "Could not set permissions on $dir"
    log_debug "✓ Created: $dir"
done

# Copy persistent config if available
if [ -d /config/cups ]; then
    log_info "Found persistent CUPS configuration, copying..."
    cp -f /config/cups/* /etc/cups/ 2>/dev/null || log_warning "Some config files could not be copied"
else
    log_debug "No persistent config found at /config/cups"
fi

# Update cupsd.conf with configured port
log_info "Configuring CUPS to listen on port ${CUPS_PORT}..."
if [ ! -f /etc/cups/cupsd.conf ]; then
    log_fatal "cupsd.conf not found! Check if COPY rootfs/ / worked in Dockerfile"
fi

log_debug "Updating Listen directive in cupsd.conf..."
if sed -i "s/^Listen 0\.0\.0\.0:[0-9]\+/Listen 0.0.0.0:${CUPS_PORT}/" /etc/cups/cupsd.conf; then
    log_debug "✓ Updated existing Listen directive"
else
    log_warning "sed failed or no Listen directive found"
fi

# Verify Listen directive exists
if ! grep -q "^Listen 0\.0\.0\.0:" /etc/cups/cupsd.conf; then
    log_warning "No Listen 0.0.0.0 found, adding it..."
    sed -i '/^Listen/d' /etc/cups/cupsd.conf
    sed -i "1i Listen 0.0.0.0:${CUPS_PORT}" /etc/cups/cupsd.conf
    sed -i '2i Listen /var/run/cups/cups.sock' /etc/cups/cupsd.conf
fi

# ══════════════════════════════════════════════════════════
# Important: Sync config to /usr/etc/cups if it exists
# ══════════════════════════════════════════════════════════
if [ -d /usr/etc/cups ]; then
    log_debug "Syncing cupsd.conf to /usr/etc/cups (for compatibility)..."
    
    # If symlink doesn't exist, force sync
    if [ ! -L /usr/etc/cups/cupsd.conf ]; then
        log_warning "/usr/etc/cups/cupsd.conf is not a symlink, forcing sync..."
        cp -f /etc/cups/cupsd.conf /usr/etc/cups/cupsd.conf
    fi
    
    # Also ensure Listen directive is correct in the actual file CUPS reads
    sed -i "s/^Listen 127\.0\.0\.1:[0-9]\+/Listen 0.0.0.0:${CUPS_PORT}/" /usr/etc/cups/cupsd.conf 2>/dev/null || true
    sed -i "s/^Listen localhost:[0-9]\+/Listen 0.0.0.0:${CUPS_PORT}/" /usr/etc/cups/cupsd.conf 2>/dev/null || true
    
    log_debug "✓ Config synced to /usr/etc/cups"
fi
# ══════════════════════════════════════════════════════════

# Create or update CUPS user
log_info "Setting up user: ${CUPS_USERNAME}"
if ! id "$CUPS_USERNAME" >/dev/null 2>&1; then
    log_debug "User does not exist, creating..."
    if useradd --groups=lpadmin --create-home --shell=/bin/bash "$CUPS_USERNAME" 2>/dev/null; then
        log_info "✓ Created user: ${CUPS_USERNAME}"
    else
        log_fatal "Failed to create user: ${CUPS_USERNAME}"
    fi
else
    log_debug "✓ User already exists: ${CUPS_USERNAME}"
fi

log_debug "Setting password for user..."
if echo "$CUPS_USERNAME:$CUPS_PASSWORD" | chpasswd 2>/dev/null; then
    log_debug "✓ Password set successfully"
else
    log_error "Failed to set password (non-fatal)"
fi

# Set config permissions
chmod 644 /etc/cups/cupsd.conf 2>/dev/null || log_warning "Could not set cupsd.conf permissions"

# Generate SSL certificates if needed
if [ ! -f /etc/cups/ssl/server.crt ] || [ ! -f /etc/cups/ssl/server.key ]; then
    log_info "Generating SSL certificates..."
    if [ ! -f /generate-ssl.sh ]; then
        log_fatal "generate-ssl.sh not found!"
    fi
    if ! /generate-ssl.sh 2>&1 | grep -q "successfully"; then
        log_warning "SSL generation may have issues, check output above"
    fi
else
    log_debug "✓ SSL certificates already exist"
fi

# Validate CUPS configuration
log_info "Validating CUPS configuration..."
if ! cupsd -t 2>/tmp/cups-validate.err; then
    log_error "cupsd.conf validation failed:"
    cat /tmp/cups-validate.err
    log_fatal "Fix the configuration errors above"
else
    log_debug "✓ CUPS configuration is valid"
fi

# Show what Listen directives are active
log_info "Active Listen directives:"
grep "^Listen" /etc/cups/cupsd.conf || log_warning "No Listen directives found!"

# Start CUPS daemon
log_info "Starting CUPS daemon..."
cupsd -f &
CUPSD_PID=$!
log_info "✓ CUPS daemon started with PID: $CUPSD_PID"

# Wait for CUPS to be ready
log_info "Waiting for CUPS to become ready..."
READY=false
for i in {10..1}; do
    if curl -k -s --max-time 3 https://localhost:${CUPS_PORT}/ >/dev/null 2>&1; then
        log_info "✓ CUPS is ready!"
        READY=true
        break
    fi
    log_debug "Waiting... ($i seconds left)"
    sleep 1
done

if [ "$READY" = false ]; then
    log_error "CUPS failed to start within 10 seconds"
    log_error "CUPS error log (last 20 lines):"
    [ -f /var/log/cups/error_log ] && tail -20 /var/log/cups/error_log || echo "No error log found"
    log_fatal "CUPS startup failed"
fi

# Network diagnostics
log_info "════════════════════════════════════════════════════════════"
log_info "Network Diagnostics:"
log_info "════════════════════════════════════════════════════════════"

if command -v ip >/dev/null 2>&1; then
    log_info "Container IP addresses:"
    ip addr show | grep "inet " || log_warning "Could not get IP addresses"
    CONTAINER_IP=$(ip addr show eth0 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d'/' -f1 || echo "")
    [ -n "$CONTAINER_IP" ] && log_info "Container IP: $CONTAINER_IP" || log_warning "Could not determine container IP"
else
    log_warning "ip command not found, skipping IP detection"
    CONTAINER_IP=""
fi

log_info "Listening ports:"
netstat -tuln 2>/dev/null | grep ${CUPS_PORT} || ss -tuln 2>/dev/null | grep ${CUPS_PORT} || log_warning "Could not check listening ports"

log_info "Testing local CUPS access:"
curl -k -I https://localhost:${CUPS_PORT}/ 2>&1 | head -5 || log_warning "Local access test failed"

if [ -n "$CONTAINER_IP" ]; then
    log_info "Testing external CUPS access (via ${CONTAINER_IP}:${CUPS_PORT}):"
    curl -k -I https://$CONTAINER_IP:${CUPS_PORT}/ 2>&1 | head -5 || log_warning "External access test failed"
fi

# Start Avahi for AirPrint discovery
log_info "════════════════════════════════════════════════════════════"
log_info "Starting D-Bus and Avahi..."
mkdir -p /var/run/dbus
if dbus-daemon --system --fork 2>/dev/null; then
    log_debug "✓ D-Bus started"
else
    log_warning "D-Bus failed to start (non-fatal)"
fi

if avahi-daemon --daemonize 2>/dev/null; then
    log_debug "✓ Avahi started"
else
    log_warning "Avahi failed to start (non-fatal, AirPrint won't work)"
fi

log_info "════════════════════════════════════════════════════════════"
log_info "✓ CUPS Print Server is running!"
log_info "════════════════════════════════════════════════════════════"
log_info "Web Interface: https://[homeassistant-ip]:${CUPS_PORT}"
log_info "Username: ${CUPS_USERNAME}"
log_info "Password: <configured by user>"
log_info "════════════════════════════════════════════════════════════"

# Keep container alive
log_info "Container is now running. Monitoring CUPS process..."
wait $CUPSD_PID
EXIT_CODE=$?

log_error "CUPS process exited with code: $EXIT_CODE"
log_error "Last 50 lines of CUPS error log:"
tail -50 /var/log/cups/error_log 2>/dev/null || echo "No error log available"

exit $EXIT_CODE
