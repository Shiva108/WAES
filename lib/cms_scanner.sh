#!/usr/bin/env bash
#==============================================================================
# WAES CMS Detection and Scanning Module
# Detects and performs CMS-specific vulnerability scans
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
# CMS DETECTION
#==============================================================================

detect_wordpress() {
    local target="$1"
    
    # Check for WordPress indicators
    if curl -s -L "$target" | grep -qi "wp-content\|wp-includes\|wordpress"; then
        return 0
    fi
    
    # Check for common WP files
    if curl -s -I "${target}/wp-login.php" 2>/dev/null | grep -q "200 OK"; then
        return 0
    fi
    
    return 1
}

detect_drupal() {
    local target="$1"
    
    # Check for Drupal indicators
    if curl -s -L "$target" | grep -qi "Drupal\|sites/default\|misc/drupal.js"; then
        return 0
    fi
    
    # Check for Drupal headers
    if curl -s -I "$target" 2>/dev/null | grep -qi "X-Drupal\|X-Generator.*Drupal"; then
        return 0
    fi
    
    return 1
}

detect_joomla() {
    local target="$1"
    
    # Check for Joomla indicators
    if curl -s -L "$target" | grep -qi "joomla\|/components/\|/administrator/"; then
        return 0
    fi
    
    # Check Joomla specific files
    if curl -s -I "${target}/administrator/" 2>/dev/null | grep -q "200 OK"; then
        return 0
    fi
    
    return 1
}

detect_cms() {
    local target="$1"
    local output_file="$2"
    
    print_info "Detecting CMS..."
    
    {
        echo "=== CMS Detection ==="
        echo "Target: $target"
        echo ""
        
        # Try WhatWeb if available
        if command -v whatweb &>/dev/null; then
            echo "--- WhatWeb Detection ---"
            whatweb -a 3 "$target" 2>/dev/null | grep -i "cms\|wordpress\|drupal\|joomla" || echo "No CMS detected by WhatWeb"
            echo ""
        fi
        
        # Manual detection
        echo "--- Manual Detection ---"
        
        if detect_wordpress "$target"; then
            echo "[DETECTED] WordPress"
        else
            echo "[NOT DETECTED] WordPress"
        fi
        
        if detect_drupal "$target"; then
            echo "[DETECTED] Drupal"
        else
            echo "[NOT DETECTED] Drupal"
        fi
        
        if detect_joomla "$target"; then
            echo "[DETECTED] Joomla"
        else
            echo "[NOT DETECTED] Joomla"
        fi
        
        echo ""
    } | tee "$output_file"
}

#==============================================================================
# WORDPRESS SCANNING
#==============================================================================

scan_wordpress() {
    local target="$1"
    local output_file="$2"
    
    print_info "Scanning WordPress installation..."
    
    {
        echo "=== WordPress Scan ==="
        echo ""
        
        # Version detection
        echo "--- Version Detection ---"
        local version
        version=$(curl -s -L "$target" | grep -oP '(?<=content="WordPress )[0-9.]+' | head -1)
        if [[ -n "$version" ]]; then
            echo "WordPress Version: $version"
        else
            echo "Version: Unknown"
        fi
        echo ""
        
        # Theme detection
        echo "--- Active Theme ---"
        local theme
        theme=$(curl -s -L "$target" | grep -oP '(?<=wp-content/themes/)[^/]+' | head -1)
        if [[ -n "$theme" ]]; then
            echo "Theme: $theme"
        else
            echo "Theme: Unknown"
        fi
        echo ""
        
        # Plugin enumeration
        echo "--- Plugin Enumeration ---"
        local plugins
        plugins=$(curl -s -L "$target" | grep -oP '(?<=wp-content/plugins/)[^/]+' | sort -u)
        if [[ -n "$plugins" ]]; then
            echo "$plugins"
        else
            echo "No plugins detected"
        fi
        echo ""
        
        # Common vulnerable files
        echo "--- Vulnerable Files Check ---"
        local check_files=(
            "readme.html"
            "wp-config.php.bak"
            "wp-config-sample.php"
            "xmlrpc.php"
            "wp-cron.php"
        )
        
        for file in "${check_files[@]}"; do
            if curl -s -I "${target}/${file}" 2>/dev/null | grep -q "200 OK"; then
                echo "[ACCESSIBLE] $file"
            fi
        done
        echo ""
        
        # User enumeration
        echo "--- User Enumeration ---"
        for i in {1..5}; do
            local user
            user=$(curl -s "${target}/?author=${i}" 2>/dev/null | grep -oP '(?<=author/)[^/]+' | head -1)
            [[ -n "$user" ]] && echo "User ID $i: $user"
        done
        echo ""
        
        # WPScan if available
        if command -v wpscan &>/dev/null; then
            echo "--- WPScan Results ---"
            wpscan --url "$target" --enumerate vp,vt,u --random-user-agent --no-banner 2>/dev/null || \
                echo "WPScan failed"
        else
            echo "WPScan not installed. Install with: gem install wpscan"
        fi
        echo ""
        
    } | tee -a "$output_file"
}

#==============================================================================
# DRUPAL SCANNING
#==============================================================================

scan_drupal() {
    local target="$1"
    local output_file="$2"
    
    print_info "Scanning Drupal installation..."
    
    {
        echo "=== Drupal Scan ==="
        echo ""
        
        # Version detection
        echo "--- Version Detection ---"
        local version
        version=$(curl -s -L "$target/CHANGELOG.txt" 2>/dev/null | grep -oP 'Drupal \K[0-9.]+' | head -1)
        if [[ -n "$version" ]]; then
            echo "Drupal Version: $version"
        else
            echo "Version: Unknown (CHANGELOG.txt not accessible)"
        fi
        echo ""
        
        # Common vulnerable files
        echo "--- Vulnerable Files Check ---"
        local check_files=(
            "CHANGELOG.txt"
            "INSTALL.txt"
            "README.txt"
            "UPGRADE.txt"
            "INSTALL.mysql.txt"
            "sites/default/settings.php"
        )
        
        for file in "${check_files[@]}"; do
            if curl -s -I "${target}/${file}" 2>/dev/null | grep -q "200 OK"; then
                echo "[ACCESSIBLE] $file"
            fi
        done
        echo ""
        
        # Module detection
        echo "--- Module Detection ---"
        local modules
        modules=$(curl -s -L "$target" | grep -oP '(?<=sites/all/modules/)[^/]+' | sort -u | head -10)
        if [[ -n "$modules" ]]; then
            echo "$modules"
        else
            echo "No modules detected"
        fi
        echo ""
        
        # Droopescan if available
        if command -v droopescan &>/dev/null; then
            echo "--- Droopescan Results ---"
            droopescan scan drupal -u "$target" 2>/dev/null || echo "Droopescan failed"
        else
            echo "Droopescan not installed. Install with: pip install droopescan"
        fi
        echo ""
        
    } | tee -a "$output_file"
}

#==============================================================================
# JOOMLA SCANNING
#==============================================================================

scan_joomla() {
    local target="$1"
    local output_file="$2"
    
    print_info "Scanning Joomla installation..."
    
    {
        echo "=== Joomla Scan ==="
        echo ""
        
        # Version detection
        echo "--- Version Detection ---"
        local version
        version=$(curl -s -L "${target}/administrator/manifests/files/joomla.xml" 2>/dev/null | \
            grep -oP '(?<=<version>)[0-9.]+(?=</version>)')
        if [[ -n "$version" ]]; then
            echo "Joomla Version: $version"
        else
            echo "Version: Unknown"
        fi
        echo ""
        
        # Admin panel access
        echo "--- Admin Panel ---"
        if curl -s -I "${target}/administrator/" 2>/dev/null | grep -q "200 OK"; then
            echo "[ACCESSIBLE] Administrator panel at /administrator/"
        fi
        echo ""
        
        # Configuration files
        echo "--- Configuration Files Check ---"
        local check_files=(
            "configuration.php"
            "configuration.php.bak"
            "htaccess.txt"
            "web.config.txt"
        )
        
        for file in "${check_files[@]}"; do
            if curl -s -I "${target}/${file}" 2>/dev/null | grep -q "200 OK"; then
                echo "[ACCESSIBLE] $file"
            fi
        done
        echo ""
        
        # Component enumeration
        echo "--- Component Enumeration ---"
        local components
        components=$(curl -s -L "$target" | grep -oP '(?<=components/)[^/]+' | sort -u | head -10)
        if [[ -n "$components" ]]; then
            echo "$components"
        else
            echo "No components detected"
        fi
        echo ""
        
        # JoomScan if available
        if command -v joomscan &>/dev/null; then
            echo "--- JoomScan Results ---"
            joomscan -u "$target" 2>/dev/null || echo "JoomScan failed"
        else
            echo "JoomScan not installed."
        fi
        echo ""
        
    } | tee -a "$output_file"
}

#==============================================================================
# MAIN CMS SCANNER
#==============================================================================

scan_cms() {
    local target="$1"
    local report_dir="${2:-.}"
    
    local domain
    domain=$(echo "$target" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
    local output_file="${report_dir}/${domain}_cms_scan.txt"
    
    print_info "Starting CMS scan for: $target"
    echo ""
    
    # Clear previous file
    > "$output_file"
    
    # Detect CMS
    detect_cms "$target" "$output_file"
    
    # Scan specific CMS
    if detect_wordpress "$target"; then
        scan_wordpress "$target" "$output_file"
    fi
    
    if detect_drupal "$target"; then
        scan_drupal "$target" "$output_file"
    fi
    
    if detect_joomla "$target"; then
        scan_joomla "$target" "$output_file"
    fi
    
    print_success "CMS scan complete: $output_file"
}

# If script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat << EOF
Usage: $0 <target_url> [report_dir]

Examples:
    $0 http://example.com
    $0 https://blog.example.com ./reports
EOF
        exit 1
    fi
    
    scan_cms "$@"
fi
