#!/usr/bin/env bash
#==============================================================================
# WAES API Security Testing Module
# Tests for API-specific vulnerabilities
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
# API ENDPOINT DISCOVERY
#==============================================================================

discover_api_endpoints() {
    local url="$1"
    local output_file="$2"
    
    print_running "  Discovering API endpoints..."
    
    # Common API documentation paths
    local api_docs=(
        "swagger.json" "swagger/v1/swagger.json" "openapi.json"
        "api/swagger.json" "api-docs" "api-docs.json"
        "swagger-ui.html" "swagger-ui/" "docs/api"
        "v1/api-docs" "v2/api-docs" "api/v1" "api/v2"
        ".well-known/openapi.json" "graphql" "graphql/schema"
    )
    
    local found_endpoints=()
    
    for endpoint in "${api_docs[@]}"; do
        local code
        code=$(curl -sk -o /dev/null -w "%{http_code}" "${url}/${endpoint}" 2>/dev/null)
        
        if [[ "$code" == "200" ]]; then
            found_endpoints+=("/$endpoint")
            echo "[API] API documentation found: /${endpoint}" >> "$output_file"
            print_warn "    → Found: /${endpoint}"
        fi
    done
    
    # Common API paths
    local api_paths=(
        "api" "api/v1" "api/v2" "v1" "v2"
        "rest" "graphql" "query" "mutation"
        "api/users" "api/admin" "api/config" "api/debug"
    )
    
    for path in "${api_paths[@]}"; do
        local response
        response=$(curl -sk -w "\n%{http_code}" "${url}/${path}" 2>/dev/null)
        local code
        code=$(echo "$response" | tail -1)
        local body
        body=$(echo "$response" | head -n -1)
        
        # Check for JSON response (likely API)
        if [[ "$code" == "200" ]] && echo "$body" | grep -qE '^\s*[\[{]'; then
            found_endpoints+=("/$path")
            print_info "    Found API endpoint: /${path}"
        fi
    done
    
    echo "${found_endpoints[@]}"
}

#==============================================================================
# API AUTHENTICATION TESTS
#==============================================================================

test_api_auth_bypass() {
    local url="$1"
    local output_file="$2"
    
    print_running "  Testing API authentication bypass..."
    
    local protected_paths=("api/admin" "api/users" "api/config" "api/internal" "admin/api")
    local issues=0
    
    for path in "${protected_paths[@]}"; do
        local response
        response=$(curl -sk -w "\n%{http_code}" "${url}/${path}" 2>/dev/null)
        local code
        code=$(echo "$response" | tail -1)
        local body
        body=$(echo "$response" | head -n -1)
        
        # Check if sensitive endpoint accessible without auth
        if [[ "$code" == "200" ]]; then
            if echo "$body" | grep -qiE 'user|admin|config|password|secret|key'; then
                echo "[API] Unprotected sensitive API endpoint: /${path}" >> "$output_file"
                print_warn "    → Unprotected: /${path}"
                ((issues++))
            fi
        fi
    done
    
    # Test missing auth header scenarios
    local api_base="${url}/api"
    
    # Test without any auth
    local no_auth
    no_auth=$(curl -sk -o /dev/null -w "%{http_code}" "$api_base" 2>/dev/null)
    
    # Test with fake JWT
    local fake_jwt="eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0.eyJhZG1pbiI6dHJ1ZX0."
    local jwt_bypass
    jwt_bypass=$(curl -sk -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $fake_jwt" "$api_base" 2>/dev/null)
    
    if [[ "$jwt_bypass" == "200" ]] && [[ "$no_auth" != "200" ]]; then
        echo "[API] JWT 'alg:none' bypass possible" >> "$output_file"
        print_warn "    → JWT algorithm bypass detected"
        ((issues++))
    fi
    
    return $issues
}

#==============================================================================
# RATE LIMITING TEST
#==============================================================================

test_api_rate_limiting() {
    local url="$1"
    local output_file="$2"
    
    print_running "  Testing API rate limiting..."
    
    local api_endpoint="${url}/api"
    local blocked=false
    local request_count=0
    
    for i in {1..50}; do
        local code
        code=$(curl -sk -o /dev/null -w "%{http_code}" "$api_endpoint" --max-time 2 2>/dev/null)
        ((request_count++))
        
        if [[ "$code" == "429" ]]; then
            blocked=true
            break
        fi
    done
    
    if [[ "$blocked" == "false" ]]; then
        echo "[API] No rate limiting detected (50 rapid requests allowed)" >> "$output_file"
        print_warn "    → No rate limiting after $request_count requests"
        return 1
    else
        print_success "    Rate limiting triggered after $request_count requests"
        return 0
    fi
}

#==============================================================================
# DATA EXPOSURE TEST
#==============================================================================

test_data_exposure() {
    local url="$1"
    local output_file="$2"
    
    print_running "  Testing for excessive data exposure..."
    
    local issues=0
    local sensitive_patterns=(
        "password" "secret" "api_key" "apikey" "token" "access_token"
        "private_key" "credit_card" "ssn" "social_security"
        "internal" "debug" "stack_trace" "exception"
    )
    
    # Check common API responses
    local api_paths=("api" "api/user" "api/me" "api/profile" "api/account")
    
    for path in "${api_paths[@]}"; do
        local response
        response=$(curl -sk "${url}/${path}" --max-time 10 2>/dev/null)
        
        if [[ -z "$response" ]]; then
            continue
        fi
        
        for pattern in "${sensitive_patterns[@]}"; do
            if echo "$response" | grep -qi "\"$pattern\""; then
                echo "[API] Potential data exposure in /${path}: $pattern field present" >> "$output_file"
                print_warn "    → /${path}: Exposes '$pattern' field"
                ((issues++))
                break
            fi
        done
    done
    
    return $issues
}

#==============================================================================
# CORS MISCONFIGURATION TEST
#==============================================================================

test_cors_config() {
    local url="$1"
    local output_file="$2"
    
    print_running "  Testing CORS configuration..."
    
    local issues=0
    
    # Test with evil origin
    local response
    response=$(curl -sk -I -H "Origin: https://evil.com" "$url" 2>/dev/null)
    
    local acao
    acao=$(echo "$response" | grep -i "Access-Control-Allow-Origin" | head -1)
    
    if echo "$acao" | grep -qi "evil.com"; then
        echo "[API] CORS misconfiguration: Reflects arbitrary origin (evil.com)" >> "$output_file"
        print_warn "    → Reflects arbitrary Origin header"
        ((issues++))
    elif echo "$acao" | grep -qi "\*"; then
        # Check if credentials allowed with wildcard
        if echo "$response" | grep -qi "Access-Control-Allow-Credentials.*true"; then
            echo "[API] CORS misconfiguration: Wildcard with credentials" >> "$output_file"
            print_warn "    → Wildcard origin with credentials allowed"
            ((issues++))
        fi
    fi
    
    return $issues
}

#==============================================================================
# MAIN API SCAN FUNCTION
#==============================================================================

scan_api_security() {
    local target_url="$1"
    local report_dir="${2:-.}"
    
    local domain
    domain=$(echo "$target_url" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
    local output_file="${report_dir}/${domain}_api_scan.txt"
    
    print_info "Starting API Security scan for: $target_url"
    echo ""
    
    {
        echo "=== API Security Scan ==="
        echo "Target: $target_url"
        echo "Scan Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } > "$output_file"
    
    local total_issues=0
    
    discover_api_endpoints "$target_url" "$output_file"
    
    test_api_auth_bypass "$target_url" "$output_file"
    total_issues=$((total_issues + $?))
    
    test_api_rate_limiting "$target_url" "$output_file"
    total_issues=$((total_issues + $?))
    
    test_data_exposure "$target_url" "$output_file"
    total_issues=$((total_issues + $?))
    
    test_cors_config "$target_url" "$output_file"
    total_issues=$((total_issues + $?))
    
    {
        echo ""
        echo "=== Scan Summary ==="
        echo "Total issues found: $total_issues"
    } >> "$output_file"
    
    if [[ $total_issues -gt 0 ]]; then
        print_warn "Found $total_issues API security issues"
    else
        print_success "No major API security issues detected"
    fi
    
    print_success "API security scan complete: $output_file"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat <<EOF
Usage: $0 <target_url> [report_dir]

API Security Testing Module
Tests for endpoint discovery, auth bypass, rate limiting, data exposure, and CORS.

Examples:
    $0 http://example.com/
    $0 http://example.com ./reports
EOF
        exit 1
    fi
    
    scan_api_security "$@"
fi
