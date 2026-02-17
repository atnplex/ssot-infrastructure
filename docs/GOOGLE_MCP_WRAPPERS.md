# Google Service MCP Wrappers (Phase 6b)

> **Status**: Planned | **Target**: Post Phase 6 deployment | **Priority**: Medium

## Planned Wrappers

| Wrapper       | Service                          | Ports | RAM   | Location |
| :------------ | :------------------------------- | :---- | :---- | :------- |
| `mcp-jules`   | Google Jules (AI code gen)       | 9020  | 4-8GB | Unraid   |
| `mcp-stitch`  | Google Stitch (data integration) | 9021  | 2-4GB | Unraid   |
| `mcp-imagefx` | Google ImageFX (image gen)       | 9022  | 4-8GB | Unraid   |
| `mcp-flow`    | Google Flow (workflows)          | 9023  | 2-4GB | Unraid   |

> [!IMPORTANT]
> Google Labs services require headless browser management with session cookie rotation.
> These run **only on Unraid** (not VPS) due to 8-16GB RAM requirements for browser instances.

## Architecture

```
Unraid (Docker) → labs-mcp container
  ├── Headless Chromium (Playwright)
  ├── Session manager (cookie rotation)
  ├── MCP server (stdio/SSE)
  └── Health endpoint (:9021/health)

Agent → Tailscale → Unraid:9020 → MCP tools
```

## Reference

- Placeholder: [unraid-labs-mcp-REFERENCE.yml](file:///C:/atn/github/atnplex/ssot-infrastructure/services/unraid-labs-mcp-REFERENCE.yml)
- Volume: `labs_session_data` (pre-allocated)
- Network: `atn_link` (Unraid Docker bridge)
- Profile: `research` (40 maxTools)

## Implementation Plan

1. Create `docker/mcp-wrapper-base/Dockerfile` (Playwright + MCP SDK)
2. Implement each wrapper as extension of base
3. Add to `mcp_registry.json` with profile tags
4. Test with agent skills (parallel-research)
5. Deploy to Unraid labs environment
6. Add to `tool_manifest.yaml` with trigger keywords

## Timeline

- **Phase 6b** (post-deployment): Design + prototype
- **Phase 7**: Production deployment + integration
