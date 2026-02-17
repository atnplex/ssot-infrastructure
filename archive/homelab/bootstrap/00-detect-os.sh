#!/bin/bash
# 00-detect-os.sh - Detect OS and set environment variables
set -euo pipefail

export HOMELAB_ROOT="${HOMELAB_ROOT:-/opt/homelab}"

# Detect OS
if [[ -f /etc/os-release ]]; then
	. /etc/os-release
	export HOMELAB_OS="$ID"
	export HOMELAB_OS_VERSION="$VERSION_ID"

	# Special detection for Unraid
	if [[ -f /boot/config/ident.cfg ]] || grep -qi "unraid" /etc/os-release 2>/dev/null; then
		export HOMELAB_OS="unraid"
		export HOMELAB_OS_VERSION=$(cat /etc/unraid-version 2>/dev/null | cut -d'"' -f2 || echo "unknown")
	fi
elif [[ "$(uname -s)" == "Darwin" ]]; then
	export HOMELAB_OS="macos"
	export HOMELAB_OS_VERSION=$(sw_vers -productVersion)
else
	export HOMELAB_OS="unknown"
	export HOMELAB_OS_VERSION="unknown"
fi

# Detect if running in WSL
if grep -qi microsoft /proc/version 2>/dev/null; then
	export HOMELAB_WSL=true
else
	export HOMELAB_WSL=false
fi

# Set package manager
case "$HOMELAB_OS" in
debian | ubuntu)
	export HOMELAB_PKG_MGR="apt"
	export HOMELAB_PKG_INSTALL="apt-get install -y"
	;;
alpine)
	export HOMELAB_PKG_MGR="apk"
	export HOMELAB_PKG_INSTALL="apk add"
	;;
unraid)
	export HOMELAB_PKG_MGR="nerdpack"
	export HOMELAB_PKG_INSTALL="nerdctl install"
	;;
*)
	export HOMELAB_PKG_MGR="unknown"
	export HOMELAB_PKG_INSTALL="echo 'Unknown package manager:'"
	;;
esac

echo "=== Homelab Environment Detected ==="
echo "OS: $HOMELAB_OS"
echo "Version: $HOMELAB_OS_VERSION"
echo "WSL: $HOMELAB_WSL"
echo "Package Manager: $HOMELAB_PKG_MGR"
echo "Root: $HOMELAB_ROOT"
echo "===================================="
