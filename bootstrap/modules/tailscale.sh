#!/bin/bash
# Description: Tailscale VPN installation
# Dependencies: base

log "Installing Tailscale..."

if ! command -v tailscale &>/dev/null; then
	curl -fsSL https://tailscale.com/install.sh | sh
	log "Tailscale installed - run 'sudo tailscale up' to authenticate"
else
	log "Tailscale already installed"
fi

# Enable route acceptance
sudo tailscale set --accept-routes

log "Tailscale setup complete"
