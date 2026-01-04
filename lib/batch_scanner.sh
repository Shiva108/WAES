#!/usr/bin/env bash
#==============================================================================
# WAES Batch Scanner
# Scan multiple targets from a file or CIDR range
#==============================================================================

set -euo pipefail

# Source color library if available
if [[ -f "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh" ]]; then
    source "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh"
else
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
fi

#==============================================================================
# BATCH SCANNING FUNCTIONS
#==============================================================================

# Parse target file
parse_targets() {
    local target_file="$1"
    
    if [[ ! -f "$target_file" ]]; then
        print_error "Target file not found: $target_file"
        return 1
    fi
    
    # Read targets, skip comments and empty lines
    grep -v "^#" "$target_file" | grep -v "^$" | while read -r target; do
        # Trim whitespace
        target=$(echo "$target" | xargs)
        echo "$target"
    done
}

# Expand CIDR notation to individual IPs
expand_cidr() {
    local cidr="$1"
    
    if command -v nmap &>/dev/null; then
        # Use nmap to list IPs
        nmap -sL -n "$cidr" 2>/dev/null | grep "Nmap scan report" | awk '{print $NF}' | tr -d '()'
    else
        print_error "nmap required for CIDR expansion"
        return 1
    fi
}

# Check if target is CIDR
is_cidr() {
    local target="$1"
    [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]
}

# Scan single target with progress
scan_target_batch() {
    local target="$1"
    local scan_type="$2"
    local report_dir="$3"
    local scan_flags="$4"
    local target_num="$5"
    local total_targets="$6"
    
    print_info "[$target_num/$total_targets] Scanning: $target"
    
    # Create target-specific report directory
    local target_report_dir="${report_dir}/${target//:/_}"
    mkdir -p "$target_report_dir"
    
    # Run scan (call main waes.sh)
    if [[ -x "./waes.sh" ]]; then
        ./waes.sh -u "$target" -t "$scan_type" $scan_flags 2>&1 | \
            sed "s/^/[$target] /" | \
            tee "${target_report_dir}/scan.log"
    else
        print_error "waes.sh not found or not executable"
        return 1
    fi
    
    print_success "[$target_num/$total_targets] Completed: $target"
}

# Main batch scanning function
batch_scan() {
    local target_file="$1"
    local scan_type="${2:-full}"
    local report_dir="${3:-./report/batch}"
    local parallel="${4:-false}"
    local scan_flags="${5:-}"
    
    print_info "Starting batch scan from: $target_file"
    print_info "Scan type: $scan_type"
    print_info "Report directory: $report_dir"
    echo ""
    
    # Create batch report directory
    mkdir -p "$report_dir"
    
    # Parse targets
    local -a targets
    mapfile -t targets < <(parse_targets "$target_file")
    
    # Expand CIDR if needed
    local -a expanded_targets
    for target in "${targets[@]}"; do
        if is_cidr "$target"; then
            print_info "Expanding CIDR: $target"
            mapfile -t -O "${#expanded_targets[@]}" expanded_targets < <(expand_cidr "$target")
        else
            expanded_targets+=("$target")
        fi
    done
    
    local total=${#expanded_targets[@]}
    print_success "Total targets: $total"
    echo ""
    
    # Scan targets
    local count=0
    local -a pids
    
    for target in "${expanded_targets[@]}"; do
        ((count++))
        
        if [[ "$parallel" == "true" ]]; then
            # Parallel execution
            scan_target_batch "$target" "$scan_type" "$report_dir" "$scan_flags" "$count" "$total" &
            pids+=($!)
            
            # Limit concurrent scans
            if (( ${#pids[@]} >= 5 )); then
                wait "${pids[0]}"
                pids=("${pids[@]:1}")
            fi
        else
            # Sequential execution
            scan_target_batch "$target" "$scan_type" "$report_dir" "$scan_flags" "$count" "$total"
        fi
    done
    
    # Wait for remaining jobs
    if [[ "$parallel" == "true" ]] && (( ${#pids[@]} > 0 )); then
        print_info "Waiting for remaining scans to complete..."
        wait "${pids[@]}"
    fi
    
    # Generate summary
    echo ""
    print_success "Batch scan complete!"
    print_info "Results saved to: $report_dir"
    
    # Summary report
    {
        echo "# Batch Scan Summary"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Total targets: $total"
        echo ""
        echo "## Targets Scanned"
        for target in "${expanded_targets[@]}"; do
            echo "- $target"
        done
    } > "${report_dir}/summary.md"
    
    print_success "Summary: ${report_dir}/summary.md"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat << EOF
Usage: $0 <targets_file> [scan_type] [report_dir] [parallel] [flags]

Arguments:
    targets_file    File with targets (one per line) or CIDR notation
    scan_type       fast, full, deep, advanced (default: full)
    report_dir      Output directory (default: ./report/batch)
    parallel        true/false for parallel execution (default: false)
    flags           Additional flags to pass to waes.sh

Target File Format:
    # Comment lines start with #
    example.com
    192.168.1.100
    10.10.10.0/24    # CIDR notation

Examples:
    $0 targets.txt
    $0 targets.txt deep ./results
    $0 targets.txt advanced ./results true "-H"
EOF
        exit 1
    fi
    
    batch_scan "$@"
fi
