#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   scripts/review/promote.sh atnplex_cloudflared_unraid candidates/.github/workflows/ci.yml templates/repo-bootstrap/.github/workflows/ci.yml workflow "baseline CI"
# Categories: policy|template|script|workflow|doc

slug="${1:-}"
src_rel="${2:-}"
dst_rel="${3:-}"
category="${4:-}"
notes="${5:-}"
[[ -n "$slug" && -n "$src_rel" && -n "$dst_rel" && -n "$category" ]] || {
  echo "Usage: $0 <repo_slug> <src_rel> <dst_rel> <category> [notes]" >&2
  exit 2
}

ts="$(date -u +%Y%m%dT%H%M%SZ)"
src="docs/reviews/${slug}/${src_rel}"
dst="${dst_rel}"

[[ -f "$src" ]] || {
  echo "FATAL: source missing: $src" >&2
  exit 1
}

# Enforce SSOT naming rules on destination paths (lowercase + no '__')
if [[ "$dst" =~ __ ]]; then
  echo "FATAL: dst contains '__' (forbidden): $dst" >&2
  exit 1
fi
if [[ "$dst" =~ [A-Z] ]]; then
  echo "FATAL: dst contains uppercase (forbidden): $dst" >&2
  exit 1
fi

mkdir -p "$(dirname "$dst")"
cp -f "$src" "$dst"

printf '%s,%s,%s,%s,%s,%s\n' \
  "$ts" "$slug" "$src_rel" "$dst_rel" "$category" "${notes//,/;}" \
  >> docs/inventory/04-promotions.csv

echo "[promote] $src -> $dst"
