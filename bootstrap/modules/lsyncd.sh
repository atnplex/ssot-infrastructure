#!/bin/bash
# Description: lsyncd file synchronization daemon
# Dependencies: base

log "Installing lsyncd..."

sudo apt-get install -y lsyncd rsync

# Create directories
sudo mkdir -p /etc/lsyncd /var/log/lsyncd

# Deploy lsyncd config if available
if [[ -f "$REPO_DIR/lsyncd/lsyncd.conf.lua" ]]; then
	log "Deploying lsyncd config from repo..."
	sudo cp "$REPO_DIR/lsyncd/lsyncd.conf.lua" /etc/lsyncd/lsyncd.conf.lua
fi

# Enable lsyncd (don't start - needs SSH keys configured)
sudo systemctl enable lsyncd

log "lsyncd installed - configure SSH keys before starting"
