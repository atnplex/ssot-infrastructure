#!/usr/bin/env bash
# bootstrap-oci.sh — Phase 6 bootstrap for OCI instances
# Usage: ./bootstrap-oci.sh <account1|account2|account3>
# Remote: curl -fsSL https://raw.githubusercontent.com/atnplex/ssot-infrastructure/main/deployment/bootstrap-oci.sh | bash -s -- account1
#
# What it does:
#   1. Installs Docker + Docker Compose
#   2. Installs Tailscale + joins tailnet
#   3. Clones ssot-infrastructure
#   4. Starts the appropriate account Compose stack

set -euo pipefail

NAMESPACE="/atn"
REPO="https://github.com/atnplex/ssot-infrastructure.git"

log() { echo "[bootstrap] $(date +%H:%M:%S) $*"; }
err() {
	echo "[bootstrap] ERROR: $*" >&2
	exit 1
}

# ── Parse arguments ──────────────────────────────────────────────────────
ACCOUNT="${1:-}"
if [[ -z "$ACCOUNT" ]]; then
	echo "Usage: $0 <account1|account2|account3>"
	echo ""
	echo "  account1 — Primary DB + workers + media-adjacent (100.67.88.109)"
	echo "  account2 — Redis hub + HA brain + dashboards (100.102.55.88)"
	echo "  account3 — Distributed workers + failover replicas"
	exit 1
fi

case "$ACCOUNT" in
account1 | account2 | account3)
	COMPOSE_DIR="deployment/$ACCOUNT"
	;;
*)
	err "Unknown account: $ACCOUNT. Use account1, account2, or account3."
	;;
esac

log "Bootstrapping $ACCOUNT → $COMPOSE_DIR"

# ── 1. Install Docker ───────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
	log "Installing Docker..."
	curl -fsSL https://get.docker.com | sh
	sudo usermod -aG docker "$USER"
	log "Docker installed: $(docker --version)"
else
	log "Docker already installed: $(docker --version)"
fi

# Ensure Docker Compose plugin
if ! docker compose version &>/dev/null; then
	log "Installing Docker Compose plugin..."
	sudo apt-get update -qq && sudo apt-get install -y docker-compose-plugin
fi

# ── 2. Install Tailscale ────────────────────────────────────────────────
if ! command -v tailscale &>/dev/null; then
	log "Installing Tailscale..."
	curl -fsSL https://tailscale.com/install.sh | sh
	log "Tailscale installed — run 'sudo tailscale up' to authenticate"
else
	log "Tailscale: $(tailscale version 2>/dev/null || echo 'installed')"
fi

# Check Tailscale status
if tailscale status &>/dev/null; then
	TS_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
	log "Tailscale connected: $TS_IP"
else
	log "⚠ Tailscale not connected — run: sudo tailscale up"
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
	git -C "$NAMESPACE/ssot-infrastructure" pull --ff-only
fi

# ── 4. Start services ───────────────────────────────────────────────────
DEPLOY_DIR="$NAMESPACE/ssot-infrastructure/$COMPOSE_DIR"

if [[ ! -d "$DEPLOY_DIR" ]]; then
	err "Compose directory not found: $DEPLOY_DIR"
fi

cd "$DEPLOY_DIR"

if [[ ! -f .env ]]; then
	if [[ -f .env.example ]]; then
		cp .env.example .env
		log "⚠ Created .env from template — POPULATE SECRETS before starting:"
		log "  vim $DEPLOY_DIR/.env"
		log "  Then run: docker compose up -d"
	else
		err "No .env or .env.example found in $DEPLOY_DIR"
	fi
else
	log "Starting services for $ACCOUNT..."
	docker compose pull
	docker compose up -d
	log "Services started. Check: docker compose ps"
fi

log "✅ Bootstrap complete for $ACCOUNT"
log "   Compose dir: $DEPLOY_DIR"
log "   Tailscale:   $(tailscale ip -4 2>/dev/null || echo 'not connected')"
log "   Next steps:  Edit .env → docker compose up -d"
