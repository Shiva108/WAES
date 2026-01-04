#!/usr/bin/env bash
#==============================================================================
# WAES JSON Exporter
# Exports scan results to structured JSON format
#==============================================================================

set -euo pipefail

# Source color library if available
if [[ -f "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh" ]]; then
    source "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh"
else
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
fi

#==============================================================================
# JSON GENERATION FUNCTIONS
#==============================================================================

# Escape JSON strings
json_escape() {
    local string="$1"
    # Escape backslashes, quotes, newlines, tabs
    string="${string//\\/\\\\}"
    string="${string//\"/\\\"}"
    string="${string//$'\n'/\\n}"
    string="${string//$'\t'/\\t}"
    echo "$string"
}

# Generate JSON header
json_header() {
    local target="$1"
    local scan_type="$2"
    local scan_date="${3:-$(date '+%Y-%m-%d %H:%M:%S')}"
    
    cat << EOF
{
  "waes_version": "1.2.0",
  "scan_meta": {
    "target": "$target",
    "scan_type": "$scan_type",
    "scan_date": "$scan_date",
    "scanner": "WAES - Web Auto Enum & Scanner"
  },
EOF
}

# Parse and export nmap results
export_nmap_json() {
    local nmap_file="$1"
    
    if [[ ! -f "$nmap_file" ]]; then
        echo '  "nmap_results": [],'
        return
    fi
    
    echo '  "nmap_results": {'
    echo '    "ports": ['
    
    local first=true
    grep -E "^[0-9]+/tcp" "$nmap_file" 2>/dev/null | while read -r line; do
        local port state service version
        port=$(echo "$line" | awk '{print $1}' | cut -d'/' -f1)
        state=$(echo "$line" | awk '{print $2}')
        service=$(echo "$line" | awk '{print $3}')
        version=$(echo "$line" | cut -d' ' -f4-)
        version=$(json_escape "$version")
        
        [[ "$first" == "true" ]] || echo ","
        echo -n "      {\"port\": $port, \"state\": \"$state\", \"service\": \"$service\", \"version\": \"$version\"}"
        first=false
    done || true
    
    echo ""
    echo '    ]'
    echo '  },'
}

# Export SSL/TLS results
export_ssl_json() {
    local ssl_file="$1"
    
    if [[ ! -f "$ssl_file" ]]; then
        echo '  "ssl_results": {},'
        return
    fi
    
    echo '  "ssl_results": {'
    
    # Extract certificate info
    local cert_expiry cert_issuer cert_subject
    cert_expiry=$(grep "Expires:" "$ssl_file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)
    cert_issuer=$(grep "Issuer:" "$ssl_file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)
    cert_subject=$(grep "Subject:" "$ssl_file" 2>/dev/null | head -1 | cut -d':' -f2- | xargs)
    
    cert_expiry=$(json_escape "${cert_expiry:-unknown}")
    cert_issuer=$(json_escape "${cert_issuer:-unknown}")
    cert_subject=$(json_escape "${cert_subject:-unknown}")
    
    echo "    \"certificate\": {"
    echo "      \"expiry\": \"$cert_expiry\","
    echo "      \"issuer\": \"$cert_issuer\","
    echo "      \"subject\": \"$cert_subject\""
    echo "    },"
    
    # Vulnerabilities
    local vulns=()
    grep -i "vulnerable\|weak\|insecure" "$ssl_file" 2>/dev/null | while read -r vuln; do
        vuln=$(json_escape "$vuln")
        echo "\"$vuln\""
    done | paste -sd',' > /tmp/ssl_vulns.txt || true
    
    echo "    \"vulnerabilities\": ["
    [[ -s /tmp/ssl_vulns.txt ]] && cat /tmp/ssl_vulns.txt || echo ""
    echo "    ]"
    echo '  },'
    
    rm -f /tmp/ssl_vulns.txt
}

# Export CMS results
export_cms_json() {
    local cms_file="$1"
    
    if [[ ! -f "$cms_file" ]]; then
        echo '  "cms_results": {},'
        return
    fi
    
    echo '  "cms_results": {'
    
    # Detect CMS type
    local cms_type="unknown"
    grep -qi "wordpress" "$cms_file" && cms_type="wordpress"
    grep -qi "drupal" "$cms_file" && cms_type="drupal"
    grep -qi "joomla" "$cms_file" && cms_type="joomla"
    
    echo "    \"cms_type\": \"$cms_type\","
    
    # Extract version
    local version
    version=$(grep -i "version" "$cms_file" 2>/dev/null | head -1 | awk '{print $NF}')
    version=$(json_escape "${version:-unknown}")
    
    echo "    \"version\": \"$version\","
    
    # Plugins/modules
    echo "    \"plugins\": ["
    grep -E "plugin|module|component" "$cms_file" 2>/dev/null | head -10 | while read -r plugin; do
        plugin=$(json_escape "$plugin")
        echo "      \"$plugin\","
    done | sed '$ s/,$//' || true
    echo "    ]"
    echo '  },'
}

# Export XSS results
export_xss_json() {
    local xss_file="$1"
    
    if [[ ! -f "$xss_file" ]]; then
        echo '  "xss_results": [],'
        return
    fi
    
    echo '  "xss_results": ['
    
    grep "POTENTIAL XSS" "$xss_file" 2>/dev/null | while read -r finding; do
        finding=$(json_escape "$finding")
        echo "    {\"finding\": \"$finding\"},"
    done | sed '$ s/,$//' || true
    
    echo '  ],'
}

# Export summary
export_summary_json() {
    local report_dir="$1"
    local target="$2"
    
    echo '  "summary": {'
    
    # Count findings
    local total_files
    total_files=$(find "$report_dir" -name "${target}*" -type f 2>/dev/null | wc -l)
    
    echo "    \"total_files\": $total_files,"
    echo "    \"scan_complete\": true"
    echo '  }'
}

# Main JSON export function
export_to_json() {
    local target="$1"
    local report_dir="${2:-.}"
    local scan_type="${3:-full}"
    local output_file="${4:-${report_dir}/${target}_report.json}"
    
    print_info "Exporting results to JSON: $output_file"
    
    {
        json_header "$target" "$scan_type"
        
        # Export each scan type
        export_nmap_json "${report_dir}/${target}_nmap_standard.nmap" || true
        export_ssl_json "${report_dir}/${target}_ssl_scan.txt" || true
        export_cms_json "${report_dir}/${target}_cms_scan.txt" || true
        export_xss_json "${report_dir}/${target}_xss_scan.txt" || true
        export_summary_json "$report_dir" "$target"
        
        echo "}"
    } > "$output_file"
    
    # Validate JSON
    if command -v jq &>/dev/null; then
        if jq empty "$output_file" 2>/dev/null; then
            print_success "Valid JSON exported: $output_file"
        else
            print_error "Invalid JSON generated"
            return 1
        fi
    else
        print_success "JSON exported (install 'jq' for validation): $output_file"
    fi
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat << EOF
Usage: $0 <target> [report_dir] [scan_type] [output_file]

Examples:
    $0 example.com
    $0 example.com ./report deep
    $0 example.com ./report deep custom_output.json
EOF
        exit 1
    fi
    
    export_to_json "$@"
fi
