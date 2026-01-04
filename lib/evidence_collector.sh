#!/usr/bin/env bash
#==============================================================================
# WAES - Evidence Auto-Collector
# Automatically collects and organizes evidence during scans
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true

# Evidence storage
EVIDENCE_DIR="${REPORT_DIR:-./report}/evidence"
EVIDENCE_MANIFEST="${EVIDENCE_DIR}/manifest.json"

#==============================================================================
# INITIALIZATION
#==============================================================================

init_evidence_collection() {
    local target="$1"
    
    mkdir -p "$EVIDENCE_DIR"
    
    # Initialize manifest
    cat > "$EVIDENCE_MANIFEST" <<EOF
{
  "target": "$target",
  "scan_date": "$(date -Iseconds)",
  "evidence_count": 0,
  "evidence": []
}
EOF
    
    print_success "Evidence collection initialized: $EVIDENCE_DIR"
}

#==============================================================================
# EVIDENCE COLLECTION
#==============================================================================

collect_http_response() {
    local url="$1"
    local finding_type="$2"
    local description="$3"
    
    local evidence_id=$(generate_evidence_id)
    local evidence_file="${EVIDENCE_DIR}/${evidence_id}_response.txt"
    
    # Capture HTTP response
    curl -i -s -L "$url" --max-time 10 > "$evidence_file" 2>&1
    
    # Add to manifest
    add_to_manifest "$evidence_id" "http_response" "$finding_type" "$description" "$evidence_file"
    
    print_info "Evidence collected: $evidence_id"
}

collect_command_output() {
    local command="$1"
    local finding_type="$2"
    local description="$3"
    
    local evidence_id=$(generate_evidence_id)
    local evidence_file="${EVIDENCE_DIR}/${evidence_id}_command.txt"
    
    # Save command and output
    {
        echo "Command: $command"
        echo "Timestamp: $(date -Iseconds)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        eval "$command" 2>&1
    } > "$evidence_file"
    
    add_to_manifest "$evidence_id" "command_output" "$finding_type" "$description" "$evidence_file"
}

collect_file_content() {
    local file_path="$1"
    local finding_type="$2"
    local description="$3"
    
    local evidence_id=$(generate_evidence_id)
    local evidence_file="${EVIDENCE_DIR}/${evidence_id}_file.txt"
    
    # Copy file with metadata
    {
        echo "Source: $file_path"
        echo "Timestamp: $(date -Iseconds)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        cat "$file_path" 2>&1
    } > "$evidence_file"
    
    add_to_manifest "$evidence_id" "file_content" "$finding_type" "$description" "$evidence_file"
}

collect_screenshot() {
    local url="$1"
    local finding_type="$2"
    local description="$3"
    
    # Check if screenshot tool is available
    if ! command -v cutycapt &>/dev/null && ! command -v wkhtmltoimage &>/dev/null; then
        print_warn "No screenshot tool available (cutycapt or wkhtmltoimage)"
        return 1
    fi
    
    local evidence_id=$(generate_evidence_id)
    local evidence_file="${EVIDENCE_DIR}/${evidence_id}_screenshot.png"
    
    # Take screenshot
    if command -v cutycapt &>/dev/null; then
        cutycapt --url="$url" --out="$evidence_file" --max-wait=5000 2>/dev/null
    elif command -v wkhtmltoimage &>/dev/null; then
        wkhtmltoimage --quiet "$url" "$evidence_file" 2>/dev/null
    fi
    
    if [[ -f "$evidence_file" ]]; then
        add_to_manifest "$evidence_id" "screenshot" "$finding_type" "$description" "$evidence_file"
        print_success "Screenshot captured: $evidence_id"
    fi
}

#==============================================================================
# AUTOMATED EVIDENCE
#==============================================================================

auto_collect_for_finding() {
    local url="$1"
    local finding_type="$2"
    local description="$3"
    
    print_info "Auto-collecting evidence for: $finding_type"
    
    # Collect HTTP response
    collect_http_response "$url" "$finding_type" "$description"
    
    # Attempt screenshot
    collect_screenshot "$url" "$finding_type" "$description" 2>/dev/null || true
    
    # Type-specific evidence
    case "$finding_type" in
        sql_injection)
            # Collect error response
            collect_http_response "${url}'" "sql_injection_error" "SQL error page"
            ;;
        xss)
            # Collect reflected payload
            collect_http_response "${url}<script>alert(1)</script>" "xss_reflection" "XSS payload reflection"
            ;;
        directory_listing)
            # Collect directory index
            collect_http_response "$url" "directory_listing" "Directory index page"
            ;;
    esac
}

#==============================================================================
# HELPERS
#==============================================================================

generate_evidence_id() {
    # Format: YYYYMMDD_HHMMSS_NNN
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local count=$(jq -r '.evidence_count // 0' "$EVIDENCE_MANIFEST" 2>/dev/null || echo 0)
    printf "%s_%03d" "$timestamp" "$((count + 1))"
}

add_to_manifest() {
    local evidence_id="$1"
    local evidence_type="$2"
    local finding_type="$3"
    local description="$4"
    local file_path="$5"
    
    local temp_file=$(mktemp)
    
    jq --arg id "$evidence_id" \
       --arg type "$evidence_type" \
       --arg finding "$finding_type" \
       --arg desc "$description" \
       --arg path "$file_path" \
       '.evidence_count += 1 |
        .evidence += [{
            "id": $id,
            "type": $type,
            "finding_type": $finding,
            "description": $desc,
            "file": $path,
            "timestamp": now | todate
        }]' "$EVIDENCE_MANIFEST" > "$temp_file"
    
    mv "$temp_file" "$EVIDENCE_MANIFEST"
}

#==============================================================================
# REPORTING
#==============================================================================

generate_evidence_report() {
    local output="${EVIDENCE_DIR}/evidence_summary.txt"
    
    {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "           EVIDENCE COLLECTION SUMMARY"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Total Evidence Collected: $(jq -r '.evidence_count' "$EVIDENCE_MANIFEST")"
        echo "Target: $(jq -r '.target' "$EVIDENCE_MANIFEST")"
        echo "Scan Date: $(jq -r '.scan_date' "$EVIDENCE_MANIFEST")"
        echo ""
        echo "Evidence Index:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        jq -r '.evidence[] | 
               "\nID: \(.id)\nType: \(.type)\nFinding: \(.finding_type)\nDescription: \(.description)\nFile: \(.file)\n"' \
               "$EVIDENCE_MANIFEST"
        
    } | tee "$output"
    
    print_success "Evidence report: $output"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        init)
            init_evidence_collection "${2:-target}"
            ;;
        collect-http)
            collect_http_response "$2" "$3" "$4"
            ;;
        collect-command)
            collect_command_output "$2" "$3" "$4"
            ;;
        auto-collect)
            auto_collect_for_finding "$2" "$3" "$4"
            ;;
        report)
            generate_evidence_report
            ;;
        *)
            echo "Usage: $0 {init|collect-http|collect-command|auto-collect|report}"
            exit 1
            ;;
    esac
fi
