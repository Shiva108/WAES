#!/usr/bin/env bash
#==============================================================================
# WAES - OWASP Top 10 (2021) Scanner
# Focused vulnerability testing for OWASP categories
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/cvss_calculator.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/evidence_collector.sh" 2>/dev/null || true

#==============================================================================
# CONFIGURATION
#==============================================================================

OWASP_MODE="${OWASP_MODE:-quick}"  # quick or thorough
OWASP_FINDINGS=()

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

add_owasp_finding() {
    local category="$1"
    local severity="$2"
    local title="$3"
    local description="$4"
    local evidence="$5"
    
    local finding=$(cat <<EOF
{
  "category": "$category",
  "severity": "$severity",
  "title": "$title",
  "description": "$description",
  "evidence": "$evidence",
  "timestamp": "$(date '+%Y-%m-%d %H:%M:%S')"
}
EOF
)
    
    OWASP_FINDINGS+=("$finding")
    
    # Save to findings file
    if [[ -n "${REPORT_DIR:-}" ]]; then
        echo "$finding" >> "${REPORT_DIR}/.owasp_findings.json"
    fi
}

#==============================================================================
# A01: BROKEN ACCESS CONTROL
#==============================================================================

test_access_control() {
    local base_url="$1"
    print_info "[A01] Testing Broken Access Control..."
    
    # Path traversal
    print_running "  - Path traversal detection"
    local paths=("../../../etc/passwd" "..\\..\\..\\windows\\win.ini" "....//....//....//etc/passwd")
    
    for path in "${paths[@]}"; do
        local response
        response=$(curl -sk -o /dev/null -w "%{http_code}" "${base_url}/${path}" 2>/dev/null)
        
        if [[ "$response" == "200" ]]; then
            add_owasp_finding "A01" "HIGH" \
                "Path Traversal Vulnerability" \
                "Server responds to path traversal attempt: ${path}" \
                "HTTP 200 response to ${base_url}/${path}"
            print_warn "    → Found: Path traversal (${path})"
        fi
    done
    
    # Forced browsing
    print_running "  - Forced browsing (admin paths)"
    local admin_paths=("admin" "administrator" "api/admin" "api/internal" "dashboard" "manage")
    
    for path in "${admin_paths[@]}"; do
        local response
        response=$(curl -sk -o /dev/null -w "%{http_code}" "${base_url}/${path}" 2>/dev/null)
        
        if [[ "$response" == "200" ]]; then
            add_owasp_finding "A01" "MEDIUM" \
                "Unprotected Admin Path" \
                "Admin path accessible without authentication: /${path}" \
                "HTTP 200 response to ${base_url}/${path}"
            print_warn "    → Found: Accessible admin path (/${path})"
        fi
    done
}

#==============================================================================
# A02: CRYPTOGRAPHIC FAILURES
#==============================================================================

test_crypto_failures() {
    local target="$1"
    local port="$2"
    print_info "[A02] Testing Cryptographic Failures..."
    
    if command -v openssl &>/dev/null; then
        print_running "  - SSL/TLS configuration"
        
        # Test for SSLv3, TLS 1.0, TLS 1.1
        local weak_protocols=("ssl3" "tls1" "tls1_1")
        
        for proto in "${weak_protocols[@]}"; do
            if timeout 3 openssl s_client -connect "${target}:${port}" -"${proto}" </dev/null 2>/dev/null | grep -q "CONNECTED"; then
                add_owasp_finding "A02" "HIGH" \
                    "Weak TLS Protocol Supported" \
                    "Server accepts deprecated protocol: ${proto}" \
                    "OpenSSL connection successful with -${proto}"
                print_warn "    → Found: Weak protocol ${proto}"
            fi
        done
    fi
    
    # Check for sensitive data in responses
    print_running "  - Sensitive data exposure"
    local response
    response=$(curl -sk "${base_url}" 2>/dev/null)
    
    if echo "$response" | grep -qiE "(password|api[_-]?key|secret|token)"; then
        add_owasp_finding "A02" "CRITICAL" \
            "Sensitive Data in Response" \
            "Response contains potential credentials/keys" \
            "Found sensitive keywords in HTTP response"
        print_warn "    → Found: Potential sensitive data exposure"
    fi
}

#==============================================================================
# A03: INJECTION
#==============================================================================

test_injection() {
    local base_url="$1"
    print_info "[A03] Testing Injection Vulnerabilities..."
    
    # SQL Injection - Error-based
    print_running "  - SQL Injection (error-based)"
    local sqli_payloads=("'" "1' OR '1'='1" "admin'--" "1' UNION SELECT NULL--")
    
    for payload in "${sqli_payloads[@]}"; do
        local encoded
        encoded=$(echo -n "$payload" | jq -sRr @uri)
        local response
        response=$(curl -sk "${base_url}?id=${encoded}" 2>/dev/null)
        
        if echo "$response" | grep -qiE "(sql|mysql|sqlite|postgresql|quer y error|syntax error)"; then
            add_owasp_finding "A03" "CRITICAL" \
                "SQL Injection Vulnerability" \
                "SQL error message detected with payload: ${payload}" \
                "Database error in response"
            print_warn "    → Found: SQL injection (error-based)"
            break
        fi
    done
    
    # XSS - Reflected
    print_running "  - Cross-Site Scripting (XSS)"
    local xss_payloads=("<script>alert(1)</script>" "<img src=x onerror=alert(1)>")
    
    for payload in "${xss_payloads[@]}"; do
        local encoded
        encoded=$(echo -n "$payload" | jq -sRr @uri)
        local response
        response=$(curl -sk "${base_url}?q=${encoded}" 2>/dev/null)
        
        if echo "$response" | grep -qF "$payload"; then
            add_owasp_finding "A03" "HIGH" \
                "Reflected XSS Vulnerability" \
                "Input reflected without sanitization: ${payload}" \
                "Payload echoed in response"
            print_warn "    → Found: Reflected XSS"
            break
        fi
    done
    
    # Command Injection
    print_running "  - Command Injection"
    local cmd_payloads=(";ls" "| whoami" "\`id\`")
    
    for payload in "${cmd_payloads[@]}"; do
        local response
        response=$(curl -sk "${base_url}?cmd=${payload}" 2>/dev/null)
        
        if echo "$response" | grep -qE "(root|bin|etc|uid=)"; then
            add_owasp_finding "A03" "CRITICAL" \
                "Command Injection Vulnerability" \
                "System command output detected with payload: ${payload}" \
                "Command output in response"
            print_warn "    → Found: Command injection"
            break
        fi
    done
}

#==============================================================================
# A05: SECURITY MISCONFIGURATION
#==============================================================================

test_misconfiguration() {
    local base_url="$1"
    print_info "[A05] Testing Security Misconfiguration..."
    
    # Directory listing
    print_running "  - Directory listing"
    local response
    response=$(curl -sk "${base_url}/" 2>/dev/null)
    
    if echo "$response" | grep -qiE "(index of|directory listing|parent directory)"; then
        add_owasp_finding "A05" "MEDIUM" \
            "Directory Listing Enabled" \
            "Web server exposes directory contents" \
            "Directory index page detected"
        print_warn "    → Found: Directory listing"
    fi
    
    # Missing security headers
    print_running "  - Security headers"
    local headers
    headers=$(curl -skI "${base_url}" 2>/dev/null)
    
    local missing_headers=()
    echo "$headers" | grep -qi "X-Frame-Options" || missing_headers+=("X-Frame-Options")
    echo "$headers" | grep -qi "X-Content-Type-Options" || missing_headers+=("X-Content-Type-Options")
    echo "$headers" | grep -qi "Content-Security-Policy" || missing_headers+=("Content-Security-Policy")
    echo "$headers" | grep -qi "Strict-Transport-Security" || missing_headers+=("Strict-Transport-Security")
    
    if [[ ${#missing_headers[@]} -gt 0 ]]; then
        add_owasp_finding "A05" "LOW" \
            "Missing Security Headers" \
            "Missing headers: ${missing_headers[*]}" \
            "HTTP response header analysis"
        print_warn "    → Found: Missing security headers (${#missing_headers[@]})"
    fi
    
    # Verbose error messages
    print_running "  - Error message disclosure"
    response=$(curl -sk "${base_url}/nonexistent" 2>/dev/null)
    
    if echo "$response" | grep -qiE "(stack trace|exception|debug|version)"; then
        add_owasp_finding "A05" "LOW" \
            "Verbose Error Messages" \
            "Server exposes stack traces or debug information" \
            "Detailed error in 404 response"
        print_warn "    → Found: Verbose errors"
    fi
}

#==============================================================================
# A07: AUTHENTICATION FAILURES
#==============================================================================

test_auth_failures() {
    local base_url="$1"
    print_info "[A07] Testing Authentication Failures..."
    
    # Default credentials
    print_running "  - Default credentials"
    local creds=("admin:admin" "admin:password" "root:root" "test:test")
    
    for cred in "${creds[@]}"; do
        local response
        response=$(curl -sk -u "$cred" "${base_url}/admin" -o /dev/null -w "%{http_code}" 2>/dev/null)
        
        if [[ "$response" == "200" ]]; then
            add_owasp_finding "A07" "CRITICAL" \
                "Default Credentials Accepted" \
                "Server accepts default credentials: ${cred%%:*}" \
                "HTTP 200 with Basic Auth: ${cred}"
            print_warn "    → Found: Default credentials work"
            break
        fi
    done
    
    # Session fixation check
    print_running "  - Session management"
    local cookies1 cookies2
    cookies1=$(curl -skI "${base_url}" | grep -i "Set-Cookie" || true)
    cookies2=$(curl -skI "${base_url}" | grep -i "Set-Cookie" || true)
    
    if [[ -n "$cookies1" ]] && [[ "$cookies1" == "$cookies2" ]]; then
        add_owasp_finding "A07" "MEDIUM" \
            "Weak Session Management" \
            "Session tokens appear predictable or reused" \
            "Identical cookies on subsequent requests"
        print_warn "    → Found: Weak session tokens"
    fi
}

#==============================================================================
# MAIN SCAN ORCHESTRATOR
#==============================================================================

run_owasp_scan() {
    local target="$1"
    local port="${2:-80}"
    local protocol="${3:-http}"
    
    local base_url="${protocol}://${target}:${port}"
    
    print_header "OWASP Top 10 Security Scan"
    echo "Target: ${base_url}"
    echo "Mode: ${OWASP_MODE}"
    echo ""
    
    # Run tests
    test_access_control "$base_url"
    test_crypto_failures "$target" "$port"
    test_injection "$base_url"
    test_misconfiguration "$base_url"
    test_auth_failures "$base_url"
    
    # Summary
    echo ""
    print_success "OWASP scan completed"
    print_info "Findings: ${#OWASP_FINDINGS[@]}"
    
    # Generate report
    if declare -f generate_owasp_report &>/dev/null; then
        generate_owasp_report "$target" "${REPORT_DIR}"
    fi
}

# CLI interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_owasp_scan "$@"
fi
