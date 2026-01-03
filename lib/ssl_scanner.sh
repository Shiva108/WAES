#!/usr/bin/env bash
#==============================================================================
# WAES SSL/TLS Scanner Module
# Comprehensive SSL/TLS certificate and configuration analysis
#==============================================================================

# Source color library if available
if [[ -f "${SCRIPT_DIR:-$(dirname "$0")}/colors.sh" ]]; then
    # shellcheck source=colors.sh
    source "${SCRIPT_DIR:-$(dirname "$0")}/colors.sh"
else
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
fi

#==============================================================================
# SSL/TLS SCANNING FUNCTIONS
#==============================================================================

# Check SSL/TLS certificate details
ssl_certificate_info() {
    local target="$1"
    local port="${2:-443}"
    local output_file="$3"
    
    print_info "Gathering SSL/TLS certificate information..."
    
    {
        echo "=== SSL/TLS Certificate Information ==="
        echo "Target: ${target}:${port}"
        echo "Scan Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        # Get certificate details
        if command -v openssl &>/dev/null; then
            echo "--- Certificate Details ---"
            timeout 10 openssl s_client -connect "${target}:${port}" -servername "$target" </dev/null 2>/dev/null | \
                openssl x509 -noout -text 2>/dev/null || echo "Failed to retrieve certificate"
            echo ""
            
            # Certificate expiration
            echo "--- Certificate Expiration ---"
            local cert_end_date
            cert_end_date=$(timeout 10 openssl s_client -connect "${target}:${port}" -servername "$target" </dev/null 2>/dev/null | \
                openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
            
            if [[ -n "$cert_end_date" ]]; then
                echo "Expires: $cert_end_date"
                
                # Calculate days until expiration
                local end_epoch
                end_epoch=$(date -d "$cert_end_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$cert_end_date" +%s 2>/dev/null)
                local now_epoch
                now_epoch=$(date +%s)
                local days_left=$(( (end_epoch - now_epoch) / 86400 ))
                
                if [[ $days_left -lt 0 ]]; then
                    echo "STATUS: EXPIRED (${days_left#-} days ago)"
                elif [[ $days_left -lt 30 ]]; then
                    echo "STATUS: EXPIRING SOON ($days_left days remaining)"
                else
                    echo "STATUS: Valid ($days_left days remaining)"
                fi
            fi
            echo ""
            
            # Certificate chain
            echo "--- Certificate Chain ---"
            timeout 10 openssl s_client -connect "${target}:${port}" -servername "$target" -showcerts </dev/null 2>/dev/null | \
                grep -E "s:|i:" || echo "Failed to retrieve chain"
            echo ""
        fi
    } | tee "$output_file"
}

# Test SSL/TLS protocols and cipher suites
ssl_protocol_test() {
    local target="$1"
    local port="${2:-443}"
    local output_file="$3"
    
    print_info "Testing SSL/TLS protocols and cipher suites..."
    
    {
        echo "=== SSL/TLS Protocol and Cipher Testing ==="
        echo ""
        
        if command -v openssl &>/dev/null; then
            # Test various SSL/TLS versions
            local protocols=("ssl2" "ssl3" "tls1" "tls1_1" "tls1_2" "tls1_3")
            local protocol_names=("SSLv2" "SSLv3" "TLSv1.0" "TLSv1.1" "TLSv1.2" "TLSv1.3")
            
            echo "--- Protocol Support ---"
            for i in "${!protocols[@]}"; do
                local proto="${protocols[$i]}"
                local proto_name="${protocol_names[$i]}"
                
                if timeout 5 openssl s_client -connect "${target}:${port}" "-${proto}" </dev/null &>/dev/null; then
                    echo "[ENABLED] $proto_name"
                else
                    echo "[DISABLED] $proto_name"
                fi
            done
            echo ""
            
            # Get supported cipher suites
            echo "--- Supported Cipher Suites ---"
            timeout 10 openssl s_client -connect "${target}:${port}" -cipher 'ALL:eNULL' </dev/null 2>/dev/null | \
                grep "Cipher" || echo "Unable to enumerate ciphers"
            echo ""
        fi
    } | tee -a "$output_file"
}

# Check for common SSL/TLS vulnerabilities
ssl_vulnerability_check() {
    local target="$1"
    local port="${2:-443}"
    local output_file="$3"
    
    print_info "Checking for SSL/TLS vulnerabilities..."
    
    {
        echo "=== SSL/TLS Vulnerability Checks ==="
        echo ""
        
        if command -v openssl &>/dev/null; then
            # Heartbleed (CVE-2014-0160)
            echo "--- Heartbleed (CVE-2014-0160) ---"
            if timeout 5 openssl s_client -connect "${target}:${port}" -tlsextdebug </dev/null 2>&1 | \
                grep -q "heartbeat"; then
                echo "Heartbeat extension detected - manual verification recommended"
            else
                echo "Heartbeat extension not detected"
            fi
            echo ""
            
            # POODLE (SSLv3)
            echo "--- POODLE (SSLv3 enabled) ---"
            if timeout 5 openssl s_client -connect "${target}:${port}" -ssl3 </dev/null &>/dev/null; then
                echo "VULNERABLE: SSLv3 is enabled"
            else
                echo "NOT VULNERABLE: SSLv3 is disabled"
            fi
            echo ""
            
            # BEAST (TLSv1.0 with CBC ciphers)
            echo "--- BEAST (TLSv1.0 CBC ciphers) ---"
            if timeout 5 openssl s_client -connect "${target}:${port}" -tls1 -cipher 'AES:DES:3DES' </dev/null &>/dev/null; then
                echo "POTENTIALLY VULNERABLE: TLSv1.0 with CBC ciphers enabled"
            else
                echo "NOT VULNERABLE: TLSv1.0 CBC ciphers not available"
            fi
            echo ""
            
            # Weak ciphers
            echo "--- Weak/Export Ciphers ---"
            if timeout 5 openssl s_client -connect "${target}:${port}" -cipher 'EXPORT:LOW:NULL:aNULL' </dev/null &>/dev/null; then
                echo "VULNERABLE: Weak ciphers accepted"
            else
                echo "NOT VULNERABLE: Weak ciphers rejected"
            fi
            echo ""
        fi
    } | tee -a "$output_file"
}

# Use sslscan if available
ssl_comprehensive_scan() {
    local target="$1"
    local port="${2:-443}"
    local output_file="$3"
    
    if command -v sslscan &>/dev/null; then
        print_info "Running comprehensive SSL scan with sslscan..."
        {
            echo "=== SSLScan Comprehensive Report ==="
            echo ""
            sslscan --no-colour "${target}:${port}" 2>/dev/null || echo "SSLScan failed"
        } | tee -a "$output_file"
    fi
    
    if command -v testssl.sh &>/dev/null; then
        print_info "Running testssl.sh comprehensive scan..."
        {
            echo ""
            echo "=== TestSSL.sh Comprehensive Report ==="
            echo ""
            testssl.sh --quiet --fast "${target}:${port}" 2>/dev/null || echo "TestSSL.sh failed"
        } | tee -a "$output_file"
    fi
}

# Main SSL scanner function
scan_ssl() {
    local target="$1"
    local port="${2:-443}"
    local report_dir="${3:-.}"
    
    local output_file="${report_dir}/${target}_ssl_scan.txt"
    
    print_info "Starting SSL/TLS scan for ${target}:${port}"
    echo ""
    
    # Clear previous file
    > "$output_file"
    
    # Run all SSL tests
    ssl_certificate_info "$target" "$port" "$output_file"
    ssl_protocol_test "$target" "$port" "$output_file"
    ssl_vulnerability_check "$target" "$port" "$output_file"
    ssl_comprehensive_scan "$target" "$port" "$output_file"
    
    print_success "SSL/TLS scan complete: $output_file"
}

# If script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <target> [port] [report_dir]"
        echo "Example: $0 example.com 443 ./reports"
        exit 1
    fi
    
    scan_ssl "$@"
fi
