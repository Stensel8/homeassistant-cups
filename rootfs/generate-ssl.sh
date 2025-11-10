#!/bin/bash

# Generate SSL certificates for CUPS (ensure compatibility with TLS 1.2+)

set -euo pipefail

SSL_DIR="/etc/cups/ssl"
mkdir -p "$SSL_DIR"

# Generate a strong private key (RSA 4096)
if [ ! -f "$SSL_DIR/server.key" ]; then
    openssl genrsa -out "$SSL_DIR/server.key" 4096
fi

# Generate certificate signing request
openssl req -new -key "$SSL_DIR/server.key" -out "$SSL_DIR/server.csr" -subj "/C=NL/ST=Netherlands/L=Amsterdam/O=HomeAssistant/OU=CUPS/CN=localhost/emailAddress=admin@localhost"

# Create a temporary extfile for subjectAltName and extensions
EXTFILE="/tmp/openssl-ext.cnf"
cat > "$EXTFILE" <<'EOF'
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = localhost
DNS.2 = *.local
DNS.3 = cups
IP.1 = 127.0.0.1
IP.2 = 0.0.0.0
EOF

# Generate self-signed certificate (valid 10 years)
openssl x509 -req -days 3650 -in "$SSL_DIR/server.csr" -signkey "$SSL_DIR/server.key" -out "$SSL_DIR/server.crt" -extensions v3_req -extfile "$EXTFILE"

# Create combined PEM (some clients expect certificate+key in one file)
cat "$SSL_DIR/server.key" "$SSL_DIR/server.crt" > "$SSL_DIR/server.pem" || true

# Set proper permissions
chmod 600 "$SSL_DIR/server.key"
chmod 644 "$SSL_DIR/server.crt"
chmod 600 "$SSL_DIR/server.pem" || true
chown -R root:lp "$SSL_DIR" || true

# Clean up CSR and extfile
rm -f "$SSL_DIR/server.csr" "$EXTFILE"

echo "SSL certificates generated successfully!"
echo "Certificate: $SSL_DIR/server.crt"
echo "Private Key: $SSL_DIR/server.key"
echo "Combined PEM: $SSL_DIR/server.pem"
