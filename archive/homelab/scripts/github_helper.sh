#!/bin/bash
#
# Script Name: github_helper.sh
# Date:        2025-11-11
# Author:      anguy079
# Purpose:     Interactive and CLI automation for GitHub repo management:
#              sync, push, pull, commit, branch management, tags, releases.
#
# Requires: bash, git, (optional: gh GitHub CLI)
#

set -euo pipefail

# --- Configuration & Logging ---
timestamp=$(date +%Y-%m-%d_%H%M%S)
log_file=~/github_helper_log_"$timestamp".log
touch "$log_file"

if [[ -t 1 ]]; then
  green="\033[1;32m"; yellow="\033[1;33m"; red="\033[1;31m"; reset="\033[0m"
else
  green=""; yellow=""; red=""; reset=""
fi

log()       { printf "${green}[%s] %s${reset}\n" "$(date +'%F %T')" "$1"; echo "[$(date +'%F %T')] $1" >>"$log_file"; }
log_warn()  { printf "${yellow}[%s] [WARN] %s${reset}\n" "$(date +'%F %T')" "$1"; echo "[$(date +'%F %T')] [WARN] $1" >>"$log_file"; }
log_error() { printf "${red}[%s] [ERROR] %s${reset}\n" "$(date +'%F %T')" "$1" >&2; echo "[$(date +'%F %T')] [ERROR] $1" >>"$log_file"; }

# --- Sanitizers ---
# FIX: No spaces in branch names
sanitize_branch_name() { echo "$1" | tr -cd '[:alnum:]_.-/'; }
# FIX: No slashes or spaces in tag names
sanitize_tag_name()    { echo "$1" | tr -cd '[:alnum:]_.-'; }
# Allow newlines for commit messages
sanitize_input()       { echo "$1" | tr -cd '\n[:alnum:] _.,;:!?@#$%&()[]{}|=+-/_\'; }

# --- Usage/Help Output ---
usage() {
  echo "Usage: $0 [command] [options]"
  echo
  echo "Examples:"
  echo "  $0 --commit \"Fix bug\""
  echo "  $0 --branch-create feature-x"
  echo "  $0 --tag-create v1.2.0 \"Release notes here\""
  echo "  $0 --release-create v1.2.0 \"Release v1.2.0\" \"Detailed notes\""
  echo
  echo "Commands:"
  echo "  --status                     Show git status"
  echo "  --pull                       Pull latest changes"
  echo "  --push                       Push current branch"
  echo "  --commit [msg]               Commit all changes (default msg if blank)"
  echo "  --sync                       Pull (rebase) then push"
  echo "  --branch-create [name]       Create and switch to a new branch"
  echo "  --branch-delete [name]       Force-delete a local branch"
  echo "  --branch-switch [name]       Switch to an existing branch (local or remote)"
  echo "  --tag-create [name] [msg]    Create an annotated tag and push it"
  echo "  --tag-delete [name]          Delete a tag locally and from origin"
  echo "  --tag-list                   List all tags"
  echo "  --release-create [tag]...    Create a GitHub release (needs 'gh' CLI)"
  echo "  --release-delete [tag]       Delete a GitHub release (needs 'gh' CLI)"
  echo "  --release-list               List GitHub releases (needs 'gh' CLI)"
  echo "  -h, --help                   Show this help"
  echo
  echo "Run without arguments for an interactive menu."
  exit 0
}


# --- Dependency Check ---
has_gh=0
check_deps() {
  log "Checking dependencies..."
  command -v git >/dev/null || { log_error "git not found. Please install it."; exit 1; }
  log "[✔] Found git"
  if command -v gh >/dev/null; then
    log "[✔] Found gh (GitHub CLI)"
    has_gh=1
  else
    log_warn "gh (GitHub CLI) not found. Release functions will be disabled."
  fi
}

repo_root=$(git rev-parse --show-toplevel 2>/dev/null || true)
repo_name=$(basename "$repo_root" 2>/dev/null || echo "Unknown")

# --- Core Functions ---
git_status() { log "Showing repository status..."; git status; }

# FIX: Use 'return 1' on failure so 'git_sync' can safely stop
git_pull() {
  log "Pulling latest changes from origin (rebase)..."
  if ! git pull --rebase --autostash; then
    log_error "Pull failed. You may have merge conflicts to resolve."
    return 1
  fi
}

# FIX: Use 'return 1' on failure
git_push() {
  log "Pushing current branch to origin..."
  if ! git push; then
    log_error "Push failed. (Is your branch behind? Try pulling first.)"
    return 1
  fi
}

git_commit() {
  local msg="${1:-Auto-commit at $timestamp}"
  msg=$(sanitize_input "$msg") # Sanitize commit message
  
  # FIX: Check for changes *before* adding
  if [[ -z "$(git status --porcelain)" ]]; then
    log_warn "No changes to commit."
    return
  fi
  
  log "Committing changes: $msg"
  git add -A
  if git commit -m "$msg"; then
    log "[✔] Commit successful."
  else
    log_warn "Commit failed."
  fi
}

# FIX: Check for pull failure before pushing
git_sync() {
  log "Syncing repository..."
  if ! git_pull; then
    log_error "Pull failed. Halting sync."
    return 1
  fi
  git_push
}

git_branch() {
  log "Current branch: $(git symbolic-ref --short HEAD)"
  log "All local branches:"
  git branch
}

# --- Branch Management ---
branch_create() {
  local name
  name=$(sanitize_branch_name "${1:-new-branch}")
  [[ -z "$name" ]] && { log_error "Branch name cannot be empty."; return 1; }
  
  log "Creating and switching to branch: $name"
  if git checkout -b "$name"; then
    log "[✔] Switched to new branch '$name'."
  else
    log_error "Could not create or switch to branch '$name'."
    return 1
  fi
}

branch_delete() {
  local name
  name=$(sanitize_branch_name "${1:-}")
  [[ -z "$name" ]] && { log_error "Branch name required"; return 1; }
  
  # FIX: Add safety check for current branch
  local current_branch
  current_branch=$(git symbolic-ref --short HEAD)
  if [[ "$name" == "$current_branch" ]]; then
    log_error "Cannot delete the branch you are currently on ('$name')."
    return 1
  fi

  log "Force-deleting local branch: $name"
  if git branch -D "$name"; then
    log "[✔] Local branch '$name' deleted."
  else
    log_error "Failed to delete local branch '$name'."
    return 1
  fi
  
  # Interactive only: ask to delete remote
  if [[ -z "${cli_mode-}" ]]; then
    read -p "Delete remote branch 'origin/$name' as well? (y/N): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
      log "Deleting remote branch 'origin/$name'..."
      if git push origin ":$name"; then
        log "[✔] Remote branch deleted."
      else
        log_error "Failed to delete remote branch."
      fi
    fi
  fi
}

# FIX: Add smart remote-tracking checkout
branch_switch() {
  local name
  name=$(sanitize_branch_name "${1:-}")
  [[ -z "$name" ]] && { log_error "Branch name required"; return 1; }
  
  # Check if branch exists locally
  if git show-ref --verify --quiet "refs/heads/$name"; then
    log "Switching to local branch: $name"
    if git checkout "$name"; then
      log "[✔] Switched to '$name'."
    else
      log_error "Failed to checkout '$name'."
    fi
  # Check if branch exists on origin
  elif git ls-remote --exit-code --heads origin "$name" &>/dev/null; then
    log_warn "Branch '$name' not found locally, but exists on origin."
    # In CLI mode, just do it. In interactive, ask.
    local choice="y"
    if [[ -z "${cli_mode-}" ]]; then
        read -p "Checkout and track 'origin/$name'? (y/N): " choice
    fi
    
    if [[ "$choice" =~ ^[Yy]$ ]]; then
      if git checkout --track "origin/$name"; then
        log "[✔] Switched to and tracking '$name'."
      else
        log_error "Failed to checkout remote branch '$name'."
      fi
    fi
  else
    log_error "Branch '$name' not found locally or on origin."
  fi
}

# --- Tagging/Releases ---
tag_create() {
  local name msg
  name=$(sanitize_tag_name "${1:-v1.0.0}")
  msg=$(sanitize_input "${2:-Release $name}")
  [[ -z "$name" ]] && { log_error "Tag name cannot be empty."; return 1; }
  
  log "Creating annotated tag: $name"
  if git tag -a "$name" -m "$msg"; then
    log "[✔] Tag '$name' created locally."
    log "Pushing tag to origin..."
    if git push origin "$name"; then
      log "[✔] Tag '$name' pushed to origin."
    else
      log_error "Failed to push tag '$name' to origin."
    fi
  else
    log_error "Failed to create tag '$name'. Does it already exist?"
  fi
}

# FIX: Make tag deletion safer (two steps)
tag_delete() {
  local name
  name=$(sanitize_tag_name "${1:-}")
  [[ -z "$name" ]] && { log_error "Tag name required"; return 1; }
  
  log "Deleting tag: $name"
  if git tag -d "$name"; then
    log "[✔] Tag '$name' deleted locally."
    log "Deleting tag from origin..."
    if git push origin ":refs/tags/$name"; then
      log "[✔] Tag '$name' deleted from origin."
    else
      log_error "Failed to delete tag '$name' from origin (it may not exist there)."
    fi
  else
    log_error "Failed to delete local tag '$name'. Does it exist?"
  fi
}

tag_list() { log "Listing tags..."; git tag --list; }

# --- GitHub Release (via gh CLI) ---
release_create() {
  if [[ $has_gh -eq 0 ]]; then log_error "gh CLI not found."; return 1; fi
  local tag title notes
  tag=$(sanitize_tag_name "${1:-v1.0.0}")
  title=$(sanitize_input "${2:-Release $tag}")
  notes="${3:-Auto-generated release}" # Allow full input for notes
  [[ -z "$tag" ]] && { log_error "Release tag cannot be empty."; return 1; }
  
  log "Creating GitHub release: $tag"
  # First, ensure the tag exists locally and is pushed
  if ! git show-ref --verify --quiet "refs/tags/$tag"; then
    log "Tag '$tag' not found. Creating it first..."
    tag_create "$tag" "$title"
  fi
  
  if gh release create "$tag" --title "$title" --notes "$notes"; then
     log "[✔] GitHub release '$tag' created."
  else
     log_error "gh release create failed."
  fi
}

release_delete() {
  if [[ $has_gh -eq 0 ]]; then log_error "gh CLI not found."; return 1; fi
  local tag
  tag=$(sanitize_tag_name "${1:-}")
  [[ -z "$tag" ]] && { log_error "Release tag required"; return 1; }
  
  log "Deleting GitHub release: $tag"
  
  # SAFER: Let 'gh' prompt for confirmation, even in CLI mode,
  # unless a *new* --force flag is added (which we haven't).
  # The user's -y in CLI was too dangerous.
  if gh release delete "$tag"; then
    log "[✔] GitHub release '$tag' deleted."
  else
    log_error "Failed to delete release '$tag'."
  fi
}

release_list() {
  if [[ $has_gh -eq 0 ]]; then log_error "gh CLI not found."; return 1; fi
  log "Listing GitHub releases...";
  gh release list
}

# --- Interactive Menu ---
menu() {
  while true; do
    local current_branch
    current_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "N/A")
    printf "\n${yellow}--- GitHub Helper Menu ($repo_name | $current_branch) ---${reset}\n"
    
    printf "${green}Common Operations:${reset}\n"
    echo "  1) Status           8) Commit"
    echo "  2) Pull             9) Push"
    echo "  3) Sync (Pull+Push)"
    
    printf "\n${green}Branch Management:${reset}\n"
    echo " 10) Show Branches    12) Delete Branch"
    echo " 11) Create Branch    13) Switch Branch"

    printf "\n${green}Tagging & Releases:${reset}\n"
    echo " 20) List Tags        22) Delete Tag"
    echo " 21) Create Tag       "
    if [[ $has_gh -eq 1 ]]; then
    echo " 30) List Releases    32) Delete Release"
    echo " 31) Create Release"
    fi
    
    echo "  0) Exit"
    
    read -p "Your choice: " sel
    
    # FIX: Add safety check for uncommitted changes
    if [[ "$sel" =~ ^(2|3|11|12|13|21|22|31|32)$ ]]; then
        if [[ -n $(git status --porcelain) ]]; then
            log_warn "You have uncommitted changes."
            read -p "Proceed anyway? (y/N): " choice
            [[ "$choice" =~ ^[Yy]$ ]] || { log "Cancelled."; continue; }
        fi
    fi

    case "$sel" in
      1) git_status ;;
      2) git_pull ;;
      3) git_push ;;
      8) read -p "Commit message [default: Auto-commit]: " msg; git_commit "${msg:-Auto-commit at $timestamp}" ;;
      # 9 was a duplicate of 3, let's make it push --force
      9) 
        read -p "Are you sure you want to force push? (y/N): " c;
        [[ "$c" =~ ^[Yy]$ ]] && git push --force
        ;;
      
      10) git_branch ;;
      11) read -p "New branch name [default: new-branch]: " b; branch_create "${b:-new-branch}" ;;
      12) read -p "Branch name to delete: " b; 
           if [[ -n "$b" ]]; then
             read -p "Are you sure you want to delete branch '$b'? (y/N): " c;
             [[ "$c" =~ ^[Yy]$ ]] && branch_delete "$b"
           fi
           ;;
      13) read -p "Branch name to switch to: " b; branch_switch "$b" ;;
      
      20) tag_list ;;
      21) read -p "Tag name [default: v1.0.0]: " t; read -p "Tag message [default: Release $t]: " m; tag_create "${t:-v1.0.0}" "${m:-Release ${t:-v1.0.0}}" ;;
      22) read -p "Tag name to delete: " t; 
           if [[ -n "$t" ]]; then
             read -p "Are you sure you want to delete tag '$t' locally AND from origin? (y/N): " c;
             [[ "$c" =~ ^[Yy]$ ]] && tag_delete "$t"
           fi
           ;;
           
      30) [[ $has_gh -eq 1 ]] && release_list ;;
      31) [[ $has_gh -eq 1 ]] && { read -p "Release tag [default: v1.0.0]: " t; read -p "Release title [default: Release $t]: " ti; read -p "Release notes [default: Auto-generated]: " n; release_create "${t:-v1.0.0}" "${ti:-Release ${t:-v1.0.0}}" "${n:-Auto-generated}"; } ;;
      32) [[ $has_gh -eq 1 ]] && { read -p "Release tag to delete: " t;
           if [[ -n "$t" ]]; then
             read -p "Are you sure you want to delete release '$t' from GitHub? (y/N): " c;
             [[ "$c" =~ ^[Yy]$ ]] && release_delete "$t"
           fi; }
           ;;
           
      0) log "Exiting."; exit 0 ;;
      *) log_warn "Invalid choice." ;;
    esac
    read -p "Press [Enter] to continue..."
  done
}

# --- Main Execution ---

# Check dependencies first
check_deps

# Check if we are inside a repo. If not, only --help is allowed.
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  if [[ "$#" -gt 0 && ( "$1" == "-h" || "$1" == "--help" ) ]]; then
    usage
  fi
  log_error "Not inside a git repository. Aborting."; exit 1
fi

# Set flag for CLI mode to disable interactive prompts
cli_mode=""

# --- Robust CLI Argument Parsing ---
while [[ $# -gt 0 ]]; do
  cli_mode=1
  case "$1" in
    --status) git_status; shift ;;
    --pull) git_pull; shift ;;
    --push) git_push; shift ;;
    --commit) 
      local msg="${2-}"
      if [[ "$msg" =~ ^-- ]]; then msg=""; fi
      git_commit "$msg"
      shift; [[ -n "$msg" && ! "$msg" =~ ^-- ]] && shift || true
      ;;
    --sync) git_sync; shift ;;
    
    --branch-create)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --branch-create"; usage; }
      branch_create "$2"; shift 2 ;;
    --branch-delete)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --branch-delete"; usage; }
      log_warn "CLI delete is a local force-delete (-D). Remote branch is NOT deleted."
      branch_delete "$2"; shift 2 ;;
    --branch-switch)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --branch-switch"; usage; }
      branch_switch "$2"; shift 2 ;;
      
    --tag-create)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --tag-create"; usage; }
      tag_create "$2" "${3-}"
      shift 2; [[ -n "${3-}" && ! "${3-}" =~ ^-- ]] && shift || true
      ;;
    --tag-delete)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --tag-delete"; usage; }
      log_warn "This will delete the tag locally AND from origin."
      tag_delete "$2"; shift 2 ;;
    --tag-list) tag_list; shift ;;
    
    --release-create)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --release-create"; usage; }
      release_create "$2" "${3-}" "${4-}"
      shift 2;
      [[ -n "${3-}" && ! "${3-}" =~ ^-- ]] && shift || true
      [[ -n "${4-}" && ! "${4-}" =~ ^-- ]] && shift || true
      ;;
    --release-delete)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --release-delete"; usage; }
      log_warn "This will delete the release from GitHub. Confirmation will be required."
      release_delete "$2"; shift 2 ;;
    --release-list) release_list; shift ;;
    
    -h|--help) usage ;;
    *) log_error "Unknown option: $1"; usage ;;
  esac
done

# --- Default: Interactive Menu ---
if [[ -z "$cli_mode" ]]; then
  unset cli_mode # Ensure it's not set
  menu
fi
