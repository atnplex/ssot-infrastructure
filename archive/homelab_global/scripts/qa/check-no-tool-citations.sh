#!/usr/bin/env bash
set -euo pipefail
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[check-no-tool-citations] scanning scripts/ and .github/"
bad=$(
  git ls-files -z scripts .github 2> /dev/null |
    tr '\0' '\n' |
    while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      if LC_ALL=C grep -qU $'\x00' "$f" 2> /dev/null; then
        continue
      fi
      if grep -nE '\[(web|page|file|memory|chart|image):[0-9]+\]' "$f" > /dev/null 2>&1; then
        echo "$f"
      fi
    done
)
if [[ -n "$bad" ]]; then
  echo "Found tool-style citations in code/workflows (remove them):"
  echo "$bad"
  exit 1
fi
echo "[check-no-tool-citations] OK"
