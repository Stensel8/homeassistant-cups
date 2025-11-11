# Base image for local development/testing
# When built by Home Assistant Supervisor, build.yaml overrides this with:
# ghcr.io/hassio-addons/debian-base:8.1.4 (per architecture)
FROM ghcr.io/hassio-addons/debian-base:8.1.4

ARG DEBIAN_FRONTEND=noninteractive

LABEL maintainer="Sten Tijhuis"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
  build-essential \
  avahi-daemon \
  dbus \
  openssl \
  libssl-dev \
  curl \
  ca-certificates \
  git \
  pkg-config \
  libgnutls28-dev \
  libavahi-client-dev \
  libdbus-1-dev \
  zlib1g-dev \
  net-tools \
  procps \
  socat \
  jq \
  iproute2 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install bashio for Home Assistant config parsing
RUN curl -L https://github.com/hassio-addons/bashio/archive/v0.16.2.tar.gz | tar xz \
  && mv bashio-0.16.2/lib /usr/lib/bashio \
  && ln -s /usr/lib/bashio/bashio /usr/bin/bashio \
  && rm -rf bashio-0.16.2

# Download and build CUPS
WORKDIR /tmp
RUN curl -L -o cups-2.4.14-source.tar.gz https://github.com/OpenPrinting/cups/releases/download/v2.4.14/cups-2.4.14-source.tar.gz \
  && echo "660288020dd6f79caf799811c4c1a3207a48689899ac2093959d70a3bdcb7699  cups-2.4.14-source.tar.gz" | sha256sum -c - \
  && tar xzf cups-2.4.14-source.tar.gz \
  && cd cups-2.4.14 \
  && ./configure --prefix=/usr --sysconfdir=/etc --disable-local-only --enable-shared --with-tls=openssl \
  && make -j$(nproc) \
  && make install \
  && echo -e "/usr/lib\n/usr/local/lib\n/usr/lib64" > /etc/ld.so.conf.d/cups.conf \
  && ldconfig \
  && cd .. \
  && rm -rf cups-2.4.14 cups-2.4.14-source.tar.gz

# Create lp user and group for CUPS (non-root for security)
RUN groupadd -r lp 2>/dev/null || true \
  && useradd -r -g lp -d /var/spool/cups -s /usr/sbin/nologin lp 2>/dev/null || true

# Copy runtime files
COPY rootfs/ /

# Create necessary directories and set ownership
RUN mkdir -p /var/log/cups /var/cache/cups /var/spool/cups /var/run/cups /etc/cups/ssl \
  && chown -R lp:lp /var/log/cups /var/cache/cups /var/spool/cups /var/run/cups /etc/cups/ssl

# Create symlinks so CUPS uses /etc/cups/ as the single source of truth
RUN mkdir -p /usr/etc/cups \
  && ln -sf /etc/cups/cupsd.conf /usr/etc/cups/cupsd.conf \
  && ln -sf /etc/cups/cups-files.conf /usr/etc/cups/cups-files.conf

# Ensure scripts are executable
RUN chmod +x /generate-ssl.sh /health-check.sh /start-services.sh

EXPOSE 631

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD /health-check.sh || exit 1

CMD ["/start-services.sh"]
