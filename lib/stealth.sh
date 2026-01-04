#!/usr/bin/env bash
#==============================================================================
# WAES Stealth & Evasion Module
# Techniques to avoid detection during security scanning
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
# USER AGENT ROTATION
#==============================================================================

# Realistic user agents
declare -a USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:121.0) Gecko/20100101 Firefox/121.0"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Edge/120.0.0.0"
)

# Get random user agent
get_random_user_agent() {
    local random_index=$((RANDOM % ${#USER_AGENTS[@]}))
    echo "${USER_AGENTS[$random_index]}"
}

# Export for curl/wget
export_random_user_agent() {
    export USER_AGENT=$(get_random_user_agent)
    echo "$USER_AGENT"
}

#==============================================================================
# TIMING & DELAYS
#==============================================================================

# Random delay between requests
random_delay() {
    local min=${1:-1}
    local max=${2:-5}
    local delay=$((RANDOM % (max - min + 1) + min))
    
    sleep "$delay"
}

# Exponential backoff
exponential_backoff() {
    local attempt=$1
    local max_delay=${2:-32}
    
    local delay=$((2 ** attempt))
    [[ $delay -gt $max_delay ]] && delay=$max_delay
    
    sleep "$delay"
}

#==============================================================================
# REQUEST OBFUSCATION
#==============================================================================

# Add random headers
add_random_headers() {
    local -a headers
    
    headers+=("-H" "User-Agent: $(get_random_user_agent)")
    headers+=("-H" "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
    headers+=("-H" "Accept-Language: en-US,en;q=0.5")
    headers+=("-H" "Accept-Encoding: gzip, deflate")
    headers+=("-H" "DNT: 1")
    headers+=("-H" "Connection: keep-alive")
    headers+=("-H" "Upgrade-Insecure-Requests: 1")
    
    # Random referrer
    local -a referrers=("https://www.google.com/" "https://www.bing.com/" "https://duckduckgo.com/")
    local random_ref=$((RANDOM % ${#referrers[@]}))
    headers+=("-H" "Referer: ${referrers[$random_ref]}")
    
    echo "${headers[@]}"
}

# Stealth curl request
stealth_curl() {
    local url="$1"
    shift
    local extra_args=("$@")
    
    local headers
    headers=$(add_random_headers)
    
    # shellcheck disable=SC2086
    curl -s -L $headers "${extra_args[@]}" "$url"
}

#==============================================================================
# TRAFFIC PATTERNS
#==============================================================================

# Mimic human browsing
mimic_human_browsing() {
    local base_url="$1"
    
    print_info "Mimicking human browsing pattern"
    
    # Visit homepage
    stealth_curl "$base_url" -o /dev/null
    random_delay 2 5
    
    # Visit common pages
    local -a common_pages=("about" "contact" "products" "services")
    local num_pages=$((RANDOM % 3 + 1))
    
    for ((i=0; i<num_pages; i++)); do
        local random_page=$((RANDOM % ${#common_pages[@]}))
        local page_url="${base_url}/${common_pages[$random_page]}"
        
        stealth_curl "$page_url" -o /dev/null 2>/dev/null || true
        random_delay 3 8
    done
}

#==============================================================================
# PROXY SUPPORT
#==============================================================================

# Test proxy connection
test_proxy() {
    local proxy="$1"
    
    if curl -s -x "$proxy" --max-time 10 "http://www.google.com" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Load proxy list
load_proxy_list() {
    local proxy_file="$1"
    
    if [[ ! -f "$proxy_file" ]]; then
        print_error "Proxy file not found: $proxy_file"
        return 1
    fi
    
    declare -a working_proxies
    
    while read -r proxy; do
        [[ -z "$proxy" ]] && continue
        [[ "$proxy" =~ ^# ]] && continue
        
        if test_proxy "$proxy"; then
            working_proxies+=("$proxy")
            print_success "Working proxy: $proxy"
        fi
    done < "$proxy_file"
    
    if [[ ${#working_proxies[@]} -eq 0 ]]; then
        print_error "No working proxies found"
        return 1
    fi
    
    # Export random working proxy
    local random_proxy=$((RANDOM % ${#working_proxies[@]}))
    export HTTP_PROXY="${working_proxies[$random_proxy]}"
    export HTTPS_PROXY="${working_proxies[$random_proxy]}"
    
    print_success "Using proxy: ${working_proxies[$random_proxy]}"
}

#==============================================================================
# NMAP STEALTH OPTIONS
#==============================================================================

# Get stealth nmap flags
get_stealth_nmap_flags() {
    local level="${1:-medium}"
    
    case "$level" in
        low)
            echo "-T2 --max-retries 1"
            ;;
        medium)
            echo "-T1 --max-retries 1 --randomize-hosts"
            ;;
        high)
            echo "-T0 --max-retries 1 --randomize-hosts --data-length 25"
            ;;
        paranoid)
            echo "-T0 --max-retries 0 --randomize-hosts --data-length 50 -f"
            ;;
        *)
            echo "-T3"
            ;;
    esac
}

#==============================================================================
# MAIN STEALTH CONFIGURATION
#==============================================================================

configure_stealth_mode() {
    local level="${1:-medium}"
    
    print_info "Configuring stealth mode: $level"
    
    # Set delays
    case "$level" in
        low)
            export STEALTH_MIN_DELAY=1
            export STEALTH_MAX_DELAY=3
            ;;
        medium)
            export STEALTH_MIN_DELAY=2
            export STEALTH_MAX_DELAY=5
            ;;
        high)
            export STEALTH_MIN_DELAY=5
            export STEALTH_MAX_DELAY=10
            ;;
        paranoid)
            export STEALTH_MIN_DELAY=10
            export STEALTH_MAX_DELAY=20
            ;;
    esac
    
    # Set user agent rotation
    export STEALTH_USER_AGENT_ROTATION=true
    
    # Set nmap flags
    export STEALTH_NMAP_FLAGS=$(get_stealth_nmap_flags "$level")
    
    print_success "Stealth mode configured"
    print_info "Delays: ${STEALTH_MIN_DELAY}-${STEALTH_MAX_DELAY} seconds"
    print_info "Nmap flags: $STEALTH_NMAP_FLAGS"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        configure)
            configure_stealth_mode "${2:-medium}"
            ;;
        test-proxy)
            test_proxy "$2"
            ;;
        user-agent)
            get_random_user_agent
            ;;
        *)
            cat << EOF
Usage: $0 <command> [arguments]

Commands:
    configure [level]    Configure stealth mode (low|medium|high|paranoid)
    test-proxy <proxy>   Test if proxy is working
    user-agent           Get random user agent

Examples:
    $0 configure high
    $0 test-proxy socks5://127.0.0.1:9050
    $0 user-agent
EOF
            exit 1
            ;;
    esac
fi
