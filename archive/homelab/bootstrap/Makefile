# Homelab Bootstrap Makefile
# Idempotent setup for all servers

SHELL := /bin/bash
HOMELAB_ROOT ?= /opt/homelab
HOMELAB_USER ?= homelab
HOMELAB_UID ?= 1000
HOMELAB_GID ?= 1000

.PHONY: all bootstrap deps user config core ai apps clean help

# Default target
all: bootstrap

# Full bootstrap sequence
bootstrap: deps user config core
	@echo "=== Full bootstrap complete ==="

# Install dependencies
deps:
	@./bootstrap/01-install-deps.sh

# Create homelab user
user:
	@HOMELAB_ROOT=$(HOMELAB_ROOT) HOMELAB_USER=$(HOMELAB_USER) \
		HOMELAB_UID=$(HOMELAB_UID) HOMELAB_GID=$(HOMELAB_GID) \
		./bootstrap/02-create-user.sh

# Sync config from GitHub SSOT
config:
	@HOMELAB_ROOT=$(HOMELAB_ROOT) ./bootstrap/03-clone-config.sh

# Deploy core infrastructure (Traefik, PiHole, Cloudflared, Tailscale)
core:
	@HOMELAB_ROOT=$(HOMELAB_ROOT) ./bootstrap/04-core-stack.sh

# Deploy AI stack (Antigravity, Ollama, Chatbot)
ai:
	@HOMELAB_ROOT=$(HOMELAB_ROOT) docker compose -f $(HOMELAB_ROOT)/docker-compose/ai.yml up -d

# Deploy application stack
apps:
	@HOMELAB_ROOT=$(HOMELAB_ROOT) docker compose -f $(HOMELAB_ROOT)/docker-compose/apps.yml up -d

# Health check all services
health:
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Sync from GitHub (pull latest)
sync:
	@git -C $(HOMELAB_ROOT)/config pull origin main --ff-only
	@echo "Config synced from GitHub SSOT"

# Restart all stacks
restart:
	@docker compose -f $(HOMELAB_ROOT)/docker-compose/core.yml restart
	@docker compose -f $(HOMELAB_ROOT)/docker-compose/ai.yml restart 2>/dev/null || true
	@docker compose -f $(HOMELAB_ROOT)/docker-compose/apps.yml restart 2>/dev/null || true

# Clean up (dangerous!)
clean:
	@echo "This will remove all containers and data. Are you sure? [y/N]"
	@read -r confirm && [ "$$confirm" = "y" ] && \
		docker compose -f $(HOMELAB_ROOT)/docker-compose/core.yml down -v && \
		docker compose -f $(HOMELAB_ROOT)/docker-compose/ai.yml down -v 2>/dev/null || true && \
		docker compose -f $(HOMELAB_ROOT)/docker-compose/apps.yml down -v 2>/dev/null || true

# Help
help:
	@echo "Homelab Bootstrap Targets:"
	@echo "  make bootstrap  - Full setup (deps + user + config + core)"
	@echo "  make deps       - Install dependencies"
	@echo "  make user       - Create homelab user"
	@echo "  make config     - Sync config from GitHub SSOT"
	@echo "  make core       - Deploy core infrastructure"
	@echo "  make ai         - Deploy AI stack"
	@echo "  make apps       - Deploy application stack"
	@echo "  make health     - Check service health"
	@echo "  make sync       - Pull latest from GitHub"
	@echo "  make restart    - Restart all stacks"
	@echo "  make clean      - Remove all containers (dangerous!)"
