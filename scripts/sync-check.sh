#!/bin/bash
# /atn/github/infrastructure/scripts/sync-check.sh
# Check sync status across servers
set -euo pipefail

echo "=== Infrastructure Sync Status ==="
echo "Timestamp: $(date -Iseconds)"
echo

# Check git status
echo "--- Git Status ---"
cd /atn/github/infrastructure
git fetch origin 2>/dev/null || echo "Cannot reach remote"
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main 2>/dev/null || echo "no-remote")
if [ "$LOCAL" = "$REMOTE" ]; then
	echo "✅ Git: In sync with origin/main"
else
	echo "⚠️  Git: Local differs from origin/main"
fi

# Check Caddyfile sync
echo
echo "--- Caddyfile ---"
REPO_HASH=$(md5sum /atn/github/infrastructure/caddy/Caddyfile 2>/dev/null | cut -d' ' -f1 || echo "missing")
LIVE_HASH=$(sudo md5sum /etc/caddy/Caddyfile 2>/dev/null | cut -d' ' -f1 || echo "missing")
if [ "$REPO_HASH" = "$LIVE_HASH" ]; then
	echo "✅ Caddyfile: Repo matches /etc/caddy"
else
	echo "⚠️  Caddyfile: Repo differs from /etc/caddy"
	echo "   Repo: $REPO_HASH"
	echo "   Live: $LIVE_HASH"
fi

# Check lsyncd status
echo
echo "--- lsyncd ---"
if systemctl is-active --quiet lsyncd 2>/dev/null; then
	echo "✅ lsyncd: Running"
else
	echo "⚠️  lsyncd: Not running"
fi

echo
echo "=== Done ==="
