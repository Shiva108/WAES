#!/usr/bin/env bash
#==============================================================================
# WAES Email Compliance - SPF Validator
# Validates Sender Policy Framework records
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/email_compliance/dns_resolver.sh" 2>/dev/null || true

# SPF validation result structure
declare -A SPF_RESULT=(
    [status]="unknown"
    [record]=""
    [policy]=""
    [lookups]=0
    [issues]=""
    [recommendations]=""
)

# Validate SPF record syntax and policy
validate_spf_record() {
    local domain="$1"
    local records
    
    # Get TXT records
    records=$(query_dns_txt "$domain")
    
    if [[ -z "$records" ]]; then
        SPF_RESULT[status]="fail"
        SPF_RESULT[issues]="No DNS TXT records found"
        return 1
    fi
    
    # Extract SPF record(s)
    local spf_records
    spf_records=$(echo "$records" | grep -i "^v=spf1")
    
    # Check for multiple SPF records (RFC violation)
    local spf_count
    spf_count=$(echo "$spf_records" | grep -c "^v=spf1" || echo 0)
    
    if [[ $spf_count -eq 0 ]]; then
        SPF_RESULT[status]="fail"
        SPF_RESULT[issues]="No SPF record found"
        SPF_RESULT[recommendations]="Add SPF record: v=spf1 -all"
        return 1
    elif [[ $spf_count -gt 1 ]]; then
        SPF_RESULT[status]="fail"
       SPF_RESULT[record]="$spf_records"
        SPF_RESULT[issues]="Multiple SPF records detected (RFC 7208 violation)"
        SPF_RESULT[recommendations]="Consolidate into single SPF record"
        return 1
    fi
    
    # Single valid SPF record found
    SPF_RESULT[record]="$spf_records"
    
    # Analyze SPF mechanisms and policy
    analyze_spf_policy "$spf_records"
    count_spf_lookups "$spf_records" "$domain"
    
    # Determine overall status
    if [[ -n "${SPF_RESULT[issues]}" ]]; then
        SPF_RESULT[status]="warning"
    else
        SPF_RESULT[status]="pass"
    fi
    
    return 0
}

# Analyze SPF policy strength
analyze_spf_policy() {
    local record="$1"
    
    # Extract final qualifier
    if echo "$record" | grep -q '\-all'; then
        SPF_RESULT[policy]="hard fail (-all)"
    elif echo "$record" | grep -q '\~all'; then
        SPF_RESULT[policy]="soft fail (~all)"
        SPF_RESULT[recommendations]+="Consider upgrading to -all for stricter enforcement. "
    elif echo "$record" | grep -q '\?all'; then
        SPF_RESULT[policy]="neutral (?all)"
        SPF_RESULT[issues]+="Weak policy: ?all provides no protection. "
        SPF_RESULT[recommendations]+="Change to -all or ~all. "
    elif echo "$record" | grep -q '\+all'; then
        SPF_RESULT[policy]="pass (+all)"
        SPF_RESULT[issues]+="Critical: +all allows all senders (no SPF protection). "
        SPF_RESULT[recommendations]+="Change to -all immediately. "
    else
        SPF_RESULT[policy]="unknown"
        SPF_RESULT[issues]+="No explicit all mechanism found. "
        SPF_RESULT[recommendations]+="Add -all to end of SPF record. "
    fi
    
    # Check for deprecated mechanisms
    if echo "$record" | grep -q '\bptr\b'; then
        SPF_RESULT[issues]+="Deprecated 'ptr' mechanism found. "
        SPF_RESULT[recommendations]+="Remove ptr mechanism (deprecated in RFC 7208). "
    fi
}

# Count DNS lookups (RFC limit: 10)
count_spf_lookups() {
    local record="$1"
    local domain="$2"
    local count=0
    
    # Count include mechanisms
    local includes
    includes=$(echo "$record" | grep -o 'include:[^ ]*' | wc -l)
    count=$((count + includes))
    
    # Count a mechanisms
    local a_mechs
    a_mechs=$(echo "$record" | grep -o '\ba\b' | wc -l)
    count=$((count + a_mechs))
    
    # Count mx mechanisms
    local mx_mechs
    mx_mechs=$(echo "$record" | grep -o '\bmx\b' | wc -l)
    count=$((count + mx_mechs))
    
    # Count exists mechanisms
    local exists_mechs
    exists_mechs=$(echo "$record" | grep -o 'exists:[^ ]*' | wc -l)
    count=$((count + exists_mechs))
    
    SPF_RESULT[lookups]=$count
    
    if [[ $count -gt 10 ]]; then
        SPF_RESULT[issues]+="DNS lookup limit exceeded ($count/10). "
        SPF_RESULT[recommendations]+="Reduce includes or use ip4/ip6 mechanisms. "
    elif [[ $count -gt 8 ]]; then
        SPF_RESULT[issues]+="Approaching DNS lookup limit ($count/10). "
    fi
}

# Generate SPF validation report
generate_spf_report() {
    local domain="$1"
    
    cat <<EOF

## SPF Analysis
Domain: $domain
Status: ${SPF_RESULT[status]^^}

### Record
\`${SPF_RESULT[record]}\`

### Configuration
- Policy: ${SPF_RESULT[policy]}
- DNS Lookups: ${SPF_RESULT[lookups]}/10

### Findings
EOF
    
    if [[ "${SPF_RESULT[status]}" == "pass" ]]; then
        echo "- ✅ Valid SPF record found"
        echo "- ✅ DNS lookup count within limits"
        if [[ "${SPF_RESULT[policy]}" == "hard fail (-all)" ]]; then
            echo "- ✅ Strong enforcement policy"
        fi
    fi
    
    if [[ -n "${SPF_RESULT[issues]}" ]]; then
        echo ""
        echo "### Issues"
        echo "${SPF_RESULT[issues]}" | sed 's/\. /\n- ⚠️ /g' | grep -v '^$'
    fi
    
    if [[ -n "${SPF_RESULT[recommendations]}" ]]; then
        echo ""
        echo "### Recommendations"
        echo "${SPF_RESULT[recommendations]}" | sed 's/\. /\n- 📌 /g' | grep -v '^$'
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
    
    echo "[*] Validating SPF for: $domain"
    
    if validate_spf_record "$domain"; then
        generate_spf_report "$domain"
        [[ "${SPF_RESULT[status]}" == "pass" ]] && exit 0 || exit 2
    else
        generate_spf_report "$domain"
        exit 1
    fi
fi
