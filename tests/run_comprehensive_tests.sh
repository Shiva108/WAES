#!/usr/bin/env bash
#==============================================================================
# WAES Comprehensive Test Suite (Privileged Mode)
# Runs all validation tests with sudo privileges
#==============================================================================

# Don't exit on error - we want to run all tests

# Configuration
TEST_TARGET="${1:-127.0.0.1}"
TEST_PORT="${2:-1234}"
TEST_DIR="/tmp/waes_test_$(date +%s)"
WAES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

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

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local log_file="$3"
    
    ((TOTAL_TESTS++))
    
    log_info "Running: $test_name"
    
    if eval "$test_cmd" > "$log_file" 2>&1; then
        log_success "$test_name"
        return 0
    else
        log_fail "$test_name (see $log_file)"
        return 0  # Return 0 so script continues
    fi
}

#==============================================================================
# SETUP
#==============================================================================

setup() {
    log_info "Setting up test environment..."
    mkdir -p "$TEST_DIR"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}ERROR: This script must be run with sudo${NC}"
        echo "Usage: sudo $0 [target] [port]"
        exit 1
    fi
    
    # Check target accessibility
    log_info "Checking target: http://${TEST_TARGET}:${TEST_PORT}"
    if ! curl -sf "http://${TEST_TARGET}:${TEST_PORT}" > /dev/null; then
        log_warn "Target may not be accessible, continuing anyway..."
    else
        log_success "Target is accessible"
    fi
    
    log_info "Starting test execution..."
    echo ""
}

#==============================================================================
# TEST SUITE
#==============================================================================

test_scan_modes() {
    echo -e "\n${BLUE}==== Testing Scan Modes ====${NC}\n"
    
    # Fast scan
    run_test "Fast Scan Mode" \
        "cd '$WAES_DIR' && ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --no-evidence" \
        "$TEST_DIR/test_fast_scan.log"
    
    # Full scan (limited to avoid long runtime)
    run_test "Full Scan Mode" \
        "cd '$WAES_DIR' && timeout 180 ./waes.sh -u "$TEST_TARGET" -p "$TEST_PORT" -t full --no-evidence" \
        "$TEST_DIR/test_full_scan.log"
    
    # Deep scan with orchestration
    run_test "Deep Scan with Orchestration" \
        "cd '$WAES_DIR' && timeout 180 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t deep --orchestrate --no-evidence" \
        "$TEST_DIR/test_deep_orchestrated.log"
}

test_individual_modules() {
    echo -e "\n${BLUE}==== Testing Individual Modules ====${NC}\n"
    
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
    
    run_test "Intelligence Engine - Correlate" \
        "cd '$WAES_DIR' && ./lib/intelligence_engine.sh correlate Apache '2.4.49'" \
        "$TEST_DIR/test_intel_correlate.log"
}

test_features() {
    echo -e "\n${BLUE}==== Testing Features ====${NC}\n"
    
    # Evidence collection
    run_test "Evidence Collection" \
        "cd '$WAES_DIR' && timeout 120 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --evidence" \
        "$TEST_DIR/test_evidence.log"
    
    # Chain tracking
    run_test "Vulnerability Chain Tracking" \
        "cd '$WAES_DIR' && timeout 120 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --chains --no-evidence" \
        "$TEST_DIR/test_chains.log"
    
    # Writeup generation
    run_test "Writeup Generation" \
        "cd '$WAES_DIR' && timeout 120 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --writeup --no-evidence" \
        "$TEST_DIR/test_writeup.log"
    
    # OWASP scan with intelligence
    run_test "OWASP + Intelligence Integration" \
        "cd '$WAES_DIR' && timeout 120 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --owasp --intel --no-evidence" \
        "$TEST_DIR/test_owasp_intel.log"
}

test_professional_reporting() {
    echo -e "\n${BLUE}==== Testing Professional Reporting ====${NC}\n"
    
    # Full professional workflow
    run_test "Professional Report Generation" \
        "cd '$WAES_DIR' && timeout 180 ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t advanced --professional --no-evidence" \
        "$TEST_DIR/test_professional.log"
}

test_error_handling() {
    echo -e "\n${BLUE}==== Testing Error Handling ====${NC}\n"
    
    # Invalid target
    run_test "Invalid Target Handling" \
        "cd '$WAES_DIR' && ./waes.sh -u 999.999.999.999 -p 9999 -t fast --no-evidence 2>&1 | grep -q 'error\|fail\|invalid' || exit 1" \
        "$TEST_DIR/test_invalid_target.log"
    
    # Missing dependencies (graceful degradation)
    run_test "Graceful Degradation" \
        "cd '$WAES_DIR' && PATH=/usr/bin ./waes.sh -u '$TEST_TARGET' -p '$TEST_PORT' -t fast --no-evidence" \
        "$TEST_DIR/test_degradation.log"
}

test_api() {
    echo -e "\n${BLUE}==== Testing REST API ====${NC}\n"
    
    # Start API server in background
    log_info "Starting API server..."
    cd "$WAES_DIR"
    ./lib/api/server.sh start > "$TEST_DIR/api_server.log" 2>&1 &
    local api_pid=$!
    sleep 2
    
    # Test API endpoints
    run_test "API Server Startup" \
        "curl -f http://localhost:8000/api/v1/scans -H 'X-API-Key: changeme'" \
        "$TEST_DIR/test_api_startup.log"
    
    # Create scan via API
    run_test "API Scan Creation" \
        "curl -f -X POST http://localhost:8000/api/v1/scans -H 'X-API-Key: changeme' -d '{\"target\":\"$TEST_TARGET\",\"type\":\"fast\"}'" \
        "$TEST_DIR/test_api_create.log"
    
    # Stop API server
    kill $api_pid 2>/dev/null || true
}

#==============================================================================
# RESULTS ANALYSIS
#==============================================================================

analyze_results() {
    echo -e "\n${BLUE}==== Analyzing Results ====${NC}\n"
    
    # Count findings from OWASP scan
    if [[ -f "$TEST_DIR/test_owasp.log" ]]; then
        local findings=$(grep -c "Found:" "$TEST_DIR/test_owasp.log" || echo 0)
        log_info "OWASP Scanner findings: $findings"
    fi
    
    # Check for generated reports
    local report_count=$(find "$WAES_DIR/report" -type f -name "*.md" 2>/dev/null | wc -l)
    log_info "Reports generated: $report_count"
    
    # Check evidence collection
    local evidence_count=$(find "$WAES_DIR/report" -type d -name "evidence" 2>/dev/null | wc -l)
    log_info "Evidence directories: $evidence_count"
}

#==============================================================================
# SUMMARY REPORT
#==============================================================================

generate_summary() {
    local summary_file="$TEST_DIR/test_summary.txt"
    
    cat > "$summary_file" <<EOF
WAES Comprehensive Test Suite - Summary Report
===============================================

Test Date: $(date)
Target: http://${TEST_TARGET}:${TEST_PORT}
Test Directory: ${TEST_DIR}

RESULTS
-------
Total Tests: ${TOTAL_TESTS}
Passed: ${PASSED_TESTS} ($(( PASSED_TESTS * 100 / TOTAL_TESTS ))%)
Failed: ${FAILED_TESTS} ($(( FAILED_TESTS * 100 / TOTAL_TESTS ))%)

TEST LOGS
---------
EOF
    
    find "$TEST_DIR" -name "*.log" | while read -r log; do
        echo "- $(basename "$log")" >> "$summary_file"
    done
    
    cat >> "$summary_file" <<EOF

VERDICT
-------
EOF
    
    if (( FAILED_TESTS == 0 )); then
        echo "✅ ALL TESTS PASSED" >> "$summary_file"
    elif (( FAILED_TESTS < 3 )); then
        echo "⚠️  MINOR ISSUES ($(( FAILED_TESTS )) failures)" >> "$summary_file"
    else
        echo "❌ SIGNIFICANT ISSUES ($(( FAILED_TESTS )) failures)" >> "$summary_file"
    fi
    
    cat "$summary_file"
    
    echo -e "\n${GREEN}Full summary saved to: $summary_file${NC}"
    echo -e "${GREEN}All test logs saved to: $TEST_DIR${NC}\n"
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

main() {
    echo -e "${BLUE}"
    cat <<'EOF'
╦ ╦╔═╗╔═╗╔═╗  ╔╦╗╔═╗╔═╗╔╦╗  ╔═╗╦ ╦╦╔╦╗╔═╗
║║║╠═╣║╣ ╚═╗   ║ ║╣ ╚═╗ ║   ╚═╗║ ║║ ║ ║╣ 
╚╩╝╩ ╩╚═╝╚═╝   ╩ ╚═╝╚═╝ ╩   ╚═╝╚═╝╩ ╩ ╚═╝
Comprehensive Validation Suite (Privileged)
EOF
    echo -e "${NC}\n"
    
    setup
    
    # Run all test suites
    test_scan_modes
    test_individual_modules
    test_features
    test_professional_reporting
    test_error_handling
    test_api
    
    # Analyze and report
    analyze_results
    generate_summary
    
    # Exit with appropriate code
    if (( FAILED_TESTS > 0 )); then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"
