#!/usr/bin/env bash
#==============================================================================
# WAES Intelligence Engine
# CVE correlation, exploit mapping, and risk scoring
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/lib/cvss_calculator.sh" 2>/dev/null || true

# Fallback functions
print_info() { echo "[*] $1"; }
print_warn() { echo "[~] $1"; }
print_success() { echo "[+] $1"; }
print_error() { echo "[!] $1"; }

#==============================================================================
# CONFIGURATION
#==============================================================================

CVE_DATABASE="${SCRIPT_DIR}/data/cve_database.json"
EXPLOIT_MAP="${SCRIPT_DIR}/data/exploitdb_map.json"
MSF_MODULES="${SCRIPT_DIR}/data/msf_modules.json"

# Intelligence cache
INTEL_CACHE_DIR="${SCRIPT_DIR}/data/cache"
mkdir -p "$INTEL_CACHE_DIR"

#==============================================================================
# DATABASE INITIALIZATION
#==============================================================================

initialize_databases() {
    print_info "Initializing intelligence databases..."
    
    # Create minimal CVE database if not exists
    if [[ ! -f "$CVE_DATABASE" ]]; then
        print_warn "CVE database not found, creating minimal version..."
        create_minimal_cve_db
    fi
    
    # Create exploit mapping if not exists
    if [[ ! -f "$EXPLOIT_MAP" ]]; then
        create_minimal_exploit_map
    fi
    
    # Create MSF modules index
    if [[ ! -f "$MSF_MODULES" ]]; then
        create_minimal_msf_index
    fi
}

create_minimal_cve_db() {
    cat > "$CVE_DATABASE" <<'EOF'
{
  "CVE-2021-41773": {
    "description": "Apache HTTP Server 2.4.49 Path Traversal",
    "cvss": 9.8,
    "published": "2021-10-05",
    "affected": ["Apache HTTP Server 2.4.49"],
    "exploitability": "high"
  },
  "CVE-2021-44228": {
    "description": "Log4j Remote Code Execution",
    "cvss": 10.0,
    "published": "2021-12-10",
    "affected": ["Log4j 2.0-beta9 to 2.14.1"],
    "exploitability": "high"
  },
  "CVE-2022-22965": {
    "description": "Spring4Shell Remote Code Execution",
    "cvss": 9.8,
    "published": "2022-04-01",
    "affected": ["Spring Framework 5.3.0 to 5.3.17"],
    "exploitability": "high"
  }
}
EOF
    print_success "Created minimal CVE database"
}

create_minimal_exploit_map() {
    cat > "$EXPLOIT_MAP" <<'EOF'
{
  "CVE-2021-41773": {
    "edb_id": "50383",
    "edb_url": "https://www.exploit-db.com/exploits/50383"
  },
  "CVE-2021-44228": {
    "edb_id": "50592",
    "edb_url": "https://www.exploit-db.com/exploits/50592"
  }
}
EOF
    print_success "Created exploit mapping"
}

create_minimal_msf_index() {
    cat > "$MSF_MODULES" <<'EOF'
{
  "CVE-2021-41773": {
    "module": "exploit/linux/http/apache_normalize_path",
    "rank": "excellent"
  },
  "CVE-2021-44228": {
    "module": "exploit/multi/http/log4shell",
    "rank": "excellent"
  }
}
EOF
    print_success "Created MSF modules index"
}

#==============================================================================
# CVE CORRELATION
#==============================================================================

correlate_cves() {
    local service="$1"
    local version="$2"
    
    if [[ ! -f "$CVE_DATABASE" ]]; then
        initialize_databases
    fi
    
    print_info "Correlating CVEs for: $service $version"
    
    # Search CVE database
    local cves
    cves=$(jq -r --arg svc "$service" --arg ver "$version" '
        to_entries[] | 
        select(.value.affected[] | contains($svc)) |
        {
            cve: .key,
            cvss: .value.cvss,
            description: .value.description,
            exploitability: .value.exploitability
        }
    ' "$CVE_DATABASE" 2>/dev/null || echo "[]")
    
    if [[ "$cves" != "[]" && -n "$cves" ]]; then
        echo "$cves" | jq -s '.'
    else
        echo "[]"
    fi
}

#==============================================================================
# EXPLOIT MAPPING
#==============================================================================

get_exploits() {
    local cve="$1"
    
    if [[ ! -f "$EXPLOIT_MAP" ]] || [[ ! -f "$MSF_MODULES" ]]; then
        initialize_databases
    fi
    
    local exploits=$(cat <<EOF
{
  "cve": "$cve",
  "exploitdb": $(jq -r --arg cve "$cve" '.[$cve] // {}' "$EXPLOIT_MAP" 2>/dev/null || echo "{}"),
  "metasploit": $(jq -r --arg cve "$cve" '.[$cve] // {}' "$MSF_MODULES" 2>/dev/null || echo "{}")
}
EOF
)
    
    echo "$exploits"
}

#==============================================================================
# RISK SCORING
#==============================================================================

calculate_risk_score() {
    local cvss="$1"
    local exploitability="$2"
    local asset_value="${3:-medium}"  # low, medium, high, critical
    
    # Base score from CVSS
    local base_score
    base_score=$(echo "scale=1; $cvss" | bc)
    
    # Exploitability multiplier
    local exploit_mult=1.0
    case "$exploitability" in
        high) exploit_mult=1.3 ;;
        medium) exploit_mult=1.1 ;;
        low) exploit_mult=0.9 ;;
    esac
    
    # Asset value multiplier
    local asset_mult=1.0
    case "$asset_value" in
        critical) asset_mult=1.5 ;;
        high) asset_mult=1.2 ;;
        medium) asset_mult=1.0 ;;
        low) asset_mult=0.8 ;;
    esac
    
    # Calculate final risk score
    local risk_score
    risk_score=$(echo "scale=1; $base_score * $exploit_mult * $asset_mult" | bc)
    
    # Cap at 10.0
    if (( $(echo "$risk_score > 10.0" | bc -l) )); then
        risk_score=10.0
    fi
    
    echo "$risk_score"
}

get_risk_level() {
    local score="$1"
    
    if (( $(echo "$score >= 9.0" | bc -l) )); then
        echo "CRITICAL"
    elif (( $(echo "$score >= 7.0" | bc -l) )); then
        echo "HIGH"
    elif (( $(echo "$score >= 4.0" | bc -l) )); then
        echo "MEDIUM"
    elif (( $(echo "$score >= 0.1" | bc -l) )); then
        echo "LOW"
    else
        echo "INFO"
    fi
}

#==============================================================================
# INTELLIGENCE ENRICHMENT
#==============================================================================

enrich_finding() {
    local service="$1"
    local version="$2"
    local finding_file="$3"
    
    print_info "Enriching finding with intelligence..."
    
    # Correlate CVEs
    local cves
    cves=$(correlate_cves "$service" "$version")
    
    if [[ "$cves" == "[]" || -z "$cves" ]]; then
        print_warn "No CVEs found for $service $version"
        return 1
    fi
    
    # Process each CVE
    echo "$cves" | jq -c '.[]' | while read -r cve_data; do
        local cve=$(echo "$cve_data" | jq -r '.cve')
        local cvss=$(echo "$cve_data" | jq -r '.cvss')
        local desc=$(echo "$cve_data" | jq -r '.description')
        local exploitability=$(echo "$cve_data" | jq -r '.exploitability')
        
        # Get exploits
        local exploits
        exploits=$(get_exploits "$cve")
        
        # Calculate risk
        local risk_score
        risk_score=$(calculate_risk_score "$cvss" "$exploitability" "high")
        local risk_level
        risk_level=$(get_risk_level "$risk_score")
        
        # Build enriched finding
        local enriched=$(cat <<EOF
{
  "cve": "$cve",
  "description": "$desc",
  "cvss_base": $cvss,
  "risk_score": $risk_score,
  "risk_level": "$risk_level",
  "exploitability": "$exploitability",
  "exploits": $exploits,
  "service": "$service",
  "version": "$version"
}
EOF
)
        
        # Save to file
        echo "$enriched" >> "$finding_file"
        
        # Display summary
        print_warn "  → $cve (CVSS: $cvss, Risk: $risk_level)"
        
        local edb_url=$(echo "$exploits" | jq -r '.exploitdb.edb_url // empty')
        [[ -n "$edb_url" ]] && print_info "    ExploitDB: $edb_url"
        
        local msf_module=$(echo "$exploits" | jq -r '.metasploit.module // empty')
        [[ -n "$msf_module" ]] && print_info "    Metasploit: $msf_module"
    done
}

#==============================================================================
# BULK INTELLIGENCE ANALYSIS
#==============================================================================

analyze_scan_results() {
    local scan_dir="$1"
    local output_file="${2:-${scan_dir}/intelligence_report.json}"
    
    print_header "Intelligence Analysis"
    
    local findings_file="$output_file"
    > "$findings_file"  # Clear file
    
    # Parse nmap results for versions
    local nmap_file
    for nmap_file in "$scan_dir"/*_nmap*.nmap; do
        [[ -f "$nmap_file" ]] || continue
        
        # Extract service/version pairs
        grep -E "^[0-9]+/(tcp|udp)" "$nmap_file" | while read -r line; do
            # Example: 80/tcp   open  http    Apache httpd 2.4.49
            local service=$(echo "$line" | awk '{print $4}')
            local version=$(echo "$line" | awk '{for(i=5;i<=NF;i++) printf "%s ", $i; print ""}' | xargs)
            
            if [[ -n "$service" && -n "$version" ]]; then
                enrich_finding "$service" "$version" "$findings_file"
            fi
        done
    done
    
    # Generate summary
    if [[ -f "$findings_file" && -s "$findings_file" ]]; then
        local total=$(jq -s 'length' "$findings_file")
        local critical=$(jq -s '[.[] | select(.risk_level=="CRITICAL")] | length' "$findings_file")
        local high=$(jq -s '[.[] | select(.risk_level=="HIGH")] | length' "$findings_file")
        
        print_success "Intelligence analysis complete"
        echo "  Total CVEs: $total"
        echo "  Critical: $critical"
        echo "  High: $high"
    else
        print_warn "No intelligence findings generated"
    fi
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        init)
            initialize_databases
            ;;
        correlate)
            correlate_cves "$2" "$3"
            ;;
        exploit)
            get_exploits "$2"
            ;;
        analyze)
            analyze_scan_results "$2" "$3"
            ;;
        *)
            cat <<EOF
Usage: $0 <command> [args]

Commands:
    init                          Initialize intelligence databases
    correlate <service> <version> Find CVEs for service/version
    exploit <CVE-ID>              Get exploits for CVE
    analyze <scan_dir> [output]   Analyze scan results

Examples:
    $0 init
    $0 correlate Apache "2.4.49"
    $0 exploit CVE-2021-41773
    $0 analyze ./report intelligence.json
EOF
            ;;
    esac
fi
