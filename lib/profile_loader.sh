#!/usr/bin/env bash
#==============================================================================
# WAES Profile Loader
# Loads and applies scan profiles from YAML configurations
#==============================================================================

set -euo pipefail

# Source color library if available
if [[ -f "${SCRIPT_DIR:-$(dirname "$0")}/colors.sh" ]]; then
    source "${SCRIPT_DIR:-$(dirname "$0")}/colors.sh"
else
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
fi

#==============================================================================
# PROFILE FUNCTIONS
#==============================================================================

# List available profiles
list_profiles() {
    local profile_dir="${1:-./profiles}"
    
    print_info "Available scan profiles:"
    echo ""
    
    if [[ ! -d "$profile_dir" ]]; then
        print_warn "No profiles directory found"
        return 1
    fi
    
    for profile in "$profile_dir"/*.yaml; do
        [[ -f "$profile" ]] || continue
        
        local name desc
        name=$(basename "$profile" .yaml)
        desc=$(grep "^description:" "$profile" 2>/dev/null | cut -d'"' -f2)
        
        printf "  %-15s - %s\n" "$name" "$desc"
    done
}

# Load profile configuration
load_profile() {
    local profile_name="$1"
    local profile_dir="${2:-./profiles}"
    local profile_file="${profile_dir}/${profile_name}.yaml"
    
    if [[ ! -f "$profile_file" ]]; then
        print_error "Profile not found: $profile_name"
        return 1
    fi
    
    print_info "Loading profile: $profile_name"
    
    # Parse YAML (simple parsing, no external dependencies)
    # Extract key values
    export PROFILE_SCAN_TYPE=$(grep "^scan_type:" "$profile_file" | cut -d'"' -f2)
    export PROFILE_AGGRESSIVE=$(grep "^aggressive:" "$profile_file" | awk '{print $2}')
    export PROFILE_TIMEOUT=$(grep "^timeout:" "$profile_file" | awk '{print $2}')
    export PROFILE_THREADS=$(grep "^threads:" "$profile_file" | awk '{print $2}')
    
    # Modules
    export PROFILE_SSL=$(grep -A 10 "^modules:" "$profile_file" | grep "ssl:" | awk '{print $2}')
    export PROFILE_XSS=$(grep -A 10 "^modules:" "$profile_file" | grep "xss:" | awk '{print $2}')
    export PROFILE_CMS=$(grep -A 10 "^modules:" "$profile_file" | grep "cms:" | awk '{print $2}')
    export PROFILE_FUZZING=$(grep -A 10 "^modules:" "$profile_file" | grep "fuzzing:" | awk '{print $2}')
    
    # Output
    export PROFILE_HTML=$(grep -A 5 "^output:" "$profile_file" | grep "html:" | awk '{print $2}')
    export PROFILE_JSON=$(grep -A 5 "^output:" "$profile_file" | grep "json:" | awk '{print $2}')
    export PROFILE_VERBOSE=$(grep -A 5 "^output:" "$profile_file" | grep "verbose:" | awk '{print $2}')
    
    # Nmap settings
    export PROFILE_NMAP_INTENSITY=$(grep -A 5 "^nmap:" "$profile_file" | grep "intensity:" | awk '{print $2}')
    export PROFILE_NMAP_SCRIPTS=$(grep -A 5 "^nmap:" "$profile_file" | grep "scripts:" | cut -d'"' -f2)
    export PROFILE_NMAP_PORTS=$(grep -A 5 "^nmap:" "$profile_file" | grep "port_range:" | cut -d'"' -f2)
    
    print_success "Profile loaded: $profile_name"
}

# Apply profile settings to scan
apply_profile() {
    # Set scan type
    [[ -n "${PROFILE_SCAN_TYPE:-}" ]] && SCAN_TYPE="$PROFILE_SCAN_TYPE"
    
    # Set timeout
    [[ -n "${PROFILE_TIMEOUT:-}" ]] && SCAN_TIMEOUT="$PROFILE_TIMEOUT"
    
    # Set threads
    [[ -n "${PROFILE_THREADS:-}" ]] && GOBUSTER_THREADS="$PROFILE_THREADS"
    
    # Set verbose/quiet
    if [[ "${PROFILE_VERBOSE:-false}" == "true" ]]; then
        VERBOSE=true
        QUIET=false
    elif [[ "${PROFILE_VERBOSE:-false}" == "false" ]]; then
        VERBOSE=false
    fi
    
    # Set output formats
    [[ "${PROFILE_HTML:-false}" == "true" ]] && GENERATE_HTML=true
    [[ "${PROFILE_JSON:-false}" == "true" ]] && GENERATE_JSON=true
    
    print_info "Profile settings applied"
}

# Show profile details
show_profile() {
    local profile_name="$1"
    local profile_dir="${2:-./profiles}"
    local profile_file="${profile_dir}/${profile_name}.yaml"
    
    if [[ ! -f "$profile_file" ]]; then
        print_error "Profile not found: $profile_name"
        return 1
    fi
    
    cat "$profile_file"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        list)
            list_profiles "${2:-.profiles}"
            ;;
        load)
            load_profile "$2" "${3:-./profiles}"
            ;;
        show)
            show_profile "$2" "${3:-./profiles}"
            ;;
        *)
            cat << EOF
Usage: $0 <command> [arguments]

Commands:
    list [profile_dir]              List available profiles
    load <profile> [profile_dir]    Load profile configuration
    show <profile> [profile_dir]    Show profile details

Examples:
    $0 list
    $0 load ctf-box
    $0 show web-app
EOF
            exit 1
            ;;
    esac
fi
