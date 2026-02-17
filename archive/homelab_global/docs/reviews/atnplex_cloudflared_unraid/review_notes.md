# Review notes: atnplex/cloudflared-unraid

## Status
- Candidates captured and pinned into `_unreviewed` baselines.
- No promotion to `templates/` yet (repo-specific workflows and scripts).

## Findings
- CI workflow shells `rc.cloudflared` and `cloudflaredctl` (now present in candidates).
- Release workflow uses GitHub API unauthenticated; should switch to authenticated requests using `GITHUB_TOKEN` to avoid rate limit/403 issues.

## Promotion decisions
- None yet.

## Recommended repo changes (not SSOT)
- release.yml: Authenticate GitHub API requests using GITHUB_TOKEN (Authorization: Bearer) to reduce 403/rate-limit risk.
