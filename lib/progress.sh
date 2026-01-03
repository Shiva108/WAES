#!/usr/bin/env bash
# WAES Progress Library
# Progress bar implementation for multi-step operations

# Progress state
declare -g PROGRESS_TOTAL=0
declare -g PROGRESS_CURRENT=0
declare -g PROGRESS_START_TIME=0
declare -g PROGRESS_WIDTH=40

# Initialize progress bar
progress_init() {
    local total="$1"
    local width="${2:-40}"
    
    PROGRESS_TOTAL="$total"
    PROGRESS_CURRENT=0
    PROGRESS_WIDTH="$width"
    PROGRESS_START_TIME=$(date +%s)
    
    # Hide cursor
    printf '\033[?25l'
    
    # Trap to restore cursor on exit
    trap 'printf "\033[?25h"' EXIT
}

# Update progress bar
progress_update() {
    local current="$1"
    local message="${2:-}"
    
    PROGRESS_CURRENT="$current"
    
    local percent=0
    local filled=0
    local empty=0
    
    if [[ $PROGRESS_TOTAL -gt 0 ]]; then
        percent=$(( (current * 100) / PROGRESS_TOTAL ))
        filled=$(( (current * PROGRESS_WIDTH) / PROGRESS_TOTAL ))
        empty=$(( PROGRESS_WIDTH - filled ))
    fi
    
    # Calculate ETA
    local elapsed eta_str=""
    elapsed=$(( $(date +%s) - PROGRESS_START_TIME ))
    if [[ $current -gt 0 ]] && [[ $elapsed -gt 0 ]]; then
        local eta=$(( (elapsed * (PROGRESS_TOTAL - current)) / current ))
        if [[ $eta -gt 60 ]]; then
            eta_str="ETA: $(( eta / 60 ))m$(( eta % 60 ))s"
        else
            eta_str="ETA: ${eta}s"
        fi
    fi
    
    # Build progress bar
    local bar=""
    if [[ $filled -gt 0 ]]; then
        bar=$(printf '█%.0s' $(seq 1 "$filled"))
    fi
    if [[ $empty -gt 0 ]]; then
        bar+=$(printf '░%.0s' $(seq 1 "$empty"))
    fi
    
    # Print progress bar (overwrite previous line)
    printf '\r\033[K[%s] %3d%% (%d/%d) %s %s' \
        "$bar" "$percent" "$current" "$PROGRESS_TOTAL" "$eta_str" "$message"
}

# Increment progress
progress_increment() {
    local message="${1:-}"
    PROGRESS_CURRENT=$(( PROGRESS_CURRENT + 1 ))
    progress_update "$PROGRESS_CURRENT" "$message"
}

# Complete progress bar
progress_complete() {
    local message="${1:-Complete}"
    progress_update "$PROGRESS_TOTAL" "$message"
    echo ""
    
    # Show total time
    local elapsed=$(( $(date +%s) - PROGRESS_START_TIME ))
    if [[ $elapsed -gt 60 ]]; then
        echo "Completed in $(( elapsed / 60 ))m$(( elapsed % 60 ))s"
    else
        echo "Completed in ${elapsed}s"
    fi
    
    # Restore cursor
    printf '\033[?25h'
}

# Print step with spinner
print_step_start() {
    local step_num="$1"
    local step_name="$2"
    printf '\n\033[1mStep %d:\033[0m %s ...' "$step_num" "$step_name"
}

print_step_done() {
    printf ' \033[32m✓\033[0m\n'
}

print_step_fail() {
    printf ' \033[31m✗\033[0m\n'
}

# Simple spinner for long-running operations
# Usage: long_command & spinner $!
spinner() {
    local pid="$1"
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    
    while kill -0 "$pid" 2>/dev/null; do
        for (( i=0; i<${#spinstr}; i++ )); do
            printf '\r%s' "${spinstr:$i:1}"
            sleep $delay
        done
    done
    printf '\r  \r'
}
