#!/bin/bash
# Description: Docker and Docker Compose installation
# Dependencies: base

log "Installing Docker..."

# Install Docker
if ! command -v docker &>/dev/null; then
	curl -fsSL https://get.docker.com | sudo sh
	sudo usermod -aG docker $USER
	log "Docker installed - you may need to log out and back in"
else
	log "Docker already installed"
fi

# Ensure Docker service is running
sudo systemctl enable docker
sudo systemctl start docker

# Create default bridge network
docker network create atn_bridge 2>/dev/null || log "atn_bridge network already exists"

log "Docker setup complete"
