#!/bin/bash
# 03-clone-config.sh - Clone or pull config from GitHub SSOT
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-detect-os.sh"

HOMELAB_REPO="${HOMELAB_REPO:-https://github.com/atnplex/homelab.git}"
HOMELAB_BRANCH="${HOMELAB_BRANCH:-main}"
CONFIG_DIR="$HOMELAB_ROOT/config"

echo "Syncing configuration from GitHub SSOT..."

# Check if git is available
if ! command -v git &>/dev/null; then
	echo "ERROR: git not installed. Run 01-install-deps.sh first."
	exit 1
fi

# Clone or pull
if [[ -d "$CONFIG_DIR/.git" ]]; then
	echo "→ Pulling latest config from $HOMELAB_BRANCH..."
	git -C "$CONFIG_DIR" fetch origin
	git -C "$CONFIG_DIR" reset --hard "origin/$HOMELAB_BRANCH"
	echo "✓ Config updated"
else
	echo "→ Cloning config from $HOMELAB_REPO..."

	# Remove existing config if it exists but isn't a git repo
	if [[ -d "$CONFIG_DIR" ]]; then
		echo "  Backing up existing config..."
		sudo mv "$CONFIG_DIR" "${CONFIG_DIR}.backup.$(date +%s)"
	fi

	sudo -u "${HOMELAB_USER:-homelab}" git clone --branch "$HOMELAB_BRANCH" "$HOMELAB_REPO" "$CONFIG_DIR"
	echo "✓ Config cloned"
fi

# Create required directories if they don't exist
for dir in data logs secrets; do
	if [[ ! -d "$HOMELAB_ROOT/$dir" ]]; then
		sudo -u "${HOMELAB_USER:-homelab}" mkdir -p "$HOMELAB_ROOT/$dir"
		echo "✓ Created $HOMELAB_ROOT/$dir"
	fi
done

# Set permissions on secrets directory
sudo chmod 700 "$HOMELAB_ROOT/secrets"
echo "✓ Secured secrets directory"

echo "=== Config sync complete ==="
