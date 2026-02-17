#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "[check-whitespace] running git diff --check for whitespace errors"
# git diff --check flags lines with trailing whitespace and missing newline at EOF.
git diff --check HEAD --

echo "[check-whitespace] scanning for CR characters (CRLF) in tracked files"
# Look for literal CR in tracked, text-like files
git ls-files -z | while IFS= read -r -d '' f; do
  if LC_ALL=C grep -qU $'\x00' "$f" 2> /dev/null; then
    continue
  fi
  if LC_ALL=C grep -q $'\r' "$f"; then
    echo "CRLF or stray CR found in: $f"
    exit 1
  fi
done

echo "[check-whitespace] OK"
