#!/usr/bin/env bash
#==============================================================================
# WAES SSL/TLS Certificate Analysis Module
# Comprehensive SSL/TLS security assessment
#==============================================================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

source "${SCRIPT_DIR}/colors.sh" 2>/dev/null || {
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
    print_running() { echo "[>] $*"; }
}

#==============================================================================
# CERTIFICATE EXTRACTION
#==============================================================================

extract_certificate_details() {
    local target="$1"
    local port="${2:-443}"
    local output_file="$3"
    
    print_running "Extracting SSL certificate details..."
    
    # Get certificate
    local cert
    cert=$(echo | timeout 10 openssl s_client -connect "$target:$port" -servername "$target" 2>/dev/null | \
        openssl x509 -noout -text 2>/dev/null)
    
    if [[ -z "$cert" ]]; then
        print_warn "Could not extract certificate"
        return 1
    fi
    
    {
        echo "=== SSL Certificate Details ==="
        echo ""
        
        # Subject
        echo "## Subject"
        echo "$cert" | grep "Subject:" | sed 's/^ *//'
        echo ""
        
        # Issuer
        echo "## Issuer"
        echo "$cert" | grep "Issuer:" | sed 's/^ *//'
        echo ""
        
        # Validity
        echo "## Validity"
        echo "$cert" | grep -A2 "Validity" | sed 's/^ *//'
        echo ""
        
        # Subject Alternative Names (SAN)
        echo "## Subject Alternative Names (SAN)"
        local san
        san=$(echo "$cert" | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/^ *//')
        if [[ -n "$san" ]]; then
            echo "$san" | tr ',' '\n' | sed 's/DNS://g; s/^ */  - /'
        else
            echo "  None"
        fi
        echo ""
        
        # Public Key
        echo "## Public Key Info"
        echo "$cert" | grep -A3 "Public Key Algorithm" | sed 's/^ *//'
        echo ""
        
    } > "$output_file"
    
    # Extract SANs to separate file for further processing
    echo "$cert" | grep -A1 "Subject Alternative Name" | tail -1 | \
        tr ',' '\n' | grep "DNS:" | sed 's/DNS://g; s/^ *//' | \
        sort -u > "${output_file}.san_domains.txt"
    
    local san_count=$(wc -l < "${output_file}.san_domains.txt" 2>/dev/null || echo 0)
    print_success "Certificate extracted ($san_count SAN domains found)"
    
    return 0
}

#==============================================================================
# SSL/TLS SECURITY ASSESSMENT
#==============================================================================

assess_ssl_security() {
    local target="$1"
    local port="${2:-443}"
    local output_file="$3"
    
    print_running "Assessing SSL/TLS security..."
    
    local issues=0
    
    {
        echo "=== SSL/TLS Security Assessment ==="
        echo ""
        
        # Test SSL versions
        echo "## Supported SSL/TLS Versions"
        for version in ssl2 ssl3 tls1 tls1_1 tls1_2 tls1_3; do
            if timeout 5 openssl s_client -connect "$target:$port" -"$version" </dev/null 2>&1 | grep -q "Cipher"; then
                echo "  - $version: SUPPORTED"
                if [[ "$version" =~ (ssl2|ssl3|tls1_0|tls1_1) ]]; then
                    echo "    ⚠️  WARNING: Weak protocol"
                    ((issues++))
                fi
            fi
        done
        echo ""
        
        # Test cipher suites
        echo "## Cipher Suite Analysis"
        local ciphers
        ciphers=$(timeout 10 openssl s_client -connect "$target:$port" -cipher 'ALL' </dev/null 2>&1 | \
            grep "Cipher" | head -1 | awk '{print $3}')
        
        if [[ -n "$ciphers" ]]; then
            echo "  Negotiated Cipher: $ciphers"
            
            # Check for weak ciphers
            if echo "$ciphers" | grep -qiE "(RC4|DES|MD5|NULL|EXPORT|anon)"; then
                echo "  ⚠️  WARNING: Weak cipher detected"
                ((issues++))
            fi
        fi
        echo ""
        
        # Certificate expiration check
        echo "## Certificate Expiration"
        local expiry
        expiry=$(echo | timeout 10 openssl s_client -connect "$target:$port" -servername "$target" 2>/dev/null | \
            openssl x509 -noout -enddate 2>/dev/null | cut -d'=' -f2)
        
        if [[ -n "$expiry" ]]; then
            echo "  Expires: $expiry"
            
            local expiry_epoch
            expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "$expiry" +%s 2>/dev/null)
            local now_epoch
            now_epoch=$(date +%s)
            local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
            
            if [[ $days_left -lt 30 ]]; then
                echo "  ⚠️  WARNING: Certificate expires in $days_left days"
                ((issues++))
            else
                echo "  ✓ Valid for $days_left more days"
            fi
        fi
        echo ""
        
        # HSTS header check
        echo "## HTTP Strict Transport Security (HSTS)"
        local hsts
        hsts=$(curl -skI "https://$target:$port" 2>/dev/null | grep -i "Strict-Transport-Security")
        if [[ -n "$hsts" ]]; then
            echo "  ✓ HSTS Enabled"
            echo "    $hsts"
        else
            echo "  ⚠️  HSTS Not Enabled"
            ((issues++))
        fi
        echo ""
        
        # Certificate chain validation
        echo "## Certificate Chain"
        local chain
        chain=$(echo | timeout 10 openssl s_client -connect "$target:$port" -showcerts 2>/dev/null | \
            grep -c "BEGIN CERTIFICATE")
        echo "  Chain Length: $chain certificates"
        echo ""
        
    } >> "$output_file"
    
    echo "Security Issues Found: $issues" >> "$output_file"
    
    if [[ $issues -gt 0 ]]; then
        print_warn "Found $issues SSL/TLS security issues"
    else
        print_success "No major SSL/TLS issues detected"
    fi
    
    return $issues
}

#==============================================================================
# TESTSSL.SH INTEGRATION
#==============================================================================

run_testssl_scan() {
    local target="$1"
    local port="${2:-443}"
    local output_file="$3"
    
    if ! command -v testssl.sh &>/dev/null && ! command -v testssl &>/dev/null; then
        print_warn "testssl.sh not found, skipping comprehensive scan"
        return 1
    fi
    
    print_running "Running testssl.sh comprehensive scan..."
    
    local testssl_cmd="testssl.sh"
    command -v testssl &>/dev/null && testssl_cmd="testssl"
    
    # Run testssl with common options
    timeout 600 "$testssl_cmd" --quiet --fast \
        --jsonfile "${output_file}.json" \
        "$target:$port" > "$output_file" 2>&1 || true
    
    if [[ -f "$output_file" ]] && [[ -s "$output_file" ]]; then
        print_success "testssl.sh scan complete"
        return 0
    else
        print_warn "testssl.sh scan failed or produced no output"
        return 1
    fi
}

#==============================================================================
# MAIN SSL ANALYSIS FUNCTION
#==============================================================================

analyze_ssl() {
    local target="$1"
    local port="${2:-443}"
    local report_dir="${3:-.}"
    
    # Extract hostname from URL if needed
    local hostname
    hostname=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
    
    print_info "Starting SSL/TLS analysis for: $hostname:$port"
    echo ""
    
    local output_dir="${report_dir}/ssl_analysis"
    mkdir -p "$output_dir"
    
    local cert_file="${output_dir}/${hostname}_certificate.txt"
    local security_file="${output_dir}/${hostname}_security.txt"
    
    # 1. Extract certificate details
    extract_certificate_details "$hostname" "$port" "$cert_file"
    
    # 2. Security assessment
    assess_ssl_security "$hostname" "$port" "$security_file"
    local issues=$?
    
    # 3. Run testssl.sh if available
    local testssl_file="${output_dir}/${hostname}_testssl.txt"
    run_testssl_scan "$hostname" "$port" "$testssl_file"
    
    # Generate summary report
    local summary_file="${report_dir}/${hostname}_ssl_analysis.md"
    {
        echo "# SSL/TLS Analysis Report"
        echo ""
        echo "**Target:** $hostname:$port"
        echo "**Scan Date:** $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        echo "## Summary"
        echo "- **Security Issues:** $issues"
        
        local san_count=$(wc -l < "${cert_file}.san_domains.txt" 2>/dev/null || echo 0)
        echo "- **SAN Domains:** $san_count"
        echo ""
        
        if [[ $san_count -gt 0 ]]; then
            echo "## Related Domains (from SAN)"
            echo '```'
            cat "${cert_file}.san_domains.txt"
            echo '```'
            echo ""
        fi
        
        echo "## Certificate Details"
        echo '```'
        cat "$cert_file"
        echo '```'
        echo ""
        
        echo "## Security Assessment"
        echo '```'
        cat "$security_file"
        echo '```'
        
    } > "$summary_file"
    
    print_success "SSL/TLS analysis complete: $summary_file"
    
    return 0
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat <<EOF
Usage: $0 <target> [port] [report_dir]

SSL/TLS Certificate Analysis Module
Performs comprehensive SSL/TLS security assessment.

Features:
  - Certificate extraction and SAN domain discovery
  - SSL/TLS version and cipher testing
  - Certificate expiration checking
  - HSTS header detection
  - testssl.sh integration (if available)

Examples:
    $0 example.com
    $0 example.com 443 ./reports
EOF
        exit 1
    fi
    
    analyze_ssl "$@"
fi
