#!/usr/bin/env bash
#==============================================================================
# WAES File Upload Vulnerability Testing Module
# Tests for file upload security issues
#==============================================================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || {
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
    print_running() { echo "[>] $*"; }
}

#==============================================================================
# UPLOAD ENDPOINT DISCOVERY
#==============================================================================

discover_upload_endpoints() {
    local url="$1"
    local output_file="$2"
    
    print_running "  Discovering file upload endpoints..."
    
    # Common upload paths
    local upload_paths=(
        "upload" "file/upload" "files/upload" "api/upload"
        "avatar/upload" "image/upload" "document/upload"
        "import" "attach" "attachment" "media/upload"
        "admin/upload" "user/upload" "profile/avatar"
    )
    
    local found_endpoints=()
    
    for path in "${upload_paths[@]}"; do
        local code
        code=$(curl -sk -o /dev/null -w "%{http_code}" "${url}/${path}" 2>/dev/null)
        
        if [[ "$code" == "200" ]] || [[ "$code" == "405" ]] || [[ "$code" == "401" ]]; then
            found_endpoints+=("/$path")
            echo "[UPLOAD] Potential upload endpoint: /${path} (HTTP $code)" >> "$output_file"
            print_info "    Found: /${path} (HTTP $code)"
        fi
    done
    
    # Look for file input forms in HTML
    local html
    html=$(curl -sk "$url" --max-time 10 2>/dev/null)
    
    if echo "$html" | grep -qi 'type="file"\|type=file\|enctype="multipart'; then
        echo "[UPLOAD] File upload form detected on main page" >> "$output_file"
        print_info "    File upload form found on main page"
    fi
    
    echo "${found_endpoints[@]}"
}

#==============================================================================
# EXTENSION BYPASS TESTS
#==============================================================================

# Dangerous file extensions to test
declare -a DANGEROUS_EXTENSIONS=(
    ".php" ".php5" ".phtml" ".phar"
    ".asp" ".aspx" ".asa" ".asax"
    ".jsp" ".jspx" ".jsw" ".jsv"
    ".exe" ".bat" ".cmd" ".sh"
    ".py" ".pl" ".cgi" ".rb"
    ".htaccess" ".htpasswd"
)

# Bypass techniques
declare -a EXTENSION_BYPASSES=(
    ".php.jpg"      # Double extension
    ".php.png"      # Double extension
    ".PHP"          # Case variation
    ".pHp"          # Mixed case
    ".php "         # Trailing space
    ".php."         # Trailing dot
    ".php%00.jpg"   # Null byte
    ".php::.jpg"    # Stream wrapper
    "shell.php%0a"  # Newline injection
)

test_extension_bypass() {
    local upload_endpoint="$1"
    local output_file="$2"
    
    print_running "  Testing extension bypass techniques..."
    
    local issues=0
    
    # Create test payloads
    local test_content="<?php echo 'VULNERABLE'; ?>"
    
    for bypass in "${EXTENSION_BYPASSES[@]}"; do
        local filename="test${bypass}"
        
        # Attempt upload
        local response
        response=$(curl -sk -X POST "$upload_endpoint" \
            -F "file=@-;filename=$filename" <<< "$test_content" \
            -w "\n%{http_code}" --max-time 10 2>/dev/null)
        
        local code
        code=$(echo "$response" | tail -1)
        local body
        body=$(echo "$response" | head -n -1)
        
        # Check for successful upload indicators
        if [[ "$code" == "200" ]] || [[ "$code" == "201" ]]; then
            if ! echo "$body" | grep -qiE "denied|blocked|invalid|not allowed"; then
                echo "[UPLOAD] Extension bypass possible: $filename" >> "$output_file"
                print_warn "    → Accepted: $filename"
                ((issues++))
            fi
        fi
    done
    
    return $issues
}

#==============================================================================
# CONTENT-TYPE BYPASS
#==============================================================================

test_content_type_bypass() {
    local upload_endpoint="$1"
    local output_file="$2"
    
    print_running "  Testing Content-Type manipulation..."
    
    local issues=0
    local php_content="<?php echo 'VULNERABLE'; ?>"
    
    # Test with PHP content but image Content-Type
    local mime_types=("image/jpeg" "image/png" "image/gif" "text/plain")
    
    for mime in "${mime_types[@]}"; do
        local response
        response=$(curl -sk -X POST "$upload_endpoint" \
            -H "Content-Type: multipart/form-data" \
            -F "file=@-;filename=shell.php;type=$mime" <<< "$php_content" \
            -w "\n%{http_code}" --max-time 10 2>/dev/null)
        
        local code
        code=$(echo "$response" | tail -1)
        
        if [[ "$code" == "200" ]] || [[ "$code" == "201" ]]; then
            echo "[UPLOAD] Content-Type bypass: shell.php uploaded as $mime" >> "$output_file"
            print_warn "    → Uploaded PHP as: $mime"
            ((issues++))
            break
        fi
    done
    
    return $issues
}

#==============================================================================
# PATH TRAVERSAL IN FILENAME
#==============================================================================

test_path_traversal() {
    local upload_endpoint="$1"
    local output_file="$2"
    
    print_running "  Testing path traversal in filename..."
    
    local issues=0
    local test_content="test content"
    
    local traversal_filenames=(
        "../../../tmp/traversal.txt"
        "..\\..\\..\\tmp\\traversal.txt"
        "....//....//....//tmp/traversal.txt"
        "/etc/cron.d/evil"
        "..%2f..%2f..%2ftmp%2ftraversal.txt"
    )
    
    for filename in "${traversal_filenames[@]}"; do
        local response
        response=$(curl -sk -X POST "$upload_endpoint" \
            -F "file=@-;filename=$filename" <<< "$test_content" \
            -w "\n%{http_code}" --max-time 10 2>/dev/null)
        
        local code
        code=$(echo "$response" | tail -1)
        local body
        body=$(echo "$response" | head -n -1)
        
        if [[ "$code" == "200" ]] || [[ "$code" == "201" ]]; then
            if ! echo "$body" | grep -qiE "denied|blocked|invalid|traversal"; then
                echo "[UPLOAD] Path traversal in filename may be possible: $filename" >> "$output_file"
                print_warn "    → Possible traversal: $filename"
                ((issues++))
            fi
        fi
    done
    
    return $issues
}

#==============================================================================
# FILE SIZE LIMITS
#==============================================================================

test_file_size_limits() {
    local upload_endpoint="$1"
    local output_file="$2"
    
    print_running "  Testing file size limits..."
    
    # Generate large payload (1MB of data)
    local large_content
    large_content=$(head -c 1048576 /dev/zero | tr '\0' 'A')
    
    local response
    response=$(curl -sk -X POST "$upload_endpoint" \
        -F "file=@-;filename=large.txt" <<< "$large_content" \
        -w "\n%{http_code}" --max-time 30 2>/dev/null)
    
    local code
    code=$(echo "$response" | tail -1)
    
    if [[ "$code" == "200" ]] || [[ "$code" == "201" ]]; then
        echo "[UPLOAD] Large file upload accepted (1MB)" >> "$output_file"
        print_info "    1MB file accepted (check for DoS risk)"
        return 1
    else
        print_success "    Large file rejected (good)"
        return 0
    fi
}

#==============================================================================
# MAIN UPLOAD SCAN FUNCTION
#==============================================================================

scan_file_upload() {
    local target_url="$1"
    local report_dir="${2:-.}"
    
    local domain
    domain=$(echo "$target_url" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
    local output_file="${report_dir}/${domain}_upload_scan.txt"
    
    print_info "Starting File Upload scan for: $target_url"
    echo ""
    
    {
        echo "=== File Upload Vulnerability Scan ==="
        echo "Target: $target_url"
        echo "Scan Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } > "$output_file"
    
    local total_issues=0
    
    # Discover upload endpoints
    local endpoints
    endpoints=$(discover_upload_endpoints "$target_url" "$output_file")
    
    if [[ -n "$endpoints" ]]; then
        for endpoint in $endpoints; do
            local full_url="${target_url}${endpoint}"
            print_info "  Testing endpoint: $endpoint"
            
            test_extension_bypass "$full_url" "$output_file"
            total_issues=$((total_issues + $?))
            
            test_content_type_bypass "$full_url" "$output_file"
            total_issues=$((total_issues + $?))
            
            test_path_traversal "$full_url" "$output_file"
            total_issues=$((total_issues + $?))
            
            test_file_size_limits "$full_url" "$output_file"
            total_issues=$((total_issues + $?))
        done
    else
        print_info "  No upload endpoints found to test"
    fi
    
    {
        echo ""
        echo "=== Scan Summary ==="
        echo "Total issues found: $total_issues"
    } >> "$output_file"
    
    if [[ $total_issues -gt 0 ]]; then
        print_warn "Found $total_issues file upload security issues"
    else
        print_success "No file upload vulnerabilities detected"
    fi
    
    print_success "File upload scan complete: $output_file"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat <<EOF
Usage: $0 <target_url> [report_dir]

File Upload Vulnerability Testing Module
Tests extension bypass, content-type manipulation, path traversal, and size limits.

Examples:
    $0 http://example.com/
    $0 http://example.com ./reports
EOF
        exit 1
    fi
    
    scan_file_upload "$@"
fi
