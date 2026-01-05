#!/usr/bin/env bash
#==============================================================================
# Nuclei Scanner Wrapper for WAES
# Template-based vulnerability scanning with ProjectDiscovery nuclei
#==============================================================================

# Source colors
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true

#==============================================================================
# CONFIGURATION
#==============================================================================

# Nuclei paths
NUCLEI_BIN="${NUCLEI_BIN:-$(which nuclei 2>/dev/null)}"
NUCLEI_TEMPLATES="${SCRIPT_DIR}/external/nuclei-templates"
NUCLEI_CONFIG="${SCRIPT_DIR}/config/nuclei_profiles.yaml"

# Default settings
NUCLEI_RATE_LIMIT=150
NUCLEI_CONCURRENCY=25
NUCLEI_SEVERITY="critical,high"
NUCLEI_TIMEOUT=5
NUCLEI_RETRIES=1

#==============================================================================
# NUCLEI AVAILABILITY CHECK
#==============================================================================

check_nuclei() {
    if [[ ! -x "$NUCLEI_BIN" ]]; then
        print_warn "nuclei not found. Install with: go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
        return 1
    fi
    
    local version
    version=$($NUCLEI_BIN -version 2>&1 | head -1)
    print_info "nuclei version: $version"
    return 0
}

#==============================================================================
# TEMPLATE MANAGEMENT
#==============================================================================

update_nuclei_templates() {
    print_info "Updating nuclei templates..."
    
    if [[ -d "$NUCLEI_TEMPLATES" ]]; then
        print_info "Templates directory exists, updating..."
        cd "$NUCLEI_TEMPLATES" && git pull --quiet
    else
        print_info "Cloning nuclei-templates repository..."
        git clone --depth 1 https://github.com/projectdiscovery/nuclei-templates.git "$NUCLEI_TEMPLATES"
    fi
    
    local template_count
    template_count=$(find "$NUCLEI_TEMPLATES" -name "*.yaml" -type f | wc -l)
    print_success "Templates updated: $template_count templates available"
}

#==============================================================================
# PROFILE MANAGEMENT
#==============================================================================

get_nuclei_profile() {
    local profile="${1:-standard}"
    
    case "$profile" in
        quick|fast)
            NUCLEI_SEVERITY="critical,high"
            NUCLEI_TAGS="cve,exposure,takeover"
            NUCLEI_RATE_LIMIT=150
            NUCLEI_CONCURRENCY=25
            ;;
        bugbounty|bb)
            NUCLEI_SEVERITY="critical,high,medium"
            NUCLEI_TAGS="cve,exposure,sqli,xss,ssrf,rce"
            NUCLEI_RATE_LIMIT=100
            NUCLEI_CONCURRENCY=20
            ;;
        pentest|standard)
            NUCLEI_SEVERITY="critical,high,medium,low"
            NUCLEI_TAGS=""  # All tags
            NUCLEI_RATE_LIMIT=50
            NUCLEI_CONCURRENCY=15
            ;;
        comprehensive|full)
            NUCLEI_SEVERITY="critical,high,medium,low,info"
            NUCLEI_TAGS=""  # All tags
            NUCLEI_RATE_LIMIT=30
            NUCLEI_CONCURRENCY=10
            ;;
        *)
            print_warn "Unknown profile: $profile, using standard"
            get_nuclei_profile "standard"
            ;;
    esac
}

#==============================================================================
# SCANNING FUNCTIONS
#==============================================================================

run_nuclei_scan() {
    local target="$1"
    local output_dir="$2"
    local profile="${3:-standard}"
    
    check_nuclei || return 1
    
    # Apply profile
    get_nuclei_profile "$profile"
    
    local output_json="${output_dir}/${target}_nuclei.json"
    local output_txt="${output_dir}/${target}_nuclei.txt"
    
    print_info "Running nuclei scan on $target (profile: $profile)"
    print_info "Severity: $NUCLEI_SEVERITY | Concurrency: $NUCLEI_CONCURRENCY"
    
    # Build nuclei command
    local nuclei_cmd="$NUCLEI_BIN -u $target"
    
    # Add templates
    if [[ -d "$NUCLEI_TEMPLATES" ]]; then
        nuclei_cmd+=" -t $NUCLEI_TEMPLATES"
    else
        print_warn "Templates not found, using built-in templates only"
    fi
    
    # Add severity filter
    [[ -n "$NUCLEI_SEVERITY" ]] && nuclei_cmd+=" -severity $NUCLEI_SEVERITY"
    
    # Add tags filter
    [[ -n "$NUCLEI_TAGS" ]] && nuclei_cmd+=" -tags $NUCLEI_TAGS"
    
    # Performance settings
    nuclei_cmd+=" -rate-limit $NUCLEI_RATE_LIMIT"
    nuclei_cmd+=" -c $NUCLEI_CONCURRENCY"
    nuclei_cmd+=" -timeout $NUCLEI_TIMEOUT"
    nuclei_cmd+=" -retries $NUCLEI_RETRIES"
    
    # Output settings
    nuclei_cmd+=" -json -o $output_json"
    nuclei_cmd+=" -silent"
    
    # Execute scan
    print_info "Executing: nuclei (this may take several minutes...)"
    if eval "$nuclei_cmd" 2>&1 | tee "$output_txt"; then
        print_success "Nuclei scan completed"
        
        # Count findings
        local finding_count
        if [[ -f "$output_json" ]]; then
            finding_count=$(wc -l < "$output_json")
            print_info "Findings: $finding_count"
            
            # Generate summary
            generate_nuclei_summary "$output_json" "${output_dir}/${target}_nuclei.md"
        else
            print_warn "No findings detected"
        fi
    else
        print_error "Nuclei scan failed"
        return 1
    fi
}

#==============================================================================
# REPORTING FUNCTIONS
#==============================================================================

generate_nuclei_summary() {
    local json_file="$1"
    local output_md="$2"
    
    [[ ! -f "$json_file" ]] && return 1
    
    print_info "Generating nuclei summary report..."
    
    local target
    target=$(jq -r '.["matched-at"]' "$json_file" 2>/dev/null | head -1 | sed 's|https\?://||' | cut -d'/' -f1)
    
    cat > "$output_md" << EOF
# Nuclei Vulnerability Scan Report

**Target**: $target  
**Scan Date**: $(date '+%Y-%m-%d %H:%M:%S')  
**Total Findings**: $(wc -l < "$json_file")

---

EOF
    
    # Group by severity
    for severity in critical high medium low info; do
        local count
        count=$(jq -r "select(.info.severity == \"$severity\") | .info.name" "$json_file" 2>/dev/null | wc -l)
        
        if [[ $count -gt 0 ]]; then
            echo "## $(echo "$severity" | tr '[:lower:]' '[:upper:]') Severity ($count findings)" >> "$output_md"
            echo "" >> "$output_md"
            
            jq -r "select(.info.severity == \"$severity\") | 
                   \"- **\(.\"template-id\")**: \(.info.name)\n  - URL: \(.\"matched-at\")\n  - Type: \(.type // \"http\")\"" \
                   "$json_file" 2>/dev/null >> "$output_md"
            
            echo "" >> "$output_md"
        fi
    done
    
    # Add remediation section
    cat >> "$output_md" << 'EOF'

---

## Remediation Priority

1. **Critical**: Address immediately (< 24 hours)
2. **High**: Fix within 7 days
3. **Medium**: Schedule within 30 days
4. **Low**: Backlog (90 days)
5. **Info**: Documentation only

## Next Steps

- Review all critical and high findings
- Validate findings manually using curl commands
- Cross-reference with other scan tools
- Apply patches and retest
EOF
    
    print_success "Summary report generated: $output_md"
}

export_critical_findings() {
    local json_file="$1"
    local output_file="${json_file%.json}_critical.txt"
    
    [[ ! -f "$json_file" ]] && return 1
    
    print_info "Extracting critical findings..."
    
    jq -r 'select(.info.severity == "critical") | 
           "\(.info.name) - \(.\"matched-at\")"' \
           "$json_file" > "$output_file" 2>/dev/null
    
    local count
    count=$(wc -l < "$output_file")
    
    if [[ $count -gt 0 ]]; then
        print_warn "Critical vulnerabilities found: $count"
        print_info "Details: $output_file"
    fi
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

# Allow direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <target_url> <output_dir> [profile]"
        echo "Profiles: quick, bugbounty, pentest, comprehensive"
        exit 1
    fi
    
    run_nuclei_scan "$1" "$2" "${3:-standard}"
fi
