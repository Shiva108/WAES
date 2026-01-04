#!/usr/bin/env bash
#==============================================================================
# WAES Email Compliance - DKIM Validator
# Validates DomainKeys Identified Mail records
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/email_compliance/dns_resolver.sh" 2>/dev/null || true

# Common DKIM selectors to try
COMMON_SELECTORS=("default" "google" "dkim" "mail" "k1" "selector1" "selector2" "s1" "s2")

declare -A DKIM_RESULT=(
    [status]="unknown"
    [selectors_found]=""
    [key_algorithm]=""
    [key_size]=""
    [issues]=""
    [recommendations]=""
)

# Discover DKIM selectors for a domain
discover_dkim_selectors() {
    local domain="$1"
    local found_selectors=()
    
    echo "[*] Discovering DKIM selectors for: $domain" >&2
    
    for selector in "${COMMON_SELECTORS[@]}"; do
        local dkim_domain="${selector}._domainkey.${domain}"
        local record
        
        record=$(query_dns_txt "$dkim_domain" 2>/dev/null)
        
        if [[ -n "$record" ]] && echo "$record" | grep -qi "dkim"; then
            found_selectors+=("$selector")
            echo "  [+] Found selector: $selector" >&2
        fi
    done
    
    if [[ ${#found_selectors[@]} -gt 0 ]]; then
        DKIM_RESULT[selectors_found]="${found_selectors[*]}"
        return 0
    fi
    
    return 1
}

# Validate DKIM record for a specific selector
validate_dkim_selector() {
    local domain="$1"
    local selector="$2"
    local dkim_domain="${selector}._domainkey.${domain}"
    
    local record
    record=$(query_dns_txt "$dkim_domain")
    
    if [[ -z "$record" ]]; then
        DKIM_RESULT[issues]+="No DKIM record for selector '$selector'. "
        return 1
    fi
    
    # Check for v=DKIM1
    if ! echo "$record" | grep -qi "v=DKIM1"; then
        DKIM_RESULT[issues]+="Missing or invalid version tag (v=DKIM1). "
    fi
    
    # Extract and validate public key
    local pubkey
    pubkey=$(echo "$record" | grep -oP 'p=\K[^;]+' | tr -d ' ')
    
    if [[ -z "$pubkey" ]]; then
        DKIM_RESULT[issues]+="No public key (p=) found in DKIM record. "
        return 1
    elif [[ "$pubkey" == "" ]]; then
        DKIM_RESULT[issues]+="Empty public key - DKIM signing revoked. "
        return 1
    fi
    
    # Check key algorithm
    local key_type
    key_type=$(echo "$record" | grep -oP 'k=\K[^;]+' || echo "rsa")
    DKIM_RESULT[key_algorithm]="$key_type"
    
    if [[ "$key_type" != "rsa" ]] && [[ "$key_type" != "ed25519" ]]; then
        DKIM_RESULT[issues]+="Unknown key algorithm: $key_type. "
    fi
    
    # Estimate key size (RSA)
    if [[ "$key_type" == "rsa" ]]; then
        local key_length=${#pubkey}
        if [[ $key_length -lt 300 ]]; then
            DKIM_RESULT[key_size]="<1024 bits (weak)"
            DKIM_RESULT[issues]+="RSA key appears too short (<1024 bits). "
            DKIM_RESULT[recommendations]+="Use minimum 2048-bit RSA keys. "
        elif [[ $key_length -lt 450 ]]; then
            DKIM_RESULT[key_size]="~1024 bits"
            DKIM_RESULT[recommendations]+="Consider upgrading to 2048-bit RSA keys. "
        else
            DKIM_RESULT[key_size]=">=2048 bits"
        fi
    else
        DKIM_RESULT[key_size]="N/A (${key_type})"
    fi
    
    return 0
}

# Main DKIM validation
validate_dkim() {
    local domain="$1"
    
    # Discover selectors
    if ! discover_dkim_selectors "$domain"; then
        DKIM_RESULT[status]="fail"
        DKIM_RESULT[issues]="No DKIM selectors discovered. "
        DKIM_RESULT[recommendations]="Configure DKIM signing and publish public keys. "
        return 1
    fi
    
    # Validate each discovered selector
    local selectors=(${DKIM_RESULT[selectors_found]})
    for selector in "${selectors[@]}"; do
        validate_dkim_selector "$domain" "$selector"
    done
    
    # Determine status
    if [[ -n "${DKIM_RESULT[issues]}" ]]; then
        DKIM_RESULT[status]="warning"
    else
        DKIM_RESULT[status]="pass"
    fi
    
    return 0
}

# Generate DKIM report
generate_dkim_report() {
    local domain="$1"
    
    cat <<EOF

## DKIM Analysis
Domain: $domain
Status: ${DKIM_RESULT[status]^^}

### Discovered Selectors
\`${DKIM_RESULT[selectors_found]:-none}\`

### Configuration
- Key Algorithm: ${DKIM_RESULT[key_algorithm]:-unknown}
- Key Size: ${DKIM_RESULT[key_size]:-unknown}

### Findings
EOF
    
    if [[ "${DKIM_RESULT[status]}" == "pass" ]]; then
        echo "- ✅ DKIM selectors discovered"
        echo "- ✅ Valid public keys found"
        if [[ "${DKIM_RESULT[key_size]}" == ">=2048 bits" ]]; then
            echo "- ✅ Strong key size (2048+ bits)"
        fi
    fi
    
    if [[ -n "${DKIM_RESULT[issues]}" ]]; then
        echo ""
        echo "### Issues"
        echo "${DKIM_RESULT[issues]}" | sed 's/\. /\n- ⚠️ /g' | grep -v '^$'
    fi
    
    if [[ -n "${DKIM_RESULT[recommendations]}" ]]; then
        echo ""
        echo "### Recommendations"
        echo "${DKIM_RESULT[recommendations]}" | sed 's/\. /\n- 📌 /g' | grep -v '^$'
    fi
}

# CLI interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <domain> [selector]"
        echo "Example: $0 google.com"
        echo "Example: $0 google.com google"
        exit 1
    fi
    
    check_dns_tools || exit 1
    domain=$(sanitize_domain "$1")
    
    if [[ -n "$2" ]]; then
        # Specific selector
        echo "[*] Validating DKIM selector '$2' for: $domain"
        validate_dkim_selector "$domain" "$2"
        DKIM_RESULT[selectors_found]="$2"
        generate_dkim_report "$domain"
    else
        # Auto-discover
        echo "[*] Validating DKIM for: $domain"
        if validate_dkim "$domain"; then
            generate_dkim_report "$domain"
            [[ "${DKIM_RESULT[status]}" == "pass" ]] && exit 0 || exit 2
        else
            generate_dkim_report "$domain"
            exit 1
        fi
    fi
fi
