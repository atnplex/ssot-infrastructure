#!/usr/bin/env bash
set -euo pipefail

# file: scripts/github/protect_main.sh
# repo: homelab_global
# owner: alex
# created: 2026-01-17
# last_reviewed: 2026-01-17
# purpose: Apply branch protection to main (block direct pushes, require PR reviews + checks).
# tags: [github, branch-protection, automation, policy]

: "${GITHUB_TOKEN:?Set GITHUB_TOKEN in env (do not commit).}"

OWNER="atnplex"
REPO="homelab_global"
BRANCH="main"

# NOTE: required_status_checks contexts must match actual check names once CI is added.
payload="$(
  cat << 'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": []
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
)"

curl -fsSL -X PUT \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${OWNER}/${REPO}/branches/${BRANCH}/protection" \
  -d "${payload}" > /dev/null

echo "[protect-main] applied protection to ${OWNER}/${REPO}:${BRANCH}"
