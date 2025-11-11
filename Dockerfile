# syntax=docker/dockerfile:1
# ==============================================================================
# Stage 1: Build Stage - Compile CUPS from source
# ==============================================================================
FROM ghcr.io/hassio-addons/debian-base:8.1.4 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

WORKDIR /build

# Install ONLY build dependencies (will be discarded in final stage)
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
    https://github.com/OpenPrinting/cups/releases/download/v2.4.14/cups-2.4.14-source.tar.gz \
  && echo "660288020dd6f79caf799811c4c1a3207a48689899ac2093959d70a3bdcb7699  cups.tar.gz" | sha256sum -c - \
  && tar xzf cups.tar.gz \
  && rm cups.tar.gz

# Configure and compile CUPS with optimal settings
WORKDIR /build/cups-2.4.14
RUN ./configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --disable-local-only \
    --disable-systemd \
    --enable-shared \
    --with-tls=openssl \
  && make -j$(nproc) \
  && make install DESTDIR=/cups-install

# ==============================================================================
# Stage 2: Runtime Stage - Minimal image with only runtime dependencies
# ==============================================================================
FROM ghcr.io/hassio-addons/debian-base:8.1.4

ARG DEBIAN_FRONTEND=noninteractive

LABEL maintainer="Sten Tijhuis"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install ONLY runtime dependencies (no build tools!)
RUN apt-get update && apt-get install -y --no-install-recommends \
    avahi-daemon \
    dbus \
    openssl \
    curl \
    ca-certificates \
    libavahi-client3 \
    libdbus-1-3 \
    zlib1g \
    net-tools \
    procps \
    socat \
    jq \
    iproute2 \
  && rm -rf /var/lib/apt/lists/*

# Copy ONLY the compiled CUPS binaries from builder stage
COPY --from=builder /cups-install /

# Install bashio (lightweight, no compilation needed)
RUN curl -fsSL https://github.com/hassio-addons/bashio/archive/v0.16.2.tar.gz | tar xz \
  && mv bashio-0.16.2/lib /usr/lib/bashio \
  && ln -s /usr/lib/bashio/bashio /usr/bin/bashio \
  && rm -rf bashio-0.16.2

# Register CUPS libraries
RUN echo -e "/usr/lib\n/usr/local/lib\n/usr/lib64" > /etc/ld.so.conf.d/cups.conf \
  && ldconfig

# Create lp user/group
RUN groupadd -r lp 2>/dev/null || true \
  && useradd -r -g lp -d /var/spool/cups -s /usr/sbin/nologin lp 2>/dev/null || true

# Copy runtime files
COPY rootfs/ /

# Setup directories and fix permissions in one optimized layer
RUN mkdir -p /var/log/cups /var/cache/cups /var/spool/cups /var/run/cups \
     /etc/cups/ssl /usr/etc/cups \
  && chown -R lp:lp /var/log/cups /var/cache/cups /var/spool/cups \
     /var/run/cups /etc/cups/ssl \
  && ln -sf /etc/cups/cupsd.conf /usr/etc/cups/cupsd.conf \
  && ln -sf /etc/cups/cups-files.conf /usr/etc/cups/cups-files.conf \
  && for script in /generate-ssl.sh /health-check.sh /start-services.sh; do \
       sed -i 's/\r$//' "$script" 2>/dev/null || true; \
       sed -i '1s/^\xEF\xBB\xBF//' "$script" 2>/dev/null || true; \
       chmod +x "$script"; \
     done \
  && find /etc/services.d -type f -name "run" -exec sh -c 'sed -i "s/\r$//" "$1" && chmod +x "$1"' _ {} \; 2>/dev/null || true \
  && find /etc/cont-init.d -type f -exec sh -c 'sed -i "s/\r$//" "$1" && chmod +x "$1"' _ {} \; 2>/dev/null || true

EXPOSE 631

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD /health-check.sh || exit 1

CMD ["/start-services.sh"]
