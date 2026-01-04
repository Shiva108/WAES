# WAES Test Suite Documentation

## Quick Start

Run all tests with sudo privileges:

```bash
sudo ./tests/run_comprehensive_tests.sh
```

Specify custom target:

```bash
sudo ./tests/run_comprehensive_tests.sh 127.0.0.1 1234
```

## Test Coverage

### Scan Modes (3 tests)

- Fast scan mode
- Full scan mode (120s timeout)
- Deep scan with orchestration (180s timeout)

### Individual Modules (4 tests)

- Orchestration engine
- OWASP Top 10 scanner
- Intelligence engine initialization
- CVE correlation

### Features (4 tests)

- Evidence collection
- Vulnerability chain tracking
- Writeup generation
- OWASP + Intelligence integration

### Professional Reporting (1 test)

- Full professional workflow (180s timeout)

### Error Handling (2 tests)

- Invalid target handling
- Graceful degradation

### API Testing (2 tests)

- API server startup
- Scan creation endpoint

**Total:** 16 automated tests

## Output

All test results saved to `/tmp/waes_test_[timestamp]/`

**Files generated:**

- `test_summary.txt` - Overall results
- `test_*.log` - Individual test logs
- Reports in `report/` directory

## Exit Codes

- `0` - All tests passed
- `1` - One or more tests failed

## Example Usage

```bash
# Run against local test app
sudo ./tests/run_comprehensive_tests.sh 127.0.0.1 1234

# Run against demo app
sudo ./tests/run_comprehensive_tests.sh localhost 8080

# Check results
cat /tmp/waes_test_*/test_summary.txt
```
