# MCP Server Manifest (SSOT)

This document serves as the Single Source of Truth for all Model Context Protocol (MCP) servers in the infrastructure.

## Core Services

### 1. BWS (Secrets Manager)

- **Container**: `mcp-bws`
- **Image**: `mcp-bws:robust` (Custom build)
- **Tools**: `bws` CLI, Bitwarden SDK
- **Purpose**: Infrastructure secrets (API keys, SSH keys).
- **Access**:
  - `bws secret list`
  - `bws secret get <id>`
- **Source**: `mcp-bws/Dockerfile.robust`

### 2. OCI (Oracle Cloud)

- **Container**: `mcp-oci`
- **Purpose**: Cloud resource management (Compute, Networking).
- **Tools**: `oci` CLI.

## Future Integrations

### 3. Bitwarden (Password Manager)

- **Status**: Planned
- **Official Image**: `bitwarden/mcp-server`
- **Purpose**: Login credentials (username/password) access for agents.
- **Note**: Distinct from BWS. Requires `bw` CLI login.

## Usage Strategy

- **Agents** should query these servers via MCP protocol.
- **No Local Tools**: Agents do not need `bws` or `oci` installed locally; they delegate to the MCP server.
