#!/usr/bin/env bash
#==============================================================================
# WAES Intelligent Scan Analysis Module
# Parses tool output, scores findings, and provides recommendations
#==============================================================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

source "${SCRIPT_DIR}/colors.sh" 2>/dev/null || {
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
    print_running() { echo "[>] $*"; }
}

#==============================================================================
# FINDING DATA STRUCTURES
#==============================================================================

declare -A FINDINGS
declare -a FINDING_IDS
FINDING_COUNT=0

# Severity scoring
declare -A SEVERITY_SCORES=(
    [CRITICAL]=10
    [HIGH]=8
    [MEDIUM]=5
    [LOW]=2
    [INFO]=1
)

#==============================================================================
# NMAP OUTPUT PARSER
#==============================================================================

parse_nmap_output() {
    local nmap_file="$1"
    
    if [[ ! -f "$nmap_file" ]]; then
        return 1
    fi
    
    print_running "Parsing Nmap output: $nmap_file"
    
    # Parse open ports
    local open_ports
    open_ports=$(grep -E "^[0-9]+/tcp.*open" "$nmap_file" | wc -l)
    
    if [[ $open_ports -gt 0 ]]; then
        while IFS= read -r line; do
            if echo "$line" | grep -qE "^[0-9]+/tcp.*open"; then
                local port service version
                port=$(echo "$line" | awk '{print $1}' | cut -d'/' -f1)
                service=$(echo "$line" | awk '{print $3}')
                version=$(echo "$line" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i; print ""}')
                
                # Score based on port and service
                local severity="INFO"
                local score=1
                
                # High-risk services
                if [[ "$service" =~ (ssh|telnet|ftp|smb|rdp|vnc) ]]; then
                    severity="MEDIUM"
                    score=5
                fi
                
                # Critical remote services
                if [[ "$service" =~ (mysql|postgresql|mongodb|redis) ]]; then
                    severity="HIGH"
                    score=8
                fi
                
                add_finding "nmap" "Open Port: $port/$service" "$severity" "$score" \
                    "Service: $service $version" \
                    "Enumerate $service on port $port, check for weak credentials or known CVEs"
            fi
        done < <(grep -E "^[0-9]+/tcp.*open" "$nmap_file")
    fi
    
    # Parse HTTP scripts
    if grep -q "http-" "$nmap_file"; then
        if grep -qi "http-title" "$nmap_file"; then
            local title
            title=$(grep "http-title" "$nmap_file" | sed 's/.*http-title: //')
            add_finding "nmap" "HTTP Service Detected" "INFO" 1 \
                "Page title: $title" \
                "Perform web vulnerability scanning with nikto, dirb, or manual testing"
        fi
    fi
    
    return 0
}

#==============================================================================
# NIKTO OUTPUT PARSER
#==============================================================================

parse_nikto_output() {
    local nikto_file="$1"
    
    if [[ ! -f "$nikto_file" ]]; then
        return 1
    fi
    
    print_running "Parsing Nikto output: $nikto_file"
    
    # Parse OSVDB findings (outdated software/config)
    local osvdb_count
    osvdb_count=$(grep -c "OSVDB-" "$nikto_file" 2>/dev/null || echo 0)
    
    if [[ $osvdb_count -gt 0 ]]; then
        add_finding "nikto" "Outdated Software Detected" "MEDIUM" 5 \
            "$osvdb_count OSVDB references found" \
            "Update web server and applications to latest versions"
    fi
    
    # Parse security headers
    if grep -qi "missing.*header" "$nikto_file"; then
        local missing_headers
        missing_headers=$(grep -i "missing.*header" "$nikto_file" | wc -l)
        add_finding "nikto" "Missing Security Headers" "LOW" 2 \
            "$missing_headers headers not configured" \
            "Implement security headers: X-Frame-Options, X-XSS-Protection, CSP, HSTS"
    fi
    
    # Parse directory listings
    if grep -qi "directory.*listing\|directory.*indexing" "$nikto_file"; then
        add_finding "nikto" "Directory Listing Enabled" "MEDIUM" 5 \
            "Directory browsing is enabled" \
            "Disable directory listing in web server configuration"
    fi
    
    # Parse backup files
    if grep -qi "backup\|\.bak\|\.old" "$nikto_file"; then
        add_finding "nikto" "Backup Files Accessible" "HIGH" 7 \
            "Backup files found on web server" \
            "Remove backup files from web root, review for sensitive data"
    fi
    
    return 0
}

#==============================================================================
# WAFW00F OUTPUT PARSER
#==============================================================================

parse_wafw00f_output() {
    local waf_file="$1"
    
    if [[ ! -f "$waf_file" ]]; then
        return 1
    fi
    
    print_running "Parsing WAF detection output: $waf_file"
    
    # Check for WAF detection
    if grep -qi "is behind" "$waf_file"; then
        local waf_name
        waf_name=$(grep -i "is behind" "$waf_file" | sed 's/.*is behind //' | head -1)
        add_finding "wafw00f" "Web Application Firewall Detected" "INFO" 1 \
            "WAF: $waf_name" \
            "Use evasion techniques: slow scanning, user-agent rotation, encoding payloads"
    else
        add_finding "wafw00f" "No WAF Detected" "MEDIUM" 5 \
            "Application exposed without WAF protection" \
            "Consider deploying a WAF (ModSecurity, Cloudflare, AWS WAF) for additional protection"
    fi
    
    return 0
}

#==============================================================================
# FINDING MANAGEMENT
#==============================================================================

add_finding() {
    local tool="$1"
    local title="$2"
    local severity="$3"
    local score="$4"
    local description="$5"
    local recommendation="$6"
    
    local id="FIND-$(printf '%04d' $FINDING_COUNT)"
    FINDING_IDS+=("$id")
    
    FINDINGS["$id:tool"]="$tool"
    FINDINGS["$id:title"]="$title"
    FINDINGS["$id:severity"]="$severity"
    FINDINGS["$id:score"]="$score"
    FINDINGS["$id:description"]="$description"
    FINDINGS["$id:recommendation"]="$recommendation"
    
    ((FINDING_COUNT++))
}

#==============================================================================
# ANALYSIS ENGINE
#==============================================================================

calculate_risk_score() {
    local total_score=0
    local critical_count=0
    local high_count=0
    local medium_count=0
    
    for id in "${FINDING_IDS[@]}"; do
        local severity="${FINDINGS[$id:severity]}"
        local score="${FINDINGS[$id:score]}"
        
        total_score=$((total_score + score))
        
        case "$severity" in
            CRITICAL) ((critical_count++)) ;;
            HIGH) ((high_count++)) ;;
            MEDIUM) ((medium_count++)) ;;
        esac
    done
    
    # Calculate risk level
    local risk_level="LOW"
    if [[ $critical_count -gt 0 ]] || [[ $total_score -gt 50 ]]; then
        risk_level="CRITICAL"
    elif [[ $high_count -gt 2 ]] || [[ $total_score -gt 30 ]]; then
        risk_level="HIGH"
    elif [[ $high_count -gt 0 ]] || [[ $total_score -gt 15 ]]; then
        risk_level="MEDIUM"
    fi
    
    echo "$risk_level:$total_score:$critical_count:$high_count:$medium_count"
}

generate_next_steps() {
    local report_file="$1"
    
    {
        echo ""
        echo "## Recommended Next Steps (Prioritized)"
        echo ""
        
        # Get findings sorted by score
        local sorted_findings=()
        for id in "${FINDING_IDS[@]}"; do
            local score="${FINDINGS[$id:score]}"
            sorted_findings+=("$score:$id")
        done
        
        # Sort by score (descending)
        IFS=$'\n' sorted_findings=($(sort -rn <<< "${sorted_findings[*]}"))
        unset IFS
        
        local step=1
        for item in "${sorted_findings[@]}"; do
            local id="${item#*:}"
            local severity="${FINDINGS[$id:severity]}"
            local recommendation="${FINDINGS[$id:recommendation]}"
            
            if [[ "$severity" != "INFO" ]]; then
                echo "$step. **[$severity]** $recommendation"
                ((step++))
            fi
        done
        
    } >> "$report_file"
}

#==============================================================================
# REPORT GENERATION
#==============================================================================

generate_analysis_report() {
    local target="$1"
    local report_dir="$2"
    local output_file="${report_dir}/${target}_analysis.md"
    
    print_info "Generating intelligent analysis report..."
    
    # Calculate overall risk
    local risk_data
    risk_data=$(calculate_risk_score)
    local risk_level="${risk_data%%:*}"
    local total_score=$(echo "$risk_data" | cut -d':' -f2)
    local critical_count=$(echo "$risk_data" | cut -d':' -f3)
    local high_count=$(echo "$risk_data" | cut -d':' -f4)
    local medium_count=$(echo "$risk_data" | cut -d':' -f5)
    
    {
        echo "# Intelligent Scan Analysis Report"
        echo ""
        echo "**Target:** $target"
        echo "**Analysis Date:** $(date '+%Y-%m-%d %H:%M:%S')"
        echo "**Overall Risk Level:** 🔴 **$risk_level** (Score: $total_score)"
        echo ""
        
        echo "## Summary"
        echo ""
        echo "| Metric | Count |"
        echo "|--------|-------|"
        echo "| Total Findings | $FINDING_COUNT |"
        echo "| Critical | $critical_count |"
        echo "| High | $high_count |"
        echo "| Medium | $medium_count |"
        echo "| Risk Score | $total_score |"
        echo ""
        
        echo "## Prioritized Findings"
        echo ""
        
        # Group by severity
        for sev in CRITICAL HIGH MEDIUM LOW INFO; do
            local sev_findings=()
            for id in "${FINDING_IDS[@]}"; do
                if [[ "${FINDINGS[$id:severity]}" == "$sev" ]]; then
                    sev_findings+=("$id")
                fi
            done
            
            if [[ ${#sev_findings[@]} -gt 0 ]]; then
                local icon
                case "$sev" in
                    CRITICAL) icon="🔴" ;;
                    HIGH) icon="🟠" ;;
                    MEDIUM) icon="🟡" ;;
                    LOW) icon="🔵" ;;
                    INFO) icon="ℹ️" ;;
                esac
                
                echo "### $icon $sev Severity (${#sev_findings[@]} findings)"
                echo ""
                
                for id in "${sev_findings[@]}"; do
                    local tool="${FINDINGS[$id:tool]}"
                    local title="${FINDINGS[$id:title]}"
                    local description="${FINDINGS[$id:description]}"
                    local recommendation="${FINDINGS[$id:recommendation]}"
                    local score="${FINDINGS[$id:score]}"
                    
                    echo "#### $title"
                    echo "- **Source:** $tool"
                    echo "- **Score:** $score/10"
                    echo "- **Details:** $description"
                    echo "- **Recommendation:** $recommendation"
                    echo ""
                done
            fi
        done
        
    } > "$output_file"
    
    # Add next steps
    generate_next_steps "$output_file"
    
    {
        echo ""
        echo "---"
        echo "*Generated by WAES Intelligent Analysis Engine*"
    } >> "$output_file"
    
    print_success "Analysis report saved: $output_file"
}

#==============================================================================
# MAIN ANALYSIS FUNCTION
#==============================================================================

analyze_scan_results() {
    local target="$1"
    local report_dir="$2"
    
    print_info "Starting intelligent scan analysis for: $target"
    echo ""
    
    # Parse available scan outputs
    local parsed=0
    
    # Nmap
    if [[ -f "${report_dir}/${target}_nmap_standard.nmap" ]]; then
        parse_nmap_output "${report_dir}/${target}_nmap_standard.nmap"
        ((parsed++))
    fi
    
    # Nikto
    if [[ -f "${report_dir}/${target}_nikto.txt" ]]; then
        parse_nikto_output "${report_dir}/${target}_nikto.txt"
        ((parsed++))
    fi
    
    # WAF detection
    if [[ -f "${report_dir}/${target}_wafw00f.txt" ]]; then
        parse_wafw00f_output "${report_dir}/${target}_wafw00f.txt"
        ((parsed++))
    fi
    
    if [[ $parsed -eq 0 ]]; then
        print_warn "No scan outputs found to analyze"
        return 1
    fi
    
    print_info "Parsed $parsed tool outputs, found $FINDING_COUNT findings"
    
    # Generate analysis report
    generate_analysis_report "$target" "$report_dir"
    
    return 0
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        cat <<EOF
Usage: $0 <target> <report_dir>

Intelligent Scan Analysis Module
Parses tool outputs and generates prioritized recommendations.

Examples:
    $0 example.com ./report
    $0 10.10.10.1 /tmp/waes_reports
EOF
        exit 1
    fi
    
    analyze_scan_results "$@"
fi
