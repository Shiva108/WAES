#!/usr/bin/env bash
#==============================================================================
# WAES REST API Server
# Lightweight HTTP server for programmatic scan control
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true

#==============================================================================
# CONFIGURATION
#==============================================================================

API_PORT="${WAES_API_PORT:-8000}"
API_KEY="${WAES_API_KEY:-changeme}"
API_LOG="${SCRIPT_DIR}/data/api.log"
SCANS_DIR="${SCRIPT_DIR}/data/scans"

mkdir -p "$SCANS_DIR"

#==============================================================================
# AUTHENTICATION
#==============================================================================

check_auth() {
    local provided_key="$1"
    
    if [[ "$provided_key" != "$API_KEY" ]]; then
        echo "HTTP/1.1 401 Unauthorized"
        echo "Content-Type: application/json"
        echo ""
        echo '{"error": "Invalid API key"}'
        return 1
    fi
    return 0
}

#==============================================================================
# SCAN MANAGEMENT
#==============================================================================

start_scan() {
    local target="$1"
    local scan_type="${2:-full}"
    local scan_id
    
    # Generate scan ID
    scan_id=$(date +%s)_$(echo "$target" | md5sum | cut -c1-8)
    
    # Create scan directory
    local scan_dir="${SCANS_DIR}/${scan_id}"
    mkdir -p "$scan_dir"
    
    # Write scan metadata
    cat > "${scan_dir}/metadata.json" <<EOF
{
  "scan_id": "$scan_id",
  "target": "$target",
  "type": "$scan_type",
  "status": "queued",
  "created_at": "$(date -Iseconds)",
  "progress": 0
}
EOF
    
    # Start scan in background
    (
        cd "$SCRIPT_DIR"
        echo '{"status": "running", "progress": 10}' > "${scan_dir}/status.json"
        
        ./waes.sh -u "$target" -t "$scan_type" \
            -o "${scan_dir}/report" \
            --evidence --chains \
            > "${scan_dir}/scan.log" 2>&1
        
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            echo '{"status": "completed", "progress": 100}' > "${scan_dir}/status.json"
        else
            echo '{"status": "failed", "progress": 0, "error": "Scan failed"}' > "${scan_dir}/status.json"
        fi
    ) &
    
    echo "$scan_id"
}

get_scan_status() {
    local scan_id="$1"
    local scan_dir="${SCANS_DIR}/${scan_id}"
    
    if [[ ! -d "$scan_dir" ]]; then
        echo '{"error": "Scan not found"}'
        return 1
    fi
    
    # Combine metadata and current status
    local metadata
    local status
    
    metadata=$(cat "${scan_dir}/metadata.json" 2>/dev/null || echo '{}')
    status=$(cat "${scan_dir}/status.json" 2>/dev/null || echo '{}')
    
    jq -s '.[0] * .[1]' <(echo "$metadata") <(echo "$status")
}

get_scan_findings() {
    local scan_id="$1"
    local scan_dir="${SCANS_DIR}/${scan_id}"
    
    if [[ ! -d "$scan_dir" ]]; then
        echo '{"error": "Scan not found"}'
        return 1
    fi
    
    # Aggregate findings from various sources
    local findings="[]"
    
    # OWASP findings
    if [[ -f "${scan_dir}/report/.owasp_findings.json" ]]; then
        findings=$(jq -s 'add' "${scan_dir}/report/.owasp_findings.json" 2>/dev/null || echo '[]')
    fi
    
    # Intelligence findings
    if [[ -f "${scan_dir}/report/intelligence_report.json" ]]; then
        local intel
        intel=$(jq -s '.' "${scan_dir}/report/intelligence_report.json" 2>/dev/null || echo '[]')
        findings=$(jq -s '.[0] + .[1]' <(echo "$findings") <(echo "$intel"))
    fi
    
    echo "$findings"
}

delete_scan() {
    local scan_id="$1"
    local scan_dir="${SCANS_DIR}/${scan_id}"
    
    if [[ -d "$scan_dir" ]]; then
        rm -rf "$scan_dir"
        echo '{"success": true, "message": "Scan deleted"}'
    else
        echo '{"error": "Scan not found"}'
        return 1
    fi
}

list_scans() {
    local scans="[]"
    
    for scan_dir in "${SCANS_DIR}"/*; do
        [[ -d "$scan_dir" ]] || continue
        
        local metadata
        metadata=$(cat "${scan_dir}/metadata.json" 2>/dev/null || echo '{}')
        
        scans=$(jq -s '.[0] + [.[1]]' <(echo "$scans") <(echo "$metadata"))
    done
    
    echo "$scans"
}

#==============================================================================
# HTTP REQUEST HANDLER
#==============================================================================

handle_request() {
    local method="$1"
    local path="$2"
    local api_key="$3"
    local body="$4"
    
    # Log request
    echo "[$(date -Iseconds)] $method $path" >> "$API_LOG"
    
    # Check authentication
    if ! check_auth "$api_key"; then
        return 1
    fi
    
    # Route request
    case "$method:$path" in
        POST:/api/v1/scans)
            local target
            local scan_type
            
            target=$(echo "$body" | jq -r '.target // empty')
            scan_type=$(echo "$body" | jq -r '.type // "full"')
            
            if [[ -z "$target" ]]; then
                echo "HTTP/1.1 400 Bad Request"
                echo "Content-Type: application/json"
                echo ""
                echo '{"error": "Missing target parameter"}'
                return 1
            fi
            
            local scan_id
            scan_id=$(start_scan "$target" "$scan_type")
            
            echo "HTTP/1.1 201 Created"
            echo "Content-Type: application/json"
            echo ""
            echo "{\"scan_id\": \"$scan_id\", \"status\": \"queued\"}"
            ;;
            
        GET:/api/v1/scans)
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: application/json"
            echo ""
            list_scans
            ;;
            
        GET:/api/v1/scans/*)
            local scan_id="${path##*/}"
            local status
            status=$(get_scan_status "$scan_id")
            
            if [[ $? -eq 0 ]]; then
                echo "HTTP/1.1 200 OK"
                echo "Content-Type: application/json"
                echo ""
                echo "$status"
            else
                echo "HTTP/1.1 404 Not Found"
                echo "Content-Type: application/json"
                echo ""
                echo '{"error": "Scan not found"}'
            fi
            ;;
            
        GET:/api/v1/scans/*/findings)
            local scan_id
            scan_id=$(echo "$path" | cut -d/ -f5)
            
            local findings
            findings=$(get_scan_findings "$scan_id")
            
            echo "HTTP/1.1 200 OK"
            echo "Content-Type: application/json"
            echo ""
            echo "$findings"
            ;;
            
        DELETE:/api/v1/scans/*)
            local scan_id="${path##*/}"
            local result
            result=$(delete_scan "$scan_id")
            
            if [[ $? -eq 0 ]]; then
                echo "HTTP/1.1 200 OK"
                echo "Content-Type: application/json"
                echo ""
                echo "$result"
            else
                echo "HTTP/1.1 404 Not Found"
                echo "Content-Type: application/json"
                echo ""
                echo "$result"
            fi
            ;;
            
        *)
            echo "HTTP/1.1 404 Not Found"
            echo "Content-Type: application/json"
            echo ""
            echo '{"error": "Endpoint not found"}'
            ;;
    esac
}

#==============================================================================
# HTTP SERVER
#==============================================================================

start_server() {
    print_header "WAES API Server"
    echo "Listening on: http://localhost:${API_PORT}"
    echo "API Key: ${API_KEY}"
    echo ""
    print_warn "Press Ctrl+C to stop"
    echo ""
    
    # Simple HTTP server using netcat
    while true; do
        {
            # Read HTTP request
            read -r request_line
            local method=$(echo "$request_line" | cut -d' ' -f1)
            local path=$(echo "$request_line" | cut -d' ' -f2)
            
            # Read headers
            local api_key=""
            local content_length=0
            
            while IFS=: read -r header value; do
                header=$(echo "$header" | tr -d '\r\n' | tr '[:upper:]' '[:lower:]')
                value=$(echo "$value" | tr -d '\r\n' | sed 's/^ *//')
                
                case "$header" in
                    x-api-key) api_key="$value" ;;
                    content-length) content_length="$value" ;;
                esac
                
                # Empty line marks end of headers
                [[ -z "$header" ]] && break
            done
            
            # Read body if present
            local body=""
            if (( content_length > 0 )); then
                body=$(head -c "$content_length")
            fi
            
            # Handle request
            handle_request "$method" "$path" "$api_key" "$body"
            
        } | nc -l -p "$API_PORT" -q 1
    done
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-start}" in
        start)
            start_server
            ;;
        stop)
            pkill -f "waes.*api.*server"
            echo "API server stopped"
            ;;
        *)
            echo "Usage: $0 {start|stop}"
            exit 1
            ;;
    esac
fi
