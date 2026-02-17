#!/bin/bash
#
# Script Name: ssh_setup.sh
# Date:        2025-11-11
# Purpose:     Interactively sets up a new SSH key for a specific service
#              (GitHub, GitLab, etc.), configures ~/.ssh/config,
#              sets git identity, and adds the key to the ssh-agent.
#
set -euo pipefail

# --- Configuration & Logging ---
readonly timestamp=$(date +%Y-%m-%d_%H%M%S)
readonly log_file=~/ssh_git_setup_log_"$timestamp".log
readonly backup_dir=~/secrets/$timestamp
mkdir -p ~/.ssh "$backup_dir"
touch "$log_file"

if [[ -t 1 ]]; then
  readonly green="\033[1;32m"
  readonly yellow="\033[1;33m"
  readonly reset="\033[0m"
else
  readonly green=""; readonly yellow=""; readonly reset=""
fi

log() {
  printf "${green}[$(date +'%Y-%m-%d %T')] %s${reset}\n" "$1"
  echo "[$(date +'%Y-%m-%d %T')] $1" >> "$log_file"
}

log_warn() {
  printf "${yellow}[$(date +'%Y-%m-%d %T')] [WARNING] %s${reset}\n" "$1"
  echo "[$(date +'%Y-%m-%d %T')] [WARNING] $1" >> "$log_file"
}

log_error() {
  printf "\033[1;31m[$(date +'%Y-%m-%d %T')] [ERROR] %s${reset}\n" "$1" >&2
  echo "[$(date +'%Y-%m-%d %T')] [ERROR] $1" >> "$log_file"
}

# --- Util: Sanitizers ---
# Allows letters, numbers, underscore, dot, dash
sanitize_username() {
  echo "$1" | tr -cd '[:alnum:]_.-'
}
# Allows letters, numbers, underscore, dot, dash, @
sanitize_email() {
  echo "$1" | tr -cd '[:alnum:]_.-@'
}
# Allows letters, numbers, dot, dash (for hostnames)
sanitize_hostname() {
  echo "$1" | tr -cd '[:alnum:].-'
}
# Allows letters, numbers, dot, dash, underscore (for alias)
sanitize_alias() {
  echo "$1" | tr -cd '[:alnum:].-_'
}

# --- Dependency Check & Install ---
install_deps() {
  local pm_cmd="" git_pkg="" ssh_pkg="" install_cmd="" sudo_prefix=""
  [[ "$(id -u)" -ne 0 ]] && sudo_prefix="sudo "
  if command -v apt-get &>/dev/null; then
    pm_cmd="apt-get"; git_pkg="git"; ssh_pkg="openssh-client"
    install_cmd="${sudo_prefix}$pm_cmd install -y"
  elif command -v dnf &>/dev/null; then
    pm_cmd="dnf"; git_pkg="git"; ssh_pkg="openssh-clients"
    install_cmd="${sudo_prefix}$pm_cmd install -y"
  elif command -v yum &>/dev/null; then
    pm_cmd="yum"; git_pkg="git"; ssh_pkg="openssh-clients"
    install_cmd="${sudo_prefix}$pm_cmd install -y"
  elif command -v pacman &>/dev/null; then
    pm_cmd="pacman"; git_pkg="git"; ssh_pkg="openssh"
    install_cmd="${sudo_prefix}$pm_cmd -S --noconfirm"
  elif command -v apk &>/dev/null; then
    pm_cmd="apk"; git_pkg="git"; ssh_pkg="openssh-client"
    install_cmd="${sudo_prefix}$pm_cmd add"
  else
    log_error "No recognized package manager found."
    return 1
  fi

  log "Detected package manager: $pm_cmd"
  local packages=()
  ! command -v git &>/dev/null && packages+=("$git_pkg")
  [[ -n "$ssh_pkg" ]] && (! command -v ssh-keygen &>/dev/null || ! command -v ssh-agent &>/dev/null || ! command -v ssh-add &>/dev/null) && packages+=("$ssh_pkg")
  if [[ ${#packages[@]} -eq 0 ]]; then log "[✔] All required commands are present."; return 0; fi

  log "Missing packages: ${packages[*]}"
  read -p "Attempt to install them? (y/N): " choice
  [[ "$choice" =~ ^[Yy]$ ]] || { log "Installation skipped."; return 1; }
  log "Attempting installation..."
  if ! eval "$install_cmd ${packages[*]}"; then
    log_error "Installation failed."
    return 1
  fi
  log "[✔] Installation complete."
}

check_deps() {
  log "Checking dependencies..."
  local missing=0
  for cmd in ssh-keygen ssh-agent ssh-add git; do
    if ! command -v "$cmd" &>/dev/null; then
      log_warn "Missing: $cmd"; missing=1
    else
      log "[✔] Found $cmd"
    fi
  done
  if ((missing)); then install_deps; else log "[✔] All dependencies satisfied."; fi
}

# --- Interactive Service Menu ---
get_service_details() {
  log "Select the service to configure:"
  local services=("Cancel/Exit" "GitHub" "GitLab" "Bitbucket" "Azure DevOps" "Custom/manual input")
  local service_aliases=("" "github-alex" "gitlab-alex" "bitbucket-alex" "azure-alex" "")
  local hostnames=("" "github.com" "gitlab.com" "bitbucket.org" "ssh.dev.azure.com" "")
  while true; do
    for i in "${!services[@]}"; do
      printf "  %d = %s\n" "$i" "${services[$i]}"
    done
    read -p "Your choice (0-$((${#services[@]}-1)) or manual host: " sel
    [[ "$sel" =~ ^[0-9]+$ ]] && ((sel >=0 && sel < ${#services[@]})) || {
      # manual input path
      if [[ -n "$sel" ]]; then
        hostname=$(sanitize_hostname "$sel")
        host_alias="${hostname%%.*}-alex"
        service="Custom"
        break
      fi
      log_error "Invalid selection."
      continue
    }
    case $sel in
      0) log "Cancelled."; exit 0 ;;
      1|2|3|4)
        hostname="${hostnames[$sel]}"
        host_alias="${service_aliases[$sel]}"
        service="${services[$sel]}"
        break
        ;;
      5)
        read -p "Enter custom hostname (e.g. gitea.example.com): " hostname
        hostname=$(sanitize_hostname "$hostname")
        host_alias="${hostname%%.*}-alex"
        service="Custom"
        break ;;
      *) log_error "Invalid selection." ;;
    esac
  done
  read -p "Enter SSH alias [default: $host_alias]: " alias_input
  host_alias=$(sanitize_alias "${alias_input:-$host_alias}")
  log "Using service '$hostname' with alias '$host_alias'"
}

# --- Git Identity ---
setup_git_identity() {
  log "Configure Git identity:"

  # CRITICAL FIX: Use separate read/sanitize for user and email
  local user_input
  read -p "Git username [anguy079]: " user_input
  git_user=$(sanitize_username "${user_input:-anguy079}")

  local email_input
  read -p "Git email [anguy079@gmail.com]: " email_input
  git_email=$(sanitize_email "${email_input:-anguy079@gmail.com}")

  [[ -z "$git_user" || -z "$git_email" ]] && { log_error "Git username and email cannot be empty."; exit 1; }

  log "This will apply the Git identity globally (--global)."
  git config --global user.name "$git_user"
  git config --global user.email "$git_email"
  git config --global init.defaultBranch main
  git config --global core.editor nano
  log "[✔] Global Git identity set: $git_user <$git_email>"
}

# --- Passphrase ---
get_passphrase() {
  local pass1 pass2
  while true; do
    read -s -p "Enter passphrase (empty for none): " pass1; echo
    read -s -p "Confirm passphrase: " pass2; echo
    [[ "$pass1" == "$pass2" ]] && { echo "$pass1"; return; }
    log_warn "Passphrases do not match. Please try again."
  done
}

# --- Backup Handling ---
handle_existing_file() {
  local f="$1"
  if [[ ! -e "$f" ]]; then return 0; fi
  log_warn "File already exists: $f"

  local options=("Cancel/Exit" "Overwrite" "Backup with .backup" "Manual filename")
  while true; do
    for i in "${!options[@]}"; do printf "  %d = %s\n" "$i" "${options[$i]}"; done
    read -p "Your choice (0-3): " sel
    if [[ "$sel" =~ ^[0-3]$ ]]; then
      case $sel in
        0) log "Cancelled."; exit 0 ;;
        1) log "Overwriting $f"; return 0 ;;
        2) mv "$f" "$f.backup"; log "Moved $f to $f.backup"; return 0 ;;
        3) read -p "Enter backup filename: " newname; mv "$f" "$newname"; log "Moved $f to $newname"; return 0 ;;
      esac
    fi
    log_warn "Invalid choice."
  done
}

# --- SSH Key ---
handle_ssh_key() {
  local safe_user
  safe_user=$(sanitize_username "$git_user") # Use the same sanitizer

  key_name="id_ed25519_${safe_user}_${host_alias}"
  key_path=~/.ssh/$key_name
  pub_path="$key_path.pub"

  handle_existing_file "$key_path"
  handle_existing_file "$pub_path"

  log "Choose SSH key setup:"
  local key_opts=("Cancel/Exit" "Generate new key" "Paste existing private key")
  while true; do
    for i in "${!key_opts[@]}"; do printf "  %d = %s\n" "$i" "${key_opts[$i]}"; done
    read -p "Your choice (0-2): " sel
    if [[ "$sel" =~ ^[0-2]$ ]]; then
      case $sel in
        0) log "Cancelled."; exit 0 ;;
        1)
          log "Generating new key..."
          read -p "Encrypt key with passphrase? (y/N): " enc
          local passphrase=""
          [[ "$enc" =~ ^[Yy]$ ]] && passphrase=$(get_passphrase)
          ssh-keygen -t ed25519 -f "$key_path" -C "$git_email" -N "$passphrase"
          log "[✔] New key pair generated."
          break ;;
        2)
          log "Paste your PRIVATE key. Press Ctrl+D when finished."
          if ! cat > "$key_path"; then
              log_error "No input received. Aborting."
              exit 1
          fi
          log "[✔] Private key saved."
          log "Generating public key from private key..."
          if ! ssh-keygen -y -f "$key_path" > "$pub_path"; then
            log_error "Invalid private key. Could not generate public key."
            rm -f "$key_path"
            exit 1
          fi
          log "[✔] Public key generated."
          break ;;
      esac
    else
      log_warn "Invalid selection."
    fi
  done
  chmod 600 "$key_path"; chmod 644 "$pub_path"
  cp "$key_path" "$pub_path" "$backup_dir/"
  log "[✔] Keys saved and backed up to $backup_dir"
  local fingerprint checksum
  fingerprint=$(ssh-keygen -lf "$pub_path" | awk '{print $2}')
  checksum=$(sha256sum "$pub_path" | awk '{print $1}')
  log "🔐 Fingerprint: $fingerprint"
  log "🧾 SHA256 (pub): $checksum"
}

# --- SSH Config ---
update_ssh_config() {
  local cfg=~/.ssh/config
  touch "$cfg" && chmod 600 "$cfg"
  if grep -q "Host $host_alias" "$cfg"; then
    log_warn "SSH alias '$host_alias' already exists in $cfg. Skipping config update."
  else
    printf "\nHost %s\n  HostName %s\n  User git\n  IdentityFile %s\n  IdentitiesOnly yes\n" \
      "$host_alias" "$hostname" "$key_path" >> "$cfg"
    log "[✔] SSH config updated for '$host_alias'"
  fi
}

# --- SSH Agent ---
add_to_agent() {
  log "Attempting to add key to ssh-agent..."
  if [[ -z "${SSH_AUTH_SOCK-}" ]]; then
    log "Starting new ssh-agent..."
    eval "$(ssh-agent -s)" >/dev/null
  else
    log "Using existing ssh-agent."
  fi

  log "Adding key... If encrypted, you will be prompted for your passphrase."
  # CRITICAL FIX: Changed $key_key to $key_path
  if ssh-add "$key_path"; then
    log "[✔] Key added to agent."
  else
    log_warn "Could not add key to agent. Try manually: ssh-add $key_path"
  fi
}

# --- Final Summary ---
final_summary() {
  local pub_key_content
  pub_key_content=$(cat "$pub_path")
  printf "\n${green}--- ✅ Setup Complete ---${reset}\n"
  printf "Service:      %s\n" "$service"
  printf "Hostname:     %s\n" "$hostname"
  printf "SSH Alias:    %s\n" "$host_alias"
  printf "Private Key:  %s\n" "$key_path"
  printf "Public Key:   %s\n" "$pub_path"
  printf "Git Identity: %s <%s>\n" "$git_user" "$git_email"
  printf "Backup Dir:   %s\n" "$backup_dir"
  printf "Log File:     %s\n" "$log_file"
  printf "${green}------------------------${reset}\n"
  read -p "Display public key now? (y/N): " showkey
  [[ "$showkey" =~ ^[Yy]$ ]] && printf "\n${yellow}--- Public Key ---${reset}\n%s\n${yellow}------------------${reset}\n\n" "$pub_key_content"
  if command -v xclip &>/dev/null; then
    echo "$pub_key_content" | xclip -selection clipboard
    log "[✔] Public key copied to clipboard (Linux)"
  else
    log "Add this public key to your '$hostname' account manually."
  fi
}

# --- Main ---
main() {
  log "Starting SSH & Git Setup Script..."
  declare -g service hostname host_alias git_user git_email key_name key_path pub_path
  check_deps
  get_service_details
  setup_git_identity
  handle_ssh_key
  update_ssh_config
  add_to_agent
  final_summary
  log "Script finished."
}

main "$@"
