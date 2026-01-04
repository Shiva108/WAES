#!/usr/bin/env bash
#==============================================================================
# WAES Technology Fingerprinting Module
# Comprehensive technology stack detection
#==============================================================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

source "${SCRIPT_DIR}/colors.sh" 2>/dev/null || {
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_warn() { echo "[~] $*"; }
    print_running() { echo "[>] $*"; }
}

fingerprint_technologies() {
    local target="$1"
    local report_dir="${2:-.}"
    
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1)
    
    print_running "Fingerprinting technology stack..."
    
    local output="${report_dir}/${domain}_tech_stack.md"
    local url="https://$domain"
    
    # Get page content and headers
    local content headers
    content=$(curl -sk "$url" 2>/dev/null)
    headers=$(curl -skI "$url" 2>/dev/null)
    
    {
        echo "# Technology Stack Report"
        echo "**Target:** $domain"
        echo ""
        
        # Server
        echo "## Server"
        echo "$headers" | grep -i "Server:" || echo "Not disclosed"
        echo ""
        
        # Frameworks (from headers/HTML)
        echo "## Detected Frameworks"
        echo "$headers" | grep -iE "X-Powered-By|X-AspNet-Version" || true
        echo "$content" | grep -oE "react|vue|angular|nextjs|nuxt" | head -5 | sort -u || true
        echo ""
        
        # CMS Detection
        echo "## CMS Detection"
        if echo "$content" | grep -qi "wp-content"; then echo "- WordPress"; fi
        if echo "$content" | grep -qi "drupal"; then echo "- Drupal"; fi
        if echo "$content" | grep -qi "joomla"; then echo "- Joomla"; fi
        echo ""
        
        # CDN/Services
        echo "## CDN & Services"
        echo "$headers" | grep -iE "cloudflare|cloudfront|fastly|akamai" || echo "None detected"
        
    } > "$output"
    
    print_success "Technology fingerprint saved: $output"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $# -lt 1 ]] && { echo "Usage: $0 <target> [report_dir]"; exit 1; }
    fingerprint_technologies "$@"
fi
