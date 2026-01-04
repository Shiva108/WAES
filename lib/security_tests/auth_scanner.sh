#!/usr/bin/env bash
#==============================================================================
# WAES Authentication & Session Security Testing Module
# Tests for session management, token security, and auth weaknesses
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
# COOKIE SECURITY ANALYSIS
#==============================================================================

check_cookie_flags() {
    local url="$1"
    local output_file="$2"
    
    print_running "  Analyzing cookie security flags..."
    
    local cookies
    cookies=$(curl -sk -I -c - "$url" 2>/dev/null | grep -i "set-cookie")
    
    if [[ -z "$cookies" ]]; then
        print_info "    No cookies set by server"
        return 0
    fi
    
    local issues=0
    
    # Check each cookie
    while IFS= read -r cookie; do
        local cookie_name
        cookie_name=$(echo "$cookie" | sed 's/Set-Cookie: *//i' | cut -d'=' -f1)
        
        # Check HttpOnly flag
        if ! echo "$cookie" | grep -qi "httponly"; then
            echo "[AUTH] Cookie '$cookie_name' missing HttpOnly flag" >> "$output_file"
            print_warn "    → $cookie_name: Missing HttpOnly"
            ((issues++))
        fi
        
        # Check Secure flag
        if ! echo "$cookie" | grep -qi "secure"; then
            echo "[AUTH] Cookie '$cookie_name' missing Secure flag" >> "$output_file"
            print_warn "    → $cookie_name: Missing Secure"
            ((issues++))
        fi
        
        # Check SameSite
        if ! echo "$cookie" | grep -qi "samesite"; then
            echo "[AUTH] Cookie '$cookie_name' missing SameSite attribute" >> "$output_file"
            print_warn "    → $cookie_name: Missing SameSite"
            ((issues++))
        fi
    done <<< "$cookies"
    
    return $issues
}

#==============================================================================
# SESSION TOKEN ANALYSIS
#==============================================================================

analyze_session_token() {
    local url="$1"
    local output_file="$2"
    
    print_running "  Analyzing session token entropy..."
    
    # Collect multiple session tokens
    local tokens=()
    for i in {1..5}; do
        local token
        token=$(curl -sk -c - "$url" 2>/dev/null | grep -i "session\|token\|sid" | head -1 | awk '{print $NF}')
        [[ -n "$token" ]] && tokens+=("$token")
        sleep 0.5
    done
    
    if [[ ${#tokens[@]} -lt 2 ]]; then
        print_info "    Unable to collect session tokens for analysis"
        return 0
    fi
    
    local issues=0
    
    # Check for sequential tokens
    local prev_token=""
    for token in "${tokens[@]}"; do
        if [[ -n "$prev_token" ]]; then
            # Simple check for similar tokens
            local diff_chars
            diff_chars=$(echo "$token$prev_token" | fold -w1 | sort | uniq -u | wc -l)
            
            if [[ $diff_chars -lt 5 ]]; then
                echo "[AUTH] Session tokens appear sequential or predictable" >> "$output_file"
                print_warn "    → Tokens show low variance (potential predictability)"
                ((issues++))
                break
            fi
        fi
        prev_token="$token"
    done
    
    # Check token length
    local token_len=${#tokens[0]}
    if [[ $token_len -lt 16 ]]; then
        echo "[AUTH] Session token too short: $token_len characters" >> "$output_file"
        print_warn "    → Token length $token_len chars (recommended: 32+)"
        ((issues++))
    fi
    
    return $issues
}

#==============================================================================
# RATE LIMITING TEST
#==============================================================================

test_rate_limiting() {
    local url="$1"
    local output_file="$2"
    
    print_running "  Testing login rate limiting..."
    
    # Find login endpoint
    local login_paths=("login" "signin" "auth" "api/login" "user/login")
    local login_url=""
    
    for path in "${login_paths[@]}"; do
        local code
        code=$(curl -sk -o /dev/null -w "%{http_code}" "${url}/${path}" 2>/dev/null)
        if [[ "$code" == "200" ]] || [[ "$code" == "302" ]]; then
            login_url="${url}/${path}"
            break
        fi
    done
    
    if [[ -z "$login_url" ]]; then
        print_info "    No login endpoint found"
        return 0
    fi
    
    print_info "    Testing rate limiting on $login_url"
    
    # Send multiple failed login attempts
    local blocked=false
    for i in {1..20}; do
        local response
        response=$(curl -sk -X POST "$login_url" \
            -d "username=admin&password=wrongpass$i" \
            -w "\n%{http_code}" --max-time 5 2>/dev/null)
        
        local code
        code=$(echo "$response" | tail -1)
        
        # Check for rate limiting indicators
        if [[ "$code" == "429" ]] || [[ "$code" == "403" ]]; then
            blocked=true
            break
        fi
        
        if echo "$response" | grep -qiE "too many|rate limit|locked|blocked|try again"; then
            blocked=true
            break
        fi
    done
    
    if [[ "$blocked" == "false" ]]; then
        echo "[AUTH] No rate limiting detected on login (20 attempts allowed)" >> "$output_file"
        print_warn "    → No rate limiting after 20 failed attempts"
        return 1
    else
        print_success "    Rate limiting detected"
        return 0
    fi
}

#==============================================================================
# SESSION FIXATION TEST
#==============================================================================

test_session_fixation() {
    local url="$1"
    local output_file="$2"
    
    print_running "  Testing for session fixation..."
    
    # Get initial session
    local session1
    session1=$(curl -sk -c - "$url" 2>/dev/null | grep -i "session\|sid" | head -1 | awk '{print $NF}')
    
    if [[ -z "$session1" ]]; then
        print_info "    No session cookie detected"
        return 0
    fi
    
    # Simulate login with forced session
    local login_paths=("login" "signin" "auth")
    for path in "${login_paths[@]}"; do
        local response
        response=$(curl -sk -X POST "${url}/${path}" \
            -b "session=$session1" \
            -d "username=test&password=test" \
            -c - 2>/dev/null)
        
        # Check if session changed
        local session2
        session2=$(echo "$response" | grep -i "session\|sid" | head -1 | awk '{print $NF}')
        
        if [[ -n "$session2" ]] && [[ "$session1" == "$session2" ]]; then
            echo "[AUTH] Session fixation vulnerability - session not regenerated after login" >> "$output_file"
            print_warn "    → Session not regenerated after authentication"
            return 1
        fi
    done
    
    return 0
}

#==============================================================================
# SECURITY HEADERS CHECK
#==============================================================================

check_security_headers() {
    local url="$1"
    local output_file="$2"
    
    print_running "  Checking authentication-related security headers..."
    
    local headers
    headers=$(curl -sk -I "$url" 2>/dev/null)
    
    local issues=0
    
    # Check for important security headers
    declare -A required_headers=(
        ["X-Frame-Options"]="Clickjacking protection"
        ["X-Content-Type-Options"]="MIME sniffing protection"
        ["X-XSS-Protection"]="XSS filter"
        ["Content-Security-Policy"]="CSP policy"
        ["Strict-Transport-Security"]="HSTS"
    )
    
    for header in "${!required_headers[@]}"; do
        if ! echo "$headers" | grep -qi "$header"; then
            echo "[AUTH] Missing security header: $header (${required_headers[$header]})" >> "$output_file"
            print_warn "    → Missing: $header"
            ((issues++))
        fi
    done
    
    return $issues
}

#==============================================================================
# MAIN AUTH SCAN FUNCTION
#==============================================================================

scan_authentication() {
    local target_url="$1"
    local report_dir="${2:-.}"
    
    local domain
    domain=$(echo "$target_url" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
    local output_file="${report_dir}/${domain}_auth_scan.txt"
    
    print_info "Starting Authentication/Session scan for: $target_url"
    echo ""
    
    {
        echo "=== Authentication & Session Security Scan ==="
        echo "Target: $target_url"
        echo "Scan Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } > "$output_file"
    
    local total_issues=0
    
    check_cookie_flags "$target_url" "$output_file"
    total_issues=$((total_issues + $?))
    
    analyze_session_token "$target_url" "$output_file"
    total_issues=$((total_issues + $?))
    
    test_rate_limiting "$target_url" "$output_file"
    total_issues=$((total_issues + $?))
    
    test_session_fixation "$target_url" "$output_file"
    total_issues=$((total_issues + $?))
    
    check_security_headers "$target_url" "$output_file"
    total_issues=$((total_issues + $?))
    
    {
        echo ""
        echo "=== Scan Summary ==="
        echo "Total issues found: $total_issues"
    } >> "$output_file"
    
    if [[ $total_issues -gt 0 ]]; then
        print_warn "Found $total_issues authentication/session security issues"
    else
        print_success "No major authentication issues detected"
    fi
    
    print_success "Authentication scan complete: $output_file"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat <<EOF
Usage: $0 <target_url> [report_dir]

Authentication & Session Security Testing Module
Tests cookie security, session tokens, rate limiting, and security headers.

Examples:
    $0 http://example.com/
    $0 http://example.com ./reports
EOF
        exit 1
    fi
    
    scan_authentication "$@"
fi
