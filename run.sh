#!/bin/bash
set -e

echo "[INFO] Initializing CUPS container..."

CUPS_USERNAME="${CUPS_USERNAME:-admin}"
CUPS_PASSWORD="${CUPS_PASSWORD:-admin}"

# Add admin user for CUPS with lpadmin privileges
if ! id "$CUPS_USERNAME" >/dev/null 2>&1; then
    useradd --groups=lpadmin,lp --create-home --shell=/bin/bash "$CUPS_USERNAME"
    echo "$CUPS_USERNAME:$CUPS_PASSWORD" | chpasswd
    echo "[INFO] Created admin user: $CUPS_USERNAME"
else
    echo "[INFO] Admin user $CUPS_USERNAME already exists"
    usermod -a -G lpadmin,lp "$CUPS_USERNAME"
    echo "$CUPS_USERNAME:$CUPS_PASSWORD" | chpasswd
    echo "[INFO] Updated admin password and groups"
fi

# Prepare required directories
for dir in /etc/cups/ssl /var/log/cups /var/run/cups /var/cache/cups /var/spool/cups; do
    mkdir -p "$dir"
    chmod 755 "$dir"
done

# Generate SSL cert if missing
if [ ! -f /etc/cups/ssl/server.crt ] || [ ! -f /etc/cups/ssl/server.key ]; then
    echo "[INFO] Generating self-signed SSL certificate..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/cups/ssl/server.key \
    -out /etc/cups/ssl/server.crt \
    -subj "/C=NL/ST=Netherlands/L=Amsterdam/O=HomeAssistant/OU=CUPS/CN=localhost"
    cat /etc/cups/ssl/server.crt /etc/cups/ssl/server.key > /etc/cups/ssl/server.pem
    chmod 600 /etc/cups/ssl/server.*
    echo "[INFO] SSL certificate generated."
fi

# Print server stats for Home Assistant add-on tab
echo "[STATS] $(date) Uptime: $(uptime -p)" > /var/log/cups/status.log
lpstat -t >> /var/log/cups/status.log

echo "[INFO] Starting CUPS daemon..."
cupsd -f
