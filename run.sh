#!/bin/bash
set -e

echo "[INFO] Initialiseren CUPS container..."

# Setup user for CUPS
useradd -r -s /sbin/nologin -G lp,lpadmin print || true
echo "print:print" | chpasswd

# Ensure required folders
mkdir -p /etc/cups/ssl /var/log/cups /var/run/cups /var/cache/cups /var/spool/cups
chmod 755 /var/log/cups /var/run/cups /var/cache/cups /var/spool/cups

# Check SSL certs
if [ ! -f /etc/cups/ssl/server.crt ] || [ ! -f /etc/cups/ssl/server.key ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/cups/ssl/server.key \
    -out /etc/cups/ssl/server.crt \
    -subj "/C=NL/ST=Netherlands/L=Amsterdam/O=HomeAssistant/OU=CUPS/CN=localhost"
    cat /etc/cups/ssl/server.crt /etc/cups/ssl/server.key > /etc/cups/ssl/server.pem
    chmod 600 /etc/cups/ssl/server.*
fi

# Start CUPS
cupsd -f
