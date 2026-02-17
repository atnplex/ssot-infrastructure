#!/usr/bin/env bash
set -euo pipefail

repo_full="${1:-}"
[[ -n "$repo_full" ]] || {
  echo "Usage: $0 owner/repo" >&2
  exit 2
}

owner="${repo_full%/*}"
name="${repo_full#*/}"
url="https://github.com/${repo_full}.git"
ts="$(date -u +%Y%m%dT%H%M%SZ)"

# SSOT slug rules:
# - lowercase
# - non [a-z0-9] -> _
# - collapse multiple _ to single _
# - trim leading/trailing _
slug_raw="${owner}_${name}"
slug="$(printf '%s' "$slug_raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/_/g; s/_+/_/g; s/^_+//; s/_+$//')"

work_root="/tmp/atn-intake"
work_dir="${work_root}/${slug}-${ts}"
repo_dir="${work_dir}/repo"

review_dir="docs/reviews/${slug}"
cand_dir="${review_dir}/candidates"

mkdir -p "$work_root" "$review_dir" "$cand_dir"
rm -rf "$work_dir"
git clone --depth 1 "$url" "$repo_dir" > /dev/null

pushd "$repo_dir" > /dev/null
head_sha="$(git rev-parse HEAD)"
git ls-files > "${work_dir}/manifest.txt"
popd > /dev/null

printf '%s\n' "$repo_full" > "${review_dir}/source_repo_full_name.txt"
printf '%s\n' "$url" > "${review_dir}/source_url.txt"
printf '%s\n' "$head_sha" > "${review_dir}/source_head_sha.txt"
printf '%s\n' "$ts" > "${review_dir}/intake_timestamp_utc.txt"
cp -f "${work_dir}/manifest.txt" "${review_dir}/manifest.txt"

max_bytes=$((512 * 1024)) # 512 KiB per file
skip_ext_re='\.((png|jpg|jpeg|gif|ico|pdf|zip|tar|gz|xz|7z|bin|exe|dll|so|dylib))$'

while IFS= read -r rel; do
  src="${repo_dir}/${rel}"
  [[ -f "$src" ]] || continue

  if [[ "$rel" =~ $skip_ext_re ]]; then
    continue
  fi

  size="$(stat -c '%s' "$src" 2> /dev/null || echo 0)"
  if ((size > max_bytes)); then
    continue
  fi

  case "$rel" in
    # Allowlisted extensionless / important paths referenced by CI/release workflows
    src/etc/rc.d/* | src/usr/local/emhttp/plugins/*/scripts/* | build/build.py)
      mkdir -p "$(dirname "${cand_dir}/${rel}")"
      cp -f "$src" "${cand_dir}/${rel}"
      ;;
    # Common reviewable text/source files
    *.md | *.markdown | *.txt | *.yml | *.yaml | *.json | *.jsonc | *.toml | *.ini | *.cfg | *.conf | *.xml | *.sh | *.plg | *.php | *.py | Makefile | Dockerfile | .editorconfig | .gitattributes | .gitignore | .github/* | .vscode/*)
      mkdir -p "$(dirname "${cand_dir}/${rel}")"
      cp -f "$src" "${cand_dir}/${rel}"
      ;;
    *) ;;
  esac
done < "${work_dir}/manifest.txt"

csv="docs/inventory/03-processed-repos.csv"
if [[ ! -f "$csv" ]]; then
  mkdir -p docs/inventory
  printf '%s\n' "repo_full_name,source_url,source_head_sha,intake_timestamp_utc,status,notes" > "$csv"
fi

printf '%s,%s,%s,%s,%s,%s\n' \
  "$repo_full" \
  "https://github.com/${repo_full}" \
  "$head_sha" \
  "$ts" \
  "intaked" \
  "review in ${review_dir}" \
  >> "$csv"

echo "[intake] repo=${repo_full} sha=${head_sha} ts=${ts}"
echo "[intake] review_dir=${review_dir}"
echo "[intake] candidates=${cand_dir}"
