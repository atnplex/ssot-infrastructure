#!/bin/bash
# /atn/github/infrastructure/bootstrap/setup.sh
# Modular server bootstrap script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() {
	echo -e "${RED}[ERROR]${NC} $1"
	exit 1
}

# Show usage
usage() {
	cat <<EOF
Infrastructure Bootstrap Script

Usage: $0 [options] [modules...]

Options:
    -h, --help      Show this help message
    -l, --list      List available modules
    -a, --all       Install all modules
    -n, --dry-run   Show what would be installed

Modules:
    base        Base system packages (curl, git, jq)
    docker      Docker and Docker Compose
    tailscale   Tailscale VPN
    caddy       Caddy web server
    lsyncd      lsyncd file sync
    mcp         MCP server Docker images
    antigravity Antigravity Manager

Examples:
    $0 base docker tailscale  # Install specific modules
    $0 --all                  # Install everything
    $0 --list                 # Show available modules
EOF
}

# List available modules
list_modules() {
	log "Available modules:"
	for module in "$SCRIPT_DIR/modules"/*.sh; do
		if [[ -f "$module" ]]; then
			name=$(basename "$module" .sh)
			desc=$(grep -m1 '^# Description:' "$module" | sed 's/# Description: //' || echo "No description")
			printf "  %-15s %s\n" "$name" "$desc"
		fi
	done
}

# Run a module
run_module() {
	local module="$1"
	local module_path="$SCRIPT_DIR/modules/${module}.sh"

	if [[ ! -f "$module_path" ]]; then
		warn "Module not found: $module"
		return 1
	fi

	log "Running module: $module"
	source "$module_path"
}

# Main
main() {
	local dry_run=false
	local modules=()

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-h | --help)
			usage
			exit 0
			;;
		-l | --list)
			list_modules
			exit 0
			;;
		-a | --all)
			for module in "$SCRIPT_DIR/modules"/*.sh; do
				modules+=("$(basename "$module" .sh)")
			done
			shift
			;;
		-n | --dry-run)
			dry_run=true
			shift
			;;
		*)
			modules+=("$1")
			shift
			;;
		esac
	done

	if [[ ${#modules[@]} -eq 0 ]]; then
		usage
		exit 1
	fi

	log "Infrastructure Bootstrap"
	log "========================"
	log "Modules to install: ${modules[*]}"

	if $dry_run; then
		log "Dry run - no changes will be made"
		exit 0
	fi

	for module in "${modules[@]}"; do
		run_module "$module"
	done

	log "Bootstrap complete!"
}

main "$@"
