#!/bin/bash
# Cloudflared Watchdog Script with Auto-Reconnect
# This script monitors cloudflared and automatically restarts it if it stops

CONFIG_DIR="/boot/config/plugins/cloudflared/config"
LOG_FILE="/var/log/cloudflared/cloudflared.log"
CTL_SCRIPT="/usr/local/emhttp/plugins/cloudflared/scripts/cloudflaredctl"
CHECK_INTERVAL=30 # Check every 30 seconds
MAX_RESTART_ATTEMPTS=5
RESTART_BACKOFF=60 # Wait 60 seconds between rapid restarts

# Ensure log directory and file exist
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE" 2> /dev/null

log_message() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] WATCHDOG: $1" >> "$LOG_FILE"
}

check_config() {
  # Check if token is configured
  if [ ! -f "$CONFIG_DIR/token" ] || [ ! -s "$CONFIG_DIR/token" ]; then
    return 1
  fi

  # Check if service is enabled in settings.json
  if [ -f "$CONFIG_DIR/settings.json" ]; then
    if ! grep -q '"enabled"[[:space:]]*:[[:space:]]*true' "$CONFIG_DIR/settings.json"; then
      return 1
    fi
  else
    return 1
  fi

  return 0
}

is_running() {
  pgrep -x cloudflared > /dev/null 2>&1
  return $?
}

start_service() {
  log_message "Starting cloudflared service..."
  if [ -x "$CTL_SCRIPT" ]; then
    "$CTL_SCRIPT" start >> "$LOG_FILE" 2>&1
    sleep 5
    if is_running; then
      log_message "Service started successfully"
      return 0
    else
      log_message "Failed to start service"
      return 1
    fi
  else
    log_message "ERROR: Control script not found or not executable"
    return 1
  fi
}

log_message "Watchdog started"

restart_count=0
last_restart=0

while true; do
  # Check if configuration is valid
  if ! check_config; then
    # Configuration not ready or service disabled, skip this cycle
    sleep "$CHECK_INTERVAL"
    continue
  fi

  # Check if cloudflared is running
  if ! is_running; then
    current_time=$(date +%s)
    time_since_last_restart=$((current_time - last_restart))

    # Reset restart count if enough time has passed
    if [ $time_since_last_restart -gt $RESTART_BACKOFF ]; then
      restart_count=0
    fi

    # Check if we've exceeded max restart attempts
    if [ $restart_count -ge $MAX_RESTART_ATTEMPTS ]; then
      log_message "WARNING: Maximum restart attempts ($MAX_RESTART_ATTEMPTS) reached. Waiting before retry..."
      sleep $RESTART_BACKOFF
      restart_count=0
    fi

    log_message "Service not running. Attempting to restart (attempt $((restart_count + 1))/$MAX_RESTART_ATTEMPTS)..."

    if start_service; then
      restart_count=0
    else
      restart_count=$((restart_count + 1))
    fi

    last_restart=$(date +%s)
  fi

  # Wait before next check
  sleep "$CHECK_INTERVAL"
done
