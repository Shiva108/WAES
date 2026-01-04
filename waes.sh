#!/usr/bin/env bash
#==============================================================================
# WAES - Web Auto Enum & Scanner
# 2018-2024 by Shiva @ CPH:SEC
#
# A comprehensive web enumeration toolkit for CTF and penetration testing
# GitHub: https://github.com/Shiva108/WAES
#==============================================================================

set -o pipefail

#==============================================================================
# CONFIGURATION & LIBRARIES
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration and libraries
# shellcheck source=config.sh
source "${SCRIPT_DIR}/config.sh" 2>/dev/null || {
    echo "[!] Warning: config.sh not found, using defaults"
    REPORT_DIR="${SCRIPT_DIR}/report"
    VULSCAN_DIR="${SCRIPT_DIR}/vulscan"
}

# shellcheck source=lib/colors.sh
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || {
    # Fallback functions if library not found
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_info() { echo "[*] $*"; }
    print_warn() { echo "[~] $*"; }
    print_running() { echo "[>] $*"; }
    print_header() { echo "#### $1 ####"; }
    print_step() { echo -e "\nStep $1: $2"; }
}

# shellcheck source=lib/validation.sh
source "${SCRIPT_DIR}/lib/validation.sh" 2>/dev/null || {
    validate_ipv4() { [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; }
    validate_port() { [[ "$1" =~ ^[0-9]+$ ]] && (( $1 >= 1 && $1 <= 65535 )); }
    command_exists() { command -v "$1" &>/dev/null; }
}

# shellcheck source=lib/progress.sh
source "${SCRIPT_DIR}/lib/progress.sh" 2>/dev/null || true

# shellcheck source=lib/state_manager.sh
source "${SCRIPT_DIR}/lib/state_manager.sh" 2>/dev/null || true

# shellcheck source=lib/ssl_scanner.sh
source "${SCRIPT_DIR}/lib/ssl_scanner.sh" 2>/dev/null || true

# shellcheck source=lib/xss_scanner.sh
source "${SCRIPT_DIR}/lib/xss_scanner.sh" 2>/dev/null || true

# shellcheck source=lib/cms_scanner.sh
source "${SCRIPT_DIR}/lib/cms_scanner.sh" 2>/dev/null || true

# shellcheck source=lib/report_generator.sh
source "${SCRIPT_DIR}/lib/report_generator.sh" 2>/dev/null || true

#==============================================================================
# VARIABLES
#==============================================================================

VERSION="${WAES_VERSION:-1.0.0}"
TARGET=""
PORT="${DEFAULT_HTTP_PORT:-80}"
PROTOCOL="${DEFAULT_PROTOCOL:-http}"
SCAN_TYPE="full"
VERBOSE=false
QUIET=false
RESUME=false
GENERATE_HTML=false

# Tools required for scanning
REQUIRED_TOOLS=("nmap" "nikto" "gobuster" "dirb" "whatweb" "wafw00f")

# Nmap HTTP scripts
HTTPNSE="http-date,http-title,http-server-header,http-headers,http-enum,http-devframework,http-dombased-xss,http-stored-xss,http-xssed,http-cookie-flags,http-errors,http-grep,http-traceroute"

#==============================================================================
# BANNER & USAGE
#==============================================================================

show_banner() {
    if [[ "$QUIET" != "true" ]]; then
        print_header "Web Auto Enum & Scanner v${VERSION}"
        echo ""
        echo "  Auto enums HTTP/HTTPS ports and dumps results to report/"
        echo ""
    fi
}

usage() {
    cat << EOF
Usage: ${0##*/} [OPTIONS] -u <target>

Options:
    -u <target>     Target IP or domain (required)
    -p <port>       Port number (default: 80, or 443 with -s)
    -s              Use HTTPS protocol
    -t <type>       Scan type: fast, full, deep, advanced (default: full)
    -r              Resume previous scan
    -H              Generate HTML report
    -v              Verbose output
    -q              Quiet mode (minimal output)
    -h              Show this help message

Scan Types:
    fast     - Quick reconnaissance (wafw00f, nmap http-enum)
    full     - Standard scan (adds nikto, nmap scripts) [default]
    deep     - Comprehensive (adds vulscan, uniscan, fuzzing)
    advanced - Deep scan + SSL/TLS, XSS, CMS-specific scans

Examples:
    ${0##*/} -u 10.10.10.130
    ${0##*/} -u 10.10.10.130 -p 8080
    ${0##*/} -u example.com -s -t advanced -H
    ${0##*/} -u example.com -r  # Resume previous scan

EOF
}

#==============================================================================
# VALIDATION & SETUP
#==============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root. Use 'sudo ${0##*/}'"
        exit 1
    fi
}

check_tools() {
    local missing_tools=()
    
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if ! command_exists "$tool"; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_warn "Missing tools: ${missing_tools[*]}"
        print_info "Run: sudo ./install.sh to install required tools"
        
        # Continue anyway, but warn about missing functionality
        return 1
    fi
    
    return 0
}

setup_report_dir() {
    if [[ ! -d "$REPORT_DIR" ]]; then
        mkdir -p "$REPORT_DIR"
        print_info "Created report directory: $REPORT_DIR"
    fi
}

parse_args() {
    while getopts ":u:p:t:rHsvqh" opt; do
        case $opt in
            u) TARGET="$OPTARG" ;;
            p) PORT="$OPTARG" ;;
            s) 
                PROTOCOL="https"
                [[ "$PORT" == "80" ]] && PORT="443"
                ;;
            t) SCAN_TYPE="$OPTARG" ;;
            r) RESUME=true ;;
            H) GENERATE_HTML=true ;;
            v) VERBOSE=true ;;
            q) QUIET=true ;;
            h) 
                show_banner
                usage
                exit 0
                ;;
            :)
                print_error "Option -$OPTARG requires an argument"
                usage
                exit 1
                ;;
            \?)
                print_error "Invalid option: -$OPTARG"
                usage
                exit 1
                ;;
        esac
    done
    
    # Validate required arguments
    if [[ -z "$TARGET" ]]; then
        print_error "Target is required. Use -u <target>"
        usage
        exit 1
    fi
    
    # Validate port
    if ! validate_port "$PORT"; then
        print_error "Invalid port: $PORT (must be 1-65535)"
        exit 1
    fi
    
    # Validate scan type
    case "$SCAN_TYPE" in
        fast|full|deep|advanced) ;;
        *)
            print_error "Invalid scan type: $SCAN_TYPE"
            print_info "Valid types: fast, full, deep, advanced"
            exit 1
            ;;
    esac
}

#==============================================================================
# SCANNING FUNCTIONS
#==============================================================================

# Step 1: Passive reconnaissance
passive_scan() {
    print_step "0" "Passive reconnaissance (online targets only)"
    
    if command_exists whatweb; then
        print_running "whatweb - CMS and technology detection"
        whatweb -a 3 "${PROTOCOL}://${TARGET}:${PORT}" 2>&1 | tee "${REPORT_DIR}/${TARGET}_whatweb.txt"
    fi
    
    # OSIRA subdomain enum (if available)
    if [[ -x "${SCRIPT_DIR}/OSIRA/osira.sh" ]]; then
        print_running "OSIRA - Subdomain enumeration"
        "${SCRIPT_DIR}/OSIRA/osira.sh" -u "${TARGET}:${PORT}" 2>&1 | tee "${REPORT_DIR}/${TARGET}_osira.txt"
    fi
}

# Step 2: Fast scan
fast_scan() {
    print_step "1" "Fast scan - firewall detection and quick enum"
    
    # Firewall detection
    if command_exists wafw00f; then
        print_running "wafw00f - Web Application Firewall detection"
        wafw00f -a "${PROTOCOL}://${TARGET}:${PORT}" 2>&1 | tee "${REPORT_DIR}/${TARGET}_wafw00f.txt"
    fi
    
    # Quick nmap http-enum
    if command_exists nmap; then
        print_running "nmap - HTTP enumeration script"
        nmap -sSV -Pn -T4 -p "$PORT" --script http-enum "$TARGET" \
            -oA "${REPORT_DIR}/${TARGET}_nmap_http-enum"
    fi
}

# Step 3: In-depth scanning
deep_scan() {
    print_step "2" "In-depth scanning - vulnerability and service analysis"
    
    if command_exists nmap; then
        # HTTP scripts
        print_running "nmap - HTTP vulnerability scripts"
        nmap -sSV -Pn -T4 -p "$PORT" --script "$HTTPNSE" "$TARGET" \
            -oA "${REPORT_DIR}/${TARGET}_nmap_http-scripts"
        
        # Vulscan if available
        if [[ -f "${VULSCAN_DIR}/vulscan.nse" ]]; then
            print_running "nmap - Vulscan (CVSS 5.0+)"
            nmap -sSV -Pn -T4 --version-all -p "$PORT" \
                --script "${VULSCAN_DIR}/vulscan.nse" "$TARGET" \
                --script-args mincvss=5.0 \
                -oA "${REPORT_DIR}/${TARGET}_nmap_vulscan"
        fi
    fi
    
    # Nikto
    if command_exists nikto; then
        print_running "nikto - Web server scanner"
        nikto -h "${PROTOCOL}://${TARGET}" -port "$PORT" -C all -ask no -evasion A 2>&1 \
            | tee "${REPORT_DIR}/${TARGET}_nikto.txt"
    fi
    
    # Uniscan (optional)
    if command_exists uniscan; then
        print_running "uniscan - Vulnerability scanner"
        uniscan -u "${PROTOCOL}://${TARGET}:${PORT}" -qweds 2>&1 \
            | tee "${REPORT_DIR}/${TARGET}_uniscan.txt"
    fi
}

# Step 4: Directory/file fuzzing
fuzzing_scan() {
    print_step "3" "Fuzzing - Directory and file discovery"
    
    local base_url="${PROTOCOL}://${TARGET}:${PORT}"
    
    # Run supergobuster if available
    if [[ -x "${SCRIPT_DIR}/supergobuster.sh" ]]; then
        print_running "supergobuster - Multi-wordlist directory busting"
        "${SCRIPT_DIR}/supergobuster.sh" "$base_url" 2>&1 \
            | tee "${REPORT_DIR}/${TARGET}_supergobust.txt"
    elif command_exists gobuster; then
        # Fall back to simple gobuster
        print_running "gobuster - Directory enumeration"
        local wordlist
        wordlist=$(find_wordlist "directory-list-2.3-medium.txt" 2>/dev/null) || \
            wordlist="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
        
        if [[ -f "$wordlist" ]]; then
            gobuster dir -u "$base_url" -w "$wordlist" \
                -t "${GOBUSTER_THREADS:-10}" --wildcard 2>&1 \
                | tee "${REPORT_DIR}/${TARGET}_gobuster.txt"
        else
            print_warn "No wordlist found for gobuster"
        fi
    fi
}

# Standard nmap scan
standard_scan() {
    print_step "S" "Standard nmap scan (-sC -sV)"
    
    if command_exists nmap; then
        print_running "nmap - Standard scripts and version detection"
        nmap -sSCV -Pn -T4 "$TARGET" -oA "${REPORT_DIR}/${TARGET}_nmap_standard"
    fi
}

#==============================================================================
# ADVANCED SCANNING FUNCTIONS
#==============================================================================

# SSL/TLS certificate and vulnerability scanning
ssl_tls_scan() {
    print_step "SSL" "SSL/TLS Certificate and Configuration Analysis"
    
    if [[ "$PROTOCOL" == "https" ]] || [[ "$PORT" == "443" ]]; then
        if declare -f scan_ssl &>/dev/null; then
            scan_ssl "$TARGET" "$PORT" "$REPORT_DIR"
        else
            print_warn "SSL scanner module not loaded"
        fi
    else
        print_info "Skipping SSL scan (not HTTPS)"
    fi
}

# XSS vulnerability testing
xss_vulnerability_scan() {
    print_step "XSS" "Cross-Site Scripting Vulnerability Testing"
    
    local base_url="${PROTOCOL}://${TARGET}:${PORT}"
    
    if declare -f scan_xss &>/dev/null; then
        scan_xss "$base_url" "$REPORT_DIR"
    else
        print_warn "XSS scanner module not loaded"
    fi
}

# CMS-specific scanning
cms_detection_scan() {
    print_step "CMS" "Content Management System Detection & Scanning"
    
    local base_url="${PROTOCOL}://${TARGET}:${PORT}"
    
    if declare -f scan_cms &>/dev/null; then
        scan_cms "$base_url" "$REPORT_DIR"
    else
        print_warn "CMS scanner module not loaded"
    fi
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

main() {
    # Check root
    check_root
    
    # Parse arguments
    parse_args "$@"
    
    # Show banner
    show_banner
    
    # Check for resume
    if [[ "$RESUME" == "true" ]]; then
        if declare -f resume_scan &>/dev/null; then
            print_info "Attempting to resume scan..."
            local completed_stages
            completed_stages=$(resume_scan "$TARGET" "$REPORT_DIR")
            
            if [[ $? -eq 0 ]]; then
                print_success "Resuming from saved state"
                # Skip completed stages (implementation would check each stage)
            else
                print_warn "No saved state found, starting fresh scan"
            fi
        else
            print_warn "State manager module not loaded, cannot resume"
        fi
    fi
    
    # Display target info
    print_info "Target: ${PROTOCOL}://${TARGET}:${PORT}"
    print_info "Scan type: ${SCAN_TYPE}"
    
    # Setup
    check_tools
    setup_report_dir
    
    # Initialize scan state
    if declare -f init_scan_state &>/dev/null; then
        init_scan_state "$TARGET" "$SCAN_TYPE" "$REPORT_DIR"
    fi
    
    echo ""
    
    # Execute scans based on type
    case "$SCAN_TYPE" in
        fast)
            fast_scan
            [[ -f mark_stage_completed ]] && mark_stage_completed "$TARGET" "$REPORT_DIR" "fast_scan"
            ;;
        full)
            fast_scan
            deep_scan
            standard_scan
            ;;
        deep)
            passive_scan
            fast_scan
            deep_scan
            fuzzing_scan
            standard_scan
            ;;
        advanced)
            passive_scan
            fast_scan
            deep_scan
            fuzzing_scan
            standard_scan
            ssl_tls_scan
            xss_vulnerability_scan
            cms_detection_scan
            ;;
    esac
    
    # Mark scan as complete
    if declare -f complete_scan &>/dev/null; then
        complete_scan "$TARGET" "$REPORT_DIR"
    fi
    
    # Generate HTML report if requested
    if [[ "$GENERATE_HTML" == "true" ]]; then
        echo ""
        print_info "Generating HTML report..."
        
        if declare -f generate_html_report &>/dev/null; then
            generate_html_report "$TARGET" "$REPORT_DIR"
        else
            print_warn "Report generator module not loaded"
        fi
    fi
    
    # Completion message
    echo ""
    print_success "WAES completed! Results saved to: ${REPORT_DIR}/"
    
    # List generated files
    if [[ "$VERBOSE" == "true" ]]; then
        echo ""
        print_info "Generated files:"
        ls -lah "${REPORT_DIR}/${TARGET}"* 2>/dev/null || true
    fi
    
    # Show scan summary if state manager is available
    if declare -f get_scan_progress &>/dev/null; then
        echo ""
        get_scan_progress "$TARGET" "$REPORT_DIR"
    fi
}

# Run main function
main "$@"
