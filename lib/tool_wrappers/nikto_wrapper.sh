#!/usr/bin/env bash
#==============================================================================
# Nikto Wrapper with WAF Evasion
# Applies evasion techniques to Nikto scans when WAF is detected
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/evasion_techniques.sh"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true

run_nikto_with_evasion() {
    local target="$1"
    local port="${2:-80}"
    local protocol="${3:-http}"
    local output_file="$4"
    local evasion_level="${5:-moderate}"
    
    # Check if evasion is enabled
    if [[ "${EVASION_ENABLED:-false}" != "true" ]]; then
        # Standard nikto scan
        nikto -h "${protocol}://${target}:${port}" -C all -ask no \
              -output "$output_file" 2>&1
        return $?
    fi
    
    # Apply evasion techniques
    print_info "Running Nikto with ${evasion_level} evasion"
    
    local user_agent
    user_agent=$(randomize_user_agent)
    
    local evasion_flags
    evasion_flags=$(get_nikto_evasion "$evasion_level")
    
    local delay
    delay=$(calculate_delay "$evasion_level")
    
    # Convert milliseconds to seconds
    local pause_sec
    pause_sec=$(echo "scale=0; $delay/1000" | bc)
    
    print_info "Evasion settings: UA rotated, flags: $evasion_flags, pause: ${pause_sec}s"
    
    # Run nikto with evasion
    nikto -h "${protocol}://${target}:${port}" \
          -useragent "$user_agent" \
          -evasion "$evasion_flags" \
          -Pause "$pause_sec" \
          -C all \
          -ask no \
          -output "$output_file" 2>&1
}

# CLI interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_nikto_with_evasion "$@"
fi
