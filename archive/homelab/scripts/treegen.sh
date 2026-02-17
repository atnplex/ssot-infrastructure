#!/usr/bin/env bash
#
# Script Name: treegen.sh
# Date:        2025-11-11
# Author:      anguy079
# Purpose:     Interactive and CLI-driven directory tree generator.
#              Generates a list of files/dirs with [D]/[F] prefixes.
# Output:      Configurable via --outfile, --format, --depth, and ignore filters.
# Log cleanup: Manually clean /tmp/treegen_${USER}_*.log files if space is a concern.
#

set -euo pipefail

# --- Configuration & Logging ---
OUTFILE="/tmp/tree_output.txt"
LOGFILE="/tmp/treegen_${USER}_$(date +%Y%m%d_%H%M%S).log"
FORMAT="plain"
DEPTH=""
IGNORE_DIRS=()
IGNORE_EXTS=()

if [[ -t 1 ]]; then
  green="\033[1;32m"; yellow="\033[1;33m"; red="\033[1;31m"; reset="\033[0m"
else
  green=""; yellow=""; red=""; reset=""
fi

log()       { printf "${green}[%s] %s${reset}\n" "$(date +'%F %T')" "$1"; echo "[$(date +'%F %T')] $1" >>"$LOGFILE"; }
log_warn()  { printf "${yellow}[%s] [WARN] %s${reset}\n" "$(date +'%F %T')" "$1"; echo "[$(date +'%F %T')] [WARN] $1" >>"$LOGFILE"; }
log_error() { printf "${red}[%s] [ERROR] %s${reset}\n" "$(date +'%F %T')" "$1" >&2; echo "[$(date +'%F %T')] [ERROR] $1" >>"$LOGFILE"; }

# --- Dependency Check ---
check_deps() {
  log "Checking dependencies..."
  command -v tree >/dev/null || { log_error "tree command not found. Please install it."; exit 1; }
  command -v file >/dev/null || { log_error "file command not found. Please install it."; exit 1; }
  log "[✔] Found 'tree' and 'file'"
}

src="."
hflag=""
contents=0

usage() {
  echo "Usage: $0 [--src DIR] [--hidden yes|no] [--contents yes|no] [--outfile FILE]"
  echo "       [--format plain|json|yaml] [--depth N] [--ignore-dir NAME] [--ignore-ext EXT]"
  echo
  echo "Examples:"
  echo "  $0 --src /etc --hidden yes --contents no --outfile /tmp/etc_tree.json --format json --depth 2"
  echo "  $0 --ignore-dir .git --ignore-dir node_modules --ignore-ext log"
  echo "  $0  # (interactive menu)"
  exit 0
}

# --- Improved duplicate removal ---
dedupe_array() {
  printf "%s\n" "$@" | awk '!seen[$0]++'
}

check_outfile() {
  if [[ "$OUTFILE" == "-" || "$OUTFILE" == "/dev/stdout" ]]; then
    return 0 # Allow writing to stdout
  fi
  
  if [[ -e "$OUTFILE" && ! -w "$OUTFILE" ]]; then
    log_error "Output file is not writable: $OUTFILE"
    return 1
  fi
  if [[ -L "$OUTFILE" ]]; then
    log_error "Refusing to write to symlink: $OUTFILE"
    return 1
  fi
  
  # Try to create/touch the file to check directory permissions
  if ! touch "$OUTFILE" 2>/dev/null; then
    log_error "Cannot create or write to output file: $OUTFILE"
    return 1
  fi
  return 0
}

# --- Tree Generation ---
generate_tree() {
  IGNORE_DIRS=($(dedupe_array "${IGNORE_DIRS[@]}"))
  IGNORE_EXTS=($(dedupe_array "${IGNORE_EXTS[@]}"))

  log "Generating tree for $src (hidden=$([[ -n $hflag ]] && echo yes || echo no), contents=$contents, format=$FORMAT, depth=${DEPTH:-all})..."

  local depth_flag=""
  [[ -n "$DEPTH" ]] && depth_flag="-L $DEPTH"

  # Build ignore patterns for tree
  local ignore_args=()
  for d in "${IGNORE_DIRS[@]}"; do
    ignore_args+=( -I "$d" )
  done
  for e in "${IGNORE_EXTS[@]}"; do
    ignore_args+=( -I "*.$e" )
  done

  # Check output file writability just before generation
  if ! check_outfile; then
    return 1
  fi

  log "Scanning directory structure..."
  local paths=()
  if ! mapfile -t paths < <(tree -if $hflag $depth_flag --dirsfirst "$src" "${ignore_args[@]}"); then
    log_error "tree command failed (e.g., directory not found)"
    return 1
  fi

  local lines=()
  local count_files=0 count_dirs=0

  for path in "${paths[@]}"; do
    if [[ -d "$path" ]]; then
      lines+=("[D] $path")
      ((count_dirs++))
    elif [[ -f "$path" ]]; then
      lines+=("[F] $path")
      ((count_files++))
    fi
  done

  log "Formatting output..."

  case "$FORMAT" in
    plain)
      printf "%s\n" "${lines[@]}" > "$OUTFILE"
      ;;
    json)
      {
        echo "["
        for i in "${!lines[@]}"; do
          line="${lines[$i]}"
          type=$(echo "$line" | cut -d' ' -f1 | tr -d '[]')
          path=$(echo "$line" | cut -d' ' -f2-)
          path=$(echo "$path" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
          printf '  {"type":"%s","path":"%s"}' "$type" "$path"
          [[ $i -lt $(( ${#lines[@]} - 1 )) ]] && echo "," || echo
        done
        echo "]"
      } > "$OUTFILE"
      ;;
    yaml)
      {
        echo "---"
        for line in "${lines[@]}"; do
          type=$(echo "$line" | cut -d' ' -f1 | tr -d '[]')
          path=$(echo "$line" | cut -d' ' -f2-)
          path=$(echo "$path" | sed "s/'/''/g")
          echo "- type: $type"
          echo "  path: '$path'"
        done
      } > "$OUTFILE"
      ;;
    *) log_error "Unsupported format: $FORMAT"; exit 1 ;;
  esac

  if [[ $contents -eq 1 ]]; then
    if [[ "$FORMAT" != "plain" ]]; then
      log_warn "File contents can only be added to 'plain' format. Skipping."
    else
      log "Appending file contents..."
      echo -e "\n===== FILE CONTENTS =====\n" >> "$OUTFILE"
      for line in "${lines[@]}"; do
        [[ "$line" =~ ^\[F\] ]] || continue
        local f
        f=$(echo "$line" | cut -d' ' -f2-)

        echo "--- $f ---" >> "$OUTFILE"
        if [[ "$(file -b --mime-type "$f" 2>/dev/null)" == "text/"* ]]; then
          if ! cat "$f" >> "$OUTFILE" 2>/dev/null; then
            log_warn "Could not read $f (permission issue?)"
          fi
        else
          log_warn "Skipping binary file: $f"
          echo "--- (binary file, content skipped) ---" >> "$OUTFILE"
        fi
        echo >> "$OUTFILE"
      done
    fi
  fi

  if [[ ! -s "$OUTFILE" ]]; then
    [[ "$OUTFILE" != "-" && "$OUTFILE" != "/dev/stdout" ]] && rm -f "$OUTFILE"
    log_error "Output file is empty. No files or directories found matching criteria."
    return 1
  else
    log "Tree written to $OUTFILE"
    log "Summary: $count_dirs directories, $count_files files."
    
    # --- BUG FIX: Only append summary to 'plain' format ---
    if [[ "$FORMAT" == "plain" ]]; then
        echo -e "\nSummary: $count_dirs directories, $count_files files." >> "$OUTFILE"
    fi
  fi
}

menu() {
  while true; do
    echo -e "\n${yellow}--- TreeGen Menu ---${reset}"
    echo " 1) Set source directory   ($src)"
    echo " 2) Toggle hidden files    ($([[ -n $hflag ]] && echo yes || echo no))"
    echo " 3) Toggle file contents   ($([[ $contents -eq 1 ]] && echo yes || echo no))"
    echo " 4) Set output file        ($OUTFILE)"
    echo " 5) Set format             ($FORMAT)"
    echo " 6) Set depth limit        (${DEPTH:-all})"
    echo
    echo " 7) Add ignore directory   (${IGNORE_DIRS[*]:-(none)})"
    echo " 8) Add ignore extension   (${IGNORE_EXTS[*]:-(none)})"
    echo " 9) Clear ignore lists"
    echo
    echo " G) Generate tree"
    echo " 0) Exit"
    echo
    read -p "Choice: " sel
    case "$sel" in
      1)
        read -p "Enter directory [default: $src]: " d
        d="${d:-$src}"
        if [[ -d "$d" ]]; then
          src="$d"
        else
          log_error "Invalid directory"
        fi
        ;;
      2) [[ -n "$hflag" ]] && hflag="" || hflag="-a";;
      3) [[ $contents -eq 1 ]] && contents=0 || contents=1;;
      4)
        read -p "Enter output file path [default: $OUTFILE]: " of
        OUTFILE="${of:-$OUTFILE}"
        # --- IMPROVEMENT: Check writability immediately ---
        if ! check_outfile; then
            log_warn "Reverting to previous valid path."
            OUTFILE="${OUTFILE:-/tmp/tree_output.txt}" # Revert on failure
        fi
        ;;
      5)
        # --- IMPROVEMENT: Use select menu for valid format ---
        log "Select output format:"
        PS3="Your choice: "
        select f in "plain" "json" "yaml"; do
            if [[ -n "$f" ]]; then
                FORMAT="$f"
                break
            else
                log_warn "Invalid choice. Try again."
            fi
        done
        ;;
      6)
        read -p "Enter depth (number, empty=all) [default: $DEPTH]: " d
        # --- IMPROVEMENT: Validate input is a number or empty ---
        if [[ "$d" =~ ^[0-9]+$ || -z "$d" ]]; then
            DEPTH="$d"
        else
            log_error "Invalid depth. Must be a number."
        fi
        ;;
      7)
        read -p "Enter directory name to ignore (e.g., .git): " d
        if [[ -n "$d" ]]; then
          IGNORE_DIRS+=("$d")
        else
          log_warn "No ignore directory entered."
        fi
        IGNORE_DIRS=($(dedupe_array "${IGNORE_DIRS[@]}"))
        ;;
      8)
        read -p "Enter file extension to ignore (without dot, e.g., log): " e
        if [[ -n "$e" ]]; then
          IGNORE_EXTS+=("$e")
        else
          log_warn "No ignore extension entered."
        fi
        IGNORE_EXTS=($(dedupe_array "${IGNORE_EXTS[@]}"))
        ;;
      9) log "Ignore lists cleared."; IGNORE_DIRS=(); IGNORE_EXTS=();;
      G|g) generate_tree ;;
      0) log "Exiting."; exit 0 ;;
      *) log_warn "Invalid choice." ;;
    esac
  done
}

# --- Main ---
check_deps

cli_mode=""
while [[ $# -gt 0 ]]; do
  cli_mode=1
  case "$1" in
    --src)
      [[ -n "${2-}" && ! "$2" =~ ^-- && -d "$2" ]] || { log_error "Missing or invalid directory for --src"; usage; }
      src="$2"; shift 2 ;;
    --hidden)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --hidden"; usage; }
      case "$2" in
        yes|y|1) hflag="-a" ;;
        no|n|0) hflag="" ;;
        *) log_error "Invalid value for --hidden (use yes/no)"; usage ;;
      esac
      shift 2 ;;
    --contents)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --contents"; usage; }
      case "$2" in
        yes|y|1) contents=1 ;;
        no|n|0) contents=0 ;;
        *) log_error "Invalid value for --contents (use yes/no)"; usage ;;
      esac
      shift 2 ;;
    --outfile)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --outfile"; usage; }
      OUTFILE="$2"; shift 2 ;;
    --format)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --format"; usage; }
      FORMAT="$2"; shift 2 ;;
    --depth)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --depth"; usage; }
      DEPTH="$2"; shift 2 ;;
    --ignore-dir)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --ignore-dir"; usage; }
      IGNORE_DIRS+=("$2"); IGNORE_DIRS=($(dedupe_array "${IGNORE_DIRS[@]}")); shift 2 ;;
    --ignore-ext)
      [[ -n "${2-}" && ! "$2" =~ ^-- ]] || { log_error "Missing value for --ignore-ext"; usage; }
      IGNORE_EXTS+=("$2"); IGNORE_EXTS=($(dedupe_array "${IGNORE_EXTS[@]}")); shift 2 ;;
    -h|--help) usage ;;
    *) log_error "Unknown option: $1"; usage ;;
  esac
done

if [[ -n "$cli_mode" ]]; then
  generate_tree
else
  menu
fi
