# MCP Server Reference

Quick reference for all MCP servers used in the atnplex ecosystem.

## Active Servers

### github-mcp-server
- **Type**: Local stdio (`npx`)
- **Repo**: [@anthropic-ai/github-mcp-server](https://github.com/anthropic-ai/github-mcp-server)
- **Auth**: `GITHUB_PERSONAL_ACCESS_TOKEN`
- **Tools**: ~20 (repos, issues, PRs, code search, file ops)
- **Profiles**: core-dev, infra-admin, research

### perplexity-ask
- **Type**: Local stdio (`npx`)
- **Repo**: [server-perplexity-ask](https://www.npmjs.com/package/server-perplexity-ask)
- **Auth**: `PERPLEXITY_API_KEY`
- **Tools**: ~1 (perplexity_ask)
- **Profiles**: core-dev, research

### sequential-thinking
- **Type**: Local stdio (`npx`)
- **Repo**: [@anthropic-ai/sequential-thinking-mcp](https://github.com/anthropic-ai/sequential-thinking-mcp)
- **Auth**: None
- **Tools**: ~1 (sequentialthinking)
- **Profiles**: core-dev, research

## Planned Servers (Cloud Run)

### bitwarden-mcp
- **Type**: Cloud Run (HTTP)
- **Repo**: [bitwarden/mcp-server](https://github.com/bitwarden/mcp-server)
- **Auth**: Bitwarden API key via GCP Secret Manager
- **Deploy**: `gcloud run deploy bitwarden-mcp ...`
- **Profiles**: infra-admin, core-dev

### ssh-mcp
- **Type**: Cloud Run (HTTP)
- **Options**: [tufantunc/ssh-mcp](https://github.com/tufantunc/ssh-mcp)
- **Auth**: SSH keys via GCP Secret Manager
- **Profiles**: infra-admin

### tailscale-mcp
- **Type**: Cloud Run (HTTP)
- **Repo**: [HexSleeves/tailscale-mcp](https://github.com/HexSleeves/tailscale-mcp)
- **Auth**: Tailscale API key via GCP Secret Manager
- **Profiles**: infra-admin
