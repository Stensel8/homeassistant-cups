ARG BUILD_FROM=ubuntu:22.04
FROM ${BUILD_FROM}

ARG CUPS_VERSION=2.4.12

LABEL io.hass.version="1.2" io.hass.type="addon" io.hass.arch="aarch64|amd64"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install dependencies and build CUPS
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash build-essential gcc make pkg-config wget ca-certificates \
    libssl-dev libdbus-1-dev libavahi-client-dev libavahi-common-dev \
    libpam0g-dev libusb-1.0-0-dev \
    sudo locales avahi-daemon libnss-mdns dbus openssl curl \
    printer-driver-all openprinting-ppds hpijs-ppds hp-ppd hplip \
    printer-driver-foo2zjs printer-driver-hpcups printer-driver-escpr \
    gnupg2 lsb-release procps psmisc \
    python3 python3-pip python3-dev supervisor \
    mosquitto-clients jq curl && \
    wget -qO /tmp/cups.tar.gz "https://github.com/OpenPrinting/cups/releases/download/v${CUPS_VERSION}/cups-${CUPS_VERSION}-source.tar.gz" && \
    mkdir -p /tmp/cups && tar -xzf /tmp/cups.tar.gz -C /tmp/cups --strip-components=1 && \
    cd /tmp/cups && \
    ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var \
        --enable-debug --enable-avahi --enable-dbus && \
    make -j$(nproc) && make install && \
    pip3 install flask requests && \
    apt-get purge -y --auto-remove build-essential gcc make pkg-config wget ca-certificates && \
    rm -rf /tmp/cups /tmp/cups.tar.gz /var/lib/apt/lists/* && \
    mkdir -p /var/run/dbus /var/run/avahi-daemon /var/www/html && \
    groupadd -f lpadmin && groupadd -f lp

COPY rootfs /

RUN sed -i 's/\r$//' /generate-ssl.sh && chmod +x /generate-ssl.sh && \
    sed -i 's/\r$//' /health-check.sh && chmod +x /health-check.sh && \
    chmod +x /usr/bin/cups-management-api.py && \
    chmod +x /start-services.sh && \
    chmod +x /etc/services.d/cups-ha-integration/run && \
    chmod +x /etc/services.d/cups-discovery/run

# Create default user (will be reconfigured at runtime)
RUN useradd --groups=sudo,lp,lpadmin --create-home --home-dir=/home/print --shell=/bin/bash print && \
    echo "print:print" | chpasswd && \
    echo "%sudo ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

EXPOSE 631 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /health-check.sh

CMD ["/start-services.sh"]
