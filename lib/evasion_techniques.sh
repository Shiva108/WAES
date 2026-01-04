#!/usr/bin/env bash
#==============================================================================
# WAES - Evasion Techniques Library
# Implements WAF bypass and evasion techniques
#==============================================================================

# Source required libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || {
    print_info() { echo "[*] $*"; }
    print_success() { echo "[+] $*"; }
    print_warn() { echo "[~] $*"; }
}

#==============================================================================
# USER-AGENT RANDOMIZATION
#==============================================================================

# Pool of realistic User-Agents
USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:121.0) Gecko/20100101 Firefox/121.0"
    "Mozilla/5.0 (X11; Linux x86_64; rv:121.0) Gecko/20100101 Firefox/121.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"
)

randomize_user_agent() {
    local index=$((RANDOM % ${#USER_AGENTS[@]}))
    echo "${USER_AGENTS[$index]}"
}

#==============================================================================
# PAYLOAD OBFUSCATION
#==============================================================================

obfuscate_payload() {
    local payload="$1"
    local method="${2:-url}"
    
    case "$method" in
        url)
            # URL encoding
            echo -n "$payload" | jq -sRr @uri 2>/dev/null || \
            python3 -c "import urllib.parse; print(urllib.parse.quote('''$payload'''))" 2>/dev/null || \
            echo "$payload"
            ;;
        double_url)
            # Double URL encoding
            local once
            once=$(echo -n "$payload" | jq -sRr @uri 2>/dev/null)
            echo -n "$once" | jq -sRr @uri 2>/dev/null || echo "$payload"
            ;;
        unicode)
            # Unicode encoding
            python3 -c "print(''.join(f'\\u{ord(c):04x}' for c in '''$payload'''))" 2>/dev/null || \
            echo "$payload"
            ;;
        base64)
            # Base64 encoding
            echo -n "$payload" | base64 2>/dev/null || echo "$payload"
            ;;
        hex)
            # Hex encoding
            echo -n "$payload" | xxd -p | tr -d '\n' 2>/dev/null || echo "$payload"
            ;;
        case_variation)
            # Random case variation
            echo "$payload" | python3 -c "
import sys, random
text = sys.stdin.read()
result = ''.join(c.upper() if random.random() > 0.5 else c.lower() for c in text)
print(result, end='')
" 2>/dev/null || echo "$payload"
            ;;
        *)
            echo "$payload"
            ;;
    esac
}

#==============================================================================
# RATE LIMITING
#==============================================================================

apply_rate_limit() {
    local delay="${1:-1000}"  # milliseconds
    local randomize="${2:-true}"
    
    if [[ "$randomize" == "true" ]]; then
        # Add ±30% random variation
        local variance=$((delay * 30 / 100))
        local min=$((delay - variance))
        local max=$((delay + variance))
        delay=$((min + RANDOM % (max - min + 1)))
    fi
    
    # Convert milliseconds to seconds with decimal
    local sleep_time
    sleep_time=$(echo "scale=3; $delay/1000" | bc)
    
    sleep "$sleep_time" 2>/dev/null || sleep 1
}

calculate_delay() {
    local evasion_level="${1:-moderate}"
    
    case "$evasion_level" in
        low)
            echo "500"  # 0.5 seconds
            ;;
        moderate)
            echo "2000"  # 2 seconds
            ;;
        high)
            echo "4000"  # 4 seconds
            ;;
        paranoid)
            echo "8000"  # 8 seconds
            ;;
        *)
            echo "1000"  # 1 second default
            ;;
    esac
}

#==============================================================================
# HEADER MANIPULATION
#==============================================================================

generate_evasion_headers() {
    local technique="${1:-basic}"
    
    case "$technique" in
        cloudflare)
            cat <<EOF
X-Forwarded-For: 127.0.0.1
CF-Connecting-IP: 10.0.0.1
X-Originating-IP: 172.16.0.1
X-Remote-IP: 192.168.1.1
X-Remote-Addr: 192.168.1.1
EOF
            ;;
        akamai)
            cat <<EOF
X-Forwarded-For: 127.0.0.1
True-Client-IP: 10.0.0.1
X-Akamai-Origin: internal
EOF
            ;;
        aws)
            cat <<EOF
X-Forwarded-For: 127.0.0.1
X-Amzn-Trace-Id: Root=1-$(date +%s)-$(openssl rand -hex 12)
EOF
            ;;
        basic|*)
            cat <<EOF
X-Forwarded-For: 127.0.0.1
X-Originating-IP: 127.0.0.1
X-Remote-IP: 127.0.0.1
X-Remote-Addr: 127.0.0.1
EOF
            ;;
    esac
}

build_curl_headers() {
    local technique="$1"
    local headers
    headers=$(generate_evasion_headers "$technique")
    
    while IFS= read -r header; do
        if [[ -n "$header" ]]; then
            echo -n "-H '$header' "
        fi
    done <<< "$headers"
}

#==============================================================================
# REQUEST FRAGMENTATION
#==============================================================================

fragment_request() {
    local url="$1"
    local method="${2:-GET}"
    
    # Split request into chunks (simplified implementation)
    print_info "Using chunked transfer encoding for: $url"
    
    # Return curl command with chunked encoding
    echo "curl -X $method --tr-encoding '$url'"
}

#==============================================================================
# NIKTO EVASION FLAGS
#==============================================================================

get_nikto_evasion() {
    local evasion_level="${1:-moderate}"
    
    # Nikto evasion techniques:
    # 1: Random URL encoding
    # 2: Directory self-reference (/./)
    # 3: Premature URL ending
    # 4: Prepend long random string
    # 5: Fake parameter
    # 6: TAB as request spacer
    # 7: Change URL case
    # 8: Use Windows directory separator (\)
    
    case "$evasion_level" in
        low)
            echo "1"  # Just URL encoding
            ;;
        moderate)
            echo "1247"  # URL encoding + dir self-ref + case + fake param
            ;;
        high)
            echo "12345678"  # All techniques
            ;;
        paranoid)
            echo "12345678"  # All techniques
            ;;
        *)
            echo "127"
            ;;
    esac
}

#==============================================================================
# GOBUSTER EVASION
#==============================================================================

get_gobuster_options() {
    local evasion_level="${1:-moderate}"
    local user_agent
    user_agent=$(randomize_user_agent)
    
    local delay
    delay=$(calculate_delay "$evasion_level")
    
    # Convert milliseconds to seconds for gobuster
    local delay_sec
    delay_sec=$(echo "scale=0; $delay/1000" | bc)
    
    cat <<EOF
--useragent "$user_agent"
--delay ${delay_sec}s
--no-error
--wildcard
EOF
}

#==============================================================================
# NMAP TIMING
#==============================================================================

get_nmap_timing() {
    local evasion_level="${1:-moderate}"
    
    case "$evasion_level" in
        low)
            echo "T3"  # Normal
            ;;
        moderate)
            echo "T2"  # Polite
            ;;
        high)
            echo "T1"  # Sneaky
            ;;
        paranoid)
            echo "T0"  # Paranoid
            ;;
        *)
            echo "T3"
            ;;
    esac
}

#==============================================================================
# TESTING FUNCTIONS
#==============================================================================

test_evasion_techniques() {
    print_info "Testing Evasion Techniques"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo ""
    echo "1. User-Agent Rotation:"
    for i in {1..3}; do
        echo "  UA $i: $(randomize_user_agent)"
    done
    
    echo ""
    echo "2. Payload Obfuscation:"
    local payload="<script>alert(1)</script>"
    echo "  Original: $payload"
    echo "  URL:      $(obfuscate_payload "$payload" "url")"
    echo "  Unicode:  $(obfuscate_payload "$payload" "unicode")"
    echo "  Base64:   $(obfuscate_payload "$payload" "base64")"
    
    echo ""
    echo "3. Rate Limiting:"
    for level in low moderate high paranoid; do
        echo "  $level: $(calculate_delay "$level")ms"
    done
    
    echo ""
    echo "4. Evasion Headers (Cloudflare):"
    generate_evasion_headers "cloudflare" | sed 's/^/  /'
    
    echo ""
    echo "5. Nikto Evasion Flags:"
    for level in low moderate high paranoid; do
        echo "  $level: $(get_nikto_evasion "$level")"
    done
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Direct execution for testing
    test_evasion_techniques
fi
