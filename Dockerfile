# syntax=docker/dockerfile:1
# ==============================================================================
# CUPS Print Server for Home Assistant
# Version: 2.0.0
# ==============================================================================

# ==============================================================================
# Stage 1: Build CUPS from source
# ==============================================================================
FROM ghcr.io/hassio-addons/debian-base:9.1.0 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG CUPS_VERSION=2.0.0

WORKDIR /build

# Install ONLY build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  curl \
  ca-certificates \
  pkg-config \
  libgnutls28-dev \
  libavahi-client-dev \
  libdbus-1-dev \
  zlib1g-dev \
  libssl-dev \
  && rm -rf /var/lib/apt/lists/*

# Download and verify CUPS source
RUN curl -fsSL -o cups.tar.gz \
  "https://github.com/OpenPrinting/cups/releases/download/v${CUPS_VERSION}/cups-${CUPS_VERSION}-source.tar.gz" \
  && echo "660288020dd6f79caf799811c4c1a3207a48689899ac2093959d70a3bdcb7699  cups.tar.gz" | sha256sum -c - \
  && tar xzf cups.tar.gz \
  && rm cups.tar.gz

# Compile CUPS
WORKDIR /build/cups-${CUPS_VERSION}
RUN ./configure \
  --prefix=/usr \
  --sysconfdir=/etc \
  --localstatedir=/var \
  --with-tls=openssl \
  --enable-shared \
  --disable-systemd \
  && make -j$(nproc) \
  && make install DESTDIR=/cups-install

# ==============================================================================
# Stage 2: Runtime image
# ==============================================================================
FROM ghcr.io/hassio-addons/debian-base:9.1.0

ARG DEBIAN_FRONTEND=noninteractive

LABEL \
  io.hass.name="CUPS Print Server" \
  io.hass.description="Minimal CUPS 2.0.0 print server" \
  io.hass.version="2.0.0" \
  io.hass.type="addon" \
  io.hass.arch="aarch64|amd64|armv7|i386" \
  maintainer="Sten Tijhuis <https://github.com/Stensel8>"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install ONLY runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  # CUPS runtime
  cups-filters \
  libavahi-client3 \
  libdbus-1-3 \
  zlib1g \
  openssl \
  ca-certificates \
  # Avahi for AirPrint/mDNS
  avahi-daemon \
  avahi-utils \
  libnss-mdns \
  dbus \
  # Utilities
  curl \
  inotify-tools \
  procps \
  && rm -rf /var/lib/apt/lists/*

# Configure mDNS for .local hostnames
RUN if [ -f /etc/nsswitch.conf ]; then \
    sed -i 's/^hosts:.*/hosts: files mdns4_minimal [NOTFOUND=return] dns mdns4/' /etc/nsswitch.conf; \
  fi

# Copy compiled CUPS from builder
COPY --from=builder /cups-install/usr /usr
COPY --from=builder /cups-install/etc/cups /etc/cups.default

# Register CUPS libraries
RUN echo -e "/usr/lib\n/usr/local/lib" > /etc/ld.so.conf.d/cups.conf \
  && ldconfig

# Create lp user/group
RUN groupadd -r lp 2>/dev/null || true \
  && useradd -r -g lp -d /var/spool/cups -s /usr/sbin/nologin lp 2>/dev/null || true \
  && groupadd -r lpadmin 2>/dev/null || true

# Copy rootfs (config, scripts, s6 services)
COPY rootfs/ /

# Setup directories and permissions
RUN mkdir -p \
  /var/log/cups \
  /var/cache/cups \
  /var/spool/cups \
  /var/run/cups \
  /run/cups \
  /etc/cups/ssl \
  /data/cups \
  && chown -R lp:lp \
  /var/log/cups \
  /var/cache/cups \
  /var/spool/cups \
  /var/run/cups \
  /run/cups \
  /etc/cups/ssl \
  && chmod +x \
  /usr/local/bin/*.sh \
  && chmod +x \
  /etc/s6-overlay/s6-rc.d/*/run \
  /etc/s6-overlay/s6-rc.d/*/finish \
  /etc/s6-overlay/s6-rc.d/*/up \
  2>/dev/null || true

# Expose CUPS port
EXPOSE 631

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD /usr/local/bin/healthcheck.sh || exit 1

# S6-overlay start
ENTRYPOINT ["/init"]
