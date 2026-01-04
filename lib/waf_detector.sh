#!/usr/bin/env bash
#==============================================================================
# WAES - WAF Detection Module
# Detects Web Application Firewalls using wafw00f and maps to evasion profiles
#==============================================================================

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || {
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
}

#==============================================================================
# WAF DETECTION
#==============================================================================

detect_waf() {
    local target="$1"
    local port="${2:-80}"
    local protocol="${3:-http}"
    local output_file="${4:-/tmp/wafw00f_result.txt}"
    
    print_info "Running WAF detection on ${protocol}://${target}:${port}"
    
    # Check if wafw00f is installed
    if ! command -v wafw00f &>/dev/null; then
        print_warn "wafw00f not installed, skipping WAF detection"
        return 1
    fi
    
    # Run wafw00f with output capture
    local url="${protocol}://${target}:${port}"
    
    if wafw00f "$url" -o "$output_file" 2>/dev/null; then
        print_success "WAF detection completed"
        return 0
    else
        print_warn "WAF detection failed or no WAF detected"
        return 1
    fi
}

#==============================================================================
# RESULT PARSING
#==============================================================================

parse_waf_result() {
    local result_file="$1"
    
    if [[ ! -f "$result_file" ]]; then
        echo "none"
        return 1
    fi
    
    # Extract WAF name from wafw00f output
    # Format: "The site <url> is behind <WAF_NAME> WAF"
    local waf_name
    waf_name=$(grep -E "is behind|protected by" "$result_file" | \
               sed -E 's/.*is behind ([^(]+).*/\1/' | \
               sed -E 's/.*protected by ([^(]+).*/\1/' | \
               head -1 | \
               xargs)
    
    if [[ -n "$waf_name" ]] && [[ "$waf_name" != "generic"* ]]; then
        echo "$waf_name"
        return 0
    else
        echo "none"
        return 1
    fi
}

get_waf_confidence() {
    local result_file="$1"
    
    if [[ ! -f "$result_file" ]]; then
        echo "0"
        return
    fi
    
    # Check if wafw00f found definitive match
    if grep -q "is behind" "$result_file"; then
        echo "95"  # High confidence
    elif grep -q "might be" "$result_file"; then
        echo "60"  # Medium confidence
    else
        echo "30"  # Low confidence
    fi
}

#==============================================================================
# PROFILE MAPPING
#==============================================================================

get_evasion_profile() {
    local waf_name="$1"
    local profiles_dir="${SCRIPT_DIR}/lib/waf_profiles"
    
    # Normalize WAF name to lowercase and remove spaces
    local normalized
    normalized=$(echo "$waf_name" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
    
    # Map known WAF names to profile files
    case "$normalized" in
        *cloudflare*)
            echo "${profiles_dir}/cloudflare.yml"
            ;;
        *akamai*)
            echo "${profiles_dir}/akamai.yml"
            ;;
        *aws*|*awswaf*)
            echo "${profiles_dir}/aws_waf.yml"
            ;;
        *modsecurity*|*mod_security*)
            echo "${profiles_dir}/modsecurity.yml"
            ;;
        *imperva*|*incapsula*)
            echo "${profiles_dir}/imperva.yml"
            ;;
        *f5*|*bigip*)
            echo "${profiles_dir}/f5.yml"
            ;;
        *barracuda*)
            echo "${profiles_dir}/barracuda.yml"
            ;;
        *fortiweb*)
            echo "${profiles_dir}/fortiweb.yml"
            ;;
        *)
            echo "${profiles_dir}/generic.yml"
            ;;
    esac
}

#==============================================================================
# DETECTION SUMMARY
#==============================================================================

generate_waf_summary() {
    local target="$1"
    local result_file="$2"
    local output_file="${3:-/tmp/waf_summary.txt}"
    
    local waf_name
    local confidence
    local profile
    
    waf_name=$(parse_waf_result "$result_file")
    confidence=$(get_waf_confidence "$result_file")
    profile=$(get_evasion_profile "$waf_name")
    
    {
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "         WAF Detection Summary"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Target:     $target"
        echo "WAF:        $waf_name"
        echo "Confidence: ${confidence}%"
        echo "Profile:    $(basename "$profile" .yml)"
        echo ""
        
        if [[ "$waf_name" != "none" ]]; then
            echo "Status:     WAF DETECTED - Evasion techniques will be applied"
        else
            echo "Status:     No WAF detected - Standard scanning"
        fi
        
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    } | tee "$output_file"
}

#==============================================================================
# COMMAND LINE INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Direct execution for testing
    target="${1:-example.com}"
    port="${2:-80}"
    protocol="${3:-http}"
    
    result_file="/tmp/wafw00f_${target}_${port}.txt"
    
    detect_waf "$target" "$port" "$protocol" "$result_file"
    generate_waf_summary "$target" "$result_file"
    
    echo ""
    echo "WAF Name: $(parse_waf_result "$result_file")"
    echo "Profile:  $(get_evasion_profile "$(parse_waf_result "$result_file")")"
fi
