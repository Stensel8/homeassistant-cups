#!/usr/bin/env bash

# Check if cupsd process is running
if ! pgrep -x cupsd >/dev/null; then
    echo "CUPS daemon not running"
    exit 1
fi

# Check if CUPS HTTP interface responds
if ! curl -k -s --max-time 5 https://localhost:631/ >/dev/null 2>&1; then
    echo "CUPS HTTP interface not responding"
    exit 1
fi

# Check if CUPS socket exists
if [[ ! -S /var/run/cups/cups.sock ]]; then
    echo "CUPS socket not found"
    exit 1
fi

# Everything OK
exit 0
