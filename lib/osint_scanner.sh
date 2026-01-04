#!/usr/bin/env bash
#==============================================================================
# WAES OSINT Module
# Open Source Intelligence gathering for target reconnaissance
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
# SUBDOMAIN ENUMERATION
#==============================================================================

# DNS brute-forcing
subdomain_bruteforce() {
    local domain="$1"
    local wordlist="$2"
    local output_file="$3"
    
    print_info "DNS brute-forcing: $domain"
    
    if [[ ! -f "$wordlist" ]]; then
        print_warn "Wordlist not found: $wordlist"
        return 1
    fi
    
    {
        echo "=== Subdomain Brute Force ==="
        echo "Domain: $domain"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        while read -r sub; do
            local fqdn="${sub}.${domain}"
            if host "$fqdn" &>/dev/null; then
                local ip
                ip=$(host "$fqdn" | grep "has address" | awk '{print $NF}' | head -1)
                echo "[FOUND] $fqdn -> $ip"
            fi
        done < "$wordlist"
    } | tee "$output_file"
}

# Certificate Transparency logs
cert_transparency_search() {
    local domain="$1"
    local output_file="$2"
    
    print_info "Searching Certificate Transparency logs: $domain"
    
    {
        echo "=== Certificate Transparency Search ==="
        echo "Domain: $domain"
        echo ""
        
        # Use crt.sh
        curl -s "https://crt.sh/?q=%.${domain}&output=json" 2>/dev/null | \
            jq -r '.[].name_value' 2>/dev/null | \
            sort -u | \
            grep -v "^*" || echo "No results (jq might not be installed)"
    } | tee "$output_file"
}

# Passive DNS enumeration
passive_subdomain_enum() {
    local domain="$1"
    local output_file="$2"
    
    print_info "Passive subdomain enumeration: $domain"
    
    {
        echo "=== Passive Subdomain Enumeration ==="
        echo "Domain: $domain"
        echo ""
        
        # Try subfinder if available
        if command -v subfinder &>/dev/null; then
            echo "--- Subfinder Results ---"
            subfinder -d "$domain" -silent 2>/dev/null || true
        fi
        
        # Try amass if available
        if command -v amass &>/dev/null; then
            echo "--- Amass Results ---"
            amass enum -passive -d "$domain" 2>/dev/null || true
        fi
        
        # Try assetfinder if available
        if command -v assetfinder &>/dev/null; then
            echo "--- Assetfinder Results ---"
            assetfinder --subs-only "$domain" 2>/dev/null || true
        fi
        
        if ! command -v subfinder &>/dev/null && \
           ! command -v amass &>/dev/null && \
           ! command -v assetfinder &>/dev/null; then
            echo "No subdomain enumeration tools found"
            echo "Install: subfinder, amass, or assetfinder"
        fi
    } | tee "$output_file"
}

#==============================================================================
# GOOGLE DORKING
#==============================================================================

# Google dork search (informational - requires manual execution)
generate_google_dorks() {
    local domain="$1"
    local output_file="$2"
    
    print_info "Generating Google dorks for: $domain"
    
    {
        echo "=== Google Dork Queries ==="
        echo "Domain: $domain"
        echo ""
        echo "Note: These must be executed manually in a browser"
        echo ""
        
        echo "# Find exposed files"
        echo "site:${domain} ext:pdf"
        echo "site:${domain} ext:doc | ext:docx"
        echo "site:${domain} ext:xls | ext:xlsx"
        echo "site:${domain} ext:sql"
        echo "site:${domain} ext:log"
        echo ""
        
        echo "# Find configuration files"
        echo "site:${domain} inurl:config"
        echo "site:${domain} inurl:admin"
        echo "site:${domain} inurl:backup"
        echo "site:${domain} \"index of /\""
        echo ""
        
        echo "# Find exposed credentials"
        echo "site:${domain} intext:\"password\""
        echo "site:${domain} intext:\"api key\""
        echo "site:${domain} intext:\"secret\""
        echo ""
        
        echo "# Find subdomains"
        echo "site:*.${domain}"
    } | tee "$output_file"
}

#==============================================================================
# MAIN OSINT FUNCTION
#==============================================================================

osint_recon() {
    local domain="$1"
    local report_dir="${2:-.}"
    
    print_info "Starting OSINT reconnaissance: $domain"
    echo ""
    
    local output_base="${report_dir}/${domain}_osint"
    
    # Subdomain enumeration
    passive_subdomain_enum "$domain" "${output_base}_subdomains.txt"
    
    # Certificate transparency
    cert_transparency_search "$domain" "${output_base}_crt.txt"
    
    # Google dorks
    generate_google_dorks "$domain" "${output_base}_dorks.txt"
   
    # DNS brute-force (if wordlist available)
    local wordlist
    wordlist=$(find_wordlist "subdomains-top1million-5000.txt" 2>/dev/null) || \
        wordlist="/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
    
    if [[ -f "$wordlist" ]]; then
        subdomain_bruteforce "$domain" "$wordlist" "${output_base}_bruteforce.txt"
    fi
    
    echo ""
    print_success "OSINT reconnaissance complete: $domain"
    print_info "Results saved to: ${output_base}_*"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat << EOF
Usage: $0 <domain> [report_dir]

Examples:
    $0 example.com
    $0 example.com ./osint_results
EOF
        exit 1
    fi
    
    osint_recon "$@"
fi
