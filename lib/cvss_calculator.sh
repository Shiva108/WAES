#!/usr/bin/env bash
#==============================================================================
# WAES - CVSS v3.1 Scoring Calculator
# Calculates severity scores for vulnerabilities
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true

#==============================================================================
# CVSS SCORING
#==============================================================================

calculate_cvss_score() {
    local vuln_type="$1"
    
    case "$vuln_type" in
        # Critical (9.0-10.0)
        rce|remote_code_execution)
            echo "10.0"
            ;;
        sql_injection|sqli)
            echo "9.8"
            ;;
        auth_bypass|authentication_bypass)
            echo "9.1"
            ;;
            
        # High (7.0-8.9)
        xss_stored|stored_xss)
            echo "7.2"
            ;;
        xxe|xml_external_entity)
            echo "7.5"
            ;;
        csrf|cross_site_request_forgery)
            echo "7.1"
            ;;
        file_upload_unrestricted)
            echo "8.8"
            ;;
            
        # Medium (4.0-6.9)
        xss_reflected|reflected_xss)
            echo "6.1"
            ;;
        directory_listing)
            echo "5.3"
            ;;
        information_disclosure)
            echo "5.3"
            ;;
        weak_password_policy)
            echo "5.0"
            ;;
        lfi|local_file_inclusion)
            echo "6.5"
            ;;
            
        # Low (0.1-3.9)
        clickjacking)
            echo "3.7"
            ;;
        missing_security_headers)
            echo "3.1"
            ;;
        http_method_enabled)
            echo "3.7"
            ;;
        ssl_weak_cipher)
            echo "3.7"
            ;;
            
        # Info (0.0)
        info|informational)
            echo "0.0"
            ;;
            
        # Default medium
        *)
            echo "5.0"
            ;;
    esac
}

get_severity_rating() {
    local score="$1"
    
    # Convert to comparable number
    local score_int=$(echo "$score" | cut -d. -f1)
    
    if (( score_int >= 9 )); then
        echo "CRITICAL"
    elif (( score_int >= 7 )); then
        echo "HIGH"
    elif (( score_int >= 4 )); then
        echo "MEDIUM"
    elif (( score_int >= 1 )); then
        echo "LOW"
    else
        echo "INFO"
    fi
}

get_severity_color() {
    local severity="$1"
    
    case "$severity" in
        CRITICAL) echo "${RED}" ;;
        HIGH) echo "${YELLOW}" ;;
        MEDIUM) echo "${BLUE}" ;;
        LOW) echo "${GREEN}" ;;
        INFO) echo "${NC}" ;;
        *) echo "${NC}" ;;
    esac
}

#==============================================================================
# SCORING REPORT
#==============================================================================

score_finding() {
    local vuln_type="$1"
    local vuln_name="${2:-$vuln_type}"
    local location="${3:-unknown}"
    
    local score=$(calculate_cvss_score "$vuln_type")
    local severity=$(get_severity_rating "$score")
    local color=$(get_severity_color "$severity")
    
    printf "${color}[%s]${NC} %s in %s - CVSS %s\n" \
           "$severity" "$vuln_name" "$location" "$score"
}

generate_severity_distribution() {
    local findings_file="$1"
    local output_file="${2:-${REPORT_DIR}/severity_distribution.txt}"
    
    if [[ ! -f "$findings_file" ]]; then
        print_error "Findings file not found: $findings_file"
        return 1
    fi
    
    # Count by severity
    local critical=0 high=0 medium=0 low=0 info=0
    
    while IFS= read -r line; do
        local vuln_type=$(echo "$line" | cut -d: -f1)
        local score=$(calculate_cvss_score "$vuln_type")
        local severity=$(get_severity_rating "$score")
        
        case "$severity" in
            CRITICAL) ((critical++)) ;;
            HIGH) ((high++)) ;;
            MEDIUM) ((medium++)) ;;
            LOW) ((low++)) ;;
            INFO) ((info++)) ;;
        esac
    done < "$findings_file"
    
    # Generate ASCII chart
    {
        echo "Vulnerability Distribution"
        echo "══════════════════════════"
        echo ""
        printf "CRITICAL: %s (%d)\n" "$(print_bar $critical 20)" "$critical"
        printf "HIGH:     %s (%d)\n" "$(print_bar $high 20)" "$high"
        printf "MEDIUM:   %s (%d)\n" "$(print_bar $medium 20)" "$medium"
        printf "LOW:      %s (%d)\n" "$(print_bar $low 20)" "$low"
        printf "INFO:     %s (%d)\n" "$(print_bar $info 20)" "$info"
        echo ""
        printf "TOTAL:    %d findings\n" "$((critical + high + medium + low + info))"
    } | tee "$output_file"
}

print_bar() {
    local count="$1"
    local max_width="${2:-50}"
    
    if (( count == 0 )); then
        echo ""
        return
    fi
    
    local bar_width=$((count > max_width ? max_width : count))
    printf '█%.0s' $(seq 1 $bar_width)
}

#==============================================================================
# RISK RATING
#==============================================================================

calculate_overall_risk() {
    local findings_file="$1"
    
    local total_score=0
    local count=0
    
    while IFS= read -r line; do
        local vuln_type=$(echo "$line" | cut -d: -f1)
        local score=$(calculate_cvss_score "$vuln_type")
        total_score=$(echo "$total_score + $score" | bc)
        ((count++))
    done < "$findings_file"
    
    if (( count == 0 )); then
        echo "NONE"
        return
    fi
    
    # Calculate average
    local avg_score=$(echo "scale=1; $total_score / $count" | bc)
    
    get_severity_rating "$avg_score"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        score)
            score_finding "$2" "$3" "$4"
            ;;
        distribution)
            generate_severity_distribution "$2" "$3"
            ;;
        risk)
            calculate_overall_risk "$2"
            ;;
        *)
            echo "Usage: $0 {score|distribution|risk} [args]"
            exit 1
            ;;
    esac
fi
