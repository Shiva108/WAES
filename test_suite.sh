#!/usr/bin/env bash
#==============================================================================
# WAES Test Suite
# Comprehensive automated testing for all WAES components
#==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="${SCRIPT_DIR}/test_results"
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Setup
mkdir -p "$TEST_DIR"

log_test() {
    echo -e "${BLUE}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((PASS_COUNT++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((FAIL_COUNT++))
}

log_info() {
    echo -e "${YELLOW}[INFO]${NC} $*"
}

#==============================================================================
# SYNTAX TESTS
#==============================================================================

test_syntax() {
    log_test "Syntax validation tests"
    
    local scripts=(
        "waes.sh"
        "supergobuster.sh"
        "install.sh"
        "cleanrf.sh"
        "config.sh"
        "lib/colors.sh"
        "lib/validation.sh"
        "lib/progress.sh"
        "lib/state_manager.sh"
        "lib/ssl_scanner.sh"
        "lib/xss_scanner.sh"
        "lib/cms_scanner.sh"
        "lib/report_generator.sh"
    )
    
    for script in "${scripts[@]}"; do
        ((TEST_COUNT++))
        if bash -n "${SCRIPT_DIR}/${script}" 2>/dev/null; then
            log_pass "Syntax: $script"
        else
            log_fail "Syntax: $script"
        fi
    done
    
    # Python script
    ((TEST_COUNT++))
    if python3 -m py_compile "${SCRIPT_DIR}/resolveip.py" 2>/dev/null; then
        log_pass "Syntax: resolveip.py"
    else
        log_fail "Syntax: resolveip.py"
    fi
}

#==============================================================================
# HELP FLAG TESTS
#==============================================================================

test_help_flags() {
    log_test "Help flag tests"
    
    # supergobuster
    ((TEST_COUNT++))
    if "${SCRIPT_DIR}/supergobuster.sh" -h 2>&1 | grep -q "Usage:"; then
        log_pass "Help: supergobuster.sh"
    else
        log_fail "Help: supergobuster.sh"
    fi
    
    # cleanrf
    ((TEST_COUNT++))
    if "${SCRIPT_DIR}/cleanrf.sh" -h 2>&1 | grep -q "Usage:"; then
        log_pass "Help: cleanrf.sh"
    else
        log_fail "Help: cleanrf.sh"
    fi
    
    # resolveip
    ((TEST_COUNT++))
    if "${SCRIPT_DIR}/resolveip.py" -h 2>&1 | grep -q "usage:"; then
        log_pass "Help: resolveip.py"
    else
        log_fail "Help: resolveip.py"
    fi
    
    # state_manager
    ((TEST_COUNT++))
    if "${SCRIPT_DIR}/lib/state_manager.sh" 2>&1 | grep -q "Usage:"; then
        log_pass "Help: state_manager.sh"
    else
        log_fail "Help: state_manager.sh"
    fi
}

#==============================================================================
# FUNCTIONAL TESTS
#==============================================================================

test_resolveip() {
    log_test "resolveip.py functional tests"
    
    # Create test file
    echo -e "localhost\n127.0.0.1" > "${TEST_DIR}/test_domains.txt"
    
    # Test plain output
    ((TEST_COUNT++))
    if "${SCRIPT_DIR}/resolveip.py" "${TEST_DIR}/test_domains.txt" -q 2>/dev/null | grep -q "127.0.0.1"; then
        log_pass "resolveip: plain output"
    else
        log_fail "resolveip: plain output"
    fi
    
    # Test JSON output
    ((TEST_COUNT++))
    if "${SCRIPT_DIR}/resolveip.py" "${TEST_DIR}/test_domains.txt" -f json -q 2>/dev/null | grep -q '"domain"'; then
        log_pass "resolveip: JSON output"
    else
        log_fail "resolveip: JSON output"
    fi
    
    # Test CSV output
    ((TEST_COUNT++))
    if "${SCRIPT_DIR}/resolveip.py" "${TEST_DIR}/test_domains.txt" -f csv -q 2>/dev/null | grep -q "domain,ip,error"; then
        log_pass "resolveip: CSV output"
    else
        log_fail "resolveip: CSV output"
    fi
}

test_state_manager() {
    log_test "State manager functional tests"
    
    # Init state
    ((TEST_COUNT++))
    if "${SCRIPT_DIR}/lib/state_manager.sh" init "test.localhost" "full" "${TEST_DIR}" 2>/dev/null; then
        log_pass "state_manager: init"
    else
        log_fail "state_manager: init"
    fi
    
    # Check state file exists
    ((TEST_COUNT++))
    if [[ -f "${TEST_DIR}/.waes_state_test.localhost.json" ]]; then
        log_pass "state_manager: state file created"
    else
        log_fail "state_manager: state file created"
    fi
    
    # Status command
    ((TEST_COUNT++))
    if "${SCRIPT_DIR}/lib/state_manager.sh" status "test.localhost" "${TEST_DIR}" 2>/dev/null | grep -q "Status:"; then
        log_pass "state_manager: status"
    else
        log_fail "state_manager: status"
    fi
    
    # List command
    ((TEST_COUNT++))
    if "${SCRIPT_DIR}/lib/state_manager.sh" list "${TEST_DIR}" 2>/dev/null | grep -q "test.localhost"; then
        log_pass "state_manager: list"
    else
        log_fail "state_manager: list"
    fi
}

test_cleanrf() {
    log_test "cleanrf.sh functional tests"
    
    # Dry run (should not delete)
    ((TEST_COUNT++))
    if "${SCRIPT_DIR}/cleanrf.sh" --dry-run 2>/dev/null | grep -q "Dry run mode"; then
        log_pass "cleanrf: dry-run mode"
    else
        log_fail "cleanrf: dry-run mode"
    fi
}

test_library_functions() {
    log_test "Library function tests"
    
    # Source colors library
    ((TEST_COUNT++))
    if source "${SCRIPT_DIR}/lib/colors.sh" 2>/dev/null; then
        log_pass "Library: colors.sh loads"
    else
        log_fail "Library: colors.sh loads"
    fi
    
    # Source validation library
    ((TEST_COUNT++))
    if source "${SCRIPT_DIR}/lib/validation.sh" 2>/dev/null; then
        log_pass "Library: validation.sh loads"
    else
        log_fail "Library: validation.sh loads"
    fi
    
    # Test validation functions
    source "${SCRIPT_DIR}/lib/validation.sh" 2>/dev/null
    
    ((TEST_COUNT++))
    if validate_ipv4 "192.168.1.1"; then
        log_pass "Validation: valid IPv4"
    else
        log_fail "Validation: valid IPv4"
    fi
    
    ((TEST_COUNT++))
    if ! validate_ipv4 "999.999.999.999"; then
        log_pass "Validation: invalid IPv4"
    else
        log_fail "Validation: invalid IPv4"
    fi
    
    ((TEST_COUNT++))
    if validate_port "80"; then
        log_pass "Validation: valid port"
    else
        log_fail "Validation: valid port"
    fi
    
    ((TEST_COUNT++))
    if ! validate_port "70000"; then
        log_pass "Validation: invalid port"
    else
        log_fail "Validation: invalid port"
    fi
}

#==============================================================================
# INTEGRATION TESTS
#==============================================================================

test_config_loading() {
    log_test "Configuration loading tests"
    
    ((TEST_COUNT++))
    if source "${SCRIPT_DIR}/config.sh" 2>/dev/null; then
        log_pass "Config: loads successfully"
    else
        log_fail "Config: loads successfully"
    fi
    
    ((TEST_COUNT++))
    if [[ -n "${WAES_VERSION:-}" ]]; then
        log_pass "Config: WAES_VERSION defined"
    else
        log_fail "Config: WAES_VERSION defined"
    fi
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

main() {
    echo ""
    echo "=========================================="
    echo "  WAES Test Suite"
    echo "=========================================="
    echo ""
    
    test_syntax
    echo ""
    
    test_help_flags
    echo ""
    
    test_resolveip
    echo ""
    
    test_state_manager
    echo ""
    
    test_cleanrf
    echo ""
    
    test_library_functions
    echo ""
    
    test_config_loading
    echo ""
    
    # Cleanup
    rm -rf "${TEST_DIR}"
    
    # Summary
    echo "=========================================="
    echo "  Test Results"
    echo "=========================================="
    echo ""
    echo "Total:  $TEST_COUNT"
    echo -e "${GREEN}Passed: $PASS_COUNT${NC}"
    echo -e "${RED}Failed: $FAIL_COUNT${NC}"
    echo ""
    
    if [[ $FAIL_COUNT -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        exit 1
    fi
}

main "$@"
