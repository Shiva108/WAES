#!/usr/bin/env bash
#==============================================================================
# WAES Fuzzing Module
# Parameter, directory, and header fuzzing with ffuf
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true

#==============================================================================
# CONFIGURATION
#==============================================================================

FFUF_BIN="${FFUF_BIN:-$(which ffuf 2>/dev/null)}"
FUZZ_THREADS=40
FUZZ_TIMEOUT=10
FUZZ_RATE=100  # requests per second

# Wordlist paths
PARAM_WORDLIST="${SCRIPT_DIR}/wordlists/parameters.txt"
DIR_WORDLIST="${SCRIPT_DIR}/wordlists/directories.txt"
HEADER_WORDLIST="${SCRIPT_DIR}/wordlists/headers.txt"

# Fallback to common wordlists
[[ ! -f "$PARAM_WORDLIST" ]] && PARAM_WORDLIST="/usr/share/seclists/Discovery/Web-Content/burp-parameter-names.txt"
[[ ! -f "$DIR_WORDLIST" ]] && DIR_WORDLIST="/usr/share/seclists/Discovery/Web-Content/raft-medium-directories.txt"
[[ ! -f "$HEADER_WORDLIST" ]] && HEADER_WORDLIST="/usr/share/seclists/Discovery/Web-Content/common-http-headers.txt"

#==============================================================================
# FUZZING FUNCTIONS
#==============================================================================

check_ffuf() {
    if [[ ! -x "$FFUF_BIN" ]]; then
        print_warn "ffuf not found. Install with: go install github.com/ffuf/ffuf@latest"
        return 1
    fi
    
    local version
    version=$($FFUF_BIN -V 2>&1 | head -1)
    print_info "ffuf version: $version"
    return 0
}

# Fuzz GET parameters
fuzz_parameters() {
    local url="$1"
    local output_dir="$2"
    local wordlist="${3:-$PARAM_WORDLIST}"
    
    check_ffuf || return 1
    
    [[ ! -f "$wordlist" ]] && print_error "Wordlist not found: $wordlist" && return 1
    
    print_info "Fuzzing GET parameters on $url"
    
    local output_json="${output_dir}/fuzz_parameters.json"
    local output_txt="${output_dir}/fuzz_parameters.txt"
    
    # Add FUZZ keyword to URL
    local fuzz_url="${url}?FUZZ=test"
    
    $FFUF_BIN -u "$fuzz_url" \
        -w "$wordlist" \
        -t "$FUZZ_THREADS" \
        -timeout "$FUZZ_TIMEOUT" \
        -rate "$FUZZ_RATE" \
        -mc 200,201,202,204,301,302,307,401,403 \
        -fc 404 \
        -o "$output_json" \
        -of json \
        -s 2>&1 | tee "$output_txt"
    
    if [[ -f "$output_json" ]]; then
        local found_params
        found_params=$(jq -r '.results[].input.FUZZ' "$output_json" 2>/dev/null | wc -l)
        print_success "Parameter fuzzing complete: $found_params parameters discovered"
        
        # Generate summary
        generate_param_summary "$output_json" "${output_dir}/fuzz_parameters.md"
    else
        print_warn "No parameters discovered"
    fi
}

# Fuzz directories
fuzz_directories() {
    local base_url="$1"
    local output_dir="$2"
    local wordlist="${3:-$DIR_WORDLIST}"
    
    check_ffuf || return 1
    
    [[ ! -f "$wordlist" ]] && print_error "Wordlist not found: $wordlist" && return 1
    
    print_info "Fuzzing directories on $base_url"
    
    local output_json="${output_dir}/fuzz_directories.json"
    local output_txt="${output_dir}/fuzz_directories.txt"
    
    # Ensure trailing slash
    [[ "$base_url" != */ ]] && base_url="${base_url}/"
    
    $FFUF_BIN -u "${base_url}FUZZ" \
        -w "$wordlist" \
        -t "$FUZZ_THREADS" \
        -timeout "$FUZZ_TIMEOUT" \
        -rate "$FUZZ_RATE" \
        -mc 200,201,204,301,302,307,401,403,405 \
        -fc 404 \
        -recursion \
        -recursion-depth 2 \
        -e .php,.html,.js,.txt,.json,.xml,.asp,.aspx,.jsp \
        -o "$output_json" \
        -of json \
        -s 2>&1 | tee "$output_txt"
    
    if [[ -f "$output_json" ]]; then
        local found_dirs
        found_dirs=$(jq -r '.results[].input.FUZZ' "$output_json" 2>/dev/null | wc -l)
        print_success "Directory fuzzing complete: $found_dirs paths discovered"
        
        # Generate summary
        generate_dir_summary "$output_json" "${output_dir}/fuzz_directories.md"
    else
        print_warn "No directories discovered"
    fi
}

# Fuzz HTTP headers
fuzz_headers() {
    local url="$1"
    local output_dir="$2"
    local wordlist="${3:-$HEADER_WORDLIST}"
    
    check_ffuf || return 1
    
    [[ ! -f "$wordlist" ]] && print_error "Wordlist not found: $wordlist" && return 1
    
    print_info "Fuzzing HTTP headers on $url"
    
    local output_json="${output_dir}/fuzz_headers.json"
    local output_txt="${output_dir}/fuzz_headers.txt"
    
    $FFUF_BIN -u "$url" \
        -H "FUZZ: test" \
        -w "$wordlist" \
        -t "$FUZZ_THREADS" \
        -timeout "$FUZZ_TIMEOUT" \
        -rate "$FUZZ_RATE" \
        -mc all \
        -fc 404 \
        -o "$output_json" \
        -of json \
        -s 2>&1 | tee "$output_txt"
    
    if [[ -f "$output_json" ]]; then
        local found_headers
        found_headers=$(jq -r '.results[].input.FUZZ' "$output_json" 2>/dev/null | wc -l)
        print_success "Header fuzzing complete: $found_headers interesting headers"
        
        # Generate summary
        generate_header_summary "$output_json" "${output_dir}/fuzz_headers.md"
    else
        print_warn "No interesting headers found"
    fi
}

# Fuzz API endpoints (JSON/REST)
fuzz_api_endpoints() {
    local base_url="$1"
    local output_dir="$2"
    
    check_ffuf || return 1
    
    print_info "Fuzzing API endpoints on $base_url"
    
    local output_json="${output_dir}/fuzz_api.json"
    local output_txt="${output_dir}/fuzz_api.txt"
    
    # Common API paths
    local api_wordlist="/tmp/api_paths_$$.txt"
    cat > "$api_wordlist" << 'EOF'
users
user
admin
api
v1
v2
auth
login
logout
register
profile
settings
config
status
health
version
EOF
    
    [[ "$base_url" != */ ]] && base_url="${base_url}/"
    
    $FFUF_BIN -u "${base_url}api/FUZZ" \
        -w "$api_wordlist" \
        -t "$FUZZ_THREADS" \
        -timeout "$FUZZ_TIMEOUT" \
        -rate "$FUZZ_RATE" \
        -mc 200,201,400,401,403,405,500 \
        -fc 404 \
        -H "Content-Type: application/json" \
        -o "$output_json" \
        -of json \
        -s 2>&1 | tee "$output_txt"
    
    rm -f "$api_wordlist"
    
    if [[ -f "$output_json" ]]; then
        local found_endpoints
        found_endpoints=$(jq -r '.results[].input.FUZZ' "$output_json" 2>/dev/null | wc -l)
        print_success "API fuzzing complete: $found_endpoints endpoints discovered"
        
        # Generate summary
        generate_api_summary "$output_json" "${output_dir}/fuzz_api.md"
    else
        print_warn "No API endpoints discovered"
    fi
}

#==============================================================================
# REPORTING FUNCTIONS
#==============================================================================

generate_param_summary() {
    local json_file="$1"
    local output_md="$2"
    
    [[ ! -f "$json_file" ]] && return 1
    
    cat > "$output_md" << EOF
# Parameter Fuzzing Results

**Scan Date**: $(date '+%Y-%m-%d %H:%M:%S')

## Discovered Parameters

EOF
    
    jq -r '.results[] | "- **\(.input.FUZZ)** - Status: \(.status) - Size: \(.length) bytes"' \
        "$json_file" 2>/dev/null >> "$output_md"
    
    cat >> "$output_md" << 'EOF'

## Recommendations
- Test each parameter for injection vulnerabilities
- Check for parameter pollution
- Verify input validation
- Test for IDOR vulnerabilities
EOF
    
    print_success "Parameter summary generated: $output_md"
}

generate_dir_summary() {
    local json_file="$1"
    local output_md="$2"
    
    [[ ! -f "$json_file" ]] && return 1
    
    cat > "$output_md" << EOF
# Directory Fuzzing Results

**Scan Date**: $(date '+%Y-%m-%d %H:%M:%S')

## Discovered Paths

EOF
    
    jq -r '.results[] | "- **\(.input.FUZZ)** - Status: \(.status) - Size: \(.length) bytes"' \
        "$json_file" 2>/dev/null | sort >> "$output_md"
    
    cat >> "$output_md" << 'EOF'

## Recommendations
- Review all 200/403 responses
- Check for sensitive file exposure
- Test admin/config directories
- Look for backup files (.bak, .old, ~)
EOF
    
    print_success "Directory summary generated: $output_md"
}

generate_header_summary() {
    local json_file="$1"
    local output_md="$2"
    
    [[ ! -f "$json_file" ]] && return 1
    
    cat > "$output_md" << EOF
# Header Fuzzing Results

**Scan Date**: $(date '+%Y-%m-%d %H:%M:%S')

## Interesting Headers

EOF
    
    jq -r '.results[] | "- **\(.input.FUZZ)** - Status: \(.status)"' \
        "$json_file" 2>/dev/null >> "$output_md"
    
    cat >> "$output_md" << 'EOF'

## Recommendations
- Test for header injection
- Check authentication bypass via headers
- Test X-Forwarded headers
- Look for debug/admin headers
EOF
    
    print_success "Header summary generated: $output_md"
}

generate_api_summary() {
    local json_file="$1"
    local output_md="$2"
    
    [[ ! -f "$json_file" ]] && return 1
    
    cat > "$output_md" << EOF
# API Endpoint Fuzzing Results

**Scan Date**: $(date '+%Y-%m-%d %H:%M:%S')

## Discovered Endpoints

EOF
    
    jq -r '.results[] | "- **/api/\(.input.FUZZ)** - Status: \(.status)"' \
        "$json_file" 2>/dev/null >> "$output_md"
    
    cat >> "$output_md" << 'EOF'

## Recommendations
- Test each endpoint with various HTTP methods
- Check for authentication requirements
- Test for IDOR/BOLA vulnerabilities
- Verify rate limiting
- Test with malformed JSON
EOF
    
    print_success "API summary generated: $output_md"
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

# Full fuzzing suite
run_full_fuzz() {
    local target="$1"
    local output_dir="$2"
    
    print_header "Web Application Fuzzing"
    
    # Parameter fuzzing
    fuzz_parameters "$target" "$output_dir"
    
    # Directory fuzzing
    fuzz_directories "$target" "$output_dir"
    
    # Header fuzzing
    fuzz_headers "$target" "$output_dir"
    
    # API fuzzing
    fuzz_api_endpoints "$target" "$output_dir"
    
    print_success "Full fuzzing suite completed"
}

# Allow direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <target_url> <output_dir> [type]"
        echo "Types: param, dir, header, api, all"
        exit 1
    fi
    
    case "${3:-all}" in
        param) fuzz_parameters "$1" "$2" ;;
        dir) fuzz_directories "$1" "$2" ;;
        header) fuzz_headers "$1" "$2" ;;
        api) fuzz_api_endpoints "$1" "$2" ;;
        all) run_full_fuzz "$1" "$2" ;;
        *) echo "Unknown type: $3"; exit 1 ;;
    esac
fi
