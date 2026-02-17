#!/usr/bin/env bash
set -euo pipefail

# file: scripts/qa/strip_citations.sh
# repo: homelab_global
# owner: alex
# created: 2026-01-17
# last_reviewed: 2026-01-17
# purpose: Remove Perplexity-style citation markers and ppl-ai upload links from tracked text files.
# tags: [qa, cleanup, citations, perplexity]

# Only operate on tracked text-like files to avoid touching binaries.
mapfile -t files < <(
  git ls-files \
    '*.md' '*.markdown' '*.txt' \
    '*.yml' '*.yaml' '*.json' '*.jsonc' \
    '*.sh' '*.bash' \
    2> /dev/null || true
)

if ((${#files[@]} == 0)); then
  echo "[strip-citations] no matching tracked files found; nothing to do"
  exit 0
fi

# Remove citation tokens like , , , , , , .
# Also remove markdown links whose visible text is a ppl-ai upload host (common artifact).
for f in "${files[@]}"; do
  # Skip if file missing (paranoia)
  [[ -f "$f" ]] || continue

  perl -0777 -i -pe '
    s/\[(web|file|page|memory|conversation_history|chart|image):\d+\]//g;
    s/\[ppl-ai-file-upload[^\]]*\]\([^)]+\)//g;
  ' "$f"
done

echo "[strip-citations] done"
