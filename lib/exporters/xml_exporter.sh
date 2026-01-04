#!/usr/bin/env bash
#==============================================================================
# WAES XML Exporter
# Export scan results to XML format
#==============================================================================

set -euo pipefail

# XML escaping
xml_escape() {
    local string="$1"
    string="${string//&/&amp;}"
    string="${string//</&lt;}"
    string="${string//>/&gt;}"
    string="${string//\"/&quot;}"
    string="${string//\'/&apos;}"
    echo "$string"
}

# Generate XML report
export_to_xml() {
    local target="$1"
    local report_dir="${2:-.}"
    local scan_type="${3:-full}"
    local output_file="${4:-${report_dir}/${target}_report.xml}"
    
    local scan_date
    scan_date=$(date '+%Y-%m-%d %H:%M:%S')
    
    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<waes_scan>'
        echo "  <meta>"
        echo "    <version>1.2.0</version>"
        echo "    <target>$(xml_escape "$target")</target>"
        echo "    <scan_type>$scan_type</scan_type>"
        echo "    <scan_date>$scan_date</scan_date>"
        echo "  </meta>"
        
        # Nmap results
        if [[ -f "${report_dir}/${target}_nmap_standard.nmap" ]]; then
            echo "  <nmap_results>"
            grep -E "^[0-9]+/tcp" "${report_dir}/${target}_nmap_standard.nmap" | while read -r line; do
                local port state service
                port=$(echo "$line" | awk '{print $1}' | cut -d'/' -f1)
                state=$(echo "$line" | awk '{print $2}')
                service=$(echo "$line" | awk '{print $3}')
                
                echo "    <port>"
                echo "      <number>$port</number>"
                echo "      <state>$state</state>"
                echo "      <service>$(xml_escape "$service")</service>"
                echo "    </port>"
            done
            echo "  </nmap_results>"
        fi
        
        echo '</waes_scan>'
    } > "$output_file"
    
    echo "[+] XML report generated: $output_file"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    export_to_xml "$@"
fi
