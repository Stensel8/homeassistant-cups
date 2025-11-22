#!/bin/bash
set -euo pipefail

LOG() { echo "[CUPS-JOB-MONITOR] $(date '+%F %T') - $*"; }

CACHE_DIR="/var/cache/cups"
mkdir -p "$CACHE_DIR"
SEEN_FILE="$CACHE_DIR/seen-jobs.txt"
touch "$SEEN_FILE"
JOB_DIR="$CACHE_DIR/jobs"
mkdir -p "$JOB_DIR"

poll_interval=3

get_active_jobs(){
    lpstat -W not-completed -o 2>/dev/null || true
}

parse_job_line(){
    echo "$1" | awk '{job=$1; user=$2; sub(/^[^ ]+ [^ ]+ [^ ]+ [^ ]+ /, ""); title=$0; print job"|"user"|"title"}'
}

while true; do
    active=$(get_active_jobs)
    current_ids=()
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        jobid=$(echo "$line" | awk '{print $1}')
        current_ids+=("$jobid")
        if ! grep -q "^$jobid$" "$SEEN_FILE" 2>/dev/null; then
            entry=$(parse_job_line "$line")
            user=$(echo "$entry" | cut -d'|' -f2)
            title=$(echo "$entry" | cut -d'|' -f3)
            LOG "Job added: id=$jobid user=$user title=$title"
            echo "$jobid" >> "$SEEN_FILE"
            # Write a job JSON record for integration/consumption
            printf '{"job":"%s","user":"%s","title":"%s","when":"%s"}\n' \
                "$jobid" "$user" "$title" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$JOB_DIR/${jobid}.json" 2>/dev/null || true
        fi
    done <<< "$active"

    # Check for completed jobs
    if [ -f "$SEEN_FILE" ]; then
        while IFS= read -r seen; do
            [ -z "$seen" ] && continue
            if ! printf '%s\n' "${current_ids[@]}" | grep -xq "$seen"; then
                LOG "Job completed/removed: id=$seen"
                grep -v "^$seen$" "$SEEN_FILE" > "$SEEN_FILE.tmp" && mv "$SEEN_FILE.tmp" "$SEEN_FILE" || true
                rm -f "$JOB_DIR/${seen}.json" 2>/dev/null || true
            fi
        done < "$SEEN_FILE"
    fi

    sleep "$poll_interval"
done
