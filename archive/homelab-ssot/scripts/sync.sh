#!/usr/bin/env bash
# SSOT Sync Script for Linux/macOS
# Run this to pull latest state from GitHub
# Usage: ./sync.sh
# For continuous sync: Add to crontab: */1 * * * * /path/to/sync.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
LOG_FILE="$REPO_DIR/logs/sync.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

cd "$REPO_DIR"

result=$(git pull --ff-only origin main 2>&1) || {
    log "ERROR: $result"
    echo "[SSOT] Sync failed: $result" >&2
    exit 1
}

if [[ "$result" != *"Already up to date"* ]]; then
    log "Synced: $result"
    echo "[SSOT] Synced successfully"
fi
