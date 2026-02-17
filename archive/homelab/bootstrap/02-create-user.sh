#!/bin/bash
# 02-create-user.sh - Create homelab user with consistent UID/GID
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-detect-os.sh"

HOMELAB_UID="${HOMELAB_UID:-1000}"
HOMELAB_GID="${HOMELAB_GID:-1000}"
HOMELAB_USER="${HOMELAB_USER:-homelab}"

echo "Creating homelab user (UID: $HOMELAB_UID, GID: $HOMELAB_GID)..."

# Check if group exists
if getent group "$HOMELAB_GID" &>/dev/null; then
	existing_group=$(getent group "$HOMELAB_GID" | cut -d: -f1)
	echo "✓ Group with GID $HOMELAB_GID exists ($existing_group)"
else
	echo "→ Creating group $HOMELAB_USER with GID $HOMELAB_GID"
	sudo groupadd -g "$HOMELAB_GID" "$HOMELAB_USER"
fi

# Check if user exists
if id "$HOMELAB_USER" &>/dev/null; then
	echo "✓ User $HOMELAB_USER already exists"
else
	echo "→ Creating user $HOMELAB_USER with UID $HOMELAB_UID"
	sudo useradd -u "$HOMELAB_UID" -g "$HOMELAB_GID" -d "$HOMELAB_ROOT" -m "$HOMELAB_USER" -s /bin/bash
fi

# Ensure user is in docker group
if getent group docker &>/dev/null; then
	sudo usermod -aG docker "$HOMELAB_USER"
	echo "✓ Added $HOMELAB_USER to docker group"
fi

# Create homelab root directory if it doesn't exist
if [[ ! -d "$HOMELAB_ROOT" ]]; then
	echo "→ Creating $HOMELAB_ROOT"
	sudo mkdir -p "$HOMELAB_ROOT"
fi

# Set ownership
sudo chown -R "$HOMELAB_UID:$HOMELAB_GID" "$HOMELAB_ROOT"
echo "✓ Set ownership of $HOMELAB_ROOT to $HOMELAB_USER"

# Set directory permissions
sudo find "$HOMELAB_ROOT" -type d -exec chmod 755 {} \;
echo "✓ Set directory permissions"

echo "=== User setup complete ==="
