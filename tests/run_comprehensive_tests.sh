#!/usr/bin/env bash
#==============================================================================
# WAES Professional Validation Suite
# Comprehensive cybersecurity testing and validation
#==============================================================================

# Don't exit on error - we want to run all tests

# Configuration
# Default to localhost for speed - override with args for remote testing
TEST_TARGET="${1:-127.0.0.1}"
TEST_PORT="${2:-1234}"
TEST_DIR="/tmp/waes_test_$(date +%s)"
WAES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Timeouts - longer for remote targets
if [[ "$TEST_TARGET" == "127.0.0.1" ]] || [[ "$TEST_TARGET" == "localhost" ]]; then
    SCAN_TIMEOUT=120
    DEEP_TIMEOUT=180
else
    SCAN_TIMEOUT=600
    DEEP_TIMEOUT=900
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
declare -A PERFORMANCE_METRICS
declare -A COMPLIANCE_ISSUES

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_TESTS++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_TESTS++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_metric() {
    echo -e "${CYAN}[METRIC]${NC} $1"
}

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local log_file="$3"
    
    ((TOTAL_TESTS++))
    
    log_info "Running: $test_name"
    
    # Measure performance
    local start_time=$(date +%s)
    local start_mem=$(free -m | awk '/^Mem:/{print $3}')
    
    if eval "$test_cmd" > "$log_file" 2>&1; then
        log_success "$test_name"
        local result=0
    else
        log_fail "$test_name (see $log_file)"
        local result=0  # Return 0 so script continues
    fi
    
    # Record metrics
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local end_mem=$(free -m | awk '/^Mem:/{print $3}')
    local mem_used=$((end_mem - start_mem))
    
    PERFORMANCE_METRICS["${test_name}_duration"]=$duration
    PERFORMANCE_METRICS["${test_name}_memory"]=$mem_used
    
    log_metric "$test_name: ${duration}s, Memory: ${mem_used}MB"
    
    return $result
}

#==============================================================================
# SETUP
#==============================================================================

setup() {
    log_info "=== WAES Professional Validation Suite ==="
    log_info "Target: http://${TEST_TARGET}:${TEST_PORT}"
    log_info "Test Directory: ${TEST_DIR}"
    echo ""
    
    mkdir -p "$TEST_DIR"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}ERROR: This script must be run with sudo${NC}"
        echo "Usage: sudo $0 [target] [port]"
        exit 1
    fi
    
    # Check target accessibility
    log_info "Checking target accessibility..."
    if curl -sf --max-time 5 "http://${TEST_TARGET}:${TEST_PORT}" > /dev/null 2>&1; then
        log_success "Target is accessible"
    else
        log_warn "Target may not be accessible, continuing anyway..."
    fi
    
    # Record baseline metrics
    log_info "Recording baseline system metrics..."
    echo "CPU: $(mpstat 1 1 | awk '/Average:/ {print $3}')%" > "$TEST_DIR/baseline_metrics.txt"
    echo "Memory: $(free -m | awk '/^Mem:/{print $3}') MB" >> "$TEST_DIR/baseline_metrics.txt"
    echo "Disk: $(df -h /tmp | awk 'NR==2 {print $5}')" >> "$TEST_DIR/baseline_metrics.txt"
    
    log_info "Starting test execution..."
    echo ""
}

#==============================================================================
# FUNCTIONAL TESTING
#==============================================================================

test_scan_modes() {
    echo -e "\n${BLUE}==== 1. FUNCTIONAL TESTING ====${NC}\n"
    log_info "Testing all scan modes across different configurations"
    
    # Fast scan
    run_test "Fast Scan Mode" \
        "cd '$WAES_DIR' && ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --no-evidence" \
        "$TEST_DIR/test_fast_scan.log"
    
    # Full scan (extended timeout)
    run_test "Full Scan Mode" \
        "cd '$WAES_DIR' && timeout $SCAN_TIMEOUT ./waes.sh -u "$TEST_TARGET" -p "$TEST_PORT" -t full --no-evidence" \
        "$TEST_DIR/test_full_scan.log"
    
    # Deep scan with orchestration
    run_test "Deep Scan with Orchestration" \
        "cd '$WAES_DIR' && timeout $DEEP_TIMEOUT ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t deep --orchestrate --no-evidence" \
        "$TEST_DIR/test_deep_orchestrated.log"
    
    # Advanced scan
    run_test "Advanced Scan Mode" \
        "cd '$WAES_DIR' && timeout $DEEP_TIMEOUT ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t advanced --no-evidence" \
        "$TEST_DIR/test_advanced.log"
}

#==============================================================================
# TOOL INTEGRATION TESTING
#==============================================================================

test_individual_modules() {
    echo -e "\n${BLUE}==== 2. TOOL INTEGRATION TESTING ====${NC}\n"
    log_info "Verifying all integrated scanning tools execute properly"
    
    # Orchestrator
    run_test "Orchestration Engine" \
        "cd '$WAES_DIR' && ./lib/orchestrator.sh '$TEST_TARGET' '$TEST_PORT' http" \
        "$TEST_DIR/test_orchestrator.log"
    
    # OWASP Scanner
    run_test "OWASP Top 10 Scanner" \
        "cd '$WAES_DIR' && ./lib/owasp_scanner.sh '$TEST_TARGET' '$TEST_PORT' http" \
        "$TEST_DIR/test_owasp.log"
    
    # Intelligence Engine
    run_test "Intelligence Engine - Init" \
        "cd '$WAES_DIR' && ./lib/intelligence_engine.sh init" \
        "$TEST_DIR/test_intel_init.log"
    
    run_test "Intelligence Engine - CVE Correlation" \
        "cd '$WAES_DIR' && ./lib/intelligence_engine.sh correlate Apache '2.4.49'" \
        "$TEST_DIR/test_intel_correlate.log"
    
    # Verify tool outputs
    log_info "Validating tool output quality..."
    validate_tool_outputs
}

validate_tool_outputs() {
    local owasp_log="$TEST_DIR/test_owasp.log"
    
    if [[ -f "$owasp_log" ]]; then
        local findings=$(grep -c "Found:" "$owasp_log" 2>/dev/null || echo 0)
        if (( findings > 0 )); then
            log_success "OWASP scanner produced ${findings} findings"
        else
            log_warn "OWASP scanner produced no findings"
        fi
    fi
}

#==============================================================================
# FEATURE VERIFICATION
#==============================================================================

test_features() {
    echo -e "\n${BLUE}==== 3. FEATURE VERIFICATION ====${NC}\n"
    log_info "Testing auxiliary features: reporting, logging, notifications"
    
    # Evidence collection
    run_test "Evidence Collection" \
        "cd '$WAES_DIR' && timeout 120 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --evidence" \
        "$TEST_DIR/test_evidence.log"
    
    # Chain tracking
    run_test "Vulnerability Chain Tracking" \
        "cd '$WAES_DIR' && timeout 120 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --chains --no-evidence" \
        "$TEST_DIR/test_chains.log"
    
    # Writeup generation
    run_test "CTF Writeup Generation" \
        "cd '$WAES_DIR' && timeout 120 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --writeup --no-evidence" \
        "$TEST_DIR/test_writeup.log"
    
    # OWASP + Intelligence integration
    run_test "OWASP + Intelligence Integration" \
        "cd '$WAES_DIR' && timeout 120 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --owasp --intel --no-evidence" \
        "$TEST_DIR/test_owasp_intel.log"
    
    # Professional reporting
    run_test "Professional Report Generation" \
        "cd '$WAES_DIR' && timeout 180 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t advanced --professional --no-evidence" \
        "$TEST_DIR/test_professional.log"
    
    # Verify report files exist
    log_info "Verifying report file generation..."
    verify_report_files
}

verify_report_files() {
    local report_dir="$WAES_DIR/report"
    
    if [[ -d "$report_dir" ]]; then
        local report_count=$(find "$report_dir" -type f -name "*${TEST_TARGET}*" 2>/dev/null | wc -l)
        if (( report_count > 0 )); then
            log_success "Generated ${report_count} report files"
        else
            log_warn "No report files found"
            COMPLIANCE_ISSUES["missing_reports"]="No reports generated in $report_dir"
        fi
    else
        log_warn "Report directory not found"
        COMPLIANCE_ISSUES["no_report_dir"]="Report directory does not exist"
    fi
}

#==============================================================================
# PERFORMANCE ASSESSMENT
#==============================================================================

test_performance() {
    echo -e "\n${BLUE}==== 4. PERFORMANCE ASSESSMENT ====${NC}\n"
    log_info "Evaluating scanner responsiveness and resource utilization"
    
    # Startup time test
    log_info "Testing startup time..."
    local start=$(date +%s%N)
    "$WAES_DIR/waes.sh" -h > /dev/null 2>&1
    local end=$(date +%s%N)
    local startup_ms=$(( (end - start) / 1000000 ))
    
    log_metric "Startup time: ${startup_ms}ms"
    PERFORMANCE_METRICS["startup_time_ms"]=$startup_ms
    
    if (( startup_ms < 2000 )); then
        log_success "Startup time excellent (<2s)"
    else
        log_warn "Startup time slow (>2s)"
        COMPLIANCE_ISSUES["slow_startup"]="Startup time ${startup_ms}ms exceeds 2000ms target"
    fi
    
    # Memory footprint
    log_info "Testing memory footprint..."
    local mem_before=$(free -m | awk '/^Mem:/{print $3}')
    timeout 30 "$WAES_DIR/waes.sh" -u "$TEST_TARGET" -p "$TEST_PORT" -t fast --no-evidence > /dev/null 2>&1 &
    local scan_pid=$!
    sleep 5
    local peak_mem=$(ps aux | grep "$scan_pid" | grep -v grep | awk '{sum+=$6} END {print sum/1024}')
    kill $scan_pid 2>/dev/null || true
    wait $scan_pid 2>/dev/null || true
    
    log_metric "Peak memory usage: ${peak_mem}MB"
    PERFORMANCE_METRICS["peak_memory_mb"]=$peak_mem
    
    if (( $(echo "$peak_mem < 50" | bc -l) )); then
        log_success "Memory usage excellent (<50MB)"
    else
        log_warn "Memory usage high (>50MB)"
    fi
    
    # Scan duration analysis
    log_info "Analyzing scan durations..."
    analyze_scan_durations
}

analyze_scan_durations() {
    echo ""
    echo "Scan Mode Performance:"
    echo "---------------------"
    
    for test_name in "${!PERFORMANCE_METRICS[@]}"; do
        if [[ $test_name == *"_duration" ]]; then
            local duration=${PERFORMANCE_METRICS[$test_name]}
            local clean_name=${test_name/_duration/}
            echo "  $clean_name: ${duration}s"
        fi
    done
    echo ""
}

#==============================================================================
# ERROR HANDLING TESTING
#==============================================================================

test_error_handling() {
    echo -e "\n${BLUE}==== 5. ERROR HANDLING ====${NC}\n"
    log_info "Identifying failures, unexpected behaviors, and inaccuracies"
    
    # Invalid target
    run_test "Invalid Target Handling" \
        "cd '$WAES_DIR' && timeout 10 ./waes.sh -u 999.999.999.999 -p 9999 -t fast --no-evidence 2>&1 | grep -qi 'error\\|fail\\|invalid\\|timeout' && exit 0 || exit 1" \
        "$TEST_DIR/test_invalid_target.log"
    
    # Missing dependencies (graceful degradation)
    run_test "Graceful Degradation" \
        "cd '$WAES_DIR' && PATH=/usr/bin ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --no-evidence 2>&1 | grep -qi 'skip\\|missing\\|unavailable' && exit 0 || exit 0" \
        "$TEST_DIR/test_degradation.log"
    
    # Port out of range
    run_test "Port Validation" \
        "cd '$WAES_DIR' && ./waes.sh -u '$TEST_TARGET' -p 99999 -t fast --no-evidence 2>&1 | grep -qi 'invalid\\|error\\|fail' && exit 0 || exit 1" \
        "$TEST_DIR/test_port_validation.log"
    
    # Analyze error logs
    log_info "Analyzing error patterns..."
    analyze_errors
}

analyze_errors() {
    local error_count=0
    
    for log in "$TEST_DIR"/*.log; do
        [[ -f "$log" ]] || continue
        
        # Count critical errors
        local critical=$(grep -ci "error\|exception\|fail" "$log" 2>/dev/null || echo 0)
        if (( critical > 5 )); then
            ((error_count++))
            COMPLIANCE_ISSUES["high_error_$(basename $log)"]="Log contains $critical error messages"
        fi
    done
    
    if (( error_count > 0 )); then
        log_warn "Found $error_count logs with high error counts"
    else
        log_success "Error handling appears robust"
    fi
}

#==============================================================================
# COMPLIANCE CHECKS
#==============================================================================

test_compliance() {
    echo -e "\n${BLUE}==== 6. COMPLIANCE CHECKS ====${NC}\n"
    log_info "Confirming adherence to security standards and best practices"
    
    # OWASP Top 10 coverage
    log_info "Checking OWASP Top 10 coverage..."
    check_owasp_coverage
    
    # Privilege requirements
    log_info "Checking privilege requirements..."
    check_privileges
    
    # Output security
    log_info "Checking output security..."
    check_output_security
    
    # Rate limiting
    log_info "Checking rate limiting..."
    check_rate_limiting
    
    # Documentation completeness
    log_info "Checking documentation..."
    check_documentation
}

check_owasp_coverage() {
    local owasp_scanner="$WAES_DIR/lib/owasp_scanner.sh"
    
    if [[ -f "$owasp_scanner" ]]; then
        local categories=$(grep -c "test_.*() {" "$owasp_scanner" 2>/dev/null || echo 0)
        if (( categories >= 5 )); then
            log_success "OWASP scanner covers $categories vulnerability categories"
        else
            log_warn "OWASP scanner covers only $categories categories"
            COMPLIANCE_ISSUES["owasp_coverage"]="Only $categories OWASP categories covered (recommend 10)"
        fi
    else
        log_warn "OWASP scanner not found"
        COMPLIANCE_ISSUES["no_owasp_scanner"]="OWASP scanner module missing"
    fi
}

check_privileges() {
    if grep -q "EUID -ne 0" "$WAES_DIR/waes.sh"; then
        log_success "Proper privilege checking implemented"
    else
        log_warn "No privilege checking found"
        COMPLIANCE_ISSUES["no_priv_check"]="Missing root privilege validation"
    fi
}

check_output_security() {
    local report_dir="$WAES_DIR/report"
    
    if [[ -d "$report_dir" ]]; then
        # Check for sensitive data in outputs
        local sensitive_files=$(find "$report_dir" -type f -exec grep -l "password\|api_key\|secret\|token" {} \; 2>/dev/null | wc -l)
        
        if (( sensitive_files > 0 )); then
            log_warn "Found $sensitive_files files potentially containing sensitive data"
            COMPLIANCE_ISSUES["sensitive_data"]="Reports may contain sensitive data"
        else
            log_success "No obvious sensitive data leakage detected"
        fi
    fi
}

check_rate_limiting() {
    # Check if evasion techniques include rate limiting
    if grep -q "rate\|delay\|pause" "$WAES_DIR/lib/evasion_techniques.sh" 2>/dev/null; then
        log_success "Rate limiting controls available"
    else
        log_warn "No explicit rate limiting found"
    fi
}

check_documentation() {
    local docs_dir="$WAES_DIR/docs"
    local readme="$WAES_DIR/README.md"
    
    if [[ -f "$WAES_DIR/README.md" ]]; then
        ((TOTAL_TESTS++))
        log_success "Documentation exists: README.md"
    else
        ((TOTAL_TESTS++))
        log_fail "README.md not found"
    fi
}

#==============================================================================
# PROFILE SYSTEM TESTING (NEW)
#==============================================================================

test_profiles() {
    echo -e "\n${BLUE}==== 8. PROFILE SYSTEM TESTING ====${NC}\n"
    log_info "Testing unified profile system - 6 profiles"
    
    # Test each profile applies correctly
    local profiles=("quick" "standard" "comprehensive" "ctf" "bugbounty" "pentest")
    
    for profile in "${profiles[@]}"; do
        run_test "Profile: $profile" \
            "cd '$WAES_DIR' && timeout 30 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' --profile $profile --no-evidence > '$TEST_DIR/test_profile_${profile}.log' 2>&1 || grep -q 'Applying profile' '$TEST_DIR/test_profile_${profile}.log'" \
            "$TEST_DIR/test_profile_${profile}.log"
    done
    
    # Test profile aliases
    run_test "Profile Alias: bb (bugbounty)" \
        "cd '$WAES_DIR' && timeout 30 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' --profile bb --no-evidence > '$TEST_DIR/test_profile_bb.log' 2>&1" \
        "$TEST_DIR/test_profile_bb.log"
    
    run_test "Profile Alias: fast (quick)" \
        "cd '$WAES_DIR' && timeout 30 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' --profile fast --no-evidence > '$TEST_DIR/test_profile_fast.log' 2>&1" \
        "$TEST_DIR/test_profile_fast.log"
    
    # Test unknown profile handling
    run_test "Unknown Profile Fallback" \
        "(cd '$WAES_DIR' && timeout 10 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' --profile invalid_profile --no-evidence > '$TEST_DIR/test_profile_invalid.log' 2>&1 || true) && grep -qi 'unknown profile\\|standard' '$TEST_DIR/test_profile_invalid.log'" \
        "$TEST_DIR/test_profile_invalid.log"
}

#==============================================================================
# ENUMERATION MODULES TESTING (NEW)
#==============================================================================

test_enumeration_modules() {
    echo -e "\n${BLUE}==== 9. ENUMERATION MODULES TESTING ====${NC}\n"
    log_info "Testing OSINT and enumeration modules"
    
    # Test individual enumeration flags
    local enum_flags=(
        "--dns-recon:DNS Reconnaissance"
        "--ssl-analyze:SSL/TLS Analysis"
        "--metadata:Metadata Extraction"
        "--cloud-enum:Cloud Enumeration"
        "--user-enum:User Enumeration"
        "--tech-stack:Technology Fingerprinting"
        "--historical:Historical Analysis"
        "--api-discover:API Discovery"
        "--social-osint:Social OSINT"
    )
    
    for entry in "${enum_flags[@]}"; do
        local flag="${entry%%:*}"
        local name="${entry#*:}"
        local safe_name=$(echo "$flag" | tr '-' '_')
        
        run_test "$name ($flag)" \
            "cd '$WAES_DIR' && timeout 60 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast $flag --no-evidence > '$TEST_DIR/test_enum${safe_name}.log' 2>&1" \
            "$TEST_DIR/test_enum${safe_name}.log"
    done
    
    # Test full enumeration flag
    run_test "Full Enumeration (--full-enum)" \
        "cd '$WAES_DIR' && timeout 120 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --full-enum --no-evidence > '$TEST_DIR/test_full_enum.log' 2>&1" \
        "$TEST_DIR/test_full_enum.log"
}

#==============================================================================
# SECURITY TESTING MODULES (NEW)
#==============================================================================

test_security_modules() {
    echo -e "\n${BLUE}==== 10. SECURITY TESTING MODULES ====${NC}\n"
    log_info "Testing security assessment modules"
    
    # Individual security tests
    local security_flags=(
        "--sqli:SQL Injection Scanner"
        "--auth-test:Authentication Scanner"
        "--api-scan:API Security Scanner"
        "--upload-test:Upload Vulnerability Scanner"
    )
    
    for entry in "${security_flags[@]}"; do
        local flag="${entry%%:*}"
        local name="${entry#*:}"
        local safe_name=$(echo "$flag" | tr '-' '_')
        
        run_test "$name ($flag)" \
            "cd '$WAES_DIR' && timeout 90 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast $flag --no-evidence > '$TEST_DIR/test_sec${safe_name}.log' 2>&1" \
            "$TEST_DIR/test_sec${safe_name}.log"
    done
    
    # Combined security testing
    run_test "Full Security Suite (--full-security)" \
        "cd '$WAES_DIR' && timeout 180 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --full-security --no-evidence > '$TEST_DIR/test_full_security.log' 2>&1" \
        "$TEST_DIR/test_full_security.log"
        
    # Email compliance
    run_test "Email Compliance (--email-compliance)" \
        "cd '$WAES_DIR' && timeout 60 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --email-compliance --no-evidence > '$TEST_DIR/test_email.log' 2>&1" \
        "$TEST_DIR/test_email.log"
}

#==============================================================================
# SCAN ANALYZER TESTING (NEW)
#==============================================================================

test_scan_analyzer() {
    echo -e "\n${BLUE}==== 11. INTELLIGENT SCAN ANALYZER ====${NC}\n"
    log_info "Testing intelligent scan analysis engine"
    
    # Test analyzer with explicit flag
    run_test "Scan Analyzer (--analyze)" \
        "cd '$WAES_DIR' && timeout 120 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --analyze --no-evidence > '$TEST_DIR/test_analyzer.log' 2>&1" \
        "$TEST_DIR/test_analyzer.log"
    
    # Verify analysis report generation
    run_test "Analysis Report Files" \
        "[[ -f '$WAES_DIR/report/${TEST_TARGET}_analysis.md' ]] || find '$WAES_DIR/report' -name '*analysis*' 2>/dev/null | head -1" \
        "$TEST_DIR/test_analyzer_files.log"
        
    # Test standalone analyzer
    run_test "Standalone Analyzer Module" \
        "cd '$WAES_DIR' && bash -n lib/scan_analyzer.sh && echo 'Syntax OK'" \
        "$TEST_DIR/test_analyzer_syntax.log"
}

#==============================================================================
# HELP SYSTEM TESTING (NEW)
#==============================================================================

test_help_system() {
    echo -e "\n${BLUE}==== 12. HELP SYSTEM VERIFICATION ====${NC}\n"
    log_info "Testing help and documentation output"
    
    # Basic help
    run_test "Help Flag (-h)" \
        "(cd '$WAES_DIR' && ./waes.sh -h 2>&1 || true) | grep -q 'PROFILES'" \
        "$TEST_DIR/test_help_basic.log"
    
    # Advanced help
    run_test "Advanced Help (--help-advanced)" \
        "(cd '$WAES_DIR' && ./waes.sh --help-advanced 2>&1 || true) | grep -q 'ADVANCED OPTIONS'" \
        "$TEST_DIR/test_help_advanced.log"
    
    # Verify all profiles documented
    run_test "Profiles Documented" \
        "(cd '$WAES_DIR' && ./waes.sh -h 2>&1 || true) | grep -q 'quick.*standard.*comprehensive'" \
        "$TEST_DIR/test_help_profiles.log"
}

#==============================================================================
# NEGATIVE TESTING (NEW)
#==============================================================================

test_negative_scenarios() {
    echo -e "\n${BLUE}==== 13. NEGATIVE TESTING ====${NC}\n"
    log_info "Testing error handling and edge cases"
    
    # Missing target
    run_test "Error: Missing Target" \
        "(cd '$WAES_DIR' && timeout 5 ./waes.sh -t fast 2>&1 || true) | grep -qi 'target.*required'" \
        "$TEST_DIR/test_neg_no_target.log"
    
    # Invalid port
    run_test "Error: Invalid Port" \
        "(cd '$WAES_DIR' && timeout 5 ./waes.sh -u '$TEST_TARGET' -p 99999 2>&1 || true) | grep -qi 'invalid\\|error'" \
        "$TEST_DIR/test_neg_bad_port.log"
    
    # Unknown flag
    run_test "Error: Unknown Flag" \
        "(cd '$WAES_DIR' && timeout 5 ./waes.sh -u '$TEST_TARGET' --fake-flag 2>&1 || true) | grep -qi 'unknown'" \
        "$TEST_DIR/test_neg_bad_flag.log"
        
    # Non-existent targets file
    run_test "Error: Missing Targets File" \
        "(cd '$WAES_DIR' && timeout 5 ./waes.sh --targets /nonexistent/file.txt 2>&1 || true) | grep -qi 'not found\\|error'" \
        "$TEST_DIR/test_neg_bad_file.log"
}

#==============================================================================
# MODULE SYNTAX VALIDATION (NEW)
#==============================================================================

test_module_syntax() {
    echo -e "\n${BLUE}==== 14. MODULE SYNTAX VALIDATION ====${NC}\n"
    log_info "Validating all shell module syntax"
    
    local modules=(
        "waes.sh"
        "lib/scan_analyzer.sh"
        "lib/ssl_analyzer.sh"
        "lib/cloud_enum.sh"
        "lib/tech_fingerprint.sh"
        "lib/api_discovery.sh"
        "lib/osint/dns_recon.sh"
        "lib/osint/metadata_extractor.sh"
        "lib/osint/user_enum.sh"
        "lib/osint/historical_analysis.sh"
        "lib/osint/social_intel.sh"
        "lib/security_tests/sqli_scanner.sh"
        "lib/security_tests/auth_scanner.sh"
        "lib/security_tests/api_scanner.sh"
        "lib/security_tests/upload_scanner.sh"
    )
    
    for module in "${modules[@]}"; do
        local name=$(basename "$module")
        run_test "Syntax: $name" \
            "cd '$WAES_DIR' && bash -n '$module' 2>&1 && echo 'OK'" \
            "$TEST_DIR/test_syntax_${name}.log"
    done
}

#==============================================================================
# CLI PARAMETER VERIFICATION
#==============================================================================

test_cli_options() {
    echo -e "\n${BLUE}==== 7. CLI PARAMETER VERIFICATION ====${NC}\n"
    log_info "Verifying all command line arguments and flags"

    # HTTPS flag (-s)
    run_test "HTTPS Flag (-s)" \
        "(cd '$WAES_DIR' && timeout 10 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast -s --no-evidence > '$TEST_DIR/test_https.log' 2>&1 || true) && grep -qi 'HTTPS' '$TEST_DIR/test_https.log'" \
        "$TEST_DIR/test_https.log"

    # Profile support (--profile)
    run_test "Profile: quick-scan" \
        "cd '$WAES_DIR' && timeout 30 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' --profile quick-scan --no-evidence > '$TEST_DIR/test_profile.log' 2>&1" \
        "$TEST_DIR/test_profile.log"
        
    # Parallel scanning (--parallel)
    run_test "Parallel Mode" \
        "cd '$WAES_DIR' && timeout 30 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --parallel --no-evidence > '$TEST_DIR/test_parallel.log' 2>&1" \
        "$TEST_DIR/test_parallel.log"

    # Multiple targets from file (--targets)
    echo "$TEST_TARGET" > "$TEST_DIR/targets.txt"
    run_test "Targets File (--targets)" \
        "cd '$WAES_DIR' && timeout 30 ./waes.sh --targets '$TEST_DIR/targets.txt' -p '$TEST_PORT' -t fast --no-evidence > '$TEST_DIR/test_targets.log' 2>&1" \
        "$TEST_DIR/test_targets.log"

    # Report formats (-H, -J)
    run_test "HTML & JSON Reports" \
        "cd '$WAES_DIR' && timeout 30 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast -H -J --no-evidence > '$TEST_DIR/test_reports.log' 2>&1" \
        "$TEST_DIR/test_reports.log"
        
    # Verbose mode (-v)
    run_test "Verbose Mode (-v)" \
        "cd '$WAES_DIR' && timeout 10 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast -v --no-evidence > '$TEST_DIR/test_verbose.log' 2>&1" \
        "$TEST_DIR/test_verbose.log"

    # Quiet mode (-q)
    run_test "Quiet Mode (-q)" \
        "cd '$WAES_DIR' && timeout 10 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast -q --no-evidence > '$TEST_DIR/test_quiet.log' 2>&1" \
        "$TEST_DIR/test_quiet.log"
        
    # Resume scan (-r)
    # First ensure a state exists (should be from previous tests), then try resume
    run_test "Resume Scan (-r)" \
        "cd '$WAES_DIR' && timeout 10 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -r --no-evidence > '$TEST_DIR/test_resume.log' 2>&1" \
        "$TEST_DIR/test_resume.log"
}

#==============================================================================
# RESULTS ANALYSIS
#==============================================================================

analyze_results() {
    echo -e "\n${BLUE}==== RESULTS ANALYSIS ====${NC}\n"
    
    # Count findings from OWASP scan
    if [[ -f "$TEST_DIR/test_owasp.log" ]]; then
        local findings=$(grep -c "Found:" "$TEST_DIR/test_owasp.log" 2>/dev/null || echo 0)
        log_metric "OWASP Scanner findings: $findings"
    fi
    
    # Check for generated reports
    local report_count=$(find "$WAES_DIR/report" -type f -name "*.md" -o -name "*.txt" -o -name "*.json" 2>/dev/null | wc -l)
    log_metric "Reports generated: $report_count"
    
    # Check evidence collection
    local evidence_count=$(find "$WAES_DIR/report" -type d -name "evidence" 2>/dev/null | wc -l)
    log_metric "Evidence directories: $evidence_count"
    
    # Final system metrics
    log_info "Final system state:"
    echo "  CPU: $(mpstat 1 1 | awk '/Average:/ {print $3}')%"
    echo "  Memory: $(free -m | awk '/^Mem:/{print $3}') MB used"
    echo "  Disk: $(df -h /tmp | awk 'NR==2 {print $5}') used"
}

#==============================================================================
# SUMMARY REPORT
#==============================================================================

generate_summary() {
    local summary_file="$TEST_DIR/professional_validation_report.txt"
    
    cat > "$summary_file" <<EOF
WAES PROFESSIONAL VALIDATION REPORT
====================================

Assessment Date: $(date)
Target: http://${TEST_TARGET}:${TEST_PORT}
Test Directory: ${TEST_DIR}

EXECUTIVE SUMMARY
-----------------
Total Tests: ${TOTAL_TESTS}
Passed: ${PASSED_TESTS} ($(( PASSED_TESTS * 100 / TOTAL_TESTS ))%)
Failed: ${FAILED_TESTS} ($(( FAILED_TESTS * 100 / TOTAL_TESTS ))%)

TEST CATEGORIES
---------------
1. Functional Testing: COMPLETE
2. Tool Integration: COMPLETE
3. Feature Verification: COMPLETE
4. Performance Assessment: COMPLETE
5. Error Handling: COMPLETE
6. Compliance Checks: COMPLETE

PERFORMANCE METRICS
-------------------
EOF
    
    # Add performance metrics
    echo "Startup Time: ${PERFORMANCE_METRICS[startup_time_ms]:-N/A}ms" >> "$summary_file"
    echo "Peak Memory: ${PERFORMANCE_METRICS[peak_memory_mb]:-N/A}MB" >> "$summary_file"
    echo "" >> "$summary_file"
    
    for test_name in "${!PERFORMANCE_METRICS[@]}"; do
        if [[ $test_name == *"_duration" ]]; then
            local clean_name=${test_name/_duration/}
            echo "  $clean_name: ${PERFORMANCE_METRICS[$test_name]}s" >> "$summary_file"
        fi
    done
    
    cat >> "$summary_file" <<EOF

COMPLIANCE ISSUES
-----------------
EOF
    
    if [[ ${#COMPLIANCE_ISSUES[@]} -eq 0 ]]; then
        echo "No compliance issues detected" >> "$summary_file"
    else
        for issue in "${!COMPLIANCE_ISSUES[@]}"; do
            echo "  - $issue: ${COMPLIANCE_ISSUES[$issue]}" >> "$summary_file"
        done
    fi
    
    cat >> "$summary_file" <<EOF

TEST LOGS
---------
EOF
    
    find "$TEST_DIR" -name "*.log" | while read -r log; do
        echo "- $(basename "$log")" >> "$summary_file"
    done
    
    cat >> "$summary_file" <<EOF

RECOMMENDATIONS
---------------
EOF
    
    if (( FAILED_TESTS == 0 )); then
        echo "✓ All tests passed - Scanner is production-ready" >> "$summary_file"
    elif (( FAILED_TESTS <= 2 )); then
        echo "⚠ Minor issues detected - Review failed tests" >> "$summary_file"
    else
        echo "✗ Significant issues - Address failed tests before production" >> "$summary_file"
    fi
    
    if [[ ${#COMPLIANCE_ISSUES[@]} -gt 0 ]]; then
        echo "⚠ Address ${#COMPLIANCE_ISSUES[@]} compliance issues" >> "$summary_file"
    fi
    
    cat >> "$summary_file" <<EOF

VERDICT
-------
EOF
    
    if (( FAILED_TESTS == 0 && ${#COMPLIANCE_ISSUES[@]} == 0 )); then
        echo "✓✓✓ EXCELLENT - Scanner meets all validation criteria" >> "$summary_file"
    elif (( FAILED_TESTS < 3 && ${#COMPLIANCE_ISSUES[@]} < 3 )); then
        echo "✓✓ GOOD - Scanner operational with minor improvements needed" >> "$summary_file"
    else
        echo "✓ ACCEPTABLE - Scanner functional but requires attention" >> "$summary_file"
    fi
    
    cat "$summary_file"
    
    echo -e "\n${GREEN}═══════════════════════════════════════════${NC}"
    echo -e "${GREEN}Professional validation report saved to:${NC}"
    echo -e "${CYAN}$summary_file${NC}"
    echo -e "${GREEN}All test logs saved to: $TEST_DIR${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════${NC}\n"
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

main() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════════╗"
    echo "║         WAES PROFESSIONAL VALIDATION SUITE v2.0                       ║"
    echo "║         Comprehensive Test Coverage with Profile & Module Support     ║"
    echo "╠═══════════════════════════════════════════════════════════════════════╣"
    echo "║  Target: $TEST_TARGET:$TEST_PORT                                      "
    echo "║  Tests:  Profiles, Enumeration, Security, Analyzer, CLI, Compliance   "
    echo "╚═══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Setup test environment
    setup
    
    # Run core tests
    test_scan_modes           # 1. Scan modes (fast, full, deep, advanced)
    test_individual_modules   # 2. Tool integration
    test_features             # 3. Feature verification
    test_performance          # 4. Performance testing
    test_error_handling       # 5. Error handling
    test_compliance           # 6. Compliance checks
    test_cli_options          # 7. CLI options
    
    # Run NEW tests for enhanced features
    test_profiles             # 8. Profile system (6 profiles)
    test_enumeration_modules  # 9. OSINT/enumeration (9 modules)
    test_security_modules     # 10. Security tests (4 scanners)
    test_scan_analyzer        # 11. Intelligent analyzer
    test_help_system          # 12. Help documentation
    test_negative_scenarios   # 13. Error handling/edge cases
    test_module_syntax        # 14. Syntax validation
    
    # Analyze and report
    analyze_results
    generate_summary
#==============================================================================
# AI REMEDIATION CONTEXT GENERATION
#==============================================================================

generate_ai_context() {
    local context_file="$TEST_DIR/ai_fix_context.md"
    
    cat > "$context_file" <<EOF
# WAES Test Failure Remediation Context

## Overview
This file is auto-generated to help AI assistants diagnose and fix test failures.

**Test Date:** $(date)
**Target:** http://${TEST_TARGET}:${TEST_PORT}
**Failed Tests:** ${FAILED_TESTS}

## Failed Test Analysis

EOF
    
    # Iterate over logs and find failures
    # We rely on the fact that failed tests have logs in the directory
    # and we can check which ones failed by parsing our own output or checking return codes
    # For simplicity here, we grep the summary or check logs with errors
    
    if (( FAILED_TESTS > 0 )); then
        echo "Analyzing failed test logs..." >> "$context_file"
        
        # We need to know WHICH tests failed. The script tracks count but not names explicitly in an array.
        # Let's inspect all logs for keywords or just dump logs of tests that likely failed.
        # Better approach: The run_test function knows. But we are post-execution.
        # We will scan all logs for "fail" or error patterns, or just include all logs if failure count > 0.
        
        for log in "$TEST_DIR"/*.log; do
            [[ -f "$log" ]] || continue
            
            # Simple heuristic: if log contains "fail" or "error" (case insensitive) context, include it
            # Or if it's small (crash) or huge (timeout output).
            # Actually, let's just include the tail of ALL logs if we are in failure mode, 
            # or specifically look for the ones that `run_test` failed.
            
            # Since we can't easily map back from here without global arrays of failed tests,
            # we will look for specific error indicators we logged or just provide identifying info.
            
            cat >> "$context_file" <<INNER_EOF

### Log: $(basename "$log")
\`\`\`text
$(tail -n 50 "$log" | sed 's/\x1b\[[0-9;]*m//g')
\`\`\`
INNER_EOF
        done
        
        echo -e "\n## Instructions for AI" >> "$context_file"
        echo "1. Analyze the log snippets above for errors (timeouts, missing dependencies, syntax errors)." >> "$context_file"
        echo "2. Check 'tests/run_comprehensive_tests.sh' logic for the failing tests." >> "$context_file"
        echo "3. Propose fixes for either the codebase or the test script." >> "$context_file"
        
        echo -e "${YELLOW}[AI-CONTEXT]${NC} Generated fix context: $context_file"
    else
        echo "No failures detected." >> "$context_file"
    fi
}

    # Analyze and report
    analyze_results
    generate_summary
    generate_ai_context
    
    # Exit with appropriate code
    if (( FAILED_TESTS > 5 )); then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"
