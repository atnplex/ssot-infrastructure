#!/usr/bin/env bash
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v gitleaks > /dev/null 2>&1; then
  echo "[scan-secrets] gitleaks not installed; skipping"
  exit 0
fi

echo "[scan-secrets] running gitleaks (filesystem mode; worktree-safe)"
# Worktree-safe: avoids tools that assume .git is a directory.
# See example usage: gitleaks detect --no-git --source .
gitleaks detect --no-git --source . --verbose
