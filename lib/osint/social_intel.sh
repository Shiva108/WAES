#!/usr/bin/env bash
#==============================================================================
# WAES Social Media OSINT Module
#==============================================================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || {
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
}

run_social_osint() {
    local target="$1"
    local report_dir="${2:-.}"
    
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1)
    
    print_running "Gathering social media intelligence..."
    
    local output="${report_dir}/${domain}_social_osint.md"
    
    {
        echo "# Social Media OSINT Report"
        echo "**Target:** $domain"
        echo ""
        
        echo "## Recommended Manual Searches"
        echo "- LinkedIn: Search for company \"$domain\""
        echo "- GitHub: https://github.com/search?q=$domain"
        echo "- Twitter/X: Search mentions of @$domain"
        echo ""
        
        echo "## Google Dorks"
        echo "\`\`\`"
        echo "site:pastebin.com \"$domain\""
        echo "site:github.com \"$domain\" password"
        echo "site:trello.com \"$domain\""
        echo "\`\`\`"
        
    } > "$output"
    
    print_success "Social OSINT guide saved: $output"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    [[ $# -lt 1 ]] && { echo "Usage: $0 <target> [report_dir]"; exit 1; }
    run_social_osint "$@"
fi
