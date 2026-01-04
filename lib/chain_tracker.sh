#!/usr/bin/env bash
#==============================================================================
# WAES - Vulnerability Chain Tracker
# Tracks relationships between vulnerabilities for attack path visualization
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true

# Chain storage
CHAIN_FILE="${REPORT_DIR:-./report}/.chains.json"

#==============================================================================
# CHAIN TRACKING
#==============================================================================

init_chain_tracking() {
    local target="$1"
    
    mkdir -p "$(dirname "$CHAIN_FILE")"
    
    # Initialize chain database
    cat > "$CHAIN_FILE" <<EOF
{
  "target": "$target",
  "scan_date": "$(date -Iseconds)",
  "chains": [],
  "nodes": {}
}
EOF
}

add_vulnerability_node() {
    local vuln_id="$1"
    local vuln_name="$2"
    local severity="$3"
    local description="$4"
    
    # Add node to graph
    local temp_file=$(mktemp)
    
    jq --arg id "$vuln_id" \
       --arg name "$vuln_name" \
       --arg sev "$severity" \
       --arg desc "$description" \
       '.nodes[$id] = {
           "name": $name,
           "severity": $sev,
           "description": $desc,
           "timestamp": now | todate
       }' "$CHAIN_FILE" > "$temp_file"
    
    mv "$temp_file" "$CHAIN_FILE"
}

add_chain_link() {
    local from_vuln="$1"
    local to_vuln="$2"
    local relationship="$3"
    
    print_info "Chain tracked: $from_vuln → $relationship → $to_vuln"
    
    local temp_file=$(mktemp)
    
    jq --arg from "$from_vuln" \
       --arg to "$to_vuln" \
       --arg rel "$relationship" \
       '.chains += [{
           "from": $from,
           "to": $to,
           "relationship": $rel,
           "timestamp": now | todate
       }]' "$CHAIN_FILE" > "$temp_file"
    
    mv "$temp_file" "$CHAIN_FILE"
}

#==============================================================================
# CHAIN ANALYSIS
#==============================================================================

get_attack_paths() {
    local target_file="${1:-$CHAIN_FILE}"
    
    if [[ ! -f "$target_file" ]]; then
        echo "No chains tracked"
        return 1
    fi
    
    # Extract unique paths
    jq -r '.chains[] | "\(.from) → \(.relationship) → \(.to)"' "$target_file"
}

visualize_chains() {
    local output_file="${1:-${REPORT_DIR}/attack_chains.txt}"
    
    {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "           ATTACK PATH VISUALIZATION"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        # Group chains by path
        local path_num=1
        local current_chain=""
        
        while IFS= read -r line; do
            echo "Path $path_num:"
            echo "  $line"
            echo ""
            ((path_num++))
        done < <(get_attack_paths)
        
        # Show critical chains
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "           CRITICAL CHAINS"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        
        jq -r '.chains[] | select(.from | IN("sql_injection", "rce", "auth_bypass")) | 
               "\(.from) → \(.relationship) → \(.to)"' "$CHAIN_FILE" 2>/dev/null || echo "None"
        
    } | tee "$output_file"
}

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

suggest_next_step() {
    local current_vuln="$1"
    
    case "$current_vuln" in
        directory_listing)
            echo "Look for: backup files, config files, sensitive data"
            ;;
        lfi)
            echo "Try: /etc/passwd, log poisoning, PHP wrapper filters"
            ;;
        sql_injection)
            echo "Try: database enumeration, credential extraction, file write"
            ;;
        xss)
            echo "Try: session hijacking, CSRF, credential phishing"
            ;;
        file_upload)
            echo "Try: shell upload, path traversal, extension bypass"
            ;;
        *)
            echo "Analyze finding for privilege escalation potential"
            ;;
    esac
}

#==============================================================================
# REPORTING
#==============================================================================

generate_chain_report() {
    local format="${1:-text}"
    local output="${REPORT_DIR}/chains_report.$format"
    
    case "$format" in
        markdown)
            {
                echo "# Attack Chain Analysis"
                echo ""
                echo "## Discovered Chains"
                echo ""
                
                local path_num=1
                while IFS= read -r line; do
                    echo "$path_num. \`$line\`"
                    ((path_num++))
                done < <(get_attack_paths)
                
                echo ""
                echo "## Vulnerability Nodes"
                echo ""
                jq -r '.nodes | to_entries[] | "### \(.key)\n- **Severity:** \(.value.severity)\n- **Description:** \(.value.description)\n"' "$CHAIN_FILE"
                
            } > "$output"
            ;;
        *)
            visualize_chains "$output"
            ;;
    esac
    
    print_success "Chain report generated: $output"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        init)
            init_chain_tracking "${2:-target}"
            ;;
        add-node)
            add_vulnerability_node "$2" "$3" "$4" "$5"
            ;;
        add-link)
            add_chain_link "$2" "$3" "$4"
            ;;
        visualize)
            visualize_chains
            ;;
        report)
            generate_chain_report "${2:-text}"
            ;;
        *)
            echo "Usage: $0 {init|add-node|add-link|visualize|report}"
            exit 1
            ;;
    esac
fi
