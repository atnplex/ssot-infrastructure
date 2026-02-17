#!/bin/bash
#
# GitHub SSH Key Deployer (v7b)
# "The Audit & Security Edition"
#
# Change Log:
# - Full restoration of v5's verbose logging and context-aware error handling.
# - Added Post-Flight Connection Verification (Test the key before exiting).
# - Added SSH Config File Backup (Audit requirement).
# - Explicit 'sudo' detection for container/WSL compatibility.
# - Refined fallbacks between 'gh' CLI and 'curl' API.
# - Fixed version consistency and standardized section numbering.
# - Interactive environment override loop if detection fails.
# - Centralized interactive menu and input helpers.
# - Generalized dependency verification with install, fallback, and manual path overrides.
# - Safer retry without eval; array-based invocation, with controlled bash -lc only for pipelines.
# - Cron path prompt and validation.
# - Memory-backed temp private key with secure removal.
# - Sanity checks for required variables.
# - Standardized dividers and temp/backup helpers for consistency.

# --- Strict Mode & Safety ---
set -euo pipefail

# --- Global Constants ---
readonly SCRIPT_NAME="GitHub SSH Key Deployer (v7)"
readonly START_TIME="$(date '+%Y-%m-%d %H:%M:%S %Z')"
readonly DATE_TAG="$(date +%Y%m%d)"
readonly HOSTNAME="$(hostname -s 2>/dev/null || hostname)"

# Paths - Using $HOME for strict POSIX compliance
readonly LOG_DIR="$HOME/logs"
readonly MAIN_SSH_CONFIG="$HOME/.ssh/config"
readonly SSH_CONFIG_DIR="$HOME/.ssh/config.d"
readonly LOG_FILE="$LOG_DIR/ssh_deploy_${HOSTNAME}_${DATE_TAG}.log"
readonly BACKUP_DIR="$HOME/.ssh.bak/${HOSTNAME}_${DATE_TAG}"

# Settings
readonly DEFAULT_TIMEOUT=15
readonly DEFAULT_RETRIES=2
readonly SLEEP_DURATION=3

# Detect Dry-Run Mode
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" || "${DRY_RUN:-}" == "true" ]]; then
  DRY_RUN=true
fi

# --- Global State ---
TEMP_FILES=()
SUDO_CMD=""
ENV="Unknown"
IP="unknown"
FZF_AVAILABLE="false"
CRON_AVAILABLE="false"
GH_AVAILABLE="false"
AGENT_FORWARDING="false"
HOST_ALIAS=""
CONFIG_FILE=""
KEY_PATH=""
PUB_PATH=""
GH_REPO=""
GH_USER=""
GH_PAT=""

# --- Colors for UX ---
if [[ -t 1 ]]; then
  green="\033[1;32m"; yellow="\033[1;33m"; red="\033[1;31m"; blue="\033[1;34m"; purple="\033[1;35m"; reset="\033[0m"
else
  green=""; yellow=""; red=""; blue=""; purple=""; reset=""
fi

# --- Logging & Audit Functions ---

_log() {
  local level_color="$1"
  local level_text="$2"
  local message="$3"
  local log_line="[$level_text] $message"
  printf "${level_color}%s${reset}\n" "$log_line"
  echo "$(date '+%Y-%m-%d %H:%M:%S') $log_line" >> "$LOG_FILE"
}

log()   { _log "$green"  "INFO"  "$1"; }
warn()  { _log "$yellow" "WARN"  "$1"; }
info()  { _log "$blue"   "STEP"  "$1"; }
audit() { _log "$purple" "AUDIT" "$1"; }
error() {
  local message="$1"
  local exit_code="${2:-1}"
  local context="${3:-}"
  _log "$red" "ERROR" "$message"
  [[ -n "$context" ]] && _log "$red" "ERROR" "Context: $context"
  _log "$red" "FATAL" "Script exiting with code $exit_code."
  exit "$exit_code"
}

# --- Dividers & Headers ---

divider_main() { echo "============================================================"; }
divider_sub()  { echo "---------------------------------------------------"; }

print_header() {
  divider_sub
  echo "  $SCRIPT_NAME"
  echo "  Date: $START_TIME"
  echo "  Host: $HOSTNAME"
  divider_sub
}

print_footer() {
  divider_main
  echo -e "${green}✅ DEPLOYMENT COMPLETE${reset}"
  echo "Repo:       ${GH_REPO:-n/a}"
  echo "Host Alias: ${HOST_ALIAS:-n/a}"
  echo "Key Path:   ${KEY_PATH:-n/a}"
  echo "Config:     ${CONFIG_FILE:-n/a}"
  echo "Backup Dir: ${BACKUP_DIR}"
  echo -e "${blue}CLONE COMMAND:${reset}"
  echo "git clone git@${HOST_ALIAS:-n/a}:${GH_REPO:-n/a}.git"
  echo "Log File:   $LOG_FILE"
  divider_main
}

# --- Temp & Backup Helpers ---

make_temp() { local f; f=$(mktemp); TEMP_FILES+=("$f"); echo "$f"; }
backup_file() { local src="$1"; cp "$src" "$BACKUP_DIR/" && audit "Backed up: $src -> $BACKUP_DIR"; }

# --- Cleanup & Hygiene ---

cleanup_on_exit() {
  local exit_code=$?
  # Clean up temp files
  for file in "${TEMP_FILES[@]}"; do
    [[ -f "$file" ]] && rm -f "$file"
  done

  # Exit Status Reporting
  if [[ $exit_code -ne 0 && $exit_code -ne 130 ]]; then
    _log "$red" "FATAL" "Script terminated unexpectedly (Code: $exit_code)."
    _log "$red" "FATAL" "Please review log: $LOG_FILE"
  elif [[ $exit_code -eq 130 ]]; then
    _log "$yellow" "ABORT" "User canceled script."
  else
    log "Script finished cleanly."
  fi
}
trap cleanup_on_exit EXIT ERR INT TERM

# --- Retry & Command Helpers ---

retry() {
  local cmd_timeout="$1"; shift
  local max_retries="$1"; shift
  local failure_exit_code="$1"; shift
  local -a cmd=( "$@" )
  local attempt=1
  local current_sleep=$SLEEP_DURATION
  while [[ $attempt -le $((max_retries + 1)) ]]; do
    log "Attempt $attempt/$((max_retries + 1)): Running command..."
    if timeout "$cmd_timeout" "${cmd[@]}"; then
      log "Command succeeded."
      return 0
    else
      local exit_status=$?
      warn "Attempt $attempt failed (exit code: $exit_status)"
      if [[ $attempt -lt $((max_retries + 1)) ]]; then
        warn "Retrying in ${current_sleep}s..."
        sleep "$current_sleep"
        current_sleep=$((current_sleep * 2))
      fi
    fi
    ((attempt++))
  done
  error "Command failed after $((max_retries + 1)) attempts." "$failure_exit_code" "Command: ${cmd[*]}"
}

command_exists() { command -v "$1" &>/dev/null; }

# --- Input & Menu Helpers ---

prompt_input() {
  local label="$1"
  local varname="$2"
  local default="${3:-}"
  local input=""
  if [[ -n "$default" ]]; then
    read -r -p "$label [$default]: " input || true
    input="${input:-$default}"
  else
    read -r -p "$label: " input || true
  fi
  printf -v "$varname" "%s" "$input"
}

menu_select() {
  local -n items_ref=$1
  local prompt_label="$2"
  local allow_manual="${3:-true}"
  local sel=""

  local total_items=${#items_ref[@]}
  local rows_per_block=10
  local max_rows=$((MENU_ROWS - 6))   # leave space for header/footer
  local col_width=30
  local max_cols=$((MENU_COLS / col_width))
  [[ $max_cols -lt 1 ]] && max_cols=1

  if (( total_items == 0 )); then
    warn "No items found for '$prompt_label'."
    [[ "$allow_manual" == "true" ]] && { echo "MANUAL"; return 0; }
    error "No items found and manual entry not allowed." 99
  fi

  log "$prompt_label"
  echo "Use the numbers shown to make a selection."
  echo "Press Enter to see more options if available."

  local start=0
  while (( start < total_items )); do
    local end=$((start + rows_per_block * max_cols))
    (( end > total_items )) && end=$total_items

    local idx=$((start + 1))
    local count=0
    for ((i=start; i<end; i++)); do
      printf " %02d = %-*s" "$idx" "$col_width" "${items_ref[$i]}"
      ((idx++))
      ((count++))
      if (( count % max_cols == 0 )); then echo ""; fi
    done
    echo ""
    printf "  00 = Cancel/Exit (quit this menu)\n"
    [[ "$allow_manual" == "true" ]] && printf "  MM = Manual entry (type your own value)\n"
    echo "Enter a number to choose, or press Enter to view the next page."

    read -r -p "Your choice: " sel
    [[ -z "$sel" ]] && { start=$end; divider_sub; continue; }
    [[ "$sel" =~ ^[0-9]$ ]] && sel="0$sel"
    [[ "$sel" == "00" ]] && log "User canceled." && exit 0
    [[ "${sel,,}" == "mm" && "$allow_manual" == "true" ]] && echo "MANUAL" && return 0

    if [[ "$sel" =~ ^[0-9]{2}$ ]]; then
      local n=$((10#$sel))
      if (( n >= 1 && n <= total_items )); then
        echo "${items_ref[$((n-1))]}"
        return 0
      fi
    fi
    warn "Invalid selection: $sel"
  done
}

# --- Parallel Runner ---
run_parallel() {
  local tasks=("$@")
  local outputs=()
  for task in "${tasks[@]}"; do
    local tmp=$(mktemp)
    $task >"$tmp" 2>&1 &
    outputs+=("$tmp")
  done
  wait
  # Now print outputs in order
  for tmp in "${outputs[@]}"; do
    cat "$tmp"
    rm -f "$tmp"
  done
}

# --- Parallel Runner ---
run_parallel() {
  local tasks=("$@")
  for task in "${tasks[@]}"; do
    $task &
  done
  wait
}

# --- Parallel Runner (buffered) ---
run_parallel_buffered() {
  local tasks=("$@")
  local bufs=()
  for t in "${tasks[@]}"; do
    local tmp; tmp=$(mktemp)
    ( $t ) >"$tmp" 2>&1 &
    bufs+=("$tmp")
  done
  wait
  for b in "${bufs[@]}"; do
    cat "$b"
    rm -f "$b"
  done
}

# --- Tmpfs Workdir Chooser ---
choose_tmp_workdir() {
  local candidates=(/dev/shm /run /tmp)
  for d in "${candidates[@]}"; do
    if [[ -d "$d" && -w "$d" ]]; then echo "$d"; return 0; fi
  done

  # Scan mountpoints for tmpfs
  local best=""
  while read -r mp fstype rest; do
    [[ "$fstype" != "tmpfs" ]] && continue
    [[ -w "$mp" ]] || continue
    local avail_kb; avail_kb=$(df -Pk "$mp" | awk 'NR==2 {print $4}')
    if [[ -n "$avail_kb" && "$avail_kb" -ge 10240 ]]; then
      best="$mp"; break
    fi
  done < <(awk '{print $2, $3}' /proc/self/mounts)

  echo "${best:-/tmp}"
}

# --- Repo Guessing Helper ---
guess_repo_candidates() {
  local root="${1:-.}"
  local host_hint="${HOSTNAME,,}"
  local patterns=(homeassistant ha haos unraid core-ssh hass io docker compose config)
  local names=()

  while IFS= read -r path; do
    local base="${path##*/}"
    names+=("${base,,}")
  done < <(find "$root" -maxdepth 2 -type d -o -type f 2>/dev/null | head -n 500)

  declare -A score
  for n in "${names[@]}"; do
    for p in "${patterns[@]}"; do
      [[ "$n" == *"$p"* ]] && ((score["$n"]+=2))
    done
    [[ "$n" == *"$host_hint"* ]] && ((score["$n"]+=3))
  done

  local uniq=()
  for k in "${!score[@]}"; do uniq+=("$k:${score[$k]}"); done
  IFS=$'\n' read -r -d '' -a sorted < <(printf "%s\n" "${uniq[@]}" | sort -t: -k2,2nr; printf '\0')
  local out=()
  for s in "${sorted[@]:0:9}"; do
    local token="${s%%:*}"
    out+=("$(printf "%s/%s" "${GH_USER:-user}" "$token")")
  done
  printf "%s\n" "${out[@]}"
}

# ============================================================
# 1. Pre-flight checks & environment
# ============================================================

get_terminal_size() {
    # Prefer tput, then stty, then fallback
    if command -v tput >/dev/null 2>&1; then
        rows=$(tput lines 2>/dev/null)
        cols=$(tput cols 2>/dev/null)
    elif command -v stty >/dev/null 2>&1; then
        read rows cols < <(stty size)
    else
        rows=25
        cols=80
    fi
    echo "$rows $cols"
}

check_permissions() {
  info "[1.1] Verifying filesystem permissions..."
  if [[ "$EUID" -eq 0 ]]; then
    SUDO_CMD=""
    log "Running as root (Container/WSL detected)."
  else
    SUDO_CMD="sudo"
    log "Running as user $USER (sudo enabled)."
  fi
  local dirs=("$HOME/.ssh" "$SSH_CONFIG_DIR" "$LOG_DIR" "$BACKUP_DIR")
  for dir in "${dirs[@]}"; do
    if ! mkdir -p "$dir"; then error "Could not create directory: $dir" 10; fi
    if [[ ! -w "$dir" ]]; then error "Directory is not writable: $dir" 11; fi
  done
  chmod 700 "$HOME/.ssh"
  if ! touch "$LOG_FILE"; then echo "FATAL: Cannot write to $LOG_FILE" >&2; exit 12; fi
  log "Environment secure. Logs: $LOG_FILE"; audit "Backup Target: $BACKUP_DIR"
}

check_internet() {
  info "[1.2] Checking internet connectivity..."
  retry 10 1 13 ping -c 1 -W 2 1.1.1.1
  log "Online connection confirmed."
}

detect_env() {
  info "[1.3] Detecting operating environment..."

  # Special case: BusyBox uses /proc/version
  if grep -qi busybox /proc/version 2>/dev/null; then
    ENV="BusyBox"
  else
    # All other distros detected from /etc/os-release
    local os_patterns=(
      "alpine:Alpine"
      "ubuntu:Ubuntu"
      "debian:Debian"
      "centos:CentOS"
      "fedora:Fedora"
    )

    ENV="Unknown"
    for entry in "${os_patterns[@]}"; do
      IFS=":" read -r pat name <<<"$entry"
      if grep -qi "$pat" /etc/os-release 2>/dev/null; then
        ENV="$name"
        break
      fi
    done
  fi

  # Get outbound IP for audit log
  IP="$(ip route get 1.1.1.1 2>/dev/null | awk -F'src ' '{print $2}' | awk '{print $1}' || echo "unknown")"
  log "System: $ENV | Host: $HOSTNAME | IP: $IP"

  # Interactive override if still unknown
  if [[ "$ENV" == "Unknown" ]]; then
    warn "Environment detection failed. Select environment manually."
    local env_options=("Alpine" "Ubuntu" "Debian" "Fedora" "CentOS" "BusyBox")
    while [[ "$ENV" == "Unknown" ]]; do
      local sel=""; sel=$(menu_select env_options "Select environment:" "true") || true
      if [[ "$sel" == "MANUAL" ]]; then
        local manual=""; prompt_input "Enter environment manually (e.g., Ubuntu, Alpine, BusyBox)" manual
        [[ -n "$manual" ]] && ENV="$manual"
      elif [[ -n "$sel" ]]; then
        ENV="$sel"
      fi
      [[ "$ENV" == "Unknown" ]] && warn "Selection invalid or empty. Try again, or choose 00 to cancel."
    done
    log "Environment override accepted: $ENV"
  fi
}

install_packages() {
  local pkgs=("$@")
  if [[ "$DRY_RUN" == "true" ]]; then log "[DRY-RUN] Would install packages: ${pkgs[*]}"; return; fi

  local install_cmd=""
  case "$ENV" in
    Alpine)        install_cmd="$SUDO_CMD apk add ${pkgs[*]}" ;;
    Ubuntu|Debian) install_cmd="$SUDO_CMD apt-get update && $SUDO_CMD apt-get install -y ${pkgs[*]}" ;;
    CentOS)        install_cmd="$SUDO_CMD yum install -y ${pkgs[*]}" ;;
    Fedora)        install_cmd="$SUDO_CMD dnf install -y ${pkgs[*]}" ;;
    *) error "Automatic install not supported for $ENV. Please install manually: ${pkgs[*]}" 20 ;;
  esac
  retry 300 1 21 bash -lc "$install_cmd"
}

verify_dependency() {
  local name="$1"; shift
  local install_pkgs=("$@")
  if command_exists "$name"; then log "Dependency OK: $name"; return 0; fi
  warn "Missing dependency: $name"
  read -r -p "Attempt to install $name automatically? (y/N): " choice || true
  if [[ "$choice" =~ ^[Yy]$ ]]; then
    if (( ${#install_pkgs[@]} > 0 )); then install_packages "${install_pkgs[@]}"; else install_packages "$name"; fi
    if command_exists "$name"; then log "Installed: $name"; return 0; fi
    warn "Automatic install reported success but '$name' not found."
  fi
  if [[ "$name" == "timeout" ]]; then
    if command_exists perl; then
      log "Using perl-based timeout shim."
      alias timeout='perl -e '\''alarm shift; exec @ARGV'\'''
      return 0
    fi
  fi
  warn "Provide full path to '$name' or press Enter to skip."
  local manual=""; prompt_input "Path to $name" manual
  if [[ -n "$manual" && -x "$manual" ]]; then
    export PATH="$(dirname "$manual"):$PATH"; log "Using manual path for $name: $manual"; return 0
  fi
  error "Dependency unresolved: $name" 22
}

check_deps() {
  info "[1.4] Checking dependencies..."

  # Define required dependencies as "command:package"
  local deps=(
    "ssh-keygen:openssh"
    "ssh-agent:openssh"
    "ssh-add:openssh"
    "git:git"
    "curl:curl"
    "jq:jq"
    "timeout:coreutils"
    "tput:ncurses-bin"
    "stty:coreutils"
    "crontab:cron"
  )

  for dep in "${deps[@]}"; do
    IFS=":" read -r cmd pkg <<<"$dep"
    verify_dependency "$cmd" "$pkg"
  done

  # Optional feature flags
  command_exists fzf && FZF_AVAILABLE="true" || FZF_AVAILABLE="false"
  command_exists crontab && CRON_AVAILABLE="true" || CRON_AVAILABLE="false"
  command_exists gh && GH_AVAILABLE="true" || GH_AVAILABLE="false"
  log "Feature Flags -> fzf: $FZF_AVAILABLE | gh: $GH_AVAILABLE | cron: $CRON_AVAILABLE"
}

# ============================================================
# 2. Cron backup setup
# ============================================================

setup_cron() {
  info "[2.1] Optional: Configure Cron Backup"

  echo "This will schedule automatic git add/commit/push for a local repo."
  echo "You can remove or edit the job later via 'crontab -e'."
  read -r -p "Enable GitHub auto-backup cron job? (y/N): " choice
  [[ "$choice" =~ ^[Yy]$ ]] || return

  local schedules=("Daily at midnight" "Every 6 hours" "Weekly on Sunday")
  local sel=""
  while [[ -z "$sel" ]]; do sel=$(menu_select schedules "Select backup schedule:" "true"); done

  local expr=""
  case "$sel" in
    "Daily at midnight") expr="0 0 * * *" ;;
    "Every 6 hours")     expr="0 */6 * * *" ;;
    "Weekly on Sunday")  expr="0 0 * * 0" ;;
    "MANUAL") read -r -p "Enter custom cron expression: " expr; [[ -z "$expr" ]] && warn "Empty expression. Skipping." && return ;;
    *) return ;;
  esac

  local repo_path=""
  while [[ -z "$repo_path" ]]; do
    prompt_input "Enter path to local repo for cron backups" repo_path
    [[ -z "$repo_path" ]] && warn "Repo path cannot be empty."
    if [[ -n "$repo_path" && ! -d "$repo_path" ]]; then warn "Directory not found: $repo_path"; repo_path=""; fi
  done

  local job="${expr} cd \"$repo_path\" && git add -A && git commit -m 'Auto backup' || true && git push"
  (crontab -l 2>/dev/null; echo "$job") | crontab -
  audit "Cron job added: $job"
}

# ============================================================
# 3. Authentication flow
# ============================================================

choose_auth_method() {
  info "[3.1] Checking GitHub Authentication..."

  if [[ -n "${SSH_AUTH_SOCK:-}" ]] && ssh-add -l &>/dev/null; then
    local ssh_out; ssh_out=$(make_temp)
    if retry 10 1 40 ssh -o StrictHostKeyChecking=accept-new -T git@github.com > "$ssh_out" 2>&1; then
      if grep -q "successfully authenticated" "$ssh_out"; then
        log "Existing SSH Agent connection confirmed."; AGENT_FORWARDING="true"; return
      fi
    fi
  fi

  AGENT_FORWARDING="false"
  info "[3.2] Agent not found. Select Authentication Method:"
  local methods=("PAT (Personal Access Token)" "Paste a temporary private SSH key")
  local sel=""
  while [[ -z "$sel" ]]; do sel=$(menu_select methods "Auth methods:" "false"); done

  if [[ "$sel" == "PAT (Personal Access Token)" ]]; then
    read -r -p "Enter GitHub PAT: " GH_PAT
    [[ -z "$GH_PAT" ]] && error "PAT cannot be empty." 41
    log "PAT received."
  else
    local tmpdir="/dev/shm"; [[ ! -d "$tmpdir" || ! -w "$tmpdir" ]] && tmpdir="$HOME/.ssh"
    local tmpkey="$tmpdir/tmp_key_${DATE_TAG}_$$"; TEMP_FILES+=("$tmpkey")
    warn "Paste your PRIVATE SSH KEY now. Press Ctrl+D when finished."
    if [[ "$DRY_RUN" == "true" ]]; then log "[DRY-RUN] Skipping key paste."; return; fi
    if ! cat > "$tmpkey"; then error "Failed to read key input." 42; fi
    chmod 600 "$tmpkey"; ssh-add "$tmpkey" || error "Failed to add temporary key to agent." 43
    AGENT_FORWARDING="true"; log "Temporary key added to agent."
    if command_exists shred; then shred -u "$tmpkey" && log "Securely removed temp key from disk."; else rm -f "$tmpkey" && log "Removed temp key from disk."; fi
  fi
}

select_repo() {
  info "[3.3] Repository Selection"
  local users=("atnplex" "anguy079" "atngit2")
  local gh_user_sel=""
  while [[ -z "$gh_user_sel" ]]; do gh_user_sel=$(menu_select users "Select GitHub User:"); done
  if [[ "$gh_user_sel" == "MANUAL" ]]; then read -r -p "Enter GitHub username: " GH_USER; else GH_USER="$gh_user_sel"; fi

  local api_out; api_out=$(make_temp)
  local curl_cmd="curl -s -H 'Accept: application/vnd.github.v3+json'"
  if [[ -n "${GH_PAT:-}" ]]; then curl_cmd+=" -H 'Authorization: token $GH_PAT'"; fi
  curl_cmd+=" 'https://api.github.com/users/${GH_USER}/repos?sort=updated&per_page=99'"
  retry 30 2 50 bash -lc "$curl_cmd | (jq -r '.[].full_name' || true) | sort > '$api_out'"

  mapfile -t REPOS < "$api_out"
  local repo_sel=""
  while [[ -z "$repo_sel" ]]; do repo_sel=$(menu_select REPOS "Select Repository:"); done
  if [[ "$repo_sel" == "MANUAL" ]]; then read -r -p "Enter Repo (user/repo): " GH_REPO; else GH_REPO="$repo_sel"; fi
  if [[ -z "${GH_REPO:-}" || "$GH_REPO" != */* ]]; then error "Invalid repository format. Expected user/repo." 50; fi
  log "Target Repository: $GH_REPO"
}

# ============================================================
# 4. Deployment logic
# ============================================================

generate_and_register() {
  info "[4.1] Generating New Deploy Key..."
  [[ -z "${GH_REPO:-}" ]] && error "GH_REPO not set; cannot generate key." 60

  local slug; slug=$(echo "$GH_REPO" | tr '/' '_')
  local base_key_name="id_ed25519_${HOSTNAME}_${slug}_${DATE_TAG}"
  KEY_PATH="$HOME/.ssh/$base_key_name"
  local count=1
  while [[ -f "$KEY_PATH" || -f "${KEY_PATH}.pub" ]]; do KEY_PATH="$HOME/.ssh/${base_key_name}_${count}"; ((count++)); done
  PUB_PATH="${KEY_PATH}.pub"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would generate key at: $KEY_PATH"
  else
    ssh-keygen -t ed25519 -f "$KEY_PATH" -C "$HOSTNAME Deploy Key" -N "" || error "SSH Key Generation Failed." 60
    chmod 600 "$KEY_PATH"; chmod 644 "$PUB_PATH"
    backup_file "$KEY_PATH"; backup_file "$PUB_PATH"
    audit "Key pair backed up to: $BACKUP_DIR"
    log "Key generated: $KEY_PATH"
  fi

  info "[4.2] Registering Key with GitHub..."
  local pub_content; pub_content=$(cat "$PUB_PATH" 2>/dev/null || echo "dry-run-key")
  [[ -z "${pub_content:-}" ]] && error "Public key content empty." 70

  if [[ "$AGENT_FORWARDING" == "true" && "$GH_AVAILABLE" == "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then log "[DRY-RUN] Would register via 'gh' CLI."; return; fi
    local gh_err; gh_err=$(make_temp)
    if ! gh repo deploy-key add "$PUB_PATH" --repo "$GH_REPO" --title "$HOSTNAME $DATE_TAG" --allow-write 2> "$gh_err"; then
      local err_msg; err_msg=$(cat "$gh_err")
      if [[ "$err_msg" == *"already in use"* ]]; then warn "Key already exists on GitHub (Skipping registration)."; else error "gh CLI failed: $err_msg" 71; fi
    else
      log "Key registered successfully via 'gh'."
    fi
  else
    if [[ -z "${GH_PAT:-}" ]]; then
      warn "No PAT available. Cannot register key via API."
      warn "MANUAL ACTION REQUIRED: Add this key to $GH_REPO manually:"; echo "$pub_content"; return
    fi
    if [[ "$DRY_RUN" == "true" ]]; then log "[DRY-RUN] Would register via REST API (curl)."; return; fi
    local json_payload; json_payload=$(jq -n --arg t "$HOSTNAME $DATE_TAG" --arg k "$pub_content" '{title: $t, key: $k, read_only: false}')
    local curl_out; curl_out=$(make_temp)
    local http_code; http_code=$(curl -s -w "%{http_code}" -o "$curl_out" -X POST \
      -H "Authorization: token $GH_PAT" -d "$json_payload" "https://api.github.com/repos/$GH_REPO/keys")
    if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
      log "Key registered successfully via API."
    else
      local response_body; response_body=$(cat "$curl_out")
      if [[ "$response_body" == *"already in use"* ]]; then warn "Key already exists on GitHub (API)."; else error "API Registration Failed (HTTP $http_code)." 72 "$response_body"; fi
    fi
  fi
}

create_config() {
  info "[4.3] Creating SSH Configuration..."
  [[ -z "${KEY_PATH:-}" || -z "${PUB_PATH:-}" || -z "${GH_REPO:-}" ]] && error "Missing key or repo info for config." 80
  local slug; slug=$(echo "$GH_REPO" | tr '/' '_')
  local base_alias="github.com-${slug}"
  local base_conf="github_${HOSTNAME}_${slug}_${DATE_TAG}"
  HOST_ALIAS="$base_alias"
  CONFIG_FILE="$SSH_CONFIG_DIR/${base_conf}.conf"
  local count=0
  while [[ -f "$CONFIG_FILE" ]]; do ((count++)); HOST_ALIAS="${base_alias}_${count}"; CONFIG_FILE="$SSH_CONFIG_DIR/${base_conf}_${count}.conf"; done

  local config_content="# Config for $GH_REPO
# Generated by $SCRIPT_NAME on $START_TIME
Host $HOST_ALIAS
  HostName github.com
  User git
  IdentityFile $KEY_PATH
  IdentitiesOnly yes
  StrictHostKeyChecking accept-new
"
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would write config to: $CONFIG_FILE"
  else
    echo "$config_content" > "$CONFIG_FILE"; chmod 600 "$CONFIG_FILE"
    backup_file "$CONFIG_FILE"; audit "SSH Config backed up to: $BACKUP_DIR"; log "SSH Config created: $CONFIG_FILE"
    if ! grep -qF "Include $SSH_CONFIG_DIR/*.conf" "$MAIN_SSH_CONFIG" 2>/dev/null; then
      echo "" >> "$MAIN_SSH_CONFIG"; echo "Include $SSH_CONFIG_DIR/*.conf" >> "$MAIN_SSH_CONFIG"; chmod 600 "$MAIN_SSH_CONFIG"
      log "Updated $MAIN_SSH_CONFIG with Include directive."
    fi
  fi
}

verify_connection() {
  info "[4.4] Post-Flight Check: Verifying Connection..."
  if [[ "$DRY_RUN" == "true" ]]; then log "[DRY-RUN] Skipping connection test."; return; fi
  local verify_out; verify_out=$(make_temp)
  log "Testing SSH handshake with alias: $HOST_ALIAS..."
  ssh -o StrictHostKeyChecking=accept-new -T "$HOST_ALIAS" > "$verify_out" 2>&1 || true
  if grep -q "successfully authenticated" "$verify_out"; then
    log "✅ SUCCESS: Connection verified."; audit "Connection Verification Passed for $HOST_ALIAS"
  else
    warn "⚠️  Connection Test Failed."; warn "Output: $(cat "$verify_out")"; audit "Connection Verification FAILED for $HOST_ALIAS"
  fi
}

# ============================================================
# 5. Main execution
# ============================================================

main() {
  check_permissions
  print_header

  # Select tmpfs-backed working dir if available
  TMP_WORKDIR="$(choose_tmp_workdir)"
  log "Working dir selected: $TMP_WORKDIR"

  # # Kick off pure checks immediately
  # check_internet &       # ping
  # detect_env &           # grep os-release
  # check_deps &           # command_exists + optional prompt/install
  # wait                   # synchronize

  # run_parallel check_internet detect_env check_deps    # Only use for pure checks, not installs, to avoid package manager lock contention
  run_parallel_buffered check_internet detect_env prewarm_github_ssh
  check_deps   # keep sequential to avoid package manager lock contention

  read MENU_ROWS MENU_COLS < <(get_terminal_size)  # Capture terminal geometry once dependencies are confirmed

  setup_cron
  choose_auth_method

  # Show repo guesses before API call
  mapfile -t FS_GUESSES < <(guess_repo_candidates "$(pwd)")
  if (( ${#FS_GUESSES[@]} )); then
    log "Preliminary repo guesses (from filesystem):"
    for g in "${FS_GUESSES[@]}"; do echo "  - $g"; done
  fi

  select_repo
  generate_and_register
  create_config
  verify_connection

  local end_time; end_time="$(date '+%Y-%m-%d %H:%M:%S %Z')"
  audit "Script Finished at $end_time"
  print_footer
}

main "$@"
