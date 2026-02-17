#!/bin/bash
#
# Script Name: github_new_orphan_branch.sh
# Date:        2025-11-11
# Purpose:     Creates a new orphan branch, removes all files,
#              adds a fresh README, and pushes to origin.
#              Includes advanced options for dry-runs, forcing,
#              and renaming the repository's default branch.
#

set -euo pipefail

# --- Configuration & Logging ---
timestamp=$(date +%Y-%m-%d_%H%M%S)
log_file=~/new_orphan_branch_log_"$timestamp".log
touch "$log_file"

if [[ -t 1 ]]; then
  green="\033[1;32m"; yellow="\033[1;33m"; red="\033[1;31m"; reset="\033[0m"
else
  green=""; yellow=""; red=""; reset=""
fi

log() { printf "${green}[%s] %s${reset}\n" "$(date +'%F %T')" "$1"; echo "[$(date +'%F %T')] $1" >>"$log_file"; }
log_warn() { printf "${yellow}[%s] [WARN] %s${reset}\n" "$(date +'%F %T')" "$1"; echo "[$(date +'%F %T')] [WARN] $1" >>"$log_file"; }
log_error() { printf "${red}[%s] [ERROR] %s${reset}\n" "$(date +'%F %T')" "$1" >&2; echo "[$(date +'%F %T')] [ERROR] $1" >>"$log_file"; }

# --- Sanitizer ---
sanitize_branch_name() { echo "$1" | tr -cd '[:alnum:]_.-/'; }
sanitize_input() { echo "$1" | tr -cd '[:alnum:] _.-/'; }

# --- Usage/Help Output ---
usage() {
  echo "Usage: $0 [--branch name] [--dry-run] [--force] [--set-default]"
  echo "       [--rename-default name] [--append-suffix string] [--readme title]"
  echo
  echo "Options:"
  echo "  --branch NAME        Name for the new orphan branch (default: fresh-start)"
  echo "  --readme TITLE       Title for the README.md"
  echo "  --dry-run            Print actions, don't modify repo"
  echo "  --force              Ignore uncommitted changes"
  echo "  --set-default        Set new branch as the default branch (uses gh CLI)"
  echo "  --rename-default NEW Rename the current default branch"
  echo "  --append-suffix TXT  Rename default branch appending TXT"
  echo "  -h, --help           Show this help"
  exit 1
}

# --- Defaults ---
branch="fresh-start"
readme_title=""
dry_run=0
force=0
set_default=0
rename_default=""
append_suffix=""

# --- Arguments Parsing w/ Validation ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --branch"; usage; }
      branch="$2"; shift 2 ;;
    --readme)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --readme"; usage; }
      readme_title="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --force) force=1; shift ;;
    --set-default) set_default=1; shift ;;
    --rename-default)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --rename-default"; usage; }
      rename_default="$2"; shift 2 ;;
    --append-suffix)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --append-suffix"; usage; }
      append_suffix="$2"; shift 2 ;;
    -h|--help) usage ;;
    *)
      log_error "Unknown option: $1"
      usage ;;
  esac
done

branch=$(sanitize_branch_name "$branch")
readme_title=$(sanitize_input "$readme_title")
rename_default=$(sanitize_branch_name "$rename_default")
# FIX: Use branch sanitizer for suffix
append_suffix=$(sanitize_branch_name "$append_suffix")

if [[ -z "$branch" ]]; then
  log_error "Branch name is empty or invalid after sanitization."
  exit 1
fi

# --- Dependency Check ---
command -v git >/dev/null || { log_error "git not found"; exit 1; }

# --- Repo Check ---
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  log_error "Not inside a git repository"; exit 1
fi

repo_root=$(git rev-parse --show-toplevel)
repo_name=$(basename "$repo_root")

# --- Rollback Safety ---
prev_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")

rollback() {
  local exit_code=$?
  if [[ $exit_code -ne 0 && -n "$prev_branch" ]]; then
    log_error "Script failed. Rolling back to previous branch: $prev_branch"
    git checkout "$prev_branch" || log_error "Rollback failed. Please check repo state."
  fi
}
trap rollback ERR EXIT

# --- Safety Checks ---
if [[ $force -eq 0 ]]; then
  if ! git diff-index --quiet HEAD --; then
    log_error "Unstaged changes detected. Use --force to override."; exit 1
  fi
  if [[ -n $(git status --porcelain) ]]; then
    log_error "Uncommitted changes detected. Use --force to override."; exit 1
  fi
else
  log_warn "Using --force. Bypassing uncommitted changes check."
fi

# --- Branch Existence ---
if git show-ref --verify --quiet "refs/heads/$branch"; then
  log_error "Branch '$branch' already exists locally"; exit 1
fi
if git ls-remote --exit-code --heads origin "$branch" &>/dev/null; then
  log_error "Branch '$branch' already exists on origin"; exit 1
fi

# --- Dry Run Helper ---
run() {
  if [[ $dry_run -eq 1 ]]; then
    printf "${yellow}[DRY-RUN] %s${reset}\n" "$*"
  else
    "$@"
  fi
}

# --- Execution ---
log "Creating orphan branch: $branch"
run git checkout --orphan "$branch"

log "Removing tracked files"
# FIX: Add || true for robustness, as this can fail in an empty repo
run git rm -rf . || true

log "Cleaning untracked files"
run git clean -fd

log "Adding README.md"
title="${readme_title:-$repo_name}"
echo "# $title (fresh start on $branch)" > README.md

run git add README.md
run git commit -m "Initial commit: fresh branch $branch with README only"

log "Pushing branch '$branch' to origin"
run git push -u origin "$branch"

# --- GitHub CLI Integration ---
if [[ $set_default -eq 1 ]]; then
  if command -v gh >/dev/null; then
    log "Setting '$branch' as default branch on GitHub"
    run gh repo set-default-branch "$branch"
  else
    log_warn "gh CLI not found; cannot set default branch automatically"
  fi
fi

# --- Default Branch Renaming Logic ---
if [[ -n "$rename_default" || -n "$append_suffix" ]]; then
  if [[ $force -eq 0 ]]; then
    log_warn "You requested to rename the *existing* default branch."
    read -p "This is a separate action from creating '$branch'. Proceed? (y/N): " choice
    [[ "$choice" =~ ^[Yy]$ ]] || { log "Default branch rename skipped."; exit 0; }
  else
    log_warn "Using --force. Proceeding with default branch rename."
  fi
  
  # IMPROVEMENT: Get ref and use shell expansion (no xargs/basename)
  current_default_ref=$(git symbolic-ref refs/remotes/origin/HEAD)
  current_default=${current_default_ref##*/} # Get part after last '/'
  
  if [[ -z "$current_default" ]]; then
    log_error "Could not determine default branch from origin/HEAD."
    exit 1
  fi

  if [[ -n "$rename_default" ]]; then
    new_name="$rename_default"
    log "Renaming default branch '$current_default' to '$new_name'"
    run git branch -m "$current_default" "$new_name"
    run git push origin ":$current_default" "$new_name"
    run git push origin -u "$new_name"
  elif [[ -n "$append_suffix" ]]; then
    new_name="${current_default}-${append_suffix}"
    log "Renaming default branch '$current_default' to '$new_name'"
    run git branch -m "$current_default" "$new_name"
    run git push origin ":$current_default" "$new_name"
    run git push origin -u "$new_name"
  fi
fi

# --- Summary ---
printf "\n${green}--- ✅ Setup Complete ---${reset}\n"
printf "Repository: %s\n" "$repo_name"
printf "New Branch: %s\n" "$branch"
printf "Dry Run: %s\n" "$dry_run"
printf "Force: %s\n" "$force"
printf "Set Default: %s\n" "$set_default"
printf "Rename Default: %s\n" "$rename_default"
printf "Append Suffix: %s\n" "$append_suffix"
printf "Log File: %s\n" "$log_file"
printf "${green}------------------------${reset}\n"

# --- Clear trap on successful exit ---
trap - ERR EXIT
