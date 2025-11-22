#!/usr/bin/env bash
set -e

info() { echo "[cups-reload] $*"; }
error() { echo "[cups-reload] ERROR: $*" >&2; }

info "Reloading CUPS configuration..."

# Check if cupsd is running
if ! pgrep -x cupsd >/dev/null; then
    error "CUPS is not running, cannot reload"
    exit 1
fi

# Validate configuration before reload
if ! cupsd -t 2>/tmp/cupsd-test.log; then
    error "Configuration is invalid, skipping reload:"
    cat /tmp/cupsd-test.log
    exit 1
fi

# Send HUP signal (reload config)
CUPSD_PID=$(pgrep -x cupsd)
info "Sending SIGHUP to cupsd (PID: $CUPSD_PID)..."
kill -HUP "$CUPSD_PID"

# Wait a bit
sleep 2

# Check if CUPS is still running
if pgrep -x cupsd >/dev/null; then
    info "CUPS reloaded successfully"
else
    error "CUPS stopped after reload attempt!"
    exit 1
fi
