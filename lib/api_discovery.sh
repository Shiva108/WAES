#!/usr/bin/env bash
#==============================================================================
# WAES Web Application Fingerprinting & API Discovery Module
#==============================================================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

source "${SCRIPT_DIR}/colors.sh" 2>/dev/null || {
    print_info() { echo "[*] $*"; }
    print_warn() { echo "[~] $*"; }
    print_success() { echo "[+] $*"; }
    print_running() { echo "[>] $*"; }
}

discover_apis() {
    local target="$1"
    local report_dir="${2:-.}"
    
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1)
    
    print_running "Discovering API endpoints..."
    
    local url="https://$domain"
    local output="${report_dir}/${domain}_api_discovery.md"
    
    {
        echo "# API & Web App Discovery Report"
        echo "**Target:** $domain"
        echo ""
        
        echo "## API Documentation Endpoints"
        
        # Test common API doc endpoints
        for endpoint in "api-docs" "swagger.json" "openapi.json" "graphql" "api/v1" "api/v2"; do
            local code
            code=$(curl -sk -o /dev/null -w "%{http_code}" "${url}/${endpoint}" 2>/dev/null)
            
            if [[ "$code" == "200" ]]; then
                echo "- ✓ Found: /$endpoint (HTTP $code)"
                print_warn "  → Found: /$endpoint"
            fi
        done
        
        echo ""
        echo "## Framework Detection"
        local content
        content=$(curl -sk "$url" 2>/dev/null)
        
        if echo "$content" | grep -qi "react"; then echo "- React detected"; fi
        if echo "$content" | grep -qi "__next"; then echo "- Next.js detected"; fi
        if echo "$content" | grep -qi "ng-version"; then echo "- Angular detected"; fi
        
    } > "$output"
    
    print_success "API discovery complete: $output"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $# -lt 1 ]] && { echo "Usage: $0 <target> [report_dir]"; exit 1; }
    discover_apis "$@"
fi
