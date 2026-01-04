#!/usr/bin/env bash
#==============================================================================
# WAES Parameter Discovery
# Discover hidden parameters in web applications
#==============================================================================

set -euo pipefail

# Source color library if available
if [[ -f "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh" ]]; then
    source "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh"
else
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
fi

#==============================================================================
# PARAMETER DISCOVERY
#==============================================================================

# Common parameter names
declare -a COMMON_PARAMS=(
    "id" "user" "username" "email" "search" "q" "query"
    "filter" "sort" "order" "page" "limit" "offset"
    "action" "cmd" "command" "exec" "debug" "test"
    "file" "path" "url" "redirect" "callback" "return"
    "lang" "language" "locale" "timezone" "format"
    "key" "token" "api_key" "auth" "session"
)

# Test parameter against URL
test_parameter() {
    local url="$1"
    local param="$2"
    local test_value="${3:-test}"
    
    # Append parameter
    local test_url
    if [[ "$url" == *"?"* ]]; then
        test_url="${url}&${param}=${test_value}"
    else
        test_url="${url}?${param}=${test_value}"
    fi
    
    # Make request
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}:%{size_download}" "$test_url" 2>/dev/null)
    
    local status_code="${response%%:*}"
    local size="${response##*:}"
    
    # Check if parameter is reflected or causes different response
    if [[ "$status_code" == "200" ]]; then
        local body
        body=$(curl -s "$test_url" 2>/dev/null)
        
        # Check if test value is reflected
        if echo "$body" | grep -q "$test_value"; then
            echo "$param:REFLECTED:$status_code:$size"
            return 0
        fi
        
        # Check if response size changed significantly
        echo "$param:ACCEPTED:$status_code:$size"
        return 0
    fi
    
    return 1
}

# Discover parameters via common list
discover_common_params() {
    local url="$1"
    local output_file="$2"
    
    print_info "Testing common parameters: $url"
    
    {
        echo "=== Common Parameter Discovery ==="
        echo "URL: $url"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "Format: PARAM:TYPE:STATUS:SIZE"
        echo ""
        
        for param in "${COMMON_PARAMS[@]}"; do
            if test_parameter "$url" "$param" "waes_test"; then
                :  # Output already printed
            fi
        done
    } | tee "$output_file"
}

# Extract parameters from JavaScript files
extract_params_from_js() {
    local url="$1"
    local output_file="$2"
    
    print_info "Extracting parameters from JavaScript: $url"
    
    {
        echo "=== JavaScript Parameter Extraction ==="
        echo "URL: $url"
        echo ""
        
        # Get page content
        local page_content
        page_content=$(curl -s -L "$url" 2>/dev/null)
        
        # Find JS files
        local js_files
        js_files=$(echo "$page_content" | grep -oP '(?<=src=")[^"]*\.js' | sort -u | head -20)
        
        if [[ -z "$js_files" ]]; then
            echo "No JavaScript files found"
            return
        fi
        
        echo "JavaScript files found:"
        echo "$js_files"
        echo ""
        
        echo "Extracted parameters:"
        for js_file in $js_files; do
            # Make URL absolute
            if [[ "$js_file" != http* ]]; then
                local base_url
                base_url=$(echo "$url" | sed 's|/[^/]*$||')
                js_file="${base_url}/${js_file}"
            fi
            
            # Fetch and analyze JS file
            local js_content
            js_content=$(curl -s "$js_file" 2>/dev/null)
            
            # Extract parameter-like patterns
            echo "$js_content" | grep -oP '[\?&][a-zA-Z_][a-zA-Z0-9_]*=' | \
                cut -d'=' -f1 | tr -d '?&' | sort -u
                
            # Extract from JSON-like structures
            echo "$js_content" | grep -oP '"[a-zA-Z_][a-zA-Z0-9_]*"\s*:' | \
                cut -d'"' -f2 | sort -u
        done | sort -u
    } | tee "$output_file"
}

# Discover parameters via Arjun (if installed)
discover_with_arjun() {
    local url="$1"
    local output_file="$2"
    
    if ! command -v arjun &>/dev/null; then
        print_warn "Arjun not installed (pip install arjun)"
        return 1
    fi
    
    print_info "Running Arjun parameter discovery: $url"
    
    {
        echo "=== Arjun Parameter Discovery ==="
        echo "URL: $url"
        echo ""
        
        arjun -u "$url" --stable 2>/dev/null || echo "Arjun scan failed"
    } | tee "$output_file"
}

# Extract parameters from HTML forms
extract_form_parameters() {
    local url="$1"
    local output_file="$2"
    
    print_info "Extracting parameters from forms: $url"
    
    {
        echo "=== Form Parameter Extraction ==="
        echo "URL: $url"
        echo ""
        
        local page_content
        page_content=$(curl -s -L "$url" 2>/dev/null)
        
        # Extract input names
        echo "Input fields:"
        echo "$page_content" | grep -oP '(?<=<input[^>]*name=")[^"]*' | sort -u
        
        # Extract form actions
        echo ""
        echo "Form actions:"
        echo "$page_content" | grep -oP '(?<=<form[^>]*action=")[^"]*'
    } | tee "$output_file"
}

#==============================================================================
# MAIN FUNCTION
#==============================================================================

discover_parameters() {
    local url="$1"
    local report_dir="${2:-.}"
    
    local domain
    domain=$(echo "$url" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
    local output_base="${report_dir}/${domain}_params"
    
    print_info "Starting parameter discovery: $url"
    echo ""
    
    # Common parameters
    discover_common_params "$url" "${output_base}_common.txt"
    
    # JS extraction
    extract_params_from_js "$url" "${output_base}_js.txt"
    
    # Form parameters
    extract_form_parameters "$url" "${output_base}_forms.txt"
    
    # Arjun (if available)
    discover_with_arjun "$url" "${output_base}_arjun.txt"
    
    echo ""
    print_success "Parameter discovery complete"
    print_info "Results: ${output_base}_*"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat << EOF
Usage: $0 <url> [report_dir]

Examples:
    $0 http://example.com/search
    $0 http://example.com ./results
EOF
        exit 1
    fi
    
    discover_parameters "$@"
fi
