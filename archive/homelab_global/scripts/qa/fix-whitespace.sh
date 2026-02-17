#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "[fix-whitespace] normalizing line endings + trailing spaces (tracked files only)"

git ls-files -z | while IFS= read -r -d '' f; do
  # Optional: skip any tracked artifact dirs anyway
  case "$f" in
    build/* | dist/* | node_modules/*) continue ;;
  esac

  # Skip files that look binary (contain NUL)
  if LC_ALL=C grep -qU $'\x00' "$f" 2> /dev/null; then
    continue
  fi

  perl -pi -e 's/\r\n/\n/g' "$f"
  perl -pi -e 's/[ \t]+$//' "$f"
done

echo "[fix-whitespace] done. Review 'git diff' and commit if acceptable."
