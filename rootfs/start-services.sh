#!/bin/bash

# Exit on error, but we'll handle errors manually for better logging
set -o pipefail

# Set TERM to prevent warnings
export TERM=xterm-256color

# Enable debug mode (set via add-on option `cupsdebug`, default: false)
DEBUG=${DEBUG:-false}

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
echo "   Version: 1.3.5                                           "
echo "════════════════════════════════════════════════════════════"
echo ""

log_info "Starting CUPS Print Server for Home Assistant"
log_debug "Shell: $SHELL, User: $(whoami), PID: $$"

# Port is fixed to 631 (CUPS standard)
CUPS_PORT=631

# Check if required commands exist
log_debug "Checking required commands..."
for cmd in curl groupadd useradd cupsd netstat; do
    if ! command -v $cmd >/dev/null 2>&1; then
        log_fatal "Required command '$cmd' not found! Docker build may have failed."
    fi
    log_debug "✓ Found: $cmd"
done

# Ensure discovery tool dependencies are present (warn only)
for cmd in avahi-browse avahi-resolve; do
    if ! command -v $cmd >/dev/null 2>&1; then
        log_warning "Optional discovery tool '$cmd' is not installed; discovery features may be limited or unavailable."
    else
        log_debug "✓ Found optional tool: $cmd"
    fi
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
    # Check bashio version
    BASHIO_VERSION=$(bashio --version 2>/dev/null | head -1 || echo "v0.16.2")
    log_info "✓ Bashio found (version: ${BASHIO_VERSION})"
    
    # Read config immediately via bashio helpers (if present) so changes from the add-on UI
    # are applied on restart even when the Supervisor is not yet reachable.
    CUPS_USERNAME=$(bashio::config 'cupsusername' 2>/dev/null || echo "admin")
    CUPS_PASSWORD=$(bashio::config 'cupspassword' 2>/dev/null || echo "admin")
    SSL_ENABLED=$(bashio::config 'sslenabled' 2>/dev/null || echo "true")
    ALLOW_REMOTE_ADMIN=$(bashio::config 'allowremoteadmin' 2>/dev/null || echo "true")
    CUPS_DEBUG=$(bashio::config 'cupsdebug' 2>/dev/null || echo "${CUPS_DEBUG:-false}")
    if [ "${CUPS_DEBUG}" = "true" ]; then
        DEBUG="true"
    fi
    ENABLE_CUPS_BROWSED=$(bashio::config 'enable_cups_browsed' 2>/dev/null || echo "false")
    ENABLE_DISCOVERY_UI=$(bashio::config 'enable_discovery_ui' 2>/dev/null || echo "false")
    ENABLE_MONITORS=$(bashio::config 'enable_monitors' 2>/dev/null || echo "true")
    PUBLIC_URL=$(bashio::config 'public_url' 2>/dev/null || echo "")
    log_info "Configuration loaded from HA - User: ${CUPS_USERNAME}"

    # Wait a bit for Supervisor if it exists, but don't force a failure if unreachable.
    CONNECTED=false
    for i in {1..30}; do
        if bashio::supervisor.ping 2>/dev/null; then
            CONNECTED=true
            break
        fi
        log_debug "Waiting for supervisor... (${i}/30)"
        sleep 1
    done
    if [ "$CONNECTED" = false ]; then
        log_warning "Supervisor not reachable after 30 seconds; using config read from bashio (if available)"
    fi
else
    log_warning "Bashio not found - using environment/default values"
    CUPS_USERNAME="${CUPS_USERNAME:-admin}"
    CUPS_PASSWORD="${CUPS_PASSWORD:-admin}"
    SSL_ENABLED="${SSL_ENABLED:-true}"
    ALLOW_REMOTE_ADMIN="${ALLOW_REMOTE_ADMIN:-true}"
    CUPS_DEBUG="${CUPS_DEBUG:-false}"
    ENABLE_CUPS_BROWSED="false"
    ENABLE_DISCOVERY_UI="false"
    ENABLE_MONITORS="true"
    PUBLIC_URL=""
fi

# Write runtime environment selections for services started in `services.d`
# No add-ons env file required - keep runtime simple and rely on bashio/config

log_debug "Config: User=$CUPS_USERNAME, Port=$CUPS_PORT (fixed), SSL=$SSL_ENABLED"

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

# Update cupsd.conf with fixed port 631
log_info "Configuring CUPS to listen on port 631..."
if [ ! -f /etc/cups/cupsd.conf ]; then
    log_fatal "cupsd.conf not found! Check if COPY rootfs/ / worked in Dockerfile"
fi

log_debug "Updating Listen directive in cupsd.conf..."
if sed -i "s/^Listen 0\.0\.0\.0:[0-9]\+/Listen 0.0.0.0:631/" /etc/cups/cupsd.conf; then
    log_debug "✓ Updated existing Listen directive"
else
    log_warning "sed failed or no Listen directive found"
fi

# Verify Listen directive exists
if ! grep -q "^Listen 0\.0\.0\.0:" /etc/cups/cupsd.conf; then
    log_warning "No Listen 0.0.0.0 found, adding it..."
    sed -i '/^Listen/d' /etc/cups/cupsd.conf
    sed -i "1i Listen 0.0.0.0:631" /etc/cups/cupsd.conf
    sed -i '2i Listen /var/run/cups/cups.sock' /etc/cups/cupsd.conf
fi

# Sync config to /usr/etc/cups if it exists
if [ -d /usr/etc/cups ]; then
    log_debug "Syncing cupsd.conf to /usr/etc/cups (for compatibility)..."
    
    # If symlink doesn't exist, force sync
    if [ ! -L /usr/etc/cups/cupsd.conf ]; then
        log_warning "/usr/etc/cups/cupsd.conf is not a symlink, forcing sync..."
        cp -f /etc/cups/cupsd.conf /usr/etc/cups/cupsd.conf
    fi
    
    # Ensure Listen directive is correct
    sed -i "s/^Listen 127\.0\.0\.1:[0-9]\+/Listen 0.0.0.0:631/" /usr/etc/cups/cupsd.conf 2>/dev/null || true
    sed -i "s/^Listen localhost:[0-9]\+/Listen 0.0.0.0:631/" /usr/etc/cups/cupsd.conf 2>/dev/null || true
    
    log_debug "✓ Config synced to /usr/etc/cups"
fi


if [ -z "$HOST_IP" ]; then
    # Try to derive a sensible public host value. Prefer explicit public_url when set,
    # otherwise try to find 'host.docker.internal' or leave empty.
    if [ -n "${PUBLIC_URL:-}" ]; then
        HOST_IP=$(echo "$PUBLIC_URL" | sed -E 's@https?://([^/:]+).*@\1@')
        log_debug "Derived HOST_IP from public_url: $HOST_IP"
    else
        HOST_IP=$(getent hosts host.docker.internal 2>/dev/null | awk '{print $1}')
        log_debug "Derived HOST_IP from host.docker.internal: $HOST_IP"
    fi
fi

# If HOST_IP still unknown, prefer the container interface address discovered earlier
# The HOST_IP fallback will be applied after network detection (where CONTAINER_IP is set)

# Note: Do not change ServerName or force HTTPS mode automatically —
# keep the configuration minimal and let Home Assistant or the user manage
# any overrides via `/config/cups` persistent config files mounted into the container.

# Sync to /usr/etc/cups as well
if [ -d /usr/etc/cups ] && [ ! -L /usr/etc/cups/cupsd.conf ]; then
    cp -f /etc/cups/cupsd.conf /usr/etc/cups/cupsd.conf
fi

# If configured, set explicit ServerName in cupsd.conf to support correct redirects
if [ -n "${PUBLIC_URL:-}" ]; then
    PUBLIC_HOST=$(echo "$PUBLIC_URL" | sed -E 's@https?://([^/:]+).*@\1@')
    log_info "Setting CUPS ServerName to: $PUBLIC_HOST"
    sed -i "s/^ServerName .*/ServerName $PUBLIC_HOST/" /etc/cups/cupsd.conf || true
    sed -i "s/^ServerAlias .*/ServerAlias $PUBLIC_HOST/" /etc/cups/cupsd.conf || true
fi

# Create or update CUPS user
CURRENT_USER_FILE="/var/cache/cups/current-username"
PREVIOUS_USER=""
if [ -f "$CURRENT_USER_FILE" ]; then
    PREVIOUS_USER=$(cat "$CURRENT_USER_FILE" 2>/dev/null || echo "")
fi

log_info "Setting up user: ${CUPS_USERNAME}"
if [ "${CUPS_USERNAME}" != "${PREVIOUS_USER}" ]; then
    log_info "Detected CUPS username change: ${PREVIOUS_USER:-<none>} -> ${CUPS_USERNAME}"
    if id "$CUPS_USERNAME" >/dev/null 2>&1; then
        log_debug "User $CUPS_USERNAME exists; ensuring group membership and applying password"
    else
        log_debug "Creating new user $CUPS_USERNAME"
        if useradd --groups=lpadmin --create-home --shell=/bin/bash "$CUPS_USERNAME" 2>/dev/null; then
            log_info "✓ Created user: ${CUPS_USERNAME}"
        else
            log_fatal "Failed to create user: ${CUPS_USERNAME}"
        fi
    fi
    # Lock the previous configured user (if different) to avoid surprise logins
    if [ -n "$PREVIOUS_USER" ] && [ "$PREVIOUS_USER" != "$CUPS_USERNAME" ]; then
        if id "$PREVIOUS_USER" >/dev/null 2>&1; then
            log_info "Locking previous username: $PREVIOUS_USER"
            usermod -L "$PREVIOUS_USER" 2>/dev/null || log_warning "Unable to lock user $PREVIOUS_USER"
        fi
    fi
    # Persist chosen username for next run
    mkdir -p "$(dirname "$CURRENT_USER_FILE")" 2>/dev/null || true
    echo "$CUPS_USERNAME" > "$CURRENT_USER_FILE" 2>/dev/null || true
else
    log_debug "CUPS username unchanged: $CUPS_USERNAME"
    if ! id "$CUPS_USERNAME" >/dev/null 2>&1; then
        log_info "CUPS username '$CUPS_USERNAME' missing; creating it"
        useradd --groups=lpadmin --create-home --shell=/bin/bash "$CUPS_USERNAME" 2>/dev/null || log_fatal "Failed to create missing user: $CUPS_USERNAME"
    fi
fi

log_debug "Setting password for user '$CUPS_USERNAME'..."
if echo "$CUPS_USERNAME:$CUPS_PASSWORD" | chpasswd 2>/dev/null; then
    log_debug "✓ Password set successfully for $CUPS_USERNAME"
else
    log_error "Failed to set password for $CUPS_USERNAME (non-fatal)"
fi

# Set config permissions
chmod 644 /etc/cups/cupsd.conf 2>/dev/null || log_warning "Could not set cupsd.conf permissions"

# Debug: show current lpadmin members for visibility
LPADMINS=$(getent group lpadmin 2>/dev/null | awk -F: '{print $4}') || LPADMINS=""
log_debug "Current lpadmin members: ${LPADMINS:-<none>}"

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

# If remote admin has been disabled via config, lock down the admin locations to localhost only
if [ "${ALLOW_REMOTE_ADMIN:-true}" = "false" ]; then
    log_info "Remote admin disabled: restricting admin pages to localhost"
    sed -i '/<Location \/admin>/,/<\/Location>/ s/Allow all/Allow From 127.0.0.1/' /etc/cups/cupsd.conf || true
    sed -i '/<Location \/admin\/conf>/,/<\/Location>/ s/Allow all/Allow From 127.0.0.1/' /etc/cups/cupsd.conf || true
fi

# If environment variable CUPS_DEBUG is set to true, set LogLevel to debug
if [ "${CUPS_DEBUG:-false}" = "true" ]; then
    log_info "CUPS debug logging enabled"
    sed -i 's/^LogLevel .*/LogLevel debug/' /etc/cups/cupsd.conf || true
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
    if curl -k -s --max-time 3 https://localhost:631/ >/dev/null 2>&1; then
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

# If HOST_IP still unknown, prefer the container interface address discovered earlier
if [ -z "$HOST_IP" ] && [ -n "$CONTAINER_IP" ]; then
    HOST_IP="$CONTAINER_IP"
    log_debug "Using container IP as HOST_IP: $HOST_IP"
fi

log_info "Listening ports:"
netstat -tuln 2>/dev/null | grep 631 || ss -tuln 2>/dev/null | grep 631 || log_warning "Could not check listening ports"

log_info "Testing local CUPS access:"
curl -k -I https://localhost:631/ 2>&1 | head -5 || log_warning "Local access test failed"

if [ -n "$CONTAINER_IP" ]; then
    log_info "Testing external CUPS access (via ${CONTAINER_IP}:631):"
    curl -k -I https://$CONTAINER_IP:631/ 2>&1 | head -5 || log_warning "External access test failed"
fi

# Start job and printer monitors (lightweight) to log jobs and printer changes.
if [ "${ENABLE_MONITORS:-true}" = "true" ] && [ -f /opt/cups-job-monitor.sh ]; then
    chmod +x /opt/cups-job-monitor.sh 2>/dev/null || true
    if ! pgrep -f 'cups-job-monitor.sh' >/dev/null 2>&1; then
        log_info "Starting job monitor..."
        nohup /opt/cups-job-monitor.sh >/var/log/cups/job-monitor.log 2>&1 &
    else
        log_debug "Job monitor already running"
    fi
fi

if [ "${ENABLE_MONITORS:-true}" = "true" ] && [ -f /opt/cups-printer-monitor.sh ]; then
    chmod +x /opt/cups-printer-monitor.sh 2>/dev/null || true
    if ! pgrep -f 'cups-printer-monitor.sh' >/dev/null 2>&1; then
        log_info "Starting printer monitor..."
        nohup /opt/cups-printer-monitor.sh >/var/log/cups/printer-monitor.log 2>&1 &
    else
        log_debug "Printer monitor already running"
    fi
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

# Quick check that avahi-browse can list services (non-fatal)
if command -v avahi-browse >/dev/null 2>&1; then
    if avahi-browse --parsable -r -t _ipp._tcp 2>/dev/null | head -n1 >/dev/null 2>&1; then
        log_debug "✓ avahi-browse available and functional"
    else
        log_warning "avahi-browse installed but no _ipp._tcp services found or it cannot resolve yet"
    fi
else
    log_debug "avahi-browse not installed; install avahi-utils for better discovery support"
fi

# Start the discovery UI if explicitly enabled and present
DISCOVERY_CONTROL_FILE="/run/cups/enable_discovery_ui"
if [ "${ENABLE_DISCOVERY_UI:-false}" = "true" ] && [ -f /opt/discovery-ui.sh ]; then
    mkdir -p $(dirname "$DISCOVERY_CONTROL_FILE") 2>/dev/null || true
    touch "$DISCOVERY_CONTROL_FILE"
    log_info "Discovery UI enabled; letting service manager start discovery-ui (control file: $DISCOVERY_CONTROL_FILE)"
else
    log_debug "Discovery UI is disabled by addon configuration"
    rm -f "$DISCOVERY_CONTROL_FILE" 2>/dev/null || true
fi

# Start cups-browsed if enabled
if [ "${ENABLE_CUPS_BROWSED:-false}" = "true" ]; then
    if command -v cups-browsed >/dev/null 2>&1; then
        log_info "Starting cups-browsed (auto-creating queues from discovered printers)..."
        # Start in foreground in background so it keeps running and logs to the console
        /usr/sbin/cups-browsed -f >/var/log/cups/cups-browsed.log 2>&1 &
    else
        log_warning "cups-browsed is not available in the container; install cups-filters to enable it"
    fi
fi

log_info "════════════════════════════════════════════════════════════"
log_info "✓ CUPS Print Server is running!"
log_info "════════════════════════════════════════════════════════════"
if [ -n "${PUBLIC_URL}" ]; then
    log_info "Web Interface: ${PUBLIC_URL}"
else
    if [ -n "${CONTAINER_IP}" ]; then
        log_info "Web Interface: https://${CONTAINER_IP}:${CUPS_PORT}"
    else
        log_info "Web Interface: https://[homeassistant-ip]:${CUPS_PORT}"    
    fi
fi
log_info "Username: ${CUPS_USERNAME}"
log_info "Password: <configured>"
log_info "════════════════════════════════════════════════════════════"

# Keep container alive
log_info "Container is now running. Monitoring CUPS process..."
wait $CUPSD_PID
EXIT_CODE=$?

log_error "CUPS process exited with code: $EXIT_CODE"
log_error "Last 50 lines of CUPS error log:"
tail -50 /var/log/cups/error_log 2>/dev/null || echo "No error log available"

exit $EXIT_CODE
