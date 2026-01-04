#!/usr/bin/env bash
#==============================================================================
# WAES Email Compliance - DMARC Validator
# Validates Domain-based Message Authentication, Reporting & Conformance
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/email_compliance/dns_resolver.sh" 2>/dev/null || true

declare -A DMARC_RESULT=(
    [status]="unknown"
    [record]=""
    [policy]=""
    [subdomain_policy]=""
    [alignment_spf]=""
    [alignment_dkim]=""
    [percentage]=""
    [rua]=""
    [ruf]=""
    [issues]=""
    [recommendations]=""
)

# Validate DMARC record
validate_dmarc_record() {
    local domain="$1"
    local dmarc_domain="_dmarc.${domain}"
    
    # Query DMARC record
    local record
    record=$(query_dns_txt "$dmarc_domain")
    
    if [[ -z "$record" ]]; then
        DMARC_RESULT[status]="fail"
        DMARC_RESULT[issues]="No DMARC record found"
        DMARC_RESULT[recommendations]="Create DMARC record at _dmarc.${domain}"
        return 1
    fi
    
    # Check for multiple DMARC records
    local dmarc_count
    dmarc_count=$(echo "$record" | grep -c "^v=DMARC1" || echo 0)
    
    if [[ $dmarc_count -gt 1 ]]; then
        DMARC_RESULT[status]="fail"
        DMARC_RESULT[record]="$record"
        DMARC_RESULT[issues]="Multiple DMARC records detected (invalid)"
        DMARC_RESULT[recommendations]="Consolidate into single DMARC record"
        return 1
    fi
    
    DMARC_RESULT[record]="$record"
    
    # Validate version tag
    if ! echo "$record" | grep -q "^v=DMARC1"; then
        DMARC_RESULT[issues]+="Invalid or missing version tag. "
    fi
    
    # Parse and validate policy
    analyze_dmarc_policy "$record"
    
    # Parse reporting addresses
    analyze_dmarc_reporting "$record"
    
    # Parse alignment modes
    analyze_dmarc_alignment "$record"
    
    # Determine overall status
    if [[ -n "${DMARC_RESULT[issues]}" ]]; then
        DMARC_RESULT[status]="warning"
    else
        DMARC_RESULT[status]="pass"
    fi
    
    return 0
}

# Analyze DMARC policy
analyze_dmarc_policy() {
    local record="$1"
    
    # Extract main policy
    local policy
    policy=$(echo "$record" | grep -oP 'p=\K[^;]+' | tr -d ' ')
    
    if [[ -z "$policy" ]]; then
        DMARC_RESULT[policy]="none"
        DMARC_RESULT[issues]+="No policy (p=) tag found. "
        return
    fi
    
    DMARC_RESULT[policy]="$policy"
    
    case "$policy" in
        none)
            DMARC_RESULT[issues]+="Policy set to 'none' (monitoring only). "
            DMARC_RESULT[recommendations]+="Progress to 'quarantine' or 'reject' policy. "
            ;;
        quarantine)
            DMARC_RESULT[recommendations]+="Consider upgrading to 'reject' for maximum protection. "
            ;;
        reject)
            # Best policy
            ;;
        *)
            DMARC_RESULT[issues]+="Invalid policy value: $policy. "
            ;;
    esac
    
    # Extract subdomain policy
    local sp
    sp=$(echo "$record" | grep -oP 'sp=\K[^;]+' | tr -d ' ')
    DMARC_RESULT[subdomain_policy]="${sp:-same as main}"
    
    if [[ -n "$sp" ]] && [[ "$sp" != "$policy" ]] && [[ "$policy" != "none" ]]; then
        DMARC_RESULT[issues]+="Subdomain policy differs from main policy. "
    fi
    
    # Extract percentage
    local pct
    pct=$(echo "$record" | grep -oP 'pct=\K[^;]+' | tr -d ' ')
    DMARC_RESULT[percentage]="${pct:-100}%"
    
    if [[ -n "$pct" ]] && [[ "$pct" -lt 100 ]]; then
        DMARC_RESULT[issues]+="Partial deployment (pct=$pct%). "
        DMARC_RESULT[recommendations]+="Increase pct to 100 after monitoring. "
    fi
}

# Analyze reporting configuration
analyze_dmarc_reporting() {
    local record="$1"
    
    # Extract aggregate report address
    local rua
    rua=$(echo "$record" | grep -oP 'rua=\K[^;]+')
    DMARC_RESULT[rua]="${rua:-none}"
    
    if [[ -z "$rua" ]]; then
        DMARC_RESULT[recommendations]+="Add rua= tag for aggregate reports. "
    fi
    
    # Extract forensic report address
    local ruf
    ruf=$(echo "$record" | grep -oP 'ruf=\K[^;]+')
    DMARC_RESULT[ruf]="${ruf:-none}"
}

# Analyze alignment modes
analyze_dmarc_alignment() {
    local record="$1"
    
    # SPF alignment
    local aspf
    aspf=$(echo "$record" | grep -oP 'aspf=\K[^;]+' | tr -d ' ')
    DMARC_RESULT[alignment_spf]="${aspf:-relaxed}"
    
    # DKIM alignment
    local adkim
    adkim=$(echo "$record" | grep -oP 'adkim=\K[^;]+' | tr -d ' ')
    DMARC_RESULT[alignment_dkim]="${adkim:-relaxed}"
    
    if [[ "$aspf" == "s" ]] || [[ "$adkim" == "s" ]]; then
        # Strict alignment is more secure but may break some forwarding
        :
    fi
}

# Generate DMARC report
generate_dmarc_report() {
    local domain="$1"
    
    cat <<EOF

## DMARC Analysis
Domain: $domain
Status: ${DMARC_RESULT[status]^^}

### Record
\`${DMARC_RESULT[record]}\`

### Policy Configuration
- Policy: ${DMARC_RESULT[policy]}
- Subdomain Policy: ${DMARC_RESULT[subdomain_policy]}
- Enforcement: ${DMARC_RESULT[percentage]}
- SPF Alignment: ${DMARC_RESULT[alignment_spf]}
- DKIM Alignment: ${DMARC_RESULT[alignment_dkim]}

### Reporting
- Aggregate Reports (rua): ${DMARC_RESULT[rua]}
- Forensic Reports (ruf): ${DMARC_RESULT[ruf]}

### Findings
EOF
    
    if [[ "${DMARC_RESULT[status]}" == "pass" ]]; then
        echo "- ✅ Valid DMARC record found"
        if [[ "${DMARC_RESULT[policy]}" == "reject" ]]; then
            echo "- ✅ Strong enforcement policy (reject)"
        fi
        if [[ "${DMARC_RESULT[percentage]}" == "100%" ]]; then
            echo "- ✅ Full deployment (100%)"
        fi
    fi
    
    if [[ -n "${DMARC_RESULT[issues]}" ]]; then
        echo ""
        echo "### Issues"
        echo "${DMARC_RESULT[issues]}" | sed 's/\. /\n- ⚠️ /g' | grep -v '^$'
    fi
    
    if [[ -n "${DMARC_RESULT[recommendations]}" ]]; then
        echo ""
        echo "### Recommendations"
        echo "${DMARC_RESULT[recommendations]}" | sed 's/\. /\n- 📌 /g' | grep -v '^$'
    fi
}

# CLI interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <domain>"
        echo "Example: $0 google.com"
        exit 1
    fi
    
    check_dns_tools || exit 1
    domain=$(sanitize_domain "$1")
    
    echo "[*] Validating DMARC for: $domain"
    
    if validate_dmarc_record "$domain"; then
        generate_dmarc_report "$domain"
        [[ "${DMARC_RESULT[status]}" == "pass" ]] && exit 0 || exit 2
    else
        generate_dmarc_report "$domain"
        exit 1
    fi
fi
