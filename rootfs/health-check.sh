#!/bin/bash
# Health check for CUPS service
set -e

echo "[HEALTH] Starting health check..."

# Check if CUPS daemon is running
if ! ps aux | grep -v grep | grep -q cupsd; then
    echo "[HEALTH] FAIL: CUPS daemon not running"
    exit 1
else
    echo "[HEALTH] PASS: CUPS daemon is running"
fi

# Check if CUPS is listening on port 631
if ! netstat -tuln | grep ':631 ' >/dev/null 2>&1; then
    echo "[HEALTH] FAIL: CUPS not listening on port 631"
    echo "[HEALTH] Current listeners:"
    netstat -tuln | grep :631 || echo "[HEALTH] No port 631 listeners found"
    exit 1
else
    echo "[HEALTH] PASS: Port 631 is listening"
fi

# Check if CUPS web interface is accessible
if ! curl -k -s --max-time 5 https://localhost:631/ >/dev/null 2>&1; then
    echo "[HEALTH] FAIL: CUPS web interface not responding on localhost"
    exit 1
else
    echo "[HEALTH] PASS: CUPS web interface responding on localhost"
fi

# Check if Avahi is running (for service discovery)
if ! ps aux | grep -v grep | grep -q avahi-daemon; then
    echo "[HEALTH] FAIL: Avahi daemon not running"
    exit 1
else
    echo "[HEALTH] PASS: Avahi daemon is running"
fi

echo "[HEALTH] All services healthy"
exit 0
