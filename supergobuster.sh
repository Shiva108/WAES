#!/usr/bin/env bash
#==============================================================================
# SuperGobuster - Multi-wordlist directory enumeration
# Part of WAES - Web Auto Enum & Scanner
#==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration if available
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh" 2>/dev/null || true

#==============================================================================
# CONFIGURATION
#==============================================================================

# Default wordlist directories (in priority order)
WORDLIST_PATHS=(
    "${SCRIPT_DIR}/SecLists/Discovery/Web-Content"
    "/usr/share/wordlists/seclists/Discovery/Web-Content"
    "/usr/share/seclists/Discovery/Web-Content"
)

KALI_DIRBUSTER="/usr/share/wordlists/dirbuster"

# Gobuster settings
THREADS="${GOBUSTER_THREADS:-10}"
TIMEOUT="${SCAN_TIMEOUT:-300}"
STATUS_CODES="${GOBUSTER_STATUS_CODES:-200,204,301,302,307,401,403,405,500}"

# Extensions to check
EXTENSIONS=("txt" "php" "html" "htm" "asp" "aspx" "jsp" "bak" "old" "conf")

#==============================================================================
# FUNCTIONS
#==============================================================================

usage() {
    cat << EOF
Usage: ${0##*/} <URL> [OPTIONS]

Arguments:
    URL             Target URL (e.g., http://10.10.10.130:80)

Options:
    -t <threads>    Number of threads (default: 10)
    -x <ext>        Comma-separated extensions to check
    -s <codes>      Status codes to report (default: 200,204,301,302,307,401,403,405,500)
    -q              Quiet mode
    -h              Show this help

Examples:
    ${0##*/} http://10.10.10.130
    ${0##*/} http://10.10.10.130:8080 -t 20 -x php,bak
EOF
    exit 1
}

log_info() {
    [[ "${QUIET:-false}" != "true" ]] && echo "[*] $*"
}

log_success() {
    echo "[+] $*"
}

log_error() {
    echo "[!] $*" >&2
}

# Find wordlist directory
find_wordlist_dir() {
    for dir in "${WORDLIST_PATHS[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

# Find specific wordlist file
find_wordlist() {
    local name="$1"
    local wordlist_dir
    
    # Try standard paths
    wordlist_dir=$(find_wordlist_dir 2>/dev/null) || true
    
    if [[ -n "$wordlist_dir" ]] && [[ -f "${wordlist_dir}/${name}" ]]; then
        echo "${wordlist_dir}/${name}"
        return 0
    fi
    
    # Try Kali dirbuster location
    if [[ -f "${KALI_DIRBUSTER}/${name}" ]]; then
        echo "${KALI_DIRBUSTER}/${name}"
        return 0
    fi
    
    return 1
}

# Run gobuster with a wordlist
run_gobuster() {
    local url="$1"
    local wordlist="$2"
    local name="${3:-}"
    local extra_args="${4:-}"
    
    if [[ ! -f "$wordlist" ]]; then
        log_error "Wordlist not found: $wordlist"
        return 1
    fi
    
    [[ -n "$name" ]] && log_info "Scanning with: $name"
    
    # shellcheck disable=SC2086
    gobuster dir \
        -u "$url" \
        -w "$wordlist" \
        -t "$THREADS" \
        -s "$STATUS_CODES" \
        --wildcard \
        --no-error \
        $extra_args 2>/dev/null || true
}

# Run dirb with a wordlist
run_dirb() {
    local url="$1"
    local wordlist="$2"
    
    if [[ ! -f "$wordlist" ]]; then
        return 1
    fi
    
    if command -v dirb &>/dev/null; then
        log_info "Running dirb with: $(basename "$wordlist")"
        dirb "$url" "$wordlist" -r -S -N 404 2>/dev/null || true
    fi
}

#==============================================================================
# MAIN
#==============================================================================

main() {
    local url=""
    local quiet=false
    local custom_ext=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -t)
                THREADS="$2"
                shift 2
                ;;
            -x)
                custom_ext="$2"
                shift 2
                ;;
            -s)
                STATUS_CODES="$2"
                shift 2
                ;;
            -q)
                quiet=true
                QUIET=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                ;;
            *)
                if [[ -z "$url" ]]; then
                    url="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Validate URL
    if [[ -z "$url" ]]; then
        log_error "URL is required"
        usage
    fi
    
    # Check for gobuster
    if ! command -v gobuster &>/dev/null; then
        log_error "gobuster not found. Install with: apt install gobuster"
        exit 1
    fi
    
    log_info "SuperGobuster targeting: $url"
    log_info "Threads: $THREADS | Status codes: $STATUS_CODES"
    echo ""
    
    # Get wordlist directory
    local wl_dir
    wl_dir=$(find_wordlist_dir) || {
        log_error "No wordlist directory found. Check paths:"
        for path in "${WORDLIST_PATHS[@]}"; do
            echo "  - $path"
        done
        exit 1
    }
    
    log_info "Using wordlists from: $wl_dir"
    echo ""
    
    # Web server specific wordlists
    local server_lists=(
        "tomcat.txt"
        "nginx.txt"
        "apache.txt"
        "iis.txt"
    )
    
    for list in "${server_lists[@]}"; do
        local wl="${wl_dir}/${list}"
        [[ -f "$wl" ]] && run_gobuster "$url" "$wl" "$list"
    done
    
    # Common enumeration lists
    local common_lists=(
        "RobotsDisallowed-Top1000.txt"
        "ApacheTomcat.fuzz.txt"
        "common.txt"
    )
    
    for list in "${common_lists[@]}"; do
        local wl="${wl_dir}/${list}"
        [[ -f "$wl" ]] && run_gobuster "$url" "$wl" "$list"
    done
    
    # Main directory list (Kali default)
    local main_wordlist
    main_wordlist=$(find_wordlist "directory-list-2.3-medium.txt") || true
    
    if [[ -n "$main_wordlist" ]]; then
        log_info "Running comprehensive scan with directory-list-2.3-medium.txt"
        
        # Basic scan
        run_gobuster "$url" "$main_wordlist" "directories" ""
        
        # Extension scans
        if [[ -n "$custom_ext" ]]; then
            run_gobuster "$url" "$main_wordlist" "with extensions: $custom_ext" "-x $custom_ext"
        else
            for ext in "${EXTENSIONS[@]:0:3}"; do
                run_gobuster "$url" "$main_wordlist" "extension: $ext" "-x $ext"
            done
        fi
    fi
    
    echo ""
    log_success "SuperGobuster complete!"
}

main "$@"
