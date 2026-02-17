#!/bin/bash
# 00-detect-env.sh - Universal environment detection for homelab bootstrap
# Per R75, R76, R78: Derive values, don't hardcode
set -euo pipefail

#===============================================================================
# ENVIRONMENT DETECTION
#===============================================================================
detect_os() {
	if [[ -f /etc/unraid-version ]]; then
		echo "unraid"
	elif [[ -f /proc/sys/fs/binfmt_misc/WSLInterop ]]; then
		echo "wsl"
	elif [[ -f /etc/debian_version ]]; then
		echo "debian"
	elif [[ -f /etc/os-release ]]; then
		# shellcheck disable=SC1091
		. /etc/os-release
		echo "$ID"
	else
		echo "unknown"
	fi
}

detect_init_system() {
	if command -v systemctl &>/dev/null && systemctl --version &>/dev/null 2>&1; then
		echo "systemd"
	elif [[ -f /etc/rc.local ]] || [[ -f /boot/config/go ]]; then
		echo "rclocal"
	else
		echo "unknown"
	fi
}

detect_docker_compose() {
	if docker compose version &>/dev/null 2>&1; then
		echo "v2" # Plugin style
	elif command -v docker-compose &>/dev/null; then
		echo "v1" # Standalone
	else
		echo "none"
	fi
}

#===============================================================================
# UID/GID DETECTION (Per R76)
#===============================================================================
detect_uid_gid() {
	local os
	os=$(detect_os)
	if [[ "$os" == "unraid" ]]; then
		echo "99:100" # nobody:users (Unraid standard)
	else
		echo "1000:1000" # Standard Linux
	fi
}

#===============================================================================
# PATH DERIVATION (Per R75)
#===============================================================================
export NAMESPACE="${NAMESPACE:-atn}"
export NAMESPACE_ROOT="/${NAMESPACE}"

detect_homelab_root() {
	local os
	os=$(detect_os)
	case "$os" in
	unraid)
		echo "/boot/config/homelab"
		;;
	wsl)
		echo "${HOME}/homelab"
		;;
	*)
		echo "/opt/homelab"
		;;
	esac
}

#===============================================================================
# COMPOSE COMMAND DERIVATION
#===============================================================================
get_compose_cmd() {
	local version
	version=$(detect_docker_compose)
	case "$version" in
	v2) echo "docker compose" ;;
	v1) echo "docker-compose" ;;
	*) echo "echo 'ERROR: No docker compose found'" ;;
	esac
}

#===============================================================================
# EXPORT ALL DERIVED VALUES
#===============================================================================
export HOMELAB_ROOT
export HOMELAB_OS
export HOMELAB_INIT
export HOMELAB_COMPOSE_VERSION
export HOMELAB_COMPOSE_CMD
export HOMELAB_UID
export HOMELAB_GID

HOMELAB_ROOT="$(detect_homelab_root)"
HOMELAB_OS="$(detect_os)"
HOMELAB_INIT="$(detect_init_system)"
HOMELAB_COMPOSE_VERSION="$(detect_docker_compose)"
HOMELAB_COMPOSE_CMD="$(get_compose_cmd)"

IFS=':' read -r HOMELAB_UID HOMELAB_GID <<<"$(detect_uid_gid)"
export HOMELAB_UID HOMELAB_GID

#===============================================================================
# DISPLAY (when sourced with --info flag)
#===============================================================================
if [[ "${1:-}" == "--info" ]]; then
	echo "=== Environment Detection ==="
	echo "OS:          $HOMELAB_OS"
	echo "Init:        $HOMELAB_INIT"
	echo "Compose:     $HOMELAB_COMPOSE_VERSION ($HOMELAB_COMPOSE_CMD)"
	echo "UID:GID:     $HOMELAB_UID:$HOMELAB_GID"
	echo "Root:        $HOMELAB_ROOT"
	echo "Namespace:   $NAMESPACE_ROOT"
fi
