#!/usr/bin/env bash

# Colors
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

ensure_tool() {
    local cmd="$1"
    local package="$2"
    
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${YELLOW}[Auto-Heal] Missing tool: $cmd. Installing $package...${NC}"
        
        # Try sudo apt-get (Debian/Ubuntu)
        if command -v apt-get &> /dev/null; then
            sudo apt-get update -qq && sudo apt-get install -y -qq "$package"
        # Try snap (Universal)
        elif command -v snap &> /dev/null; then
            sudo snap install "$package"
        # Try brew (Mac/Linux)
        elif command -v brew &> /dev/null; then
            brew install "$package"
        else
            echo -e "${RED}[Error] Could not install $cmd. Please install manually.${NC}"
            return 1
        fi
        
        # Verify installation
        if command -v "$cmd" &> /dev/null; then
            echo -e "${GREEN}[Auto-Heal] $cmd installed successfully.${NC}"
        else
            return 1
        fi
    fi
}

check_and_fix_environment() {
    echo -e "${YELLOW}🔍 Checking Environment Dependencies...${NC}"
    
    # Critical tools for this pipeline
    ensure_tool "jq" "jq"
    ensure_tool "curl" "curl"
    ensure_tool "shellcheck" "shellcheck"
    ensure_tool "git" "git"
    
    # Formatters (often missing)
    ensure_tool "shfmt" "shfmt" 
    
    # If shfmt fails via apt (common on older debian), try snap
    if ! command -v shfmt &> /dev/null; then
         if command -v snap &> /dev/null; then
             sudo snap install shfmt
         fi
    fi
    
    echo -e "${GREEN}✅ Environment Healthy.${NC}"
}
