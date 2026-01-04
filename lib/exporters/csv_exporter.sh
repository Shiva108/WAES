#!/usr/bin/env bash
#==============================================================================
# WAES CSV Exporter
# Export scan results to CSV format for spreadsheet analysis
#==============================================================================

    # CSV escaping
    csv_escape() {
        local string="$1"
        # Escape quotes and wrap in quotes if contains comma/quote/newline
        if [[ "$string" =~ [,\"] ]]; then
            string="${string//\"/\"\"}"
            echo "\"$string\""
        else
            echo "$string"
        fi
    }

    # Generate CSV report
    export_to_csv() {
        local target="$1"
        local report_dir="${2:-.}"
        local scan_type="${3:-full}"
        local output_file="${4:-${report_dir}/${target}_report.csv}"
        
        {
            # Header
            echo "Type,Target,Port,Service,State,Finding,Severity,Description"
            
            # Nmap results
            if [[ -f "${report_dir}/${target}_nmap_standard.nmap" ]]; then
                grep -E "^[0-9]+/tcp" "${report_dir}/${target}_nmap_standard.nmap" 2>/dev/null | while read -r line; do
                    local port state service version
                    port=$(echo "$line" | awk '{print $1}' | cut -d'/' -f1)
                    state=$(echo "$line" | awk '{print $2}')
                    service=$(echo "$line" | awk '{print $3}')
                    version=$(echo "$line" | cut -d' ' -f4-)
                    
                    echo "nmap,$(csv_escape "$target"),$port,$(csv_escape "$service"),$state,Port Open,Info,$(csv_escape "$version")"
                done || true
            fi
            
            # SSL results
            if [[ -f "${report_dir}/${target}_ssl_scan.txt" ]]; then
                grep -i "vulnerable\|weak\|insecure" "${report_dir}/${target}_ssl_scan.txt" 2>/dev/null | while read -r finding; do
                    echo "ssl,$(csv_escape "$target"),,,,$(csv_escape "$finding"),Medium,SSL/TLS Issue"
                done || true
            fi
            
            # CMS results
            if [[ -f "${report_dir}/${target}_cms_scan.txt" ]]; then
                if grep -qi "wordpress" "${report_dir}/${target}_cms_scan.txt" 2>/dev/null; then
                    echo "cms,$(csv_escape "$target"),,,,WordPress Detected,Info,CMS Identified"
                fi
            fi
            
            # XSS results
            if [[ -f "${report_dir}/${target}_xss_scan.txt" ]]; then
                grep "POTENTIAL XSS" "${report_dir}/${target}_xss_scan.txt" 2>/dev/null | while read -r finding; do
                    echo "xss,$(csv_escape "$target"),,,,$(csv_escape "$finding"),High,Potential XSS"
                done || true
            fi
        } > "$output_file"
        
        echo "[+] CSV report generated: $output_file"
    }

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    export_to_csv "$@"
fi
