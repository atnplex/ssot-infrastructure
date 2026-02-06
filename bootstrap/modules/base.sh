#!/bin/bash
# Description: Base system packages (curl, git, jq, vim, htop)
# Dependencies: none

log "Installing base packages..."

sudo apt-get update
sudo apt-get install -y \
	curl \
	git \
	jq \
	vim \
	htop \
	tree \
	unzip \
	wget

log "Base packages installed"
