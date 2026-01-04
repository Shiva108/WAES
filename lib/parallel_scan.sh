#!/usr/bin/env bash
#==============================================================================
# WAES Parallel Scan Engine
# Execute independent scans concurrently for improved performance
#==============================================================================

set -euo pipefail

# Source color library if available
if [[ -f "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh" ]]; then
    source "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh"
else
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
fi

#==============================================================================
# PARALLEL EXECUTION FUNCTIONS
#==============================================================================

# Job queue management
declare -a JOB_PIDS=()
declare -a JOB_NAMES=()
MAX_PARALLEL_JOBS=${MAX_PARALLEL_JOBS:-5}

# Add job to queue
add_job() {
    local job_name="$1"
    local job_pid="$2"
    
    JOB_PIDS+=("$job_pid")
    JOB_NAMES+=("$job_name")
}

# Wait for job slot
wait_for_slot() {
    while (( ${#JOB_PIDS[@]} >= MAX_PARALLEL_JOBS )); do
        # Check for completed jobs
        local -a active_pids
        local -a active_names
        
        for i in "${!JOB_PIDS[@]}"; do
            if kill -0 "${JOB_PIDS[$i]}" 2>/dev/null; then
                active_pids+=("${JOB_PIDS[$i]}")
                active_names+=("${JOB_NAMES[$i]}")
            else
                wait "${JOB_PIDS[$i]}" 2>/dev/null || true
                print_success "Completed: ${JOB_NAMES[$i]}"
            fi
        done
        
        JOB_PIDS=("${active_pids[@]}")
        JOB_NAMES=("${active_names[@]}")
        
        [[ ${#JOB_PIDS[@]} -ge $MAX_PARALLEL_JOBS ]] && sleep 1
    done
}

# Wait for all jobs to complete
wait_all_jobs() {
    print_info "Waiting for ${#JOB_PIDS[@]} remaining jobs to complete..."
    
    for i in "${!JOB_PIDS[@]}"; do
        wait "${JOB_PIDS[$i]}" 2>/dev/null || true
        print_success "Completed: ${JOB_NAMES[$i]}"
    done
    
    JOB_PIDS=()
    JOB_NAMES=()
}

#==============================================================================
# PARALLEL SCANNING FUNCTIONS
#==============================================================================

# Run scan stage in background
run_parallel_scan() {
    local scan_name="$1"
    local scan_function="$2"
    shift 2
    local scan_args=("$@")
    
    print_info "Starting parallel: $scan_name"
    
    # Execute function in background
    (
        "$scan_function" "${scan_args[@]}"
    ) &
    
    local pid=$!
    add_job "$scan_name" "$pid"
    
    # Manage queue
    wait_for_slot
}

# Parallel nmap scan
parallel_nmap() {
    local target="$1"
    local port_range="$2"
    local output_file="$3"
    
    if command -v nmap &>/dev/null; then
        nmap -sS -sV -Pn $

-T4 -p "$port_range" "$target" -oA "$output_file" 2>&1
    fi
}

# Parallel nikto scan
parallel_nikto() {
    local target_url="$1"
    local output_file="$2"
    
    if command -v nikto &>/dev/null; then
        nikto -h "$target_url" -o "$output_file" 2>&1
    fi
}

# Parallel SSL scan
parallel_ssl() {
    local target="$1"
    local port="$2"
    local report_dir="$3"
    
    if declare -f scan_ssl &>/dev/null; then
        scan_ssl "$target" "$port" "$report_dir" 2>&1
    fi
}

# Parallel CMS scan
parallel_cms() {
    local target_url="$1"
    local report_dir="$2"
    
    if declare -f scan_cms &>/dev/null; then
        scan_cms "$target_url" "$report_dir" 2>&1
    fi
}

# Parallel XSS scan
parallel_xss() {
    local target_url="$1"
    local report_dir="$2"
    
    if declare -f scan_xss &>/dev/null; then
        scan_xss "$target_url" "$report_dir" 2>&1
    fi
}

# Main parallel execution coordinator
execute_parallel_scans() {
    local target="$1"
    local protocol="$2"
    local port="$3"
    local report_dir="$4"
    local scan_type="$5"
    
    local base_url="${protocol}://${target}:${port}"
    
    print_info "Executing scans in parallel (max: $MAX_PARALLEL_JOBS concurrent)"
    echo ""
    
    # Launch independent scans in parallel
    
    # Port scan (always)
    run_parallel_scan "nmap_scan" parallel_nmap "$target" "80,443,8000-8888" "${report_dir}/${target}_nmap"
    
    # Web scans
    if [[ "$scan_type" != "fast" ]]; then
        run_parallel_scan "nikto_scan" parallel_nikto "$base_url" "${report_dir}/${target}_nikto.txt"
    fi
    
    # Advanced scans
    if [[ "$scan_type" == "advanced" ]]; then
        if [[ "$protocol" == "https" ]] || [[ "$port" == "443" ]]; then
            run_parallel_scan "ssl_scan" parallel_ssl "$target" "$port" "$report_dir"
        fi
        
        run_parallel_scan "cms_scan" parallel_cms "$base_url" "$report_dir"
        run_parallel_scan "xss_scan" parallel_xss "$base_url" "$report_dir"
    fi
    
    # Wait for all scans to complete
    wait_all_jobs
    
    echo ""
    print_success "All parallel scans completed!"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 4 ]]; then
        cat << EOF
Usage: $0 <target> <protocol> <port> <report_dir> [scan_type] [max_jobs]

Arguments:
    target      Target domain or IP
    protocol    http or https
    port        Port number
    report_dir  Output directory
    scan_type   fast, full, deep, advanced (default: full)
    max_jobs    Max concurrent jobs (default: 5)

Examples:
    $0 example.com https 443 ./report advanced
    $0 10.10.10.130 http 80 ./report full 10
EOF
        exit 1
    fi
    
    MAX_PARALLEL_JOBS="${6:-5}"
    execute_parallel_scans "$1" "$2" "$3" "$4" "${5:-full}"
fi
