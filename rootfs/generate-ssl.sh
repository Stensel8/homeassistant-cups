#!/bin/bash

# Generate SSL certificates for CUPS with TLS 1.3 support

SSL_DIR="/etc/cups/ssl"
mkdir -p "$SSL_DIR"

# Generate a strong private key (4096-bit RSA)
openssl genrsa -out "$SSL_DIR/server.key" 4096

# Generate certificate signing request
openssl req -new -key "$SSL_DIR/server.key" -out "$SSL_DIR/server.csr" -subj "/C=NL/ST=Netherlands/L=Amsterdam/O=HomeAssistant/OU=CUPS/CN=localhost/emailAddress=admin@localhost"

# Generate self-signed certificate with TLS 1.3 support
openssl x509 -req -days 3650 -in "$SSL_DIR/server.csr" -signkey "$SSL_DIR/server.key" -out "$SSL_DIR/server.crt" \
    -extensions v3_ca -extensions v3_req \
    -extfile <(echo "
[v3_ca]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

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
")

# Set proper permissions
chmod 600 "$SSL_DIR/server.key"
chmod 644 "$SSL_DIR/server.crt"
chown -R root:lp "$SSL_DIR"

# Clean up CSR file
rm -f "$SSL_DIR/server.csr"

echo "SSL certificates generated successfully!"
echo "Certificate: $SSL_DIR/server.crt"
echo "Private Key: $SSL_DIR/server.key"
