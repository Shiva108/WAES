#!/usr/bin/env bash
# WAES Color Library
# Provides consistent color output and formatting functions

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[0;37m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

# Status icons
readonly ICON_SUCCESS="[+]"
readonly ICON_ERROR="[!]"
readonly ICON_INFO="[*]"
readonly ICON_WARN="[~]"
readonly ICON_RUNNING="[>]"

# Enable/disable colors (set WAES_NO_COLOR=1 to disable)
use_colors() {
    [[ -z "${WAES_NO_COLOR:-}" ]] && [[ -t 1 ]]
}

# Output functions
print_success() {
    if use_colors; then
        echo -e "${GREEN}${ICON_SUCCESS}${RESET} $*"
    else
        echo "${ICON_SUCCESS} $*"
    fi
}

print_error() {
    if use_colors; then
        echo -e "${RED}${ICON_ERROR}${RESET} $*" >&2
    else
        echo "${ICON_ERROR} $*" >&2
    fi
}

print_info() {
    if use_colors; then
        echo -e "${BLUE}${ICON_INFO}${RESET} $*"
    else
        echo "${ICON_INFO} $*"
    fi
}

print_warn() {
    if use_colors; then
        echo -e "${YELLOW}${ICON_WARN}${RESET} $*"
    else
        echo "${ICON_WARN} $*"
    fi
}

print_running() {
    if use_colors; then
        echo -e "${CYAN}${ICON_RUNNING}${RESET} $*"
    else
        echo "${ICON_RUNNING} $*"
    fi
}

print_header() {
    local text="$1"
    local width=${2:-60}
    local line
    line=$(printf '%*s' "$width" '' | tr ' ' '#')
    
    if use_colors; then
        echo -e "${GREEN}${line}${RESET}"
        echo -e "${GREEN}#${RESET} ${BOLD}${text}${RESET}"
        echo -e "${GREEN}${line}${RESET}"
    else
        echo "$line"
        echo "# $text"
        echo "$line"
    fi
}

print_step() {
    local step_num="$1"
    local step_text="$2"
    
    if use_colors; then
        echo -e "\n${BOLD}Step ${step_num}:${RESET} ${step_text}"
    else
        echo ""
        echo "Step ${step_num}: ${step_text}"
    fi
}

# Print a separator line
print_separator() {
    local width=${1:-60}
    local char=${2:--}
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

#==============================================================================
# PROGRESS BAR FUNCTIONS
#==============================================================================

# Progress tracking variables
PROGRESS_TOTAL=100
PROGRESS_CURRENT=0
PROGRESS_BAR_WIDTH=50

# Initialize progress tracking
init_progress() {
    PROGRESS_TOTAL="${1:-100}"
    PROGRESS_CURRENT=0
    PROGRESS_BAR_WIDTH=50
}

# Update and display progress bar
show_progress() {
    local current="$1"
    local total="$2"
    local message="${3:-Processing}"
    
    # Skip if not a terminal or QUIET mode
    [[ ! -t 1 ]] || [[ "${QUIET:-false}" == "true" ]] && return
    
    # Calculate percentage
    local percent=$((current * 100 / total))
    local filled=$((current * PROGRESS_BAR_WIDTH / total))
    local empty=$((PROGRESS_BAR_WIDTH - filled))
    
    # Build progress bar
    local bar="["
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    bar+="]"
    
    # Truncate message if too long
    local display_msg
    display_msg=$(printf '%-30s' "${message:0:30}")
    
    # Print progress (overwrite previous line)
    if use_colors; then
        printf "\r${BLUE}%s${RESET} ${GREEN}%3d%%${RESET} ${YELLOW}%s${RESET}" "$bar" "$percent" "$display_msg"
    else
        printf "\r%s %3d%% %s" "$bar" "$percent" "$display_msg"
    fi
}

# Complete progress bar
complete_progress() {
    local message="${1:-Complete}"
    show_progress "$PROGRESS_TOTAL" "$PROGRESS_TOTAL" "$message"
    echo "" # New line after completion
}

# Update progress with step name
update_progress() {
    local step_name="$1"
    ((PROGRESS_CURRENT++))
    show_progress "$PROGRESS_CURRENT" "$PROGRESS_TOTAL" "$step_name"
}
