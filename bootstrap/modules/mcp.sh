#!/bin/bash
# Description: MCP server Docker images
# Dependencies: docker

log "Pulling MCP Docker images..."

docker pull mcp/filesystem
docker pull mcp/git
docker pull mcp/fetch
docker pull mcp/memory
docker pull mcp/playwright
docker pull mcp/sequentialthinking
docker pull mcp/time

# Deploy MCP config if available
if [[ -f "$REPO_DIR/mcp/mcp_config.json" ]]; then
	log "Deploying MCP config..."
	mkdir -p /atn/.gemini
	cp "$REPO_DIR/mcp/mcp_config.json" /atn/.gemini/mcp_config.json
fi

log "MCP images pulled"
