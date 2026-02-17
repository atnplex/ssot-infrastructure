#!/bin/bash
# 04-core-stack.sh - Deploy core infrastructure services
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/00-detect-os.sh"

COMPOSE_DIR="$HOMELAB_ROOT/docker-compose"

echo "Deploying core infrastructure stack..."

# Check if docker is available
if ! command -v docker &>/dev/null; then
	echo "ERROR: docker not installed. Run 01-install-deps.sh first."
	exit 1
fi

# Load secrets from BWS if available
load_secrets() {
	local AGE_KEY="$HOMELAB_ROOT/secrets/age.key"
	local BWS_TOKEN_AGE="$HOMELAB_ROOT/secrets/bws_token.age"

	if [[ -f "$BWS_TOKEN_AGE" ]] && [[ -f "$AGE_KEY" ]]; then
		export BWS_ACCESS_TOKEN=$(age -d -i "$AGE_KEY" <"$BWS_TOKEN_AGE")
		echo "✓ BWS token loaded from encrypted cache"

		# Fetch and export secrets
		export CF_TUNNEL_TOKEN=$(bws secret list 2>/dev/null | jq -r '.[] | select(.key == "CF_TUNNEL_TOKEN") | .value' || echo "")
		export TRAEFIK_CF_TOKEN=$(bws secret list 2>/dev/null | jq -r '.[] | select(.key == "CLOUDFLARE_API_TOKEN") | .value' || echo "")
	else
		echo "⚠ BWS secrets not configured - some services may not start correctly"
	fi
}

# Deploy core services
deploy_core() {
	if [[ -f "$COMPOSE_DIR/core.yml" ]]; then
		echo "→ Deploying core.yml..."
		docker compose -f "$COMPOSE_DIR/core.yml" up -d --pull always
		echo "✓ Core stack deployed"
	else
		echo "⚠ core.yml not found at $COMPOSE_DIR/core.yml"
		echo "  Creating template..."
		create_core_template
	fi
}

create_core_template() {
	cat >"$COMPOSE_DIR/core.yml" <<'EOF'
# Core Infrastructure Stack
# Deployed on ALL servers for redundancy

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ${HOMELAB_ROOT}/config/traefik:/etc/traefik
      - ${HOMELAB_ROOT}/data/traefik:/data
    environment:
      - CF_API_TOKEN=${TRAEFIK_CF_TOKEN:-}
    networks:
      - homelab
    labels:
      - "traefik.enable=true"

  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    restart: unless-stopped
    ports:
      - "53:53/tcp"
      - "53:53/udp"
    volumes:
      - ${HOMELAB_ROOT}/config/pihole:/etc/pihole
      - ${HOMELAB_ROOT}/data/pihole/dnsmasq.d:/etc/dnsmasq.d
    environment:
      - TZ=America/Los_Angeles
    networks:
      - homelab

  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel run
    environment:
      - TUNNEL_TOKEN=${CF_TUNNEL_TOKEN:-}
    networks:
      - homelab

  tailscale:
    image: tailscale/tailscale:latest
    container_name: tailscale
    restart: unless-stopped
    privileged: true
    volumes:
      - ${HOMELAB_ROOT}/data/tailscale:/var/lib/tailscale
      - /dev/net/tun:/dev/net/tun
    environment:
      - TS_AUTHKEY=${TAILSCALE_AUTHKEY:-}
      - TS_STATE_DIR=/var/lib/tailscale
    networks:
      - homelab

networks:
  homelab:
    name: homelab
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.0.0/16
EOF
	echo "✓ Created core.yml template at $COMPOSE_DIR/core.yml"
}

# Health check
health_check() {
	echo "→ Running health checks..."

	# Check each core service
	for svc in traefik pihole cloudflared tailscale; do
		if docker ps --format '{{.Names}}' | grep -q "^${svc}$"; then
			echo "✓ $svc is running"
		else
			echo "⚠ $svc is not running"
		fi
	done
}

# Main execution
load_secrets
deploy_core
health_check

echo "=== Core stack deployment complete ==="
