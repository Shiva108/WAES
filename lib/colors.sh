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
