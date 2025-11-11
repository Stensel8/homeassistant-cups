# Base image - overridden by build.yaml to ghcr.io/hassio-addons/debian-base:8.1.4
FROM ghcr.io/hassio-addons/debian-base:8.1.4

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH

LABEL maintainer="Sten Tijhuis"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Combine all RUN commands into one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential avahi-daemon dbus openssl libssl-dev curl ca-certificates \
    git pkg-config libgnutls28-dev libavahi-client-dev libdbus-1-dev \
    zlib1g-dev net-tools procps socat jq iproute2 \
  && cd /tmp \
  && curl -fsSL https://github.com/hassio-addons/bashio/archive/v0.16.2.tar.gz | tar xz \
  && mv bashio-0.16.2/lib /usr/lib/bashio \
  && ln -s /usr/lib/bashio/bashio /usr/bin/bashio \
  && rm -rf bashio-0.16.2 \
  && curl -fsSL -o cups.tar.gz https://github.com/OpenPrinting/cups/releases/download/v2.4.14/cups-2.4.14-source.tar.gz \
  && echo "660288020dd6f79caf799811c4c1a3207a48689899ac2093959d70a3bdcb7699  cups.tar.gz" | sha256sum -c - \
  && tar xzf cups.tar.gz && cd cups-2.4.14 \
  && case "${TARGETARCH}" in \
       amd64) HOST_ARG="--host=x86_64-linux-gnu" ;; \
       arm64) HOST_ARG="--host=aarch64-linux-gnu" ;; \
       armv7) HOST_ARG="--host=arm-linux-gnueabihf" ;; \
       i386)  HOST_ARG="--host=i686-linux-gnu" ;; \
       *)     HOST_ARG="" ;; \
     esac \
  && ./configure --prefix=/usr --sysconfdir=/etc --disable-local-only \
     --enable-shared --with-tls=openssl --disable-systemd ${HOST_ARG} \
  && make -j$(nproc) && make install \
  && echo -e "/usr/lib\n/usr/local/lib\n/usr/lib64" > /etc/ld.so.conf.d/cups.conf \
  && ldconfig \
  && groupadd -r lp 2>/dev/null || true \
  && useradd -r -g lp -d /var/spool/cups -s /usr/sbin/nologin lp 2>/dev/null || true \
  && cd /tmp && rm -rf cups-2.4.14 cups.tar.gz \
  && apt-get purge -y build-essential git pkg-config libgnutls28-dev \
     libavahi-client-dev libdbus-1-dev zlib1g-dev \
  && apt-get autoremove -y && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Copy runtime files
COPY rootfs/ /

# Create directories and set ALL permissions in one layer
RUN mkdir -p /var/log/cups /var/cache/cups /var/spool/cups /var/run/cups \
     /etc/cups/ssl /usr/etc/cups \
  && chown -R lp:lp /var/log/cups /var/cache/cups /var/spool/cups \
     /var/run/cups /etc/cups/ssl \
  && ln -sf /etc/cups/cupsd.conf /usr/etc/cups/cupsd.conf \
  && ln -sf /etc/cups/cups-files.conf /usr/etc/cups/cups-files.conf \
  && chmod +x /generate-ssl.sh /health-check.sh /start-services.sh \
  && find /etc/services.d -type f -name "run" -exec chmod +x {} \; \
  && find /etc/cont-init.d -type f -exec chmod +x {} \; 2>/dev/null || true

EXPOSE 631

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD /health-check.sh || exit 1

CMD ["/start-services.sh"]
