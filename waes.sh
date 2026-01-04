#!/usr/bin/env bash
#==============================================================================
# WAES - Web Auto Enum & Scanner
# 2018-2026 by Shiva @ CPH:SEC
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
source "${SCRIPT_DIR}/config/config.sh" 2>/dev/null || {
    echo "[!] Warning: config/config.sh not found, using defaults"
    REPORT_DIR="${SCRIPT_DIR}/report"
    VULSCAN_DIR="${SCRIPT_DIR}/external/vulscan"
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

# Phase 1: Quick Win Enhancements
# shellcheck source=lib/profile_loader.sh
source "${SCRIPT_DIR}/lib/profile_loader.sh" 2>/dev/null || true

# shellcheck source=lib/exporters/json_exporter.sh
source "${SCRIPT_DIR}/lib/exporters/json_exporter.sh" 2>/dev/null || true

# shellcheck source=lib/batch_scanner.sh
source "${SCRIPT_DIR}/lib/batch_scanner.sh" 2>/dev/null || true

# shellcheck source=lib/parallel_scan.sh
source "${SCRIPT_DIR}/lib/parallel_scan.sh" 2>/dev/null || true

# WAF Detection & Evasion
# shellcheck source=lib/waf_detector.sh
source "${SCRIPT_DIR}/lib/waf_detector.sh" 2>/dev/null || true

# shellcheck source=lib/evasion_techniques.sh
source "${SCRIPT_DIR}/lib/evasion_techniques.sh" 2>/dev/null || true

# New Feature Libraries (Phase 1)
source "${SCRIPT_DIR}/lib/chain_tracker.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/evidence_collector.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/cvss_calculator.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/writeup_generator.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/exporters/csv_exporter.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/exporters/markdown_exporter.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/owasp_scanner.sh" 2>/dev/null || true

# Phase 2: Advanced modules
source "${SCRIPT_DIR}/lib/orchestrator.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/intelligence_engine.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/report_engine/generator.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/email_compliance.sh" 2>/dev/null || true

#==============================================================================
# VARIABLES
#==============================================================================

VERSION="${WAES_VERSION:-1.2.0}"
TARGET=""
PORT=""
PORTS=(80 443)  # Default: scan both HTTP and HTTPS
PROTOCOL=""
SCAN_TYPE="full"
VERBOSE=false
QUIET=false
RESUME=false
GENERATE_HTML=false
GENERATE_JSON=false
USE_PROFILE=""
TARGETS_FILE=""
PARALLEL_MODE=false

# New Feature Flags
TRACK_CHAINS=false
EVIDENCE_MODE=true
GENERATE_WRITEUP=false
WRITEUP_FORMAT="markdown"
OWASP_SCAN=false
API_SCAN=false

# Advanced features (Phase 2)
ORCHESTRATE=false
INTEL_ENRICH=false
PROFESSIONAL_REPORT=false
EMAIL_COMPLIANCE=false

# Tools required for scanning
REQUIRED_TOOLS=("nmap" "nikto" "gobuster" "dirb" "whatweb" "wafw00f")

# Nmap HTTP scripts
HTTPNSE="http-date,http-title,http-server-header,http-headers,http-enum,http-devframework,http-dombased-xss,http-stored-xss,http-xssed,http-cookie-flags,http-errors,http-grep,http-traceroute"

# Skip flag for tool interruption
SKIP_CURRENT_TOOL=false
CTRL_C_COUNT=0

#==============================================================================
# SIGNAL HANDLERS
#==============================================================================

handle_interrupt() {
    ((CTRL_C_COUNT++))
    
    if (( CTRL_C_COUNT >= 2 )); then
        echo ""
        print_error "Double Ctrl+C detected. Exiting WAES..."
        exit 130
    fi
    
    echo ""
    print_warn "Ctrl+C detected - Skipping current tool..."
    print_info "(Press Ctrl+C again within 2 seconds to exit completely)"
    SKIP_CURRENT_TOOL=true
    
    # Reset counter after 2 seconds
    (sleep 2; CTRL_C_COUNT=0) &
    
    # Kill background jobs (children)
    jobs -p | xargs -r kill 2>/dev/null || true
    
    # Stop any currently running foreground command if possible
    # We don't use kill -$$ as it kills the script itself
}

# Set up trap for Ctrl+C
trap handle_interrupt SIGINT

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
    -u <target>     Target IP or domain (required, or use --targets)
    -p <port>       Port number (default: 80 and 443)
    -s              Use HTTPS protocol
    -t <type>       Scan type: fast, full, deep, advanced (default: full)
    --profile <p>   Use scan profile (ctf-box, web-app, bug-bounty, quick-scan)
    --targets <f>   Scan multiple targets from file (supports CIDR)
    --parallel      Enable parallel scanning (faster)
    -r              Resume previous scan
    -H              Generate HTML report
    -J              Generate JSON report
    -w, --writeup       Generate CTF writeup (markdown)
    -E, --evidence      Enable auto-evidence collection (Default: ON)
    --no-evidence       Disable auto-evidence collection
    -C, --chains        Enable vulnerability chain tracking
    --owasp             Run OWASP Top 10 focused scan
    --email-compliance  Test domain email authentication (SPF/DKIM/DMARC)
    --orchestrate       Use intelligent orchestration engine
    --intel             Enable CVE correlation and exploit mapping
    --professional      Generate professional pentest report (exec summary + findings)
    -v              Verbose output
    -q              Quiet mode (minimal output)
    -h              Show this help message

Scan Types:
    fast     - Quick reconnaissance (wafw00f, nmap http-enum)
    full     - Standard scan (adds nikto, nmap scripts) [default]
    deep     - Comprehensive (adds vulscan, uniscan, fuzzing)
    advanced - Deep + SSL/TLS, XSS testing, CMS-specific scans

Profiles:
    ctf-box      - Aggressive scanning for CTF machines
    web-app      - Professional web application testing
    bug-bounty   - Careful, stealthy scanning
    quick-scan   - Fast reconnaissance only

Examples:
    ${0##*/} -u 10.10.10.130
    ${0##*/} -u 10.10.10.130 -p 8080
    ${0##*/} -u example.com -s -t advanced -H -J
    ${0##*/} -u example.com --profile ctf-box --parallel
    ${0##*/} --targets targets.txt -t deep -H
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

detect_https() {
    local target="$1"
    local port="$2"
    
    # Try to connect with SSL/TLS using timeout
    if command_exists openssl; then
        if timeout 3 openssl s_client -connect "${target}:${port}" -servername "${target}" </dev/null 2>/dev/null | grep -q "CONNECTED"; then
            return 0  # HTTPS detected
        fi
    elif command_exists curl; then
        if timeout 3 curl -k -s "https://${target}:${port}" >/dev/null 2>&1; then
            return 0  # HTTPS detected
        fi
    fi
    
    return 1  # Not HTTPS
}

parse_args() {
    # Support long options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u) TARGET="$2"; shift 2 ;;
            -p) PORT="$2"; PORTS=("$PORT"); shift 2 ;;
            -s) 
                PROTOCOL="https"
                PORTS=(443)
                shift
                ;;
            -t) SCAN_TYPE="$2"; shift 2 ;;
            --profile) USE_PROFILE="$2"; shift 2 ;;
            --targets) TARGETS_FILE="$2"; shift 2 ;;
            --parallel) PARALLEL_MODE=true; shift ;;
            -r) RESUME=true; shift ;;
            -H) GENERATE_HTML=true; shift ;;
            -J) GENERATE_JSON=true; shift ;;
            -w|--writeup) GENERATE_WRITEUP=true; shift ;;
            -E|--evidence) EVIDENCE_MODE=true; shift ;;
            --no-evidence) EVIDENCE_MODE=false; shift ;;
            -C|--chains) TRACK_CHAINS=true; shift ;;
            --owasp) OWASP_SCAN=true; shift ;;
            --email-compliance) EMAIL_COMPLIANCE=true; shift ;;
            --orchestrate) ORCHESTRATED_SCAN=true; shift ;;
            --intel) INTEL_ENRICH=true; shift ;;
            --professional) PROFESSIONAL_REPORT=true; INTEL_ENRICH=true; shift ;;
            -v) VERBOSE=true; shift ;;
            -q) QUIET=true; shift ;;
            -h) 
                show_banner
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Check for batch scanning
    if [[ -n "$TARGETS_FILE" ]]; then
        if [[ ! -f "$TARGETS_FILE" ]]; then
            print_error "Targets file not found: $TARGETS_FILE"
            exit 1
        fi
        print_info "Batch scanning mode enabled"
        return 0
    fi
    
    # Require target if not batch mode
    if [[ -z "$TARGET" ]]; then
        print_error "Target required (use -u or --targets)"
        usage
        exit 1
    fi
    
    # Validate port(s)
    for p in "${PORTS[@]}"; do
        if ! validate_port "$p"; then
            print_error "Invalid port: $p (must be 1-65535)"
            exit 1
        fi
    done
    
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
    if [[ -x "${SCRIPT_DIR}/external/OSIRA/osira.sh" ]]; then
        print_running "OSIRA - Subdomain enumeration"
        "${SCRIPT_DIR}/external/OSIRA/osira.sh" -u "${TARGET}:${PORT}" 2>&1 | \
            grep -v "Unable to find the required sublis" | \
            tee "${REPORT_DIR}/${TARGET}_osira.txt" || \
            print_warn "OSIRA skipped (missing dependencies: sublist3r)"
    fi
}

# Step 2: Fast scan
fast_scan() {
    print_step "1" "Fast scan - firewall detection and quick enum"
    
    # Firewall detection with WAF profiling
    if command_exists wafw00f; then
        print_running "wafw00f - Web Application Firewall detection"
        local waf_result="${REPORT_DIR}/${TARGET}_wafw00f.txt"
        
        # Run WAF detection (non-blocking - continue regardless of result)
        detect_waf "$TARGET" "$PORT" "$PROTOCOL" "$waf_result" 2>&1 | tee -a "${REPORT_DIR}/${TARGET}_scan.log" || true
        
        # Check if skipped
        if [[ "$SKIP_CURRENT_TOOL" == "true" ]]; then
            print_warn "Skipped wafw00f"
            SKIP_CURRENT_TOOL=false
            export WAF_DETECTED=false
        else
            # Parse results and load evasion profile if available
            WAF_NAME=$(parse_waf_result "$waf_result" 2>/dev/null) || WAF_NAME="none"
            WAF_CONFIDENCE=$(get_waf_confidence "$waf_result" 2>/dev/null) || WAF_CONFIDENCE="0"
            
            if [[ "$WAF_NAME" != "none" ]]; then
                print_warn "WAF DETECTED: $WAF_NAME (Confidence: ${WAF_CONFIDENCE}%)"
                
                # Load evasion profile
                WAF_PROFILE=$(get_evasion_profile "$WAF_NAME")
                export WAF_DETECTED=true
                export WAF_NAME
                export WAF_PROFILE
                export EVASION_ENABLED=true
                
                print_info "Loading evasion profile: $(basename "$WAF_PROFILE" .yml)"
                
                # Generate summary
                generate_waf_summary "$TARGET" "$waf_result" "${REPORT_DIR}/${TARGET}_waf_summary.txt" 2>/dev/null || true
            else
                print_success "No WAF detected - proceeding with standard scanning"
                export WAF_DETECTED=false
            fi
        fi
    fi
    
    # Quick nmap http-enum (parallel)
    if command_exists nmap && [[ "$SKIP_CURRENT_TOOL" == "false" ]]; then
        print_running "nmap - HTTP enumeration script (running in background)"
        nmap -sSV -Pn -T4 -p "$PORT" --script http-enum "$TARGET" \
            -oA "${REPORT_DIR}/${TARGET}_nmap_http-enum" &
        NMAP_PID=$!
    fi
}

# Step 3: In-depth scanning
deep_scan() {
    print_step "2" "In-depth scanning - vulnerability and service analysis"
    
    # Wait for fast scan nmap to complete if still running
    if [[ -n "${NMAP_PID:-}" ]]; then
        wait $NMAP_PID 2>/dev/null || true
    fi
    
    if command_exists nmap && [[ "$SKIP_CURRENT_TOOL" == "false" ]]; then
        # HTTP scripts (parallel)
        print_running "nmap - HTTP vulnerability scripts (background)"
        nmap -sSV -Pn -T4 -p "$PORT" --script "$HTTPNSE" "$TARGET" \
            -oA "${REPORT_DIR}/${TARGET}_nmap_http-scripts" &
        
        # Vulscan if available (parallel)
        if [[ -f "${VULSCAN_DIR}/vulscan.nse" ]]; then
            print_running "nmap - Vulscan (CVSS 5.0+) (background)"
            nmap -sSV -Pn -T4 --version-all -p "$PORT" \
                --script "${VULSCAN_DIR}/vulscan.nse" "$TARGET" \
                --script-args mincvss=5.0 \
                -oA "${REPORT_DIR}/${TARGET}_nmap_vulscan" &
        fi
        
        # Wait for both to complete
        wait
    elif [[ "$SKIP_CURRENT_TOOL" == "true" ]]; then
        print_warn "Skipped nmap scans"
        SKIP_CURRENT_TOOL=false
    fi
    
    # Nikto with evasion support
    if command_exists nikto && [[ "$SKIP_CURRENT_TOOL" == "false" ]]; then
        print_running "nikto - Web server scanner"
        
        # Use wrapper if evasion is enabled
        if [[ "${EVASION_ENABLED:-false}" == "true" ]] && [[ -x "${SCRIPT_DIR}/lib/tool_wrappers/nikto_wrapper.sh" ]]; then
            local evasion_level="${WAF_EVASION_LEVEL:-moderate}"
            print_info "Running Nikto with evasion (level: $evasion_level)"
            "${SCRIPT_DIR}/lib/tool_wrappers/nikto_wrapper.sh" "$TARGET" "$PORT" "$PROTOCOL" \
                "${REPORT_DIR}/${TARGET}_nikto.txt" "$evasion_level" | tee -a "${REPORT_DIR}/${TARGET}_scan.log"
        else
            # Standard nikto with timeout to prevent hanging
            timeout 90 nikto -h "${PROTOCOL}://${TARGET}:${PORT}" -C all -ask no -evasion A 2>&1 \
                | tee "${REPORT_DIR}/${TARGET}_nikto.txt" || \
                print_warn "Nikto completed with timeout or warnings"
        fi
    elif [[ "$SKIP_CURRENT_TOOL" == "true" ]]; then
        print_warn "Skipped nikto"
        SKIP_CURRENT_TOOL=false
    fi
    
    # Uniscan (optional)
    if command_exists uniscan && [[ "$SKIP_CURRENT_TOOL" == "false" ]]; then
        print_running "uniscan - Vulnerability scanner"
        uniscan -u "${PROTOCOL}://${TARGET}:${PORT}" -qweds 2>&1 \
            | tee "${REPORT_DIR}/${TARGET}_uniscan.txt"
    elif [[ "$SKIP_CURRENT_TOOL" == "true" ]]; then
        print_warn "Skipped uniscan"
        SKIP_CURRENT_TOOL=false
    fi
}

# Step 4: Directory/file fuzzing
fuzzing_scan() {
    print_step "3" "Fuzzing - Directory and file discovery"
    
    local base_url="${PROTOCOL}://${TARGET}:${PORT}"
    
    # Run supergobuster if available
    if [[ -x "${SCRIPT_DIR}/tools/supergobuster.sh" ]]; then
        print_running "supergobuster - Multi-wordlist directory busting"
        "${SCRIPT_DIR}/tools/supergobuster.sh" "$base_url" 2>&1 \
            | tee "${REPORT_DIR}/${TARGET}_supergobust.txt"
    elif command_exists gobuster; then
        # Fall back to simple gobuster
        print_running "gobuster - Directory enumeration"
        local wordlist
        wordlist=$(find_wordlist "directory-list-2.3-medium.txt" 2>/dev/null) || \
            wordlist="/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
        
        if [[ -f "$wordlist" ]]; then
            # Use wrapper if evasion is enabled
            if [[ "${EVASION_ENABLED:-false}" == "true" ]] && [[ -x "${SCRIPT_DIR}/lib/tool_wrappers/gobuster_wrapper.sh" ]]; then
                local evasion_level="${WAF_EVASION_LEVEL:-moderate}"
                print_info "Running Gobuster with evasion (level: $evasion_level)"
                "${SCRIPT_DIR}/lib/tool_wrappers/gobuster_wrapper.sh" "$base_url" "$wordlist" \
                    "${REPORT_DIR}/${TARGET}_gobuster.txt" "$evasion_level" | tee -a "${REPORT_DIR}/${TARGET}_scan.log"
            else
                # Standard gobuster
                gobuster dir -u "$base_url" -w "$wordlist" \
                    -t "${GOBUSTER_THREADS:-10}" --wildcard 2>&1 \
                    | tee "${REPORT_DIR}/${TARGET}_gobuster.txt"
            fi
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
    
    # Load profile if specified
    if [[ -n "$USE_PROFILE" ]]; then
        if declare -f load_profile &>/dev/null; then
            load_profile "$USE_PROFILE" "${SCRIPT_DIR}/profiles"
            apply_profile 2>/dev/null || true
            print_success "Profile '$USE_PROFILE' loaded"
        fi
    fi
    
    # Batch scanning mode
    if [[ -n "$TARGETS_FILE" ]]; then
        if declare -f batch_scan &>/dev/null; then
            local scan_flags=""
            [[ "$VERBOSE" == "true" ]] && scan_flags+=" -v"
            [[ "$GENERATE_HTML" == "true" ]] && scan_flags+=" -H"
            [[ "$GENERATE_JSON" == "true" ]] && scan_flags+=" -J"
            batch_scan "$TARGETS_FILE" "$SCAN_TYPE" "${REPORT_DIR}/batch" "$PARALLEL_MODE" "$scan_flags"
            exit $?
        fi
    fi
    
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
    
    # Scan each port
    for PORT in "${PORTS[@]}"; do
        # Auto-detect protocol if not explicitly set with -s flag
        if [[ -z "$PROTOCOL" ]]; then
            print_info "Testing port ${PORT} for SSL/TLS..."
            if detect_https "$TARGET" "$PORT"; then
                PROTOCOL="https"
                print_success "HTTPS detected on port ${PORT}"
            else
                PROTOCOL="http"
                print_info "Using HTTP for port ${PORT}"
            fi
        fi
        
        # Display target info
        print_info "Scanning: ${PROTOCOL}://${TARGET}:${PORT}"
        print_info "Scan type: ${SCAN_TYPE}"
        
        # Setup
        check_tools
        setup_report_dir
        
        # Initialize scan state
        if declare -f init_scan_state &>/dev/null; then
            init_scan_state "$TARGET" "$SCAN_TYPE" "$REPORT_DIR"
        fi
        
        # Initialize new features (Phase 1) - One time per target/port combo
        if [[ "$TRACK_CHAINS" == "true" ]] && declare -f init_chain_tracking &>/dev/null; then
            print_info "Vulnerability chain tracking enabled"
            init_chain_tracking "$TARGET"
        fi
        
        if [[ "$EVIDENCE_MODE" == "true" ]] && declare -f init_evidence_collection &>/dev/null; then
            print_info "Evidence auto-collection enabled"
            init_evidence_collection "$TARGET"
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
                
                # Generate JSON report if requested
                if [[ "$GENERATE_JSON" == "true" ]]; then
                    echo ""
                    print_info "Generating JSON report..."
                    if declare -f export_to_json &>/dev/null; then
                        export_to_json "$TARGET" "$REPORT_DIR" "$SCAN_TYPE"
                    fi
                fi
                
                # Run OWASP Top 10 scan if enabled
                if [[ "$OWASP_SCAN" == "true" ]] && declare -f run_owasp_scan &>/dev/null; then
                    echo ""
                    run_owasp_scan "$TARGET" "$PORT" "$PROTOCOL"
                fi
                
                xss_vulnerability_scan
                cms_detection_scan
                ;;
        esac
        
        # Mark scan as complete
        if declare -f complete_scan &>/dev/null; then
            complete_scan "$TARGET" "$REPORT_DIR"
        fi
        
        # Run email compliance test if requested
        if [[ "$EMAIL_COMPLIANCE" == "true" ]]; then
            echo ""
            print_info "Running email compliance test..."
            local compliance_report="${REPORT_DIR}/${TARGET}_email_compliance.md"
            if declare -f scan_email_compliance &>/dev/null; then
                scan_email_compliance "$TARGET" "$compliance_report"
            else
                print_warn "Email compliance module not loaded"
            fi
        fi
        
        # Reset protocol for next port iteration
        PROTOCOL=""
    done
    
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
    
    # Generate Writeup if requested (Phase 1)
    if [[ "$GENERATE_WRITEUP" == "true" ]]; then
        echo ""
        if declare -f generate_writeup &>/dev/null; then
            generate_writeup "$TARGET" "$WRITEUP_FORMAT"
        else
            print_warn "Writeup generator module not loaded"
        fi
    fi
    
    # Export CSV if chains or evidence was active (implicit helpfulness)
    if [[ "$TRACK_CHAINS" == "true" ]] || [[ "$EVIDENCE_MODE" == "true" ]]; then
        if declare -f export_to_csv &>/dev/null; then
            export_to_csv "$TARGET" "$REPORT_DIR"
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
