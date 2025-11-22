#!/usr/bin/env bash
set -e

info() { echo "[generate-ssl] $*"; }

SSL_DIR="/etc/cups/ssl"
CERT_FILE="$SSL_DIR/server.crt"
KEY_FILE="$SSL_DIR/server.key"

info "Generating SSL certificates..."

# Create SSL directory
mkdir -p "$SSL_DIR"
chmod 700 "$SSL_DIR"

# Generate self-signed certificate (valid for 10 years)
openssl req -new -x509 -days 3650 -nodes \
    -out "$CERT_FILE" \
    -keyout "$KEY_FILE" \
    -subj "/C=NL/ST=Home/L=Assistant/O=CUPS/OU=Print/CN=$(hostname)" \
    2>/dev/null

# Fix permissions
chmod 600 "$KEY_FILE"
chmod 644 "$CERT_FILE"
chown lp:lp "$KEY_FILE" "$CERT_FILE"

info "SSL certificates generated successfully"
info "Certificate: $CERT_FILE"
info "Key: $KEY_FILE"
