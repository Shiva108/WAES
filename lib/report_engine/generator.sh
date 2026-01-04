#!/usr/bin/env bash
#==============================================================================
# WAES Professional Report Generator
# Enterprise-grade pentesting reports with executive summaries
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/cvss_calculator.sh" 2>/dev/null || true

#==============================================================================
# TEMPLATES
#==============================================================================

generate_executive_summary() {
    local target="$1"
    local findings_file="$2"
    
    # Count findings by severity
    local critical=$(jq -s '[.[] | select(.risk_level=="CRITICAL")] | length' "$findings_file" 2>/dev/null || echo 0)
    local high=$(jq -s '[.[] | select(.risk_level=="HIGH")] | length' "$findings_file" 2>/dev/null || echo 0)
    local medium=$(jq -s '[.[] | select(.risk_level=="MEDIUM")] | length' "$findings_file" 2>/dev/null || echo 0)
    local low=$(jq -s '[.[] | select(.risk_level=="LOW")] | length' "$findings_file" 2>/dev/null || echo 0)
    
    # Determine overall risk
    local overall_risk="LOW"
    if (( critical > 0 )); then
        overall_risk="CRITICAL"
    elif (( high > 0 )); then
        overall_risk="HIGH"
    elif (( medium > 0 )); then
        overall_risk="MEDIUM"
    fi
    
    cat <<EOF
# Executive Summary

## Assessment Overview

**Target:** ${target}  
**Assessment Date:** $(date '+%Y-%m-%d')  
**Overall Risk Rating:** ${overall_risk}

## Risk Summary

| Severity | Count | Status |
|----------|-------|--------|
| Critical | ${critical} | ⚠️ Immediate action required |
| High | ${high} | 🔴 Urgent remediation needed |
| Medium | ${medium} | 🟡 Should be addressed |
| Low | ${low} | 🔵 Informational |

## Key Findings

EOF

    # Add top 3 critical/high findings
    if (( critical  > 0 || high > 0 )); then
        echo "### High-Impact Vulnerabilities"
        echo ""
        jq -rs '.[] | select(.risk_level=="CRITICAL" or .risk_level=="HIGH") | 
            "- **\\(.cve)**: \\(.description) (CVSS: \\(.cvss_base))"' "$findings_file" | head -3
        echo ""
    fi
    
    cat <<EOF
## Business Impact

The identified vulnerabilities pose the following risks to the organization:

1. **Data Breach Risk**: Critical vulnerabilities could lead to unauthorized access to sensitive data
2. **Service Disruption**: Exploitable flaws may result in denial of service or system compromise
3. **Compliance Impact**: Security gaps may violate regulatory requirements (PCI-DSS, GDPR, HIPAA)
4. **Reputational Damage**: Public disclosure of vulnerabilities could harm brand reputation

## Recommended Actions

### Immediate (24-48 hours)
EOF

    if (( critical > 0 )); then
        jq -rs '.[] | select(.risk_level=="CRITICAL") | 
            "- Patch \\(.service) to remediate \\(.cve)"' "$findings_file" | head -3
    else
        echo "- No critical findings requiring immediate action"
    fi
    
    cat <<EOF

### Short-term (1-2 weeks)
- Address all HIGH severity findings
- Implement Web Application Firewall (WAF)
- Enable security monitoring and logging

### Long-term (1-3 months)
- Conduct security awareness training
- Implement secure development lifecycle
- Schedule regular penetration testing

---

EOF
}

generate_methodology_section() {
    local target="$1"
    
    cat <<EOF
# Scope and Methodology

## Scope

**In-Scope:**
- Target: ${target}
- Web application security assessment
- Network service enumeration
- Vulnerability identification

**Out-of-Scope:**
- Social engineering
- Physical security
- Denial of service testing
- Production data manipulation

## Methodology

This assessment followed industry-standard penetration testing methodology:

### 1. Reconnaissance
- Port scanning and service enumeration
- Technology stack identification
- Web application fingerprinting

### 2. Vulnerability Assessment
- Automated scanning (Nmap, Nikto, Gobuster)
- Manual testing of identified attack surfaces
- OWASP Top 10 validation

### 3. Exploitation
- Proof-of-concept development for critical findings
- Risk validation through controlled exploitation
- Evidence collection (screenshots, logs)

### 4. Post-Exploitation
- Privilege escalation attempts
- Lateral movement opportunities
- Data access validation

### 5. Reporting
- Finding classification by severity
- CVE correlation and exploit mapping
- Remediation guidance

## Tools Used

- **Nmap**: Network and service discovery
- **Nikto**: Web server vulnerability scanning
- **Gobuster**: Directory and file enumeration
- **WPScan**: WordPress-specific assessment
- **OWASP ZAP**: Manual testing and fuzzing

---

EOF
}

generate_finding_details() {
    local findings_file="$1"
    
    cat <<EOF
# Technical Findings

This section provides detailed technical analysis of identified vulnerabilities.

---

EOF

    # Process each finding
    local finding_num=1
    jq -c '.[]' "$findings_file" 2>/dev/null | while read -r finding; do
        local cve=$(echo "$finding" | jq -r '.cve')
        local desc=$(echo "$finding" | jq -r '.description')
        local cvss=$(echo "$finding" | jq -r '.cvss_base')
        local risk=$(echo "$finding" | jq -r '.risk_level')
        local service=$(echo "$finding" | jq -r '.service')
        local version=$(echo "$finding" | jq -r '.version')
        
        # Get exploits
        local edb_url=$(echo "$finding" | jq -r '.exploits.exploitdb.edb_url // "N/A"')
        local msf_module=$(echo "$finding" | jq -r '.exploits.metasploit.module // "N/A"')
        
        cat <<EOF
## Finding #${finding_num}: ${desc}

**Severity:** ${risk} (CVSS ${cvss})  
**CVE:** ${cve}  
**Affected Service:** ${service} ${version}

### Description

This vulnerability affects ${service} version ${version}. ${desc}

### Technical Details

**CVSS v3 Score:** ${cvss}  
**Exploitability:** $(echo "$finding" | jq -r '.exploitability')

### Proof of Concept

Available exploits:
- **ExploitDB:** ${edb_url}
- **Metasploit:** ${msf_module}

### Impact

This vulnerability could allow an attacker to:
- Gain unauthorized access to sensitive data
- Execute arbitrary code on the target system
- Compromise system integrity

### Remediation

**Priority:** ${risk}

**Steps:**
1. Update ${service} to the latest patched version
2. Implement input validation and sanitization
3. Enable security headers and hardening measures
4. Monitor for exploitation attempts

### References

- CVE Details: https://cve.mitre.org/cgi-bin/cvename.cgi?name=${cve}
- NVD: https://nvd.nist.gov/vuln/detail/${cve}

---

EOF
        ((finding_num++))
    done
}

#==============================================================================
# REPORT GENERATION
#==============================================================================

generate_professional_report() {
    local target="$1"
    local report_dir="$2"
    local output_file="${3:-${report_dir}/${target}_professional_report.md}"
    
    print_header "Generating Professional Report"
    
    # Find intelligence findings
    local findings_file="${report_dir}/intelligence_report.json"
    if [[ ! -f "$findings_file" ]]; then
        print_error "No intelligence findings found. Run intelligence analysis first."
        return 1
    fi
    
    # Generate report sections
    {
        generate_executive_summary "$target" "$findings_file"
        generate_methodology_section "$target"
        generate_finding_details "$findings_file"
        
        cat <<'EOF'
# Appendices

## Appendix A: Scan Outputs

Raw scan outputs are available in the report directory:
EOF
        
        # List all scan files
        find "$report_dir" -name "*.txt" -o -name "*.log" | while read -r file; do
            echo "- $(basename "$file")"
        done
        
    } > "$output_file"
    
    print_success "Report generated: $output_file"
}

#==============================================================================
# EXPORT FORMATS
#==============================================================================

export_to_pdf() {
    local markdown_file="$1"
    local pdf_file="${markdown_file%.md}.pdf"
    
    if command -v pandoc &>/dev/null; then
        print_info "Generating PDF report..."
        pandoc "$markdown_file" -o "$pdf_file" \
            --pdf-engine=xelatex \
            --toc \
            --number-sections 2>/dev/null
        
        if [[ -f "$pdf_file" ]]; then
            print_success "PDF generated: $pdf_file"
        else
            print_error "PDF generation failed"
        fi
    else
        print_warn "Pandoc not installed, skipping PDF export"
    fi
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 2 ]]; then
        echo "Usage: $0 <target> <report_dir> [output_file]"
        exit 1
    fi
    
    generate_professional_report "$@"
fi
