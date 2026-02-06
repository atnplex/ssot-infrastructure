#!/bin/bash
# Description: Caddy web server with Cloudflare DNS plugin
# Dependencies: base

log "Installing Caddy with Cloudflare DNS..."

# Add Caddy repository
if ! command -v caddy &>/dev/null; then
	sudo apt-get install -y debian-keyring debian-archive-keyring apt-transport-https
	curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
	curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
	sudo apt-get update
	sudo apt-get install -y caddy
	log "Caddy installed"
else
	log "Caddy already installed"
fi

# Deploy Caddyfile from repo if available
if [[ -f "$REPO_DIR/caddy/Caddyfile" ]]; then
	log "Deploying Caddyfile from repo..."
	sudo cp "$REPO_DIR/caddy/Caddyfile" /etc/caddy/Caddyfile
fi

# Enable and start Caddy
sudo systemctl enable caddy
sudo systemctl start caddy

log "Caddy setup complete"
