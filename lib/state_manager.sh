#!/usr/bin/env bash
#==============================================================================
# WAES Scan State Manager
# Handles scan state persistence, resumption, and progress tracking
#==============================================================================

# Source color library if available
if [[ -f "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh" ]]; then
    # shellcheck source=lib/colors.sh
    source "${SCRIPT_DIR:-$(dirname "$0")}/lib/colors.sh"
else
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
fi

#==============================================================================
# STATE FILE MANAGEMENT
#==============================================================================

# State file location
get_state_file() {
    local target="$1"
    local report_dir="${2:-.}"
    echo "${report_dir}/.waes_state_${target}.json"
}

# Initialize scan state
init_scan_state() {
    local target="$1"
    local scan_type="$2"
    local report_dir="${3:-.}"
    
    local state_file
    state_file=$(get_state_file "$target" "$report_dir")
    
    cat > "$state_file" << EOF
{
  "target": "$target",
  "scan_type": "$scan_type",
  "start_time": "$(date '+%Y-%m-%d %H:%M:%S')",
  "last_update": "$(date '+%Y-%m-%d %H:%M:%S')",
  "status": "running",
  "completed_stages": [],
  "current_stage": "",
  "total_stages": 0,
  "errors": []
}
EOF
    
    print_info "Initialized scan state: $state_file"
}

# Update scan state
update_scan_state() {
    local target="$1"
    local report_dir="$2"
    local field="$3"
    local value="$4"
    
    local state_file
    state_file=$(get_state_file "$target" "$report_dir")
    
    if [[ ! -f "$state_file" ]]; then
        print_error "State file not found: $state_file"
        return 1
    fi
    
    # Update last_update timestamp
    local temp_file="${state_file}.tmp"
    
    if command -v jq &>/dev/null; then
        jq --arg field "$field" --arg value "$value" \
            '. + {($field): $value, "last_update": "'$(date '+%Y-%m-%d %H:%M:%S')'"}' \
            "$state_file" > "$temp_file" && mv "$temp_file" "$state_file"
    else
        # Fallback without jq
        sed -i "s/\"$field\": \"[^\"]*\"/\"$field\": \"$value\"/" "$state_file"
        sed -i "s/\"last_update\": \"[^\"]*\"/\"last_update\": \"$(date '+%Y-%m-%d %H:%M:%S')\"/" "$state_file"
    fi
}

# Mark stage as completed
mark_stage_completed() {
    local target="$1"
    local report_dir="$2"
    local stage_name="$3"
    
    local state_file
    state_file=$(get_state_file "$target" "$report_dir")
    
    if command -v jq &>/dev/null; then
        local temp_file="${state_file}.tmp"
        jq --arg stage "$stage_name" \
            '.completed_stages += [$stage] | .last_update = "'$(date '+%Y-%m-%d %H:%M:%S')'"' \
            "$state_file" > "$temp_file" && mv "$temp_file" "$state_file"
    fi
    
    print_success "Stage completed: $stage_name"
}

# Add error to state
add_error() {
    local target="$1"
    local report_dir="$2"
    local error_msg="$3"
    
    local state_file
    state_file=$(get_state_file "$target" "$report_dir")
    
    if command -v jq &>/dev/null; then
        local temp_file="${state_file}.tmp"
        jq --arg error "$error_msg" \
            '.errors += [$error] | .last_update = "'$(date '+%Y-%m-%d %H:%M:%S')'"' \
            "$state_file" > "$temp_file" && mv "$temp_file" "$state_file"
    fi
    
    print_error "Error recorded: $error_msg"
}

# Check if stage is completed
is_stage_completed() {
    local target="$1"
    local report_dir="$2"
    local stage_name="$3"
    
    local state_file
    state_file=$(get_state_file "$target" "$report_dir")
    
    if [[ ! -f "$state_file" ]]; then
        return 1
    fi
    
    if command -v jq &>/dev/null; then
        jq -e --arg stage "$stage_name" \
            '.completed_stages | index($stage)' "$state_file" &>/dev/null
        return $?
    else
        grep -q "\"$stage_name\"" "$state_file"
        return $?
    fi
}

# Get scan progress
get_scan_progress() {
    local target="$1"
    local report_dir="${2:-.}"
    
    local state_file
    state_file=$(get_state_file "$target" "$report_dir")
    
    if [[ ! -f "$state_file" ]]; then
        print_error "No scan state found for: $target"
        return 1
    fi
    
    print_info "Scan State for: $target"
    echo ""
    
    if command -v jq &>/dev/null; then
        local status start_time current_stage completed
        status=$(jq -r '.status' "$state_file")
        start_time=$(jq -r '.start_time' "$state_file")
        current_stage=$(jq -r '.current_stage' "$state_file")
        completed=$(jq -r '.completed_stages | length' "$state_file")
        
        echo "Status: $status"
        echo "Started: $start_time"
        echo "Current Stage: $current_stage"
        echo "Completed Stages: $completed"
        echo ""
        echo "Completed:"
        jq -r '.completed_stages[]' "$state_file" | while read -r stage; do
            echo "  ✓ $stage"
        done
        
        local errors
        errors=$(jq -r '.errors | length' "$state_file")
        if [[ "$errors" -gt 0 ]]; then
            echo ""
            echo "Errors:"
            jq -r '.errors[]' "$state_file" | while read -r error; do
                echo "  ✗ $error"
            done
        fi
    else
        cat "$state_file"
    fi
}

# Complete scan
complete_scan() {
    local target="$1"
    local report_dir="$2"
    
    update_scan_state "$target" "$report_dir" "status" "completed"
    update_scan_state "$target" "$report_dir" "end_time" "$(date '+%Y-%m-%d %H:%M:%S')"
    
    print_success "Scan completed for: $target"
}

# List all scans
list_scans() {
    local report_dir="${1:-.}"
    
    print_info "Available scan states in: $report_dir"
    echo ""
    
    local found=0
    for state_file in "${report_dir}"/.waes_state_*.json; do
        [[ -f "$state_file" ]] || continue
        
        found=1
        local basename
        basename=$(basename "$state_file")
        local target="${basename#.waes_state_}"
        target="${target%.json}"
        
        if command -v jq &>/dev/null; then
            local status start_time
            status=$(jq -r '.status' "$state_file" 2>/dev/null || echo "unknown")
            start_time=$(jq -r '.start_time' "$state_file" 2>/dev/null || echo "unknown")
            
            printf "%-30s  Status: %-10s  Started: %s\n" "$target" "$status" "$start_time"
        else
            echo "$target"
        fi
    done
    
    if [[ $found -eq 0 ]]; then
        echo "No scan states found"
    fi
}

# Resume scan
resume_scan() {
    local target="$1"
    local report_dir="${2:-.}"
    
    local state_file
    state_file=$(get_state_file "$target" "$report_dir")
    
    if [[ ! -f "$state_file" ]]; then
        print_error "No saved state found for: $target"
        return 1
    fi
    
    print_info "Resuming scan for: $target"
    get_scan_progress "$target" "$report_dir"
    
    # Return completed stages as a list
    if command -v jq &>/dev/null; then
        jq -r '.completed_stages[]' "$state_file"
    fi
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

# If script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        init)
            init_scan_state "$2" "${3:-full}" "${4:-.}"
            ;;
        update)
            update_scan_state "$2" "${3:-.}" "$4" "$5"
            ;;
        complete)
            mark_stage_completed "$2" "${3:-.}" "$4"
            ;;
        status)
            get_scan_progress "$2" "${3:-.}"
            ;;
        list)
            list_scans "${2:-.}"
            ;;
        resume)
            resume_scan "$2" "${3:-.}"
            ;;
        *)
            cat << EOF
Usage: $0 <command> [arguments]

Commands:
    init <target> [scan_type] [report_dir]     Initialize scan state
    update <target> [report_dir] <field> <val> Update state field
    complete <target> [report_dir] <stage>      Mark stage complete
    status <target> [report_dir]                Show scan status
    list [report_dir]                           List all scans
    resume <target> [report_dir]                Resume scan

Examples:
    $0 init example.com deep ./reports
    $0 complete example.com ./reports "fast_scan"
    $0 status example.com ./reports
    $0 list ./reports
EOF
            exit 1
            ;;
    esac
fi
