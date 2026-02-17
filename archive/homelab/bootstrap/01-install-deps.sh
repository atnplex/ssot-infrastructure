#!/bin/bash
# 01-install-deps.sh - Install dependencies based on detected OS
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-detect-os.sh"

DEPS="curl wget git jq age docker docker-compose"

echo "Installing dependencies for $HOMELAB_OS..."

install_common() {
	# Check if already installed
	for dep in $DEPS; do
		if command -v "$dep" &>/dev/null; then
			echo "✓ $dep already installed"
		else
			echo "→ Installing $dep..."
			case "$HOMELAB_OS" in
			debian | ubuntu)
				sudo apt-get update -qq
				sudo apt-get install -y "$dep" 2>/dev/null || true
				;;
			unraid)
				# Unraid uses NerdPack for supplementary packages
				echo "Install $dep via NerdPack or Community Apps"
				;;
			esac
		fi
	done
}

install_docker() {
	if command -v docker &>/dev/null; then
		echo "✓ Docker already installed"
		return 0
	fi

	case "$HOMELAB_OS" in
	debian | ubuntu)
		curl -fsSL https://get.docker.com | sudo sh
		sudo usermod -aG docker "${USER:-root}"
		;;
	unraid)
		echo "Docker is built-in on Unraid"
		;;
	esac
}

install_age() {
	if command -v age &>/dev/null; then
		echo "✓ age already installed"
		return 0
	fi

	case "$HOMELAB_OS" in
	debian | ubuntu)
		sudo apt-get install -y age 2>/dev/null || {
			# Fallback: install from binary
			AGE_VERSION="1.1.1"
			curl -sSL "https://github.com/FiloSottile/age/releases/download/v${AGE_VERSION}/age-v${AGE_VERSION}-linux-amd64.tar.gz" |
				sudo tar -xz -C /usr/local/bin --strip-components=1 age/age age/age-keygen
		}
		;;
	unraid)
		# Install via NerdPack
		echo "Install age via NerdPack community plugin"
		;;
	esac
}

install_bws() {
	if command -v bws &>/dev/null; then
		echo "✓ bws (Bitwarden Secrets CLI) already installed"
		return 0
	fi

	echo "→ Installing Bitwarden Secrets CLI..."
	curl -sSL https://github.com/bitwarden/sdk/releases/latest/download/bws-x86_64-unknown-linux-gnu.zip -o /tmp/bws.zip
	unzip -o /tmp/bws.zip -d /tmp/
	sudo mv /tmp/bws /usr/local/bin/
	sudo chmod +x /usr/local/bin/bws
	rm -f /tmp/bws.zip
}

# Run installations
install_docker
install_age
install_bws
install_common

echo "=== Dependencies installation complete ==="
