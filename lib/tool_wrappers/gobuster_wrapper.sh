#!/usr/bin/env bash
#==============================================================================
# Gobuster Wrapper with WAF Evasion
# Applies evasion techniques to Gobuster scans when WAF is detected
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/evasion_techniques.sh"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true

run_gobuster_with_evasion() {
    local url="$1"
    local wordlist="$2"
    local output_file="$3"
    local evasion_level="${4:-moderate}"
    
    # Check if evasion is enabled
    if [[ "${EVASION_ENABLED:-false}" != "true" ]]; then
        # Standard gobuster scan
        gobuster dir -u "$url" -w "$wordlist" \
                 -t "${GOBUSTER_THREADS:-10}" \
                 --wildcard \
                 -o "$output_file" 2>&1
        return $?
    fi
    
    # Apply evasion techniques
    print_info "Running Gobuster with ${evasion_level} evasion"
    
    local user_agent
    user_agent=$(randomize_user_agent)
    
    local delay
    delay=$(calculate_delay "$evasion_level")
    
    # Convert milliseconds to duration format for gobuster
    local delay_sec
    delay_sec=$(echo "scale=0; $delay/1000" | bc)
    
    print_info "Evasion settings: UA rotated, delay: ${delay_sec}s per request"
    
    # Reduced thread count for stealth
    local threads
    case "$evasion_level" in
        low) threads=5 ;;
        moderate) threads=3 ;;
        high) threads=2 ;;
        paranoid) threads=1 ;;
        *) threads=5 ;;
    esac
    
    # Run gobuster with evasion
    gobuster dir \
        -u "$url" \
        -w "$wordlist" \
        --useragent "$user_agent" \
        --delay "${delay_sec}s" \
        -t "$threads" \
        --wildcard \
        --no-error \
        -o "$output_file" 2>&1
}

# CLI interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_gobuster_with_evasion "$@"
fi
