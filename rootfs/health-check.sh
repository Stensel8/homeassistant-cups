#!/bin/bash
# Health check for CUPS service
set -e

# Check if CUPS daemon is running
if ! pgrep -x cupsd >/dev/null 2>&1; then
    echo "CUPS daemon not running"
    exit 1
fi

# Check if CUPS is responding on the socket
if ! curl -k -s --max-time 5 https://localhost:631/ >/dev/null 2>&1; then
    echo "CUPS not responding on HTTPS port"
    exit 1
fi

# Check if Avahi is running (for service discovery)
if ! pgrep -x avahi-daemon >/dev/null 2>&1; then
    echo "Avahi daemon not running"
    exit 1
fi

echo "All services healthy"
exit 0
