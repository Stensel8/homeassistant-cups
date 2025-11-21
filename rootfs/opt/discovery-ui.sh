#!/bin/bash
set -euo pipefail

DISCOVERY_DIR="/var/cache/cups/discovered"
INDEX_FILE="$DISCOVERY_DIR/discovered.txt"

generate_html() {
    echo "<html><head><title>CUPS Discovered Printers</title></head><body>"
    echo "<h1>Discovered Printers</h1>"
    if [ -d "$DISCOVERY_DIR" ]; then
        echo "<ul>"
        for f in $DISCOVERY_DIR/*.txt; do
            [ -f "$f" ] || continue
            name=$(grep -m1 '^name=' "$f" | cut -d'=' -f2-)
            address=$(grep -m1 '^address=' "$f" | cut -d'=' -f2-)
            port=$(grep -m1 '^port=' "$f" | cut -d'=' -f2-)
            resource=$(grep -m1 '^resource=' "$f" | cut -d'=' -f2-)
            printf "<li><strong>%s</strong> — %s:%s%s</li>\n" "${name:-Unknown}" "${address:-?}" "${port:-631}" "${resource:-/ipp/print}"
        done
        echo "</ul>"
    else
        echo "<p>No discovered printers yet.</p>"
    fi
    echo "<p>Use the CUPS Web UI to add a printer: <a href=\"https://localhost:631\">CUPS Admin</a></p>"
    echo "</body></html>"
}

echo "[DISCOVERY-UI] Starting discovery UI on port 8080..."
while true; do
    # Serve a simple HTML page on port 8080
    generate_html | socat - tcp-listen:8080,reuseaddr,fork
done

