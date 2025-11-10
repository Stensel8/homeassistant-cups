FROM debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

LABEL maintainer="Sten Tijhuis"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Minimal image that uses packaged CUPS. Keep only what's needed to run CUPS.

# Install dependencies for libcups build
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
  socat \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Download and build libcups v3
WORKDIR /tmp
RUN curl -L -o cups-2.4.14-source.tar.gz https://github.com/OpenPrinting/cups/releases/download/v2.4.14/cups-2.4.14-source.tar.gz \
  && echo "660288020dd6f79caf799811c4c1a3207a48689899ac2093959d70a3bdcb7699  cups-2.4.14-source.tar.gz" | sha256sum -c - \
  && tar xzf cups-2.4.14-source.tar.gz \
  && cd cups-2.4.14 \
  && ./configure --prefix=/usr --disable-local-only --enable-shared --with-tls=openssl \
  && make -j$(nproc) \
  && make install \
  && echo -e "/usr/lib\n/usr/local/lib\n/usr/lib64" > /etc/ld.so.conf.d/cups.conf \
  && ldconfig \
  && cd .. \
  && rm -rf cups-2.4.14 cups-2.4.14-source.tar.gz

# Copy runtime files
COPY rootfs/ /

# Ensure scripts have LF endings and are executable
RUN sed -i 's/\r$//' /generate-ssl.sh && sed -i '1s/^\xEF\xBB\xBF//' /generate-ssl.sh && chmod +x /generate-ssl.sh || true
RUN sed -i 's/\r$//' /health-check.sh && sed -i '1s/^\xEF\xBB\xBF//' /health-check.sh && chmod +x /health-check.sh || true
RUN sed -i 's/\r$//' /start-services.sh && sed -i '1s/^\xEF\xBB\xBF//' /start-services.sh && chmod +x /start-services.sh || true

EXPOSE 631

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD /health-check.sh || exit 1

CMD ["/start-services.sh"]
