#!/usr/bin/env bash
#==============================================================================
# WAES Continuous Monitoring Script
# Schedule and watch targets for changes
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
# MONITORING FUNCTIONS
#==============================================================================

# Baseline scan
create_baseline() {
    local target="$1"
    local scan_type="${2:-fast}"
    local baseline_dir="${3:-./baselines}"
    
    print_info "Creating baseline for: $target"
    
    mkdir -p "$baseline_dir"
    
    # Run initial scan
    if [[ -x "./waes.sh" ]]; then
        sudo ./waes.sh -u "$target" -t "$scan_type" -J 2>&1 | \
            tee "${baseline_dir}/${target}_baseline.log"
        
        # Copy JSON result as baseline
        if [[ -f "report/${target}_report.json" ]]; then
            cp "report/${target}_report.json" "${baseline_dir}/${target}_baseline.json"
            print_success "Baseline created: ${baseline_dir}/${target}_baseline.json"
        fi
    fi
}

# Compare scan results
compare_scans() {
    local target="$1"
    local baseline_file="$2"
    local current_file="$3"
    local diff_file="${4:-./diff_${target}.txt}"
    
    if [[ ! -f "$baseline_file" ]] || [[ ! -f "$current_file" ]]; then
        print_error "Baseline or current file not found"
        return 1
    fi
    
    print_info "Comparing scans for: $target"
    
    {
        echo "=== Scan Comparison ===" 
        echo "Target: $target"
        echo "Baseline: $baseline_file"
        echo "Current: $current_file"
        echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        
        # Use diff or jq for JSON comparison
        if command -v jq &>/dev/null; then
            echo "--- Changes Detected ---"
            diff <(jq -S . "$baseline_file") <(jq -S . "$current_file") || true
        else
            diff "$baseline_file" "$current_file" || true
        fi
    } | tee "$diff_file"
    
    # Check if there are changes
    if diff -q "$baseline_file" "$current_file" &>/dev/null; then
        print_info "No changes detected"
        return 0
    else
        print_warn "Changes detected! See: $diff_file"
        return 1
    fi
}

# Watch target for changes
watch_target() {
    local target="$1"
    local interval="${2:-3600}"  # Default: 1 hour
    local scan_type="${3:-fast}"
    local baseline_dir="./baselines"
    local monitor_dir="./monitoring"
    
    mkdir -p "$baseline_dir" "$monitor_dir"
    
    print_info "Starting continuous monitoring: $target"
    print_info "Interval: $interval seconds"
    print_info "Scan type: $scan_type"
    
    # Create initial baseline if needed
    if [[ ! -f "${baseline_dir}/${target}_baseline.json" ]]; then
        create_baseline "$target" "$scan_type" "$baseline_dir"
    fi
    
    # Monitoring loop
    local scan_count=0
    while true; do
        ((scan_count++))
        
        print_info "Scan #$scan_count - $(date '+%Y-%m-%d %H:%M:%S')"
        
        # Run scan
        if [[ -x "./waes.sh" ]]; then
            sudo ./waes.sh -u "$target" -t "$scan_type" -J -q 2>&1 | \
                tee "${monitor_dir}/${target}_scan_${scan_count}.log" >/dev/null
            
            # Compare with baseline
            if [[ -f "report/${target}_report.json" ]]; then
                local current_scan="report/${target}_report.json"
                local baseline_scan="${baseline_dir}/${target}_baseline.json"
                local diff_file="${monitor_dir}/${target}_diff_${scan_count}.txt"
                
                if ! compare_scans "$target" "$baseline_scan" "$current_scan" "$diff_file"; then
                    print_warn "⚠️  CHANGES DETECTED in scan #$scan_count"
                    
                    # Trigger alert (if configured)
                    if [[ -f "./hooks/on_change.sh" ]]; then
                        ./hooks/on_change.sh "$target" "$diff_file"
                    fi
                fi
            fi
        fi
        
        print_info "Next scan in $interval seconds..."
        sleep "$interval"
    done
}

# Schedule scans via cron
schedule_scan() {
    local target="$1"
    local cron_expr="$2"  # e.g., "0 2 * * *" for daily at 2am
    local scan_type="${3:-fast}"
    
    local script_path
    script_path=$(realpath "$0")
    local waes_dir
    waes_dir=$(dirname "$script_path")
    
    local cron_job="$cron_expr cd $waes_dir && sudo ./waes.sh -u $target -t $scan_type -J >> monitoring/${target}_cron.log 2>&1"
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    
    print_success "Scheduled scan added to crontab"
    print_info "Expression: $cron_expr"
    print_info "Target: $target"
    print_info "Type: $scan_type"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        baseline)
            create_baseline "${2:-}" "${3:-fast}" "${4:-./baselines}"
            ;;
        watch)
            watch_target "${2:-}" "${3:-3600}" "${4:-fast}"
            ;;
        compare)
            compare_scans "${2:-}" "${3:-}" "${4:-}" "${5:-}"
            ;;
        schedule)
            schedule_scan "${2:-}" "${3:-0 2 * * *}" "${4:-fast}"
            ;;
        *)
            cat << EOF
Usage: $0 <command> [arguments]

Commands:
    baseline <target> [scan_type] [baseline_dir]
        Create initial baseline scan
        
    watch <target> [interval] [scan_type]
        Continuously monitor target for changes
        interval: seconds between scans (default: 3600)
        
    compare <target> <baseline_file> <current_file> [diff_file]
        Compare two scan results
        
    schedule <target> <cron_expr> [scan_type]
        Schedule recurring scans via cron
        cron_expr: "0 2 * * *" for daily at 2am

Examples:
    $0 baseline example.com fast
    $0 watch example.com 3600 fast
    $0 schedule example.com "0 2 * * *" deep
    $0 compare example.com baseline.json current.json
EOF
            exit 1
            ;;
    esac
fi
