#!/usr/bin/env bash
#==============================================================================
# WAES JavaScript Analysis Module
# Extract endpoints, secrets, and intelligence from JavaScript files
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true

#==============================================================================
# CONFIGURATION
#==============================================================================

JS_DOWNLOAD_DIR="${JS_DOWNLOAD_DIR:-/tmp/waes_js_$$}"
JS_MAX_SIZE=5242880  # 5MB max file size
JS_TIMEOUT=30

#==============================================================================
# JAVASCRIPT DISCOVERY
#==============================================================================

discover_js_files() {
    local target="$1"
    local output_dir="$2"
    
    print_info "Discovering JavaScript files on $target"
    
    local js_list="${output_dir}/js_files.txt"
    
    # Method 1: Extract from HTML source
    curl -s -L "$target" | \
        grep -oP '(src|href)=["'\''](https?://)?[^"'\'']*\.js[^"'\'']*["'\'']' | \
        sed 's/.*=["'\'']\(.*\)["'\'']/\1/' | \
        sed "s|^/|$target/|" | \
        sed "s|^//|https://|" | \
        sort -u > "$js_list"
    
    # Method 2: Look for inline script sources
    curl -s -L "$target" | \
        grep -oP '<script[^>]*>' | \
        grep -oP 'src=["'\'']\K[^"'\'']+' | \
        sed "s|^/|$target/|" | \
        sed "s|^//|https://|" >> "$js_list"
    
    # Deduplicate
    sort -u "$js_list" -o "$js_list"
    
    local count
    count=$(wc -l < "$js_list")
    print_success "Found $count JavaScript files"
    
    echo "$js_list"
}

download_js_files() {
    local js_list="$1"
    local download_dir="$2"
    
    [[ ! -f "$js_list" ]] && return 1
    
    mkdir -p "$download_dir"
    
    print_info "Downloading JavaScript files to $download_dir"
    
    local count=0
    while IFS= read -r url; do
        [[ -z "$url" ]] && continue
        
        # Generate safe filename
        local filename
        filename=$(echo "$url" | md5sum | cut -d' ' -f1).js
        
        # Download with size limit
        timeout "$JS_TIMEOUT" curl -s -L "$url" --max-filesize "$JS_MAX_SIZE" \
            -o "${download_dir}/${filename}" 2>/dev/null || continue
        
        ((count++))
    done < "$js_list"
    
    print_success "Downloaded $count JavaScript files"
}

#==============================================================================
# ENDPOINT EXTRACTION
#==============================================================================

extract_api_endpoints() {
    local js_dir="$1"
    local output_file="$2"
    
    print_info "Extracting API endpoints from JavaScript"
    
    # Common API patterns
    grep -rhoP '["'\''](/api/[a-zA-Z0-9/_\-\.]+)["'\'']' "$js_dir" 2>/dev/null | \
        sed 's/["\x27]//g' | sort -u > "$output_file"
    
    # REST patterns
    grep -rhoP '["'\'']/(v[0-9]+/)?[a-z]+/[a-zA-Z0-9/_\-\.]+["'\'']' "$js_dir" 2>/dev/null | \
        sed 's/["\x27]//g' | grep -E '^/(api|v[0-9]|rest|graphql)' >> "$output_file"
    
    # HTTP method calls
    grep -rhoP '(get|post|put|delete|patch)\s*\(\s*["'\''][^"'\'']+["'\'']' "$js_dir" 2>/dev/null | \
        grep -oP '["'\''][^"'\'']+["'\'']' | sed 's/["\x27]//g' | \
        grep '^/' >> "$output_file"
    
    # Axios/fetch patterns
    grep -rhoP '(axios|fetch)\s*\(\s*["'\''][^"'\'']+["'\'']' "$js_dir" 2>/dev/null | \
        grep -oP '["'\''][^"'\'']+["'\'']' | sed 's/["\x27]//g' | \
        grep '^/' >> "$output_file"
    
    # Deduplicate and clean
    sort -u "$output_file" -o "$output_file"
    
    local count
    count=$(wc -l < "$output_file")
    print_success "Extracted $count unique API endpoints"
}

#==============================================================================
# SECRET DETECTION
#==============================================================================

find_secrets_in_js() {
    local js_dir="$1"
    local output_file="$2"
    
    print_info "Searching for secrets in JavaScript"
    
    cat > "$output_file" << 'EOF'
# JavaScript Secrets Analysis

## API Keys
EOF
    
    # API keys
    grep -rhoP '(["\x27])[a-zA-Z0-9_\-]{20,}(["\x27])' "$js_dir" 2>/dev/null | \
        grep -iE '(api[_-]?key|apikey|access[_-]?key|secret)' | \
        head -20 >> "$output_file"
    
    echo -e "\n## Tokens" >> "$output_file"
    
    # JWT tokens
    grep -rhoP 'eyJ[a-zA-Z0-9_\-]*\.eyJ[a-zA-Z0-9_\-]*\.[a-zA-Z0-9_\-]*' "$js_dir" 2>/dev/null | \
        head -10 >> "$output_file"
    
    echo -e "\n## AWS Credentials" >> "$output_file"
    
    # AWS keys
    grep -rhoP 'AKIA[0-9A-Z]{16}' "$js_dir" 2>/dev/null | \
        head -10 >> "$output_file"
    
    echo -e "\n## Passwords/Credentials" >> "$output_file"
    
    # Hardcoded passwords
    grep -rhoP '(password|passwd|pwd)\s*[:=]\s*["'\''][^"'\'']+["'\'']' "$js_dir" 2>/dev/null | \
        head -20 >> "$output_file"
    
    echo -e "\n## URLs and Endpoints" >> "$output_file"
    
    # Internal URLs
    grep -rhoP 'https?://[a-zA-Z0-9\.\-]+' "$js_dir" 2>/dev/null | \
        grep -vE '(googleapis|cloudflare|cdn|jquery)' | \
        sort -u | head -30 >> "$output_file"
    
    print_success "Secret analysis complete"
}

#==============================================================================
# SUBDOMAIN DISCOVERY
#==============================================================================

find_subdomains_in_js() {
    local js_dir="$1"
    local base_domain="$2"
    local output_file="$3"
    
    print_info "Searching for subdomains in JavaScript"
    
    # Extract domain from URL if full URL provided
    local domain
    domain=$(echo "$base_domain" | sed 's|https\?://||' | cut -d'/' -f1 | sed 's/www\.//')
    
    grep -rhoP '[a-zA-Z0-9\-]+\.'$(echo "$domain" | sed 's/\./\\./g') "$js_dir" 2>/dev/null | \
        sort -u > "$output_file"
    
    local count
    count=$(wc -l < "$output_file")
    print_success "Found $count potential subdomains"
}

#==============================================================================
# INTERESTING PATTERNS
#==============================================================================

find_interesting_patterns() {
    local js_dir="$1"
    local output_file="$2"
    
    print_info "Searching for interesting patterns"
    
    cat > "$output_file" << 'EOF'
# Interesting JavaScript Patterns

## Debug/Development Code
EOF
    
    # Debug code
    grep -rn 'console\.(log|debug|error)' "$js_dir" 2>/dev/null | \
        head -20 >> "$output_file"
    
    echo -e "\n## Comments with Sensitive Info" >> "$output_file"
    
    # Comments with TODO, FIXME, XXX, HACK
    grep -rn '//.*\(TODO\|FIXME\|XXX\|HACK\|BUG\)' "$js_dir" 2>/dev/null | \
        head -20 >> "$output_file"
    
    echo -e "\n## Admin/Privileged Functions" >> "$output_file"
    
    # Admin functions
    grep -rn 'function.*\(admin\|root\|superuser\)' "$js_dir" 2>/dev/null | \
        head -20 >> "$output_file"
    
    echo -e "\n## Authentication/Authorization" >> "$output_file"
    
    # Auth patterns
    grep -rn '\(isAdmin\|hasPermission\|checkAuth\|requireAuth\)' "$js_dir" 2>/dev/null | \
        head -20 >> "$output_file"
    
    print_success "Pattern analysis complete"
}

#==============================================================================
# REPORTING
#==============================================================================

generate_js_analysis_report() {
    local target="$1"
    local output_dir="$2"
    local endpoints_file="${output_dir}/js_endpoints.txt"
    local secrets_file="${output_dir}/js_secrets.md"
    local subdomains_file="${output_dir}/js_subdomains.txt"
    local patterns_file="${output_dir}/js_patterns.md"
    local report_file="${output_dir}/js_analysis.md"
    
    cat > "$report_file" << EOF
# JavaScript Analysis Report

**Target**: $target  
**Date**: $(date '+%Y-%m-%d %H:%M:%S')

---

## Summary

EOF
    
    # Endpoints
    if [[ -f "$endpoints_file" ]]; then
        local endpoint_count
        endpoint_count=$(wc -l < "$endpoints_file")
        echo "- **API Endpoints**: $endpoint_count discovered" >> "$report_file"
        echo "" >> "$report_file"
        echo "### Top Endpoints" >> "$report_file"
        head -20 "$endpoints_file" | sed 's/^/- /' >> "$report_file"
    fi
    
    echo "" >> "$report_file"
    
    # Subdomains
    if [[ -f "$subdomains_file" ]]; then
        local subdomain_count
        subdomain_count=$(wc -l < "$subdomains_file")
        echo "- **Subdomains**: $subdomain_count found" >> "$report_file"
        echo "" >> "$report_file"
        echo "### Discovered Subdomains" >> "$report_file"
        cat "$subdomains_file" | sed 's/^/- /' >> "$report_file"
    fi
    
    echo -e "\n---\n" >> "$report_file"
    
    # Include secrets
    if [[ -f "$secrets_file" ]]; then
        echo "## Secret Analysis" >> "$report_file"
        cat "$secrets_file" >> "$report_file"
    fi
    
    echo -e "\n---\n" >> "$report_file"
    
    # Include patterns
    if [[ -f "$patterns_file" ]]; then
        echo "## Interesting Patterns" >> "$report_file"
        cat "$patterns_file" >> "$report_file"
    fi
    
    # Recommendations
    cat >> "$report_file" << 'EOF'

---

## Recommendations

1. **Test Discovered Endpoints**
   - Verify authentication requirements
   - Test for IDOR/BOLA vulnerabilities
   - Check rate limiting

2. **Validate Secrets**
   - Test any discovered API keys
   - Verify JWT token signatures
   - Check AWS credential validity

3. **Subdomain Enumeration**
   - Verify subdomain resolution
   - Test for subdomain takeover
   - Check for sensitive subdomains

4. **Review Debug Code**
   - Check for exposed development endpoints
   - Look for verbose error messages
   - Test debug functionality

EOF
    
    print_success "JavaScript analysis report generated: $report_file"
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

run_js_analysis() {
    local target="$1"
    local output_dir="$2"
    
    print_header "JavaScript Analysis"
    
    # Discover JS files
    local js_list
    js_list=$(discover_js_files "$target" "$output_dir")
    
    # Download JS files
    download_js_files "$js_list" "$JS_DOWNLOAD_DIR"
    
    # Extract endpoints
    extract_api_endpoints "$JS_DOWNLOAD_DIR" "${output_dir}/js_endpoints.txt"
    
    # Find secrets
    find_secrets_in_js "$JS_DOWNLOAD_DIR" "${output_dir}/js_secrets.md"
    
    # Find subdomains
    find_subdomains_in_js "$JS_DOWNLOAD_DIR" "$target" "${output_dir}/js_subdomains.txt"
    
    # Find interesting patterns
    find_interesting_patterns "$JS_DOWNLOAD_DIR" "${output_dir}/js_patterns.md"
    
    # Generate report
    generate_js_analysis_report "$target" "$output_dir"
    
    # Cleanup
    rm -rf "$JS_DOWNLOAD_DIR"
    
    print_success "JavaScript analysis complete"
}

# Allow direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <target_url> <output_dir>"
        exit 1
    fi
    
    run_js_analysis "$1" "$2"
fi
