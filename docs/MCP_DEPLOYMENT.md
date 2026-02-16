# MCP Deployment Guide

This guide defines strict standards for deploying Model Context Protocol (MCP) servers in the `atnplex` ecosystem.

## 1. Decision Matrix

| Requirement | Recommended Target | Transport |
| :--- | :--- | :--- |
| **Stateless** (API wrapper, calculation, logic) | **Google Cloud Run** | Ref: SSE / HTTPS |
| **Stateful** (Database, File System, Hardware) | **VPS / HomeLab** | Ref: Stdio (via SSH) or SSE (Tailscale) |
| **Local Dev** (Testing) | **Local Docker** | Ref: Stdio |

---

## 2. Option A: Cloud Run (Stateless)

Use for lightweight servers.

### 2.1 Standard Dockerfile
All MCP servers must expose a port (default 8080) and run an SSE-compatible server (e.g., using `mcp-python-sdk`).

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
# Must use an SSE adapter (e.g. starlette/fastapi)
CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8080"]
```

### 2.2 Deployment
Deploy via `infrastructure` scripts or manually:

```bash
gcloud run deploy mcp-myserver \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated # ONLY for public data. Use Auth for private.
```

### 2.3 Client Config (Claude Desktop)
For public or simple auth servers:

```json
"mcpServers": {
  "my-cloud-mcp": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-sse-client", "https://mcp-myserver-xyz.a.run.app/sse"]
  }
}
```

---

## 3. Option B: VPS / HomeLab (Stateful)

Use for heavy workloads or private networks.

### 3.1 Docker Compose (Standard atn-bootstrap)
Add to your `docker-compose.yml` in `atn-bootstrap`:

```yaml
services:
  mcp-filesystem:
    image: mcp/filesystem:latest
    environment:
      - PERMITTED_DIRS=/data
    volumes:
      - /mnt/raid:/data
    network_mode: service:tailscale # If using Tailscale sidecar
```

### 3.2 Connectivity Methods

#### Method A: SSH Tunneling (Robust)
Connects "stdio" over SSH. Requires SSH access to the host.

1.  **Config**:
    ```json
    "mcpServers": {
      "remote-fs": {
        "command": "ssh",
        "args": ["user@100.x.y.z", "docker", "run", "-i", "--rm", "-v", "/mnt:/data", "mcp/filesystem", "/data"]
      }
    }
    ```
    *Note: This runs the container ephemeral on connection.*

#### Method B: Tailscale Direct (Simpler)
If the container exposes a port on the Tailnet.

1.  **Config**:
    ```json
    "mcpServers": {
      "remote-db": {
        "command": "npx",
        "args": ["-y", "@modelcontextprotocol/server-sse-client", "http://100.x.y.z:8000/sse"]
      }
    }
    ```

---

## 4. Troubleshooting

-   **Logs**: `docker logs -f <container_id>`
-   **Inspector**: Use `@modelcontextprotocol/inspector` to debug.

```bash
npx @modelcontextprotocol/inspector <command> <args>
```

4. **Security**:
    -   NEVER expose an MCP server to the public internet (0.0.0.0) without Authentication.
    -   Prefer SSH tunneling or Tailscale for all private tools.
