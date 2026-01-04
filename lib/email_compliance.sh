#!/usr/bin/env bash
#==============================================================================
# WAES Email Compliance Scanner
# Main orchestrator for domain email authentication testing
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source validators
source "${SCRIPT_DIR}/email_compliance/dns_resolver.sh"
source "${SCRIPT_DIR}/email_compliance/spf_validator.sh"
source "${SCRIPT_DIR}/email_compliance/dkim_validator.sh"
source "${SCRIPT_DIR}/email_compliance/dmarc_validator.sh"

# Source colors if available
if [[ -f "${SCRIPT_DIR}/colors.sh" ]]; then
    source "${SCRIPT_DIR}/colors.sh"
else
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
    print_header() { echo ""; echo "# $*"; }
fi

# Run complete email compliance scan
scan_email_compliance() {
    local domain="$1"
    local output_file="${2:-}"
    
    domain=$(sanitize_domain "$domain")
    
    if ! is_valid_domain "$domain"; then
        print_error "Invalid domain format: $domain"
        return 1
    fi
    
    print_header "Email Compliance Scan: $domain"
    echo "Scan Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Check DNS tools availability
    if ! check_dns_tools; then
        print_error "No DNS query tools available"
        return 1
    fi
    
    local overall_status="pass"
    local score=0
    local max_score=0
    
    # SPF Validation
    print_info "Checking SPF records..."
    if validate_spf_record "$domain"; then
        case "${SPF_RESULT[status]}" in
            pass) score=$((score + 35)); ((max_score += 35)) ;;
            warning) score=$((score + 20)); ((max_score += 35)); overall_status="warning" ;;
            *) ((max_score += 35)); overall_status="fail" ;;
        esac
    else
        ((max_score += 35))
        overall_status="fail"
    fi
    
    # DKIM Validation
    print_info "Checking DKIM records..."
    if validate_dkim "$domain"; then
        case "${DKIM_RESULT[status]}" in
            pass) score=$((score + 30)); ((max_score += 30)) ;;
            warning) score=$((score + 15)); ((max_score += 30)); overall_status="warning" ;;
            *) ((max_score += 30)); overall_status="fail" ;;
        esac
    else
        ((max_score += 30))
        overall_status="fail"
    fi
    
    # DMARC Validation
    print_info "Checking DMARC records..."
    if validate_dmarc_record "$domain"; then
        case "${DMARC_RESULT[status]}" in
            pass) score=$((score + 35)); ((max_score += 35)) ;;
            warning) score=$((score + 20)); ((max_score += 35)); overall_status="warning" ;;
            *) ((max_score += 35)); overall_status="fail" ;;
        esac
    else
        ((max_score += 35))
        overall_status="fail"
    fi
    
    # Generate comprehensive report
    {
        echo "# Email Compliance Report"
        echo ""
        echo "**Domain:** $domain  "
        echo "**Scan Date:** $(date '+%Y-%m-%d %H:%M:%S')  "
        echo "**Overall Score:** $score/$max_score ($(( score * 100 / max_score ))%)  "
        echo "**Status:** ${overall_status^^}"
        echo ""
        
        # Summary Table
        echo "## Summary Table"
        echo ""
        echo "| Protocol | Status | Record Found | Issues | Score |"
        echo "|----------|--------|--------------|--------|-------|"
        
        # SPF Row
        local spf_icon="❌"
        [[ "${SPF_RESULT[status]}" == "pass" ]] && spf_icon="✅"
        [[ "${SPF_RESULT[status]}" == "warning" ]] && spf_icon="⚠️"
        local spf_found="No"
        [[ -n "${SPF_RESULT[record]}" ]] && spf_found="Yes"
        local spf_issues_count=$(echo "${SPF_RESULT[issues]}" | grep -o '\.' | wc -l)
        echo "| SPF | $spf_icon ${SPF_RESULT[status]^^} | $spf_found | $spf_issues_count | 35/35 |"
        
        # DKIM Row
        local dkim_icon="❌"
        [[ "${DKIM_RESULT[status]}" == "pass" ]] && dkim_icon="✅"
        [[ "${DKIM_RESULT[status]}" == "warning" ]] && dkim_icon="⚠️"
        local dkim_found="No"
        [[ -n "${DKIM_RESULT[selectors_found]}" ]] && dkim_found="Yes"
        local dkim_issues_count=$(echo "${DKIM_RESULT[issues]}" | grep -o '\.' | wc -l)
        echo "| DKIM | $dkim_icon ${DKIM_RESULT[status]^^} | $dkim_found | $dkim_issues_count | 30/30 |"
        
        # DMARC Row
        local dmarc_icon="❌"
        [[ "${DMARC_RESULT[status]}" == "pass" ]] && dmarc_icon="✅"
        [[ "${DMARC_RESULT[status]}" == "warning" ]] && dmarc_icon="⚠️"
        local dmarc_found="No"
        [[ -n "${DMARC_RESULT[record]}" ]] && dmarc_found="Yes"
        local dmarc_issues_count=$(echo "${DMARC_RESULT[issues]}" | grep -o '\.' | wc -l)
        echo "| DMARC | $dmarc_icon ${DMARC_RESULT[status]^^} | $dmarc_found | $dmarc_issues_count | 35/35 |"
        
        echo ""
        
        generate_spf_report "$domain"
        generate_dkim_report "$domain"
        generate_dmarc_report "$domain"
        
        echo ""
        echo "---"
        echo ""
        echo "## Compliance Summary"
        echo ""
        
        case "$overall_status" in
            pass)
                echo "✅ **EXCELLENT** - Domain has strong email authentication"
                ;;
            warning)
                echo "⚠️ **GOOD** - Domain has email authentication with some improvements needed"
                ;;
            fail)
                echo "❌ **NEEDS ATTENTION** - Domain requires email authentication configuration"
                ;;
        esac
        
    } | tee "${output_file:-/dev/stdout}"
    
    # Return status
    case "$overall_status" in
        pass) return 0 ;;
        warning) return 2 ;;
        *) return 1 ;;
    esac
}

# CLI Usage
show_usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS] <domain>

Options:
    -o, --output FILE    Save report to file (markdown format)
    -h, --help          Show this help message

Examples:
    $(basename "$0") google.com
    $(basename "$0") -o report.md example.com
    
Description:
    Performs comprehensive email authentication compliance testing including:
    - SPF (Sender Policy Framework) validation
    - DKIM (DomainKeys Identified Mail) verification
    - DMARC (Domain-based Message Authentication) analysis
EOF
}

# Main entry point
main() {
    local domain=""
    local output_file=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                echo "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                domain="$1"
                shift
                ;;
        esac
    done
    
    if [[ -z "$domain" ]]; then
        echo "Error: Domain required"
        show_usage
        exit 1
    fi
    
    scan_email_compliance "$domain" "$output_file"
    exit $?
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
