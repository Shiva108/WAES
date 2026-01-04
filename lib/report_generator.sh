#!/usr/bin/env bash
#==============================================================================
# WAES HTML Report Generator
# Converts text scan results to formatted HTML reports
#==============================================================================

# Source color library if available
if [[ -f "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh" ]]; then
    # shellcheck source=lib/colors.sh
    source "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh"
else
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
fi

#==============================================================================
# HTML GENERATION FUNCTIONS
#==============================================================================

html_header() {
    local title="$1"
    local scan_date="$2"
    
    cat << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>WAES Scan Report - $TITLE</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f5f5;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            border-radius: 8px;
            overflow: hidden;
        }
        
        header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
        }
        
        header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
        }
        
        .scan-info {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            padding: 20px 30px;
            background: #f8f9fa;
            border-bottom: 2px solid #e9ecef;
        }
        
        .info-item {
            padding: 10px;
            background: white;
            border-radius: 4px;
            border-left: 3px solid #667eea;
        }
        
        .info-label {
            font-size: 0.85em;
            color: #6c757d;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .info-value {
            font-size: 1.1em;
            font-weight: 600;
            color: #333;
            margin-top: 5px;
        }
        
        .content {
            padding: 30px;
        }
        
        .section {
            margin-bottom: 40px;
        }
        
        .section-title {
            font-size: 1.8em;
            color: #667eea;
            margin-bottom: 15px;
            padding-bottom: 10px;
            border-bottom: 3px solid #667eea;
        }
        
        .subsection {
            margin: 20px 0;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 6px;
        }
        
        .subsection-title {
            font-size: 1.3em;
            color: #495057;
            margin-bottom: 10px;
        }
        
        pre {
            background: #2d3748;
            color: #e2e8f0;
            padding: 15px;
            border-radius: 4px;
            overflow-x: auto;
            font-size: 0.9em;
            line-height: 1.5;
        }
        
        .vulnerability {
            margin: 15px 0;
            padding: 15px;
            border-radius: 4px;
            border-left: 4px solid;
        }
        
        .vuln-critical {
            background: #fff5f5;
            border-color: #fc8181;
        }
        
        .vuln-high {
            background: #fffaf0;
            border-color: #f6ad55;
        }
        
        .vuln-medium {
            background: #fffff0;
            border-color: #f6e05e;
        }
        
        .vuln-low {
            background: #f0fff4;
            border-color: #68d391;
        }
        
        .vuln-info {
            background: #ebf8ff;
            border-color: #4299e1;
        }
        
        .badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 0.85em;
            font-weight: 600;
            text-transform: uppercase;
        }
        
        .badge-critical { background: #fc8181; color: white; }
        .badge-high { background: #f6ad55; color: white; }
        .badge-medium { background: #f6e05e; color: #744210; }
        .badge-low { background: #68d391; color: #22543d; }
        .badge-info { background: #4299e1; color: white; }
        
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 15px 0;
        }
        
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #e2e8f0;
        }
        
        th {
            background: #edf2f7;
            font-weight: 600;
            color: #2d3748;
        }
        
        tr:hover {
            background: #f7fafc;
        }
        
        footer {
            padding: 20px 30px;
            background: #2d3748;
            color: #e2e8f0;
            text-align: center;
            font-size: 0.9em;
        }
        
        .toc {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 6px;
            margin-bottom: 30px;
        }
        
        .toc ul {
            list-style: none;
        }
        
        .toc li {
            padding: 8px 0;
        }
        
        .toc a {
            color: #667eea;
            text-decoration: none;
            font-weight: 500;
        }
        
        .toc a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🛡️ WAES Security Scan Report</h1>
            <p>Comprehensive Web Application Enumeration & Security Analysis</p>
        </header>
        
        <div class="scan-info">
            <div class="info-item">
                <div class="info-label">Target</div>
                <div class="info-value">$TITLE</div>
            </div>
            <div class="info-item">
                <div class="info-label">Scan Date</div>
                <div class="info-value">$SCAN_DATE</div>
            </div>
            <div class="info-item">
                <div class="info-label">Generated By</div>
                <div class="info-value">WAES v1.0.0</div>
            </div>
        </div>
        
        <div class="content">
EOF
    sed "s/\$TITLE/$title/g; s/\$SCAN_DATE/$scan_date/g"
}

html_footer() {
    cat << 'EOF'
        </div>
        
        <footer>
            <p>Generated by WAES - Web Auto Enum & Scanner</p>
            <p>Report generated at $TIMESTAMP</p>
        </footer>
    </div>
</body>
</html>
EOF
    sed "s/\$TIMESTAMP/$(date '+%Y-%m-%d %H:%M:%S')/g"
}

# Convert text content to HTML sections
text_to_html_section() {
    local title="$1"
    local content="$2"
    
    cat << EOF
<div class="section">
    <h2 class="section-title">$title</h2>
    <div class="subsection">
        <pre>$content</pre>
    </div>
</div>
EOF
}

# Parse nmap output
parse_nmap_output() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        return
    fi
    
    echo '<div class="section">'
    echo '<h2 class="section-title">Nmap Scan Results</h2>'
    
    # Extract ports
    echo '<div class="subsection">'
    echo '<h3 class="subsection-title">Open Ports</h3>'
    echo '<table><thead><tr><th>Port</th><th>State</th><th>Service</th><th>Version</th></tr></thead><tbody>'
    
    grep -E "^[0-9]+/tcp" "$file" | while read -r line; do
        local port state service version
        port=$(echo "$line" | awk '{print $1}')
        state=$(echo "$line" | awk '{print $2}')
        service=$(echo "$line" | awk '{print $3}')
        version=$(echo "$line" | cut -d' ' -f4-)
        
        echo "<tr><td>$port</td><td>$state</td><td>$service</td><td>$version</td></tr>"
    done
    
    echo '</tbody></table></div>'
    echo '</div>'
}

# Generate table of contents
generate_toc() {
    local -a sections=("$@")
    
    echo '<div class="toc">'
    echo '<h3>Table of Contents</h3>'
    echo '<ul>'
    
    for section in "${sections[@]}"; do
        local anchor
        anchor=$(echo "$section" | tr '[:upper:] ' '[:lower:]-')
        echo "<li><a href=\"#${anchor}\">${section}</a></li>"
    done
    
    echo '</ul></div>'
}

#==============================================================================
# MAIN REPORT GENERATION
#==============================================================================

generate_html_report() {
    local target="$1"
    local report_dir="${2:-.}"
    local output_file="${3:-${report_dir}/${target}_report.html}"
    
    print_info "Generating HTML report for: $target"
    
    local scan_date
    scan_date=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Start HTML
    html_header "$target" "$scan_date" > "$output_file"
    
    # Table of contents
    {
        generate_toc "Summary" "Nmap Results" "SSL/TLS Analysis" "CMS Detection" "Vulnerabilities" "Recommendations"
        
        # Summary section
        echo '<div class="section" id="summary">'
        echo '<h2 class="section-title">Executive Summary</h2>'
        echo '<div class="subsection">'
        echo '<p>This report contains the results of a comprehensive security scan performed on <strong>'"$target"'</strong>.</p>'
        echo '<p>The scan included port enumeration, service detection, SSL/TLS analysis, CMS detection, and vulnerability assessment.</p>'
        
        # Include scan results
        local extensions=(txt nmap gnmap)
        for ext in "${extensions[@]}"; do
            while IFS= read -r -d '' file; do
                local basename
                basename=$(basename "$file")
                local section_title="${basename%.*}"
                
                # Read file content
                local content
                content=$(<"$file")
                
                # Convert to HTML section
                text_to_html_section "$section_title" "$content"
            done < <(find "${report_dir}" -maxdepth 1 -name "${target}*.${ext}" -print0 2>/dev/null)
        done
        
        
        # Recommendations
        echo '<div class="section" id="recommendations">'
        echo '<h2 class="section-title">Security Recommendations</h2>'
        echo '<div class="subsection">'
        echo '<ul>'
        echo '<li>Review and patch all identified vulnerabilities</li>'
        echo '<li>Disable unnecessary services and close unused ports</li>'
        echo '<li>Implement strong SSL/TLS configurations</li>'
        echo '<li>Keep CMS and plugins up to date</li>'
        echo '<li>Implement Web Application Firewall (WAF)</li>'
        echo '<li>Regular security audits and penetration testing</li>'
        echo '</ul>'
        echo '</div></div>'
        
    } >> "$output_file"
    
    # Close HTML
    html_footer >> "$output_file"
    
    print_success "HTML report generated: $output_file"
}

# If script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat << EOF
Usage: $0 <target> [report_dir] [output_file]

Examples:
    $0 example.com
    $0 example.com ./reports
    $0 example.com ./reports custom_report.html
EOF
        exit 1
    fi
    
    generate_html_report "$@"
fi
