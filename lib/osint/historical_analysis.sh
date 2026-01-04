#!/usr/bin/env bash
#==============================================================================
# WAES Historical Analysis Module (Wayback Machine integration)
#==============================================================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || {
    print_info() { echo "[*] $*"; }
    print_warn() { echo "[~] $*"; }
    print_success() { echo "[+] $*"; }
}

analyze_historical() {
    local target="$1"
    local report_dir="${2:-.}"
    
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1)
    
    print_running "Analyzing historical data..."
    
    local output="${report_dir}/${domain}_historical.md"
    
    {
        echo "# Historical Analysis Report"
        echo "**Target:** $domain"
        echo ""
        echo "## Wayback Machine"
        echo "Manual review recommended:"
        echo "- https://web.archive.org/web/*/$domain"
        echo ""
        echo "## Recommended Tools"
        echo "- waybackurls: \`waybackurls $domain\`"
        echo "- gau: \`gau $domain\`"
        
    } > "$output"
    
    print_success "Historical analysis guide saved: $output"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $# -lt 1 ]] && { echo "Usage: $0 <target> [report_dir]"; exit 1; }
    analyze_historical "$@"
fi
