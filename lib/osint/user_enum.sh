#!/usr/bin/env bash
#==============================================================================
# WAES User Enumeration Module
# Email and username discovery for social engineering and auth testing
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
# EMAIL PATTERN DETECTION
#==============================================================================

detect_email_pattern() {
    local domain="$1"
    local output_file="$2"
    
    print_running "Detecting email patterns..."
    
    # Search for email addresses in web content
    local url="https://$domain"
    local content
    content=$(curl -sk "$url" 2>/dev/null)
    
    # Extract emails
    local emails
    emails=$(echo "$content" | grep -oE "[a-zA-Z0-9._%+-]+@${domain}" | sort -u)
    
    if [[ -n "$emails" ]]; then
        echo "$emails" >> "$output_file"
        
        # Analyze patterns
        local patterns=()
        while IFS= read -r email; do
            local pattern
            pattern=$(echo "$email" | sed "s/@${domain}//")
            
            # Detect pattern type
            if [[ "$pattern" =~ ^[a-z]+\.[a-z]+$ ]]; then
                patterns+=("firstname.lastname")
            elif [[ "$pattern" =~ ^[a-z][a-z]+$ ]]; then
                patterns+=("firstnamelastname")
            elif [[ "$pattern" =~ ^[a-z]\.[a-z]+$ ]]; then
                patterns+=("f.lastname")
            fi
        done <<< "$emails"
        
        # Unique patterns
        local unique_patterns
        unique_patterns=$(printf '%s\n' "${patterns[@]}" | sort -u | tr '\n' ', ' | sed 's/,$//')
        
        if [[ -n "$unique_patterns" ]]; then
            print_success "Email pattern detected: $unique_patterns@$domain"
            echo "# Email Pattern: $unique_patterns@$domain" >> "$output_file"
        fi
    fi
}

#==============================================================================
# WORDPRESS USER ENUMERATION
#==============================================================================

enum_wordpress_users() {
    local target="$1"
    local output_file="$2"
    
    print_running "Enumerating WordPress users..."
    
    local url="https://$target"
    
    # Check if WordPress
    if ! curl -sk "$url" 2>/dev/null | grep -qi "wp-content\|wordpress"; then
        print_info "  Not a WordPress site"
        return 1
    fi
    
    print_warn "  WordPress detected"
    
    # Try /wp-json/wp/v2/users endpoint
    local users
    users=$(curl -sk "${url}/wp-json/wp/v2/users" 2>/dev/null)
    
    if echo "$users" | grep -q "\"slug\""; then
        echo "=== WordPress Users ===" >> "$output_file"
        echo "$users" | grep -oE '"slug":"[^"]+"|"name":"[^"]+"' | sed 's/"//g; s/slug://; s/name://' >> "$output_file"
        print_warn "  → WordPress users exposed via REST API"
    fi
    
    # Try author enumeration
    for i in {1..10}; do
        local author
        author=$(curl -sk "${url}/?author=$i" 2>/dev/null | grep -oE "<title>.*</title>" | sed 's/<[^>]*>//g')
        
        if [[ -n "$author" ]] && [[ ! "$author" =~ (404|Not Found) ]]; then
            echo "author-$i: $author" >> "$output_file"
        fi
    done
}

#==============================================================================
# SMTP USER ENUMERATION
#==============================================================================

enum_smtp_users() {
    local domain="$1"
    local output_file="$2"
    
    print_running "Attempting SMTP user enumeration..."
    
    # Get MX records
    local mx_servers
    mx_servers=$(dig +short MX "$domain" 2>/dev/null | awk '{print $2}')
    
    if [[ -z "$mx_servers" ]]; then
        print_info "  No MX records found"
        return 1
    fi
    
    # Test VRFY command on first MX
    local mx
    mx=$(echo "$mx_servers" | head -1)
    
    print_info "  Testing SMTP VRFY on $mx"
    
    # Common usernames to test
    local test_users=("admin" "root" "postmaster" "info" "contact")
    
    for user in "${test_users[@]}"; do
        local result
        result=$(echo "VRFY $user" | nc -w 2 "$mx" 25 2>/dev/null | grep "^250")
        
        if [[ -n "$result" ]]; then
            echo "SMTP VRFY confirmed: $user@$domain" >> "$output_file"
            print_warn "  → VRFY enabled: $user exists"
        fi
    done
}

#==============================================================================
# GOOGLE DORKING FOR EMAILS
#==============================================================================

google_dork_emails() {
    local domain="$1"
    local output_file="$2"
    
    print_running "Searching for emails via search engines..."
    
    # Note: This is a passive technique simulation
    # In production, this would use Google Custom Search API or similar
    
    print_info "  Manual search recommended: site:$domain \"@$domain\""
    echo "# Recommended Google Dork: site:$domain \"@$domain\"" >> "$output_file"
}

#==============================================================================
# GITHUB ORGANIZATION ANALYSIS
#==============================================================================

enum_github_org() {
    local domain="$1"
    local output_file="$2"
    
    print_running "Checking GitHub for organization..."
    
    # Try common org names based on domain
    local org_name
    org_name=$(echo "$domain" | cut -d'.' -f1)
    
    local gh_response
    gh_response=$(curl -sk "https://api.github.com/orgs/$org_name" 2>/dev/null)
    
    if echo "$gh_response" | grep -q "\"login\""; then
        print_warn "  → GitHub organization found: $org_name"
        echo "GitHub Org: https://github.com/$org_name" >> "$output_file"
        
        # Get members (if public)
        local members
        members=$(curl -sk "https://api.github.com/orgs/$org_name/members" 2>/dev/null | \
            grep "\"login\"" | cut -d'"' -f4)
        
        if [[ -n "$members" ]]; then
            echo "=== GitHub Members ===" >> "$output_file"
            echo "$members" >> "$output_file"
        fi
    fi
}

#==============================================================================
# MAIN USER ENUMERATION FUNCTION
#==============================================================================

run_user_enumeration() {
    local target="$1"
    local report_dir="${2:-.}"
    
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
    
    print_info "Starting user enumeration for: $domain"
    echo ""
    
    local output_dir="${report_dir}/user_enum"
    mkdir -p "$output_dir"
    
    local findings_file="${output_dir}/${domain}_users.txt"
    
    # 1. Email pattern detection
    detect_email_pattern "$domain" "$findings_file"
    
    # 2. WordPress enumeration
    enum_wordpress_users "$domain" "$findings_file"
    
    # 3. SMTP enumeration
    enum_smtp_users "$domain" "$findings_file"
    
    # 4. Google dorking suggestions
    google_dork_emails "$domain" "$findings_file"
    
    # 5. GitHub org analysis
    enum_github_org "$domain" "$findings_file"
    
    # Generate summary
    local summary_file="${report_dir}/${domain}_user_enum.md"
    {
        echo "# User Enumeration Report"
        echo ""
        echo "**Target:** $domain"
        echo "**Scan Date:** $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        echo "## Findings"
        echo '```'
        cat "$findings_file"
        echo '```'
        
    } > "$summary_file"
    
    print_success "User enumeration complete: $summary_file"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat <<EOF
Usage: $0 <domain> [report_dir]

User Enumeration Module
Discovers usernames and email addresses.

Examples:
    $0 example.com
    $0 example.com ./reports
EOF
        exit 1
    fi
    
    run_user_enumeration "$@"
fi
