#!/usr/bin/env bash
#==============================================================================
# WAES Email Compliance - DNS Resolver Utility
# Provides robust DNS query functionality with fallbacks
#==============================================================================

# Try dig first (most reliable), then nslookup, then host
query_dns_txt() {
    local domain="$1"
    local result=""
    
    # Method 1: dig (preferred)
    if command -v dig &>/dev/null; then
        result=$(dig +short TXT "$domain" 2>/dev/null | tr -d '"' | grep -v '^$')
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    fi
    
    # Method 2: nslookup (fallback 1)
    if command -v nslookup &>/dev/null; then
        result=$(nslookup -type=TXT "$domain" 2>/dev/null | grep -A1 "text =" | grep -v "text =" | tr -d '"' | grep -v '^$')
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    fi
    
    # Method 3: host (fallback 2)
    if command -v host &>/dev/null; then
        result=$(host -t TXT "$domain" 2>/dev/null | grep "descriptive text" | sed 's/.*descriptive text "\(.*\)"/\1/' | grep -v '^$')
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    fi
    
    return 1
}

# Query MX records
query_dns_mx() {
    local domain="$1"
    local result=""
    
    if command -v dig &>/dev/null; then
        result=$(dig +short MX "$domain" 2>/dev/null | grep -v '^$')
    elif command -v nslookup &>/dev/null; then
        result=$(nslookup -type=MX "$domain" 2>/dev/null | grep "mail exchanger" | awk '{print $NF}' | grep -v '^$')
    elif command -v host &>/dev/null; then
        result=$(host -t MX "$domain" 2>/dev/null | grep "mail is handled" | awk '{print $NF}' | grep -v '^$')
    fi
    
    if [[ -n "$result" ]]; then
        echo "$result"
        return 0
    fi
    return 1
}

# Sanitize domain input
sanitize_domain() {
    local domain="$1"
    # Remove http(s)://
    domain="${domain#http://}"
    domain="${domain#https://}"
    # Remove trailing slash and path
    domain="${domain%%/*}"
    # Remove port
    domain="${domain%%:*}"
    # Convert to lowercase
    domain="${domain,,}"
    echo "$domain"
}

# Validate domain format
is_valid_domain() {
    local domain="$1"
    # Basic regex for domain validation
    if [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    fi
    return 1
}

# Check DNS resolver availability
check_dns_tools() {
    if ! command -v dig &>/dev/null && ! command -v nslookup &>/dev/null && ! command -v host &>/dev/null; then
        echo "[!] Error: No DNS query tools available (dig, nslookup, or host required)"
        return 1
    fi
    return 0
}

# If run directly, provide test interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <domain> [txt|mx]"
        echo "Example: $0 google.com txt"
        exit 1
    fi
    
    check_dns_tools || exit 1
    
    domain=$(sanitize_domain "$1")
    query_type="${2:-txt}"
    
    if ! is_valid_domain "$domain"; then
        echo "[!] Invalid domain format: $domain"
        exit 1
    fi
    
    case "$query_type" in
        txt)
            echo "[*] Querying TXT records for: $domain"
            query_dns_txt "$domain"
            ;;
        mx)
            echo "[*] Querying MX records for: $domain"
            query_dns_mx "$domain"
            ;;
        *)
            echo "[!] Unknown query type: $query_type"
            exit 1
            ;;
    esac
fi
