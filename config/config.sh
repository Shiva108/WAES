#!/usr/bin/env bash
# WAES Configuration File
# Customize these settings for your environment

# Version
readonly WAES_VERSION="1.0.0"

# Script directory (auto-detected)
# Script directory (root of the repository)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

#==============================================================================
# DIRECTORIES
#==============================================================================

# Report output directory
REPORT_DIR="${SCRIPT_DIR}/report"

# Wordlist directories (in priority order)
WORDLIST_DIRS=(
    "${SCRIPT_DIR}/external/SecLists/Discovery/Web-Content"
    "/usr/share/wordlists/seclists/Discovery/Web-Content"
    "/usr/share/seclists/Discovery/Web-Content"
    "/usr/share/wordlists/dirbuster"
)

# Vulscan directory
VULSCAN_DIR="${SCRIPT_DIR}/external/vulscan"

#==============================================================================
# DEFAULT SETTINGS
#==============================================================================

# Default ports
DEFAULT_HTTP_PORT=80
DEFAULT_HTTPS_PORT=443

# Default protocol (http or https)
DEFAULT_PROTOCOL="http"

# Timeouts (in seconds)
SCAN_TIMEOUT=300
TOOL_TIMEOUT=600

# Threading/performance
GOBUSTER_THREADS=10
NMAP_TIMING=4  # T4 aggressive

#==============================================================================
# TOOL OPTIONS
#==============================================================================

# Nmap HTTP scripts
NMAP_HTTP_SCRIPTS=(
    "http-date"
    "http-title"
    "http-server-header"
    "http-headers"
    "http-enum"
    "http-devframework"
    "http-dombased-xss"
    "http-stored-xss"
    "http-xssed"
    "http-cookie-flags"
    "http-errors"
    "http-grep"
    "http-traceroute"
)

# Required tools
REQUIRED_TOOLS=(
    "nmap"
    "nikto"
    "gobuster"
    "dirb"
    "whatweb"
    "wafw00f"
)

# Optional tools
OPTIONAL_TOOLS=(
    "uniscan"
    "feroxbuster"
    "xsser"
)

# Gobuster status codes to report
GOBUSTER_STATUS_CODES="200,204,301,302,307,401,403,405,500"

#==============================================================================
# WORDLISTS
#==============================================================================

# Primary wordlists for fuzzing
PRIMARY_WORDLISTS=(
    "directory-list-2.3-medium.txt"
    "common.txt"
    "raft-medium-directories.txt"
)

# CMS-specific wordlists
CMS_WORDLISTS=(
    "wordpress.fuzz.txt"
    "drupal.txt"
    "joomla.fuzz.txt"
)

# Web server wordlists
WEBSERVER_WORDLISTS=(
    "apache.txt"
    "nginx.txt"
    "tomcat.txt"
    "iis.txt"
)

#==============================================================================
# FUNCTIONS
#==============================================================================

# Find first available wordlist path
find_wordlist_dir() {
    for dir in "${WORDLIST_DIRS[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "$dir"
            return 0
        fi
    done
    return 1
}

# Find a specific wordlist file
find_wordlist() {
    local name="$1"
    local wordlist_dir
    
    wordlist_dir=$(find_wordlist_dir) || return 1
    
    local path="${wordlist_dir}/${name}"
    if [[ -f "$path" ]]; then
        echo "$path"
        return 0
    fi
    
    # Try Kali default location
    if [[ -f "/usr/share/wordlists/dirbuster/${name}" ]]; then
        echo "/usr/share/wordlists/dirbuster/${name}"
        return 0
    fi
    
    return 1
}

# Get Nmap HTTP scripts as comma-separated string
get_nmap_http_scripts() {
    local IFS=','
    echo "${NMAP_HTTP_SCRIPTS[*]}"
}

# Create report directory if needed
ensure_report_dir() {
    if [[ ! -d "$REPORT_DIR" ]]; then
        mkdir -p "$REPORT_DIR"
    fi
}

#==============================================================================
# WAF EVASION SETTINGS
#==============================================================================

# WAF Detection & Evasion
WAF_DETECTION_ENABLED=true
WAF_EVASION_ENABLED=true
WAF_EVASION_LEVEL="moderate"  # low, moderate, high, paranoid
WAF_PROFILES_DIR="${SCRIPT_DIR}/lib/waf_profiles"

# Evasion Timing (milliseconds)
DEFAULT_REQUEST_DELAY=1000
MAX_REQUEST_DELAY=5000
RANDOMIZE_DELAYS=true

# Export for use by other scripts
export WAF_DETECTION_ENABLED
export WAF_EVASION_ENABLED
export WAF_EVASION_LEVEL
