#!/usr/bin/env bash
#==============================================================================
# WAES Orchestration Engine
# Intelligent scan workflow management with technology-aware tool selection
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null || true

#==============================================================================
# CONFIGURATION
#==============================================================================

# Maximum parallel tools
MAX_PARALLEL=4

# Tool dependencies (child depends on parent)
declare -gA TOOL_DEPS=(
    ["nikto"]="nmap"
    ["gobuster"]="nmap"
    ["sqlmap"]="nikto"
    ["wpscan"]="nmap"
    ["dirb"]="nmap"
)

# Technology → Tool mapping
declare -gA TECH_TOOLS=(
    ["wordpress"]="wpscan,nikto,gobuster"
    ["apache"]="nikto,gobuster"
    ["nginx"]="nikto,gobuster"
    ["mysql"]="sqlmap"
    ["php"]="nikto"
    ["nodejs"]="retire.js"
    ["tomcat"]="nikto,gobuster"
)

# Tool execution times (estimates in seconds)
declare -gA TOOL_TIMES=(
    ["nmap"]=120
    ["nikto"]=300
    ["gobuster"]=180
    ["wpscan"]=240
    ["sqlmap"]=600
    ["dirb"]=200
)

#==============================================================================
# TECHNOLOGY DETECTION
#==============================================================================

detect_technologies() {
    local target="$1"
    local port="${2:-80}"
    local protocol="${3:-http}"
    
    local url="${protocol}://${target}:${port}"
    local technologies=()
    
    print_info "Detecting technologies on ${url}..."
    
    # HTTP headers analysis
    local headers
    headers=$(curl -skI "$url" 2>/dev/null || true)
    
    # Server detection
    if echo "$headers" | grep -qi "Server.*Apache"; then
        technologies+=("apache")
    elif echo "$headers" | grep -qi "Server.*nginx"; then
        technologies+=("nginx")
    elif echo "$headers" | grep -qi "Server.*Tomcat"; then
        technologies+=("tomcat")
    fi
    
    # Technology detection from headers  
    if echo "$headers" | grep -qi "X-Powered-By.*PHP"; then
        technologies+=("php")
    fi
    
    # WordPress detection
    local response
    response=$(curl -sk "$url" 2>/dev/null || true)
    
    if echo "$response" | grep -qi "wp-content\|wp-includes\|wordpress"; then
        technologies+=("wordpress")
        print_success "  → WordPress detected"
    fi
    
    # Database hints
    if echo "$response" | grep -qiE "mysql|mysqli"; then
        technologies+=("mysql")
    fi
    
    # Node.js detection
    if echo "$headers" | grep -qi "X-Powered-By.*Express"; then
        technologies+=("nodejs")
    fi
    
    # Export for use by other functions
    if [[ ${#technologies[@]} -gt 0 ]]; then
        printf '%s\n' "${technologies[@]}" > "${REPORT_DIR}/.detected_technologies.txt"
        print_success "Detected: ${technologies[*]}"
    else
        print_warn "No specific technologies detected, using default tools"
    fi
    
    echo "${technologies[@]}"
}

#==============================================================================
# EXECUTION PLAN BUILDER
#==============================================================================

build_execution_plan() {
    local technologies=("$@")
    local tools_to_run=()
    
    # Always run nmap first
    tools_to_run+=("nmap")
    
    # Add technology-specific tools
    for tech in "${technologies[@]}"; do
        if [[ -n "${TECH_TOOLS[$tech]:-}" ]]; then
            IFS=',' read -ra tech_tools <<< "${TECH_TOOLS[$tech]}"
            for tool in "${tech_tools[@]}"; do
                # Add if not already in list
                if [[ ! " ${tools_to_run[*]} " =~ " ${tool} " ]]; then
                    tools_to_run+=("$tool")
                fi
            done
        fi
    done
    
    # If no tech detected, use baseline tools
    if [[ ${#tools_to_run[@]} -eq 1 ]]; then
        tools_to_run+=("nikto" "gobuster")
    fi
    
    # Resolve dependencies and order tools
    local ordered_tools
    ordered_tools=$(topological_sort "${tools_to_run[@]}")
    
    echo "$ordered_tools"
}

#==============================================================================
# DEPENDENCY RESOLUTION
#==============================================================================

topological_sort() {
    local tools=("$@")
    local sorted=()
    local visited=()
    
    visit_tool() {
        local tool="$1"
        
        # Skip if already visited
        if [[ " ${visited[*]} " =~ " ${tool} " ]]; then
            return
        fi
        
        # Visit dependencies first
        local dep="${TOOL_DEPS[$tool]:-}"
        if [[ -n "$dep" ]]; then
            visit_tool "$dep"
        fi
        
        # Mark as visited and add to sorted
        visited+=("$tool")
        sorted+=("$tool")
    }
    
    # Visit all tools
    for tool in "${tools[@]}"; do
        visit_tool "$tool"
    done
    
    echo "${sorted[@]}"
}

#==============================================================================
# PARALLEL EXECUTION MANAGER
#==============================================================================

execute_parallel_safe() {
    local tools=("$@")
    local running_jobs=0
    local completed=0
    local total=${#tools[@]}
    
    print_header "Execution Plan"
    echo "Tools to run: ${tools[*]}"
    echo "Max parallel: ${MAX_PARALLEL}"
    echo ""
    
    for tool in "${tools[@]}"; do
        # Wait if at capacity
        while (( running_jobs >= MAX_PARALLEL )); do
            sleep 1
            running_jobs=$(jobs -r | wc -l)
        done
        
        # Execute tool
        print_info "[$((completed + 1))/$total] Launching: $tool"
        execute_tool "$tool" &
        
        ((running_jobs++))
        ((completed++))
        
        # Small delay to avoid race conditions
        sleep 0.5
    done
    
    # Wait for all jobs to complete
    wait
    print_success "All tools completed"
}

execute_tool() {
    local tool="$1"
    
    case "$tool" in
        nmap)
            if command_exists nmap; then
                nmap -sS -sV -Pn -T4 -p "$PORT" "$TARGET" \
                    -oA "${REPORT_DIR}/${TARGET}_nmap_${tool}" 2>&1 | \
                    tee "${REPORT_DIR}/${tool}.log" | \
                    grep -E "^\[.*\]|Discovered|PORT"
            fi
            ;;
        nikto)
            if command_exists nikto; then
                nikto -h "${PROTOCOL}://${TARGET}:${PORT}" \
                    -output "${REPORT_DIR}/${TARGET}_nikto.txt" \
                    2>&1 > "${REPORT_DIR}/nikto.log"
            fi
            ;;
        gobuster)
            if command_exists gobuster; then
                local wordlist="/usr/share/wordlists/dirb/common.txt"
                [[ -f "$wordlist" ]] && \
                gobuster dir -u "${PROTOCOL}://${TARGET}:${PORT}" \
                    -w "$wordlist" -q \
                    -o "${REPORT_DIR}/${TARGET}_gobuster.txt" \
                    2>&1 > "${REPORT_DIR}/gobuster.log"
            fi
            ;;
        wpscan)
            if command_exists wpscan; then
                wpscan --url "${PROTOCOL}://${TARGET}:${PORT}" \
                    --no-banner --no-update \
                    -o "${REPORT_DIR}/${TARGET}_wpscan.txt" \
                    2>&1 > "${REPORT_DIR}/wpscan.log"
            fi
            ;;
    esac
}

#==============================================================================
# PROGRESS TRACKING
#==============================================================================

estimate_duration() {
    local tools=("$@")
    local total_time=0
    
    for tool in "${tools[@]}"; do
        total_time=$((total_time + ${TOOL_TIMES[$tool]:-60}))
    done
    
    # Account for parallelism (rough estimate)
    total_time=$((total_time / MAX_PARALLEL))
    
    echo "$total_time"
}

format_duration() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))
    
    if (( minutes > 0 )); then
        echo "${minutes}m ${remaining_seconds}s"
    else
        echo "${seconds}s"
    fi
}

#==============================================================================
# MAIN ORCHESTRATION
#==============================================================================

orchestrate_scan() {
    local target="$1"
    local port="${2:-80}"
    local protocol="${3:-http}"
    
    export TARGET="$target"
    export PORT="$port"
    export PROTOCOL="$protocol"
    
    print_header "WAES Orchestrated Scan"
    echo "Target: ${protocol}://${target}:${port}"
    echo ""
    
    # Step 1: Detect technologies
    local technologies
    technologies=($(detect_technologies "$target" "$port" "$protocol"))
    
    # Step 2: Build execution plan
    print_info "Building execution plan..."
    local tools
    tools=($(build_execution_plan "${technologies[@]}"))
    
    # Step 3: Estimate duration
    local estimated_duration
    estimated_duration=$(estimate_duration "${tools[@]}")
    print_info "Estimated duration: $(format_duration $estimated_duration)"
    echo ""
    
    # Step 4: Execute tools
    execute_parallel_safe "${tools[@]}"
    
    # Step 5: Aggregate results
    print_info "Aggregating findings..."
    aggregate_findings
    
    print_success "Orchestrated scan completed!"
}

aggregate_findings() {
    # Combine all findings into a summary
    local findings_file="${REPORT_DIR}/.aggregated_findings.txt"
    
    {
        echo "=== Scan Summary ==="
        echo "Timestamp: $(date)"
        echo "Target: ${TARGET}:${PORT}"
        echo ""
        
        # Count findings per tool
        for log in "${REPORT_DIR}"/*.log; do
            [[ -f "$log" ]] || continue
            local tool=$(basename "$log" .log)
            local line_count=$(wc -l < "$log")
            echo "${tool}: ${line_count} lines"
        done
    } > "$findings_file"
    
    print_success "Findings aggregated to: $findings_file"
}

#==============================================================================
# CLI INTERFACE
#==============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <target> [port] [protocol]"
        exit 1
    fi
    
    orchestrate_scan "$@"
fi
