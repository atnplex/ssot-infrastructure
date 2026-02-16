# MCP Deployment Guide

This guide defines how to deploy Model Context Protocol (MCP) servers in the `atnplex` ecosystem.

## Deployment Options

### 1. Cloud Run (Preferred for Public/Scalable)
For stateless python/node MCP servers.
-   **Repo**: `atnplex/mcp-<name>`
-   **Dockerfile**: Must expose port (e.g., 8080).
-   **Auth**: Use Google IAM or a light API Key middleware.
-   **Connection**: Agents connect via HTTPS URL.

### 2. VPS / HomeLab (Preferred for heavy/stateful)
For servers needing local hardware (GPU, Zigbee) or huge storage.
-   **Repo**: `atnplex/atn-bootstrap` (add service to compose).
-   **Network**: Exposed via Tailscale (recommended) or Cloudflared.
-   **Connection**:
    -   **Tailscale**: Agents connect via `http://<tailscale-ip>:<port>`.
    -   **SSH Tunnel**: Agents use `ssh -L` to forward port.

## Connecting Agents

### Antigravity / Claude Desktop
Update your `claude_desktop_config.json` or `mcp_config.json`:

```json
{
  "mcpServers": {
    "my-server": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "my-server-image"]
    },
    "remote-server": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sse-client", "https://my-cloud-run-url.run.app/sse"]
    }
  }
}
```

## Security
-   **Never** expose raw MCP ports to the public internet without Auth.
-   Use **Tailscale** for private mesh networking.
