#!/usr/bin/env bash

# CONFIG
# Standardize this variable for all downstream scripts
export ATN_WORK_DIR="${ATN_WORK_DIR:-/_atn}"
MAX_RAM_GB=12

# Colors
BOLD='\033[1m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_fs_table() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                 RAM WORKSPACE STATUS                       ║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════╣${NC}"
    
    # Capture df output for the specific mount
    local df_out=$(df -h "$ATN_WORK_DIR" | tail -n 1)
    local size=$(echo "$df_out" | awk '{print $2}')
    local used=$(echo "$df_out" | awk '{print $3}')
    local avail=$(echo "$df_out" | awk '{print $4}')
    local use_pct=$(echo "$df_out" | awk '{print $5}')
    
    printf "${BLUE}║${NC} %-12s : ${BOLD}%-32s${NC} ${BLUE}║${NC}\n" "Mount Point" "$ATN_WORK_DIR"
    printf "${BLUE}║${NC} %-12s : ${BOLD}%-32s${NC} ${BLUE}║${NC}\n" "Size" "$size"
    printf "${BLUE}║${NC} %-12s : ${BOLD}%-32s${NC} ${BLUE}║${NC}\n" "Used" "$used ($use_pct)"
    printf "${BLUE}║${NC} %-12s : ${BOLD}%-32s${NC} ${BLUE}║${NC}\n" "Available" "$avail"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
}

init_ram_disk() {
    # 1. CI/Cloud Fallback
    if [[ "${GITHUB_ACTIONS:-}" == "true" ]]; then
        export ATN_WORK_DIR="${RUNNER_TEMP}/_atn"
        mkdir -p "$ATN_WORK_DIR"
        echo "✅ CI Environment detected. Using temp dir: $ATN_WORK_DIR"
        return 0
    fi

    # 2. Idempotency Check (Is it already mounted?)
    if mount | grep -q "on $ATN_WORK_DIR "; then
        # Ensure permissions are correct even if mounted
        sudo chmod 1777 "$ATN_WORK_DIR"
        print_fs_table
        return 0
    fi

    # 3. Calculation & Mounting
    local total_mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local half_mem_mb=$(( total_mem_kb / 2048 ))
    local cap_mb=$(( MAX_RAM_GB * 1024 ))
    local mount_size_mb=$(( half_mem_mb < cap_mb ? half_mem_mb : cap_mb ))

    echo -e "${YELLOW}⚡ Initializing RAM Disk (${mount_size_mb}MB)...${NC}"
    
    sudo mkdir -p "$ATN_WORK_DIR"
    sudo mount -t tmpfs -o size=${mount_size_mb}m,mode=1777 tmpfs "$ATN_WORK_DIR"
    
    if [ $? -eq 0 ]; then
        print_fs_table
    else
        echo -e "${RED}❌ Failed to mount tmpfs. Falling back to disk /tmp/_atn${NC}"
        export ATN_WORK_DIR="/tmp/_atn"
        mkdir -p "$ATN_WORK_DIR"
    fi
}

# Run (only when executed directly)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  init_ram_disk
fi
