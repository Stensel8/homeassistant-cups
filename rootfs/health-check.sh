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

# Check if mdns resolution is working for .local hostnames (if avahi-utils is installed)
if command -v avahi-resolve >/dev/null 2>&1; then
    echo "[HEALTH] Checking mDNS resolution sample (avahi-resolve)"
    # We won't assume a printer name, just verify that resolving localhost works
    if avahi-resolve -n localhost 2>/dev/null | grep -q "127.0.0.1"; then
        echo "[HEALTH] PASS: mDNS resolver functioning (localhost -> 127.0.0.1)"
    else
        echo "[HEALTH] WARN: mDNS resolver not returning 127.0.0.1 for localhost"
    fi
else
    echo "[HEALTH] WARN: avahi-utils not installed; skipping mdns checks"
fi

# Check discovery tooling availability
avail=true
for cmd in avahi-browse avahi-resolve; do
    if ! command -v $cmd >/dev/null 2>&1; then
        echo "[HEALTH] WARN: optional discovery tool '$cmd' not installed"
        avail=false
    fi
done
if [ "$avail" = false ]; then
    echo "[HEALTH] WARN: Some discovery capabilities may be missing; install avahi-utils"
fi

echo "[HEALTH] All services healthy"
exit 0

# Optional: Verify discovery API is alive (http://localhost:8080)
if command -v curl >/dev/null 2>&1; then
    if curl -sI http://localhost:8080/ | grep -q "200"; then
        echo "[HEALTH] PASS: Discovery UI responding on port 8080"
    else
        echo "[HEALTH] WARN: Discovery UI did not return HTTP 200 (port 8080)"
    fi
else
    echo "[HEALTH] WARN: curl not present, skipping Discovery UI check"
fi
