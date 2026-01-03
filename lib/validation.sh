#!/usr/bin/env bash
# WAES Validation Library
# Input validation functions for IP, domain, URL, and port

# Validate IPv4 address
validate_ipv4() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'
    
    if [[ ! $ip =~ $regex ]]; then
        return 1
    fi
    
    # Check each octet is <= 255
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
        if (( octet > 255 )); then
            return 1
        fi
    done
    
    return 0
}

# Validate domain name
validate_domain() {
    local domain="$1"
    local regex='^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
    
    [[ $domain =~ $regex ]]
}

# Validate port number (1-65535)
validate_port() {
    local port="$1"
    
    if [[ ! $port =~ ^[0-9]+$ ]]; then
        return 1
    fi
    
    if (( port < 1 || port > 65535 )); then
        return 1
    fi
    
    return 0
}

# Validate URL format
validate_url() {
    local url="$1"
    local regex='^https?://[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?(:[0-9]+)?(/.*)?$'
    
    [[ $url =~ $regex ]]
}

# Validate target (IP or domain)
validate_target() {
    local target="$1"
    
    validate_ipv4 "$target" || validate_domain "$target"
}

# Extract host from URL
extract_host() {
    local url="$1"
    # Remove protocol
    local host="${url#*://}"
    # Remove path
    host="${host%%/*}"
    # Remove port
    host="${host%%:*}"
    echo "$host"
}

# Extract port from URL (default 80 for http, 443 for https)
extract_port() {
    local url="$1"
    local default_port="80"
    
    if [[ $url =~ ^https:// ]]; then
        default_port="443"
    fi
    
    # Check if port is specified
    if [[ $url =~ ://[^/]+:([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "$default_port"
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Validate required tools are installed
validate_tools() {
    local -a missing=()
    local -a tools=("$@")
    
    for tool in "${tools[@]}"; do
        if ! command_exists "$tool"; then
            missing+=("$tool")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "${missing[*]}"
        return 1
    fi
    
    return 0
}

# Check if file exists and is readable
validate_file() {
    local file="$1"
    [[ -r "$file" ]]
}

# Check if directory exists and is writable
validate_directory() {
    local dir="$1"
    [[ -d "$dir" ]] && [[ -w "$dir" ]]
}
