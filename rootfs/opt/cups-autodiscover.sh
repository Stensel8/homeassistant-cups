#!/bin/bash
set -euo pipefail

# CUPS discovery using Avahi
# This script continuously monitors network printers via mDNS (_ipp._tcp) and
# logs discovered printers to a JSON file under /var/cache/cups/discovered.

LOG() { echo "[CUPS-AUTO-DISCOVERY] $(date '+%F %T') - $*"; }

sanitize_name(){
    # Replace spaces and slashes and other bad characters
    echo "$1" | tr ' ' '_' | tr -cd '[:alnum:]_-.' | sed 's/[.][.]*//g' | cut -c1-60
}

# Discovery-only script: this script only discovers printers and writes metadata.
# Discovery-only mode: do not auto-add printers in CUPS; this script only records discovered devices.


# We'll only discover and record printers, not add or remove them in CUPS.
DISCOVERY_DIR="/var/cache/cups/discovered"
mkdir -p "$DISCOVERY_DIR"
chown lp:lp "$DISCOVERY_DIR" 2>/dev/null || true

# Basic dependency check to allow the script to exit gracefully when avahi isn't present
if ! command -v avahi-browse >/dev/null 2>&1; then
    LOG "avahi-browse not installed - discovery disabled"
    exit 0
fi

update_discovery(){
    local name="$1" address="$2" port="$3" rp="$4" host="$5" srvtype="$6" domain="$7"
    local pname
    pname=$(sanitize_name "$name")
    # Write minimal key=value lines into a text file for lighter parsing and minimal runtime deps
    echo "name=$name" > "$DISCOVERY_DIR/$pname.txt.tmp" && \
    echo "pname=$pname" >> "$DISCOVERY_DIR/$pname.txt.tmp" && \
    echo "host=$host" >> "$DISCOVERY_DIR/$pname.txt.tmp" && \
    echo "address=$address" >> "$DISCOVERY_DIR/$pname.txt.tmp" && \
    echo "port=$port" >> "$DISCOVERY_DIR/$pname.txt.tmp" && \
    echo "resource=$rp" >> "$DISCOVERY_DIR/$pname.txt.tmp" && \
    echo "service=$srvtype" >> "$DISCOVERY_DIR/$pname.txt.tmp" && \
    echo "domain=$domain" >> "$DISCOVERY_DIR/$pname.txt.tmp" && \
    mv "$DISCOVERY_DIR/$pname.txt.tmp" "$DISCOVERY_DIR/$pname.txt"
    # Also write a lightweight JSON representation for integrations
    printf '{"name":"%s","pname":"%s","host":"%s","address":"%s","port":%s,"resource":"%s","service":"%s","domain":"%s","updated":"%s"}\n' \
        "$name" "$pname" "$host" "$address" "$port" "$rp" "$srvtype" "$domain" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$DISCOVERY_DIR/$pname.json" 2>/dev/null || true
    # Also refresh the aggregated index for faster UI consumption
    echo "Updated: $(date '+%F %T') - $name ($address:$port)" >> "$DISCOVERY_DIR/index.log" 2>/dev/null || true
    # Re-create consolidated index file
    (for f in $DISCOVERY_DIR/*.txt; do
        [ -f "$f" ] || continue
        grep -E '^(name|address|port|resource)=' "$f" | paste -sd ',' -
    done) > "$DISCOVERY_DIR/discovered.txt" 2>/dev/null || true
    # Build a JSON index of discovered printers
    if ls "$DISCOVERY_DIR"/*.json >/dev/null 2>&1; then
        echo "[" > "$DISCOVERY_DIR/discovered.json" 2>/dev/null || true
        first=true
        for jf in $DISCOVERY_DIR/*.json; do
            [ -f "$jf" ] || continue
            if [ "$first" = true ]; then
                cat "$jf" >> "$DISCOVERY_DIR/discovered.json"
                first=false
            else
                echo "," >> "$DISCOVERY_DIR/discovered.json"
                cat "$jf" >> "$DISCOVERY_DIR/discovered.json"
            fi
        done
        echo "]" >> "$DISCOVERY_DIR/discovered.json"
    fi
}

# No auto-add/remove functions in discovery-only mode

parse_avahi_line(){
    # Fields in avahi-browse -p (parsable):
    # ; <interface> ; <protocol> ; <name> ; <service_type> ; <domain> ; <host> ; <address> ; <port> ; <txt> ; <txt> ; ...
    local line="$1"
    local prefix
    prefix=$(echo "$line" | cut -d';' -f1 | tr -d '\r')
    if [ "$prefix" != "=" ] && [ "$prefix" != "-" ]; then
        return
    fi

    # Parse values
    # Removing leading '=' or '-'
    local data
    data=$(echo "$line" | sed 's/^[-=];//')
    IFS=';' read -r iface proto name stype domain host address port rest <<< "$data"

    # rp= in TXT is the resource path. Find it
    local rp
    rp="/ipp/print"
    # Parse rest for rp
    IFS=';' read -ra txtarr <<< "$rest"
    for item in "${txtarr[@]}"; do
        if [[ "$item" == rp=* ]]; then
            rp="/${item#rp=/}"
            # Ensure leading slash
            rp="${rp#/}"
            rp="/$rp"
            break
        fi
    done

    # Trim quotes from name and host
    name=$(echo "$name" | sed 's/^"//;s/"$//')
    host=$(echo "$host" | sed 's/^"//;s/"$//')

    if [ "$prefix" = "=" ]; then
        # Added/resolved
        LOG "Found printer: name=$name address=$address port=$port rp=$rp host=$host"
        update_discovery "$name" "$address" "$port" "$rp" "$host" "$stype" "$domain"
    else
        # Removed
        LOG "Service removed: name=$name address=$address port=$port rp=$rp host=$host"
        pname=$(sanitize_name "$name")
        rm -f "$DISCOVERY_DIR/$pname.json" 2>/dev/null || true
    fi
}

LOG "Starting auto-discovery: avahi-browse to detect _ipp._tcp printers"
while true; do
    # Use --parsable and -r (resolve) to get resolved services. -t to allow the browse to stop
    # after the initial run so the container can re-run this and detect new/removed devices periodically.
    avahi-browse --parsable -r -t _ipp._tcp 2>/dev/null | while IFS= read -r line; do
        # Skip comments or empty
        [ -z "$line" ] && continue
        parse_avahi_line "$line"
    done

    # Wait a bit before scanning again to avoid CPU and network storms
    sleep 30
done

