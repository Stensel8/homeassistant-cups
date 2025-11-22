#!/bin/bash
set -euo pipefail

LOG() { echo "[CUPS-PRINTER-MONITOR] $(date '+%F %T') - $*"; }

CACHE_DIR="/var/cache/cups"
mkdir -p "$CACHE_DIR"
SEEN_FILE="$CACHE_DIR/seen-printers.txt"
touch "$SEEN_FILE"
PRINTER_DIR="$CACHE_DIR/printers"
mkdir -p "$PRINTER_DIR"

poll_interval=10

get_printers(){
    # Output printer names via lpstat -p
    lpstat -p 2>/dev/null | awk '/^printer/ {print $2}' || true
}

while true; do
    current=()
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        current+=("$line")
        if ! grep -q "^$line$" "$SEEN_FILE" 2>/dev/null; then
            LOG "Printer added: name=$line"
            echo "$line" >> "$SEEN_FILE"
            # Create a minimal JSON entry for the printer for external consumers
            printf '{"name":"%s","detected":"%s"}\n' "$line" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$PRINTER_DIR/${line}.json" 2>/dev/null || true
        fi
    done < <(get_printers)

    if [ -f "$SEEN_FILE" ]; then
        while IFS= read -r seen; do
            [ -z "$seen" ] && continue
            if ! printf '%s\n' "${current[@]}" | grep -xq "$seen"; then
                LOG "Printer removed: name=$seen"
                grep -v "^$seen$" "$SEEN_FILE" > "$SEEN_FILE.tmp" && mv "$SEEN_FILE.tmp" "$SEEN_FILE" || true
                rm -f "$PRINTER_DIR/${seen}.json" 2>/dev/null || true
            fi
        done < "$SEEN_FILE"
    fi

    sleep "$poll_interval"
done
