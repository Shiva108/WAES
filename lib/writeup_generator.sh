#!/usr/bin/env bash
#==============================================================================
# WAES - Writeup Generator
# Auto-generates structured security assessment writeups
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/cvss_calculator.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/exporters/markdown_exporter.sh" 2>/dev/null || true

#==============================================================================
# GENERATION LOGIC
#==============================================================================

generate_writeup() {
    local target="$1"
    local format="${2:-markdown}"
    local output="${3:-${REPORT_DIR}/${target}_writeup.md}"
    
    print_info "Generating writeup for $target in $format format..."
    
    # Ensure findings summary exists
    if [[ ! -f "${REPORT_DIR}/.findings_summary.txt" ]]; then
        generate_findings_summary "$target" "${REPORT_DIR}"
    fi
    
    case "$format" in
        markdown|md)
            export_to_markdown "$target" "${REPORT_DIR}" "$output"
            ;;
        *)
            print_error "Unsupported format: $format"
            return 1
            ;;
    esac
    
    # Add instructions for user
    echo ""
    print_success "Writeup generated successfully!"
    echo "Location: $output"
    echo ""
    echo "Next steps:"
    echo "1. Review the generated writeup"
    echo "2. Add manual verification details"
    echo "3. Fill in specific exploitation steps where marked"
    echo ""
}

generate_findings_summary() {
    local target="$1"
    local report_dir="$2"
    local output="${report_dir}/.findings_summary.txt"
    
    # Calculate stats
    local critical=0 high=0 medium=0 low=0 info=0
    
    # Count from finding files
    [[ -f "${report_dir}/.findings_CRITICAL.txt" ]] && critical=$(grep -c "Type:" "${report_dir}/.findings_CRITICAL.txt" || echo 0)
    [[ -f "${report_dir}/.findings_HIGH.txt" ]] && high=$(grep -c "Type:" "${report_dir}/.findings_HIGH.txt" || echo 0)
    [[ -f "${report_dir}/.findings_MEDIUM.txt" ]] && medium=$(grep -c "Type:" "${report_dir}/.findings_MEDIUM.txt" || echo 0)
    [[ -f "${report_dir}/.findings_LOW.txt" ]] && low=$(grep -c "Type:" "${report_dir}/.findings_LOW.txt" || echo 0)
    
    local total=$((critical + high + medium + low))
    local risk="LOW"
    
    if (( critical > 0 )); then risk="CRITICAL";
    elif (( high > 0 )); then risk="HIGH";
    elif (( medium > 0 )); then risk="MEDIUM"; 
    fi
    
    {
        echo "**Target:** $target"
        echo "**Risk Rating:** $risk"
        echo "**Total Findings:** $total"
        echo ""
        echo "| Severity | Count |"
        echo "|----------|-------|"
        echo "| Critical | $critical |"
        echo "| High     | $high |"
        echo "| Medium   | $medium |"
        echo "| Low      | $low |"
        echo ""
    } > "$output"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    generate_writeup "$@"
fi
