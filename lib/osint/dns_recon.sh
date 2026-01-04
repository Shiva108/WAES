#!/usr/bin/env bash
#==============================================================================
# WAES DNS Reconnaissance Module
# Advanced subdomain discovery and DNS intelligence gathering
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
# SUBDOMAIN DISCOVERY
#==============================================================================

discover_subdomains_passive() {
    local domain="$1"
    local output_file="$2"
    
    print_running "Running passive subdomain discovery..."
    
    local found=0
    
    # subfinder (passive)
    if command -v subfinder &>/dev/null; then
        print_info "  → Using subfinder (passive sources)"
        subfinder -d "$domain" -silent -o "${output_file}.subfinder" 2>/dev/null && ((found++))
    fi
    
    # amass (passive enumeration)
    if command -v amass &>/dev/null; then
        print_info "  → Using amass (passive mode)"
        timeout 300 amass enum -passive -d "$domain" -o "${output_file}.amass" 2>/dev/null && ((found++))
    fi
    
    # sublist3r (if available)
    if command -v sublist3r &>/dev/null; then
        print_info "  → Using sublist3r"
        timeout 180 sublist3r -d "$domain" -o "${output_file}.sublist3r" 2>/dev/null || true
        ((found++))
    fi
    
    # Certificate transparency (crt.sh)
    print_info "  → Querying certificate transparency logs"
    curl -sk "https://crt.sh/?q=%.$domain&output=json" 2>/dev/null | \
        jq -r '.[].name_value' 2>/dev/null | \
        sed 's/\*\.//g' | sort -u > "${output_file}.crtsh" || true
    
    # Combine and deduplicate
    cat "${output_file}".* 2>/dev/null | sort -u > "$output_file"
    local count=$(wc -l < "$output_file" 2>/dev/null || echo 0)
    
    # Cleanup temp files
    rm -f "${output_file}".subfinder "${output_file}".amass "${output_file}".sublist3r "${output_file}".crtsh
    
    if [[ $count -gt 0 ]]; then
        print_success "Found $count subdomains"
    else
        print_warn "No subdomains discovered"
    fi
    
    return 0
}

#==============================================================================
# DNS RECORD ENUMERATION
#==============================================================================

enumerate_dns_records() {
    local domain="$1"
    local output_file="$2"
    
    print_running "Enumerating DNS records..."
    
    {
        echo "=== DNS Record Enumeration ==="
        echo "Domain: $domain"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        # A records
        echo "## A Records"
        dig +short A "$domain" 2>/dev/null || echo "None"
        echo ""
        
        # AAAA (IPv6)
        echo "## AAAA Records (IPv6)"
        dig +short AAAA "$domain" 2>/dev/null || echo "None"
        echo ""
        
        # MX records
        echo "## MX Records"
        dig +short MX "$domain" 2>/dev/null || echo "None"
        echo ""
        
        # NS records
        echo "## NS Records"
        dig +short NS "$domain" 2>/dev/null || echo "None"
        echo ""
        
        # TXT records
        echo "## TXT Records"
        dig +short TXT "$domain" 2>/dev/null || echo "None"
        echo ""
        
        # SOA
        echo "## SOA Record"
        dig +short SOA "$domain" 2>/dev/null || echo "None"
        echo ""
        
        # CAA (Certificate Authority Authorization)
        echo "## CAA Records"
        dig +short CAA "$domain" 2>/dev/null || echo "None"
        echo ""
        
    } > "$output_file"
    
    print_success "DNS records enumerated"
}

#==============================================================================
# ZONE TRANSFER ATTEMPT
#==============================================================================

attempt_zone_transfer() {
    local domain="$1"
    local output_file="$2"
    
    print_running "Attempting DNS zone transfer..."
    
    # Get nameservers
    local nameservers
    nameservers=$(dig +short NS "$domain" 2>/dev/null)
    
    if [[ -z "$nameservers" ]]; then
        print_warn "No nameservers found for zone transfer"
        return 1
    fi
    
    local transferred=false
    
    for ns in $nameservers; do
        print_info "  Testing $ns"
        if dig @"$ns" AXFR "$domain" > "${output_file}.${ns}.axfr" 2>/dev/null; then
            if grep -q "XFR size" "${output_file}.${ns}.axfr"; then
                print_warn "  → Zone transfer successful on $ns!"
                transferred=true
            else
                rm -f "${output_file}.${ns}.axfr"
            fi
        fi
    done
    
    if $transferred; then
        cat "${output_file}".*.axfr > "${output_file}.zone_transfer.txt" 2>/dev/null
        rm -f "${output_file}".*.axfr
        echo "[!] SECURITY ISSUE: Zone transfer allowed" >> "$output_file"
    else
        print_success "Zone transfer properly restricted"
    fi
}

#==============================================================================
# REVERSE DNS LOOKUPS
#==============================================================================

reverse_dns_lookup() {
    local domain="$1"
    local output_file="$2"
    
    print_running "Performing reverse DNS lookups..."
    
    # Get IP addresses
    local ips
    ips=$(dig +short A "$domain" 2>/dev/null)
    
    if [[ -z "$ips" ]]; then
        print_warn "No IPs found for reverse DNS"
        return 1
    fi
    
    {
        echo "=== Reverse DNS Lookups ==="
        for ip in $ips; do
            echo "IP: $ip"
            local ptr
            ptr=$(dig +short -x "$ip" 2>/dev/null)
            if [[ -n "$ptr" ]]; then
                echo "  PTR: $ptr"
            else
                echo "  PTR: None"
            fi
            echo ""
        done
    } >> "$output_file"
    
    print_success "Reverse DNS lookups complete"
}

#==============================================================================
# MAIN DNS RECON FUNCTION
#==============================================================================

run_dns_recon() {
    local target="$1"
    local report_dir="${2:-.}"
    
    # Extract domain from URL if needed
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
    
    print_info "Starting DNS reconnaissance for: $domain"
    echo ""
    
    local output_dir="${report_dir}/dns_recon"
    mkdir -p "$output_dir"
    
    # 1. Subdomain discovery
    local subdomain_file="${output_dir}/${domain}_subdomains.txt"
    discover_subdomains_passive "$domain" "$subdomain_file"
    
    # 2. DNS record enumeration
    local dns_records_file="${output_dir}/${domain}_dns_records.txt"
    enumerate_dns_records "$domain" "$dns_records_file"
    
    # 3. Zone transfer attempt
    local zone_file="${output_dir}/${domain}_zone_transfer.txt"
    attempt_zone_transfer "$domain" "$zone_file"
    
    # 4. Reverse DNS
    reverse_dns_lookup "$domain" "$dns_records_file"
    
    # Generate summary report
    local summary_file="${report_dir}/${domain}_dns_recon.md"
    {
        echo "# DNS Reconnaissance Report"
        echo ""
        echo "**Domain:** $domain"
        echo "**Scan Date:** $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        local subdomain_count=$(wc -l < "$subdomain_file" 2>/dev/null || echo 0)
        echo "## Summary"
        echo "- **Subdomains Discovered:** $subdomain_count"
        echo "- **DNS Records:** See ${dns_records_file##*/}"
        echo ""
        
        if [[ $subdomain_count -gt 0 ]]; then
            echo "## Discovered Subdomains"
            echo '```'
            head -20 "$subdomain_file"
            if [[ $subdomain_count -gt 20 ]]; then
                echo "... ($((subdomain_count - 20)) more)"
            fi
            echo '```'
            echo ""
        fi
        
        echo "## DNS Records"
        echo '```'
        cat "$dns_records_file"
        echo '```'
        
    } > "$summary_file"
    
    print_success "DNS reconnaissance complete: $summary_file"
    
    return 0
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat <<EOF
Usage: $0 <domain> [report_dir]

DNS Reconnaissance Module
Performs comprehensive subdomain discovery and DNS enumeration.

Tools used (if available):
  - subfinder (passive subdomain discovery)
  - amass (OWASP subdomain enumeration)
  - sublist3r (legacy subdomain tool)
  - crt.sh (certificate transparency)
  - dig (DNS queries)

Examples:
    $0 example.com
    $0 example.com ./reports
EOF
        exit 1
    fi
    
    run_dns_recon "$@"
fi
