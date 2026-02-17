#!/usr/bin/env bash
# bootstrap-oci.sh — One-liner bootstrap for OCI instances
# Usage: curl -fsSL https://raw.githubusercontent.com/atnplex/ssot-infrastructure/main/deployment/bootstrap-oci.sh | bash
# What it does:
#   1. Installs Docker
#   2. Installs Tailscale + joins tailnet
#   3. Clones ssot-infrastructure
#   4. Starts the appropriate Compose stack

set -euo pipefail

NAMESPACE="/atn"
REPO="https://github.com/atnplex/ssot-infrastructure.git"

log() { echo "[bootstrap] $*"; }

# ── Detect role from hostname ────────────────────────────────────────────
HOSTNAME=$(hostname)
case "$HOSTNAME" in
*perf*1* | *primary*)
	ROLE="primary"
	COMPOSE_DIR="deployment/utility"
	;;
*perf*2* | *backup*)
	ROLE="backup"
	COMPOSE_DIR="deployment/backup"
	;;
*)
	ROLE="utility"
	COMPOSE_DIR=""
	;;
esac

log "Detected role: $ROLE (hostname: $HOSTNAME)"

# ── 1. Install Docker ───────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
	log "Installing Docker..."
	curl -fsSL https://get.docker.com | sh
	sudo usermod -aG docker "$USER"
	log "Docker installed"
else
	log "Docker already installed: $(docker --version)"
fi

# ── 2. Install Tailscale ────────────────────────────────────────────────
if ! command -v tailscale &>/dev/null; then
	log "Installing Tailscale..."
	curl -fsSL https://tailscale.com/install.sh | sh
	log "Tailscale installed — run 'sudo tailscale up' to authenticate"
else
	log "Tailscale already installed"
fi

# ── 3. Clone infrastructure repo ────────────────────────────────────────
if [[ ! -d "$NAMESPACE" ]]; then
	sudo mkdir -p "$NAMESPACE"
	sudo chown "$USER:$USER" "$NAMESPACE"
fi

if [[ ! -d "$NAMESPACE/ssot-infrastructure" ]]; then
	log "Cloning ssot-infrastructure..."
	git clone "$REPO" "$NAMESPACE/ssot-infrastructure"
else
	log "Updating ssot-infrastructure..."
	git -C "$NAMESPACE/ssot-infrastructure" pull
fi

# ── 4. Start services ───────────────────────────────────────────────────
if [[ -n "$COMPOSE_DIR" ]]; then
	cd "$NAMESPACE/ssot-infrastructure/$COMPOSE_DIR"

	if [[ ! -f .env ]]; then
		log "Creating .env from template — POPULATE SECRETS BEFORE STARTING"
		cp .env.example .env
		log "⚠ Edit .env with actual values, then run: docker compose up -d"
	else
		log "Starting services..."
		docker compose pull
		docker compose up -d
		log "Services started. Check: docker compose ps"
	fi
else
	log "No compose stack for role=$ROLE. Bootstrap complete."
fi

log "Done. Node ready for role: $ROLE"
