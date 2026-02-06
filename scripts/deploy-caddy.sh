#!/bin/bash
# /atn/github/infrastructure/scripts/deploy-caddy.sh
# Deploy Caddyfile from git repo to /etc/caddy and reload
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "=== Caddy Deploy Script ==="
echo "Repo: $REPO_DIR"

# Pull latest from git
cd "$REPO_DIR"
echo "Pulling latest changes..."
git pull --ff-only || {
	echo "Git pull failed - check for conflicts"
	exit 1
}

# Validate before deploying
echo "Validating Caddyfile..."
if ! sudo caddy validate --config "$REPO_DIR/caddy/Caddyfile"; then
	echo "❌ Caddyfile validation failed!"
	exit 1
fi

# Backup current
echo "Backing up current Caddyfile..."
sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup.$(date +%Y%m%d%H%M%S)

# Deploy
echo "Deploying new Caddyfile..."
sudo cp "$REPO_DIR/caddy/Caddyfile" /etc/caddy/Caddyfile

# Reload
echo "Reloading Caddy..."
sudo systemctl reload caddy

echo "✅ Caddy deployed successfully!"
