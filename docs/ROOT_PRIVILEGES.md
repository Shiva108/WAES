# WAES Root Privilege Requirements

## Overview

WAES requires root (sudo) privileges for full functionality. This document explains why, what operations require privileges, and how to run securely.

## Why Root Privileges Are Required

### Network Operations

- **Raw socket access**: Tools like `nmap` use raw sockets for SYN scans (`-sS`)
- **Port scanning below 1024**: Privileged ports require root access
- **Packet crafting**: Custom packet generation for evasion techniques

### System Access

- **Process management**: Spawning privileged child processes
- **Network interface control**: Monitoring network traffic
- **File system access**: Reading system files for vulnerability validation

## Privilege Levels

### Full Functionality (sudo)

```bash
sudo ./waes.sh -u target.com -t deep
```

**Capabilities:**

- ✅ All scan modes (fast, full, deep, advanced)
- ✅ Nmap with SYN scans
- ✅ Raw packet generation
- ✅ Complete tool integration
- ✅ WAF evasion techniques

### Limited Functionality (non-root)

```bash
./waes.sh -u target.com -t fast  # Will error
```

**Limitations:**

- ❌ Main script requires root
- ⚠️ Some modules work standalone (OWASP, Intelligence)
- ⚠️ No network scanning capabilities

## Running Securely

### Recommended Practice

1. **Use sudo with full path**

   ```bash
   sudo /path/to/waes.sh -u target.com
   ```

2. **Verify script integrity before running**

   ```bash
   sha256sum waes.sh
   # Compare against known good hash
   ```

3. **Review scan profile**
   ```bash
   cat profiles/ctf-box.conf
   # Verify settings before use
   ```

### Security Considerations

**DO:**

- ✅ Run in isolated environments (VMs, containers)
- ✅ Use dedicated scanning accounts
- ✅ Enable audit logging (`-v` for verbose)
- ✅ Review generated commands before execution
- ✅ Limit network exposure (firewall rules)

**DON'T:**

- ❌ Run against production without authorization
- ❌ Use on shared systems without isolation
- ❌ Disable security features to bypass root check
- ❌ Run with SUID bit (massive security risk)

## Sudo Configuration

### Per-User Permission (Recommended)

```bash
# /etc/sudoers.d/waes
scanner_user ALL=(root) NOPASSWD: /path/to/waes.sh
```

**Benefits:**

- No password prompt
- Limited to specific script
- Audit trail in system logs

### Temporary Elevation

```bash
# Request sudo once, cache for session
sudo -v
sudo ./waes.sh -u target.com
```

## Docker Alternative (Rootless)

For environments where sudo is not available:

```dockerfile
FROM kalilinux/kali-rolling

# Install WAES dependencies
RUN apt-get update && apt-get install -y nmap nikto gobuster

# Add WAES
COPY . /opt/waes
WORKDIR /opt/waes

# Run as root in container
ENTRYPOINT ["./waes.sh"]
```

**Usage:**

```bash
docker run -it waes -u target.com -t fast
```

## Module-Specific Requirements

### Requires Root

- `waes.sh` (main script)
- `lib/orchestrator.sh` (when calling nmap)
- `lib/waf_detector.sh` (raw sockets)

### Works Without Root

- `lib/owasp_scanner.sh` ✅
- `lib/intelligence_engine.sh` ✅
- `lib/report_engine/*` ✅
- `lib/api/server.sh` ✅ (non-privileged ports)

## Troubleshooting

### "This script must be run as root"

**Solution:**

```bash
sudo ./waes.sh -u target.com
```

### "Permission denied" on report files

**Cause:** Report directory owned by root

**Solution:**

```bash
# Set output directory with correct permissions
sudo ./waes.sh -u target.com -o /tmp/scan_results
sudo chown -R $USER:$USER /tmp/scan_results
```

### Running in CI/CD

**GitHub Actions:**

```yaml
- name: Run WAES scan
  run: |
    sudo ./waes.sh -u ${{ secrets.TARGET }} --ci-mode
```

**GitLab CI:**

```yaml
security_scan:
  script:
    - sudo ./waes.sh -u $TARGET -t fast
```

## API Server Privilege Notes

The REST API server (`lib/api/server.sh`) can run without root:

```bash
# Start API on non-privileged port
WAES_API_PORT=8000 ./lib/api/server.sh start
```

However, scans triggered via API still require the main process to have root privileges.

## Summary

| Component         | Root Required | Reason                                 |
| ----------------- | ------------- | -------------------------------------- |
| Main Scanner      | ✅ Yes        | Network operations, process management |
| OWASP Module      | ❌ No         | HTTP-only operations                   |
| Intelligence      | ❌ No         | File I/O only                          |
| API Server        | ❌ No         | Can use port >1024                     |
| Report Generation | ❌ No         | File writes only                       |

**Best Practice:** Run WAES in dedicated, isolated environments with minimal privilege scope and comprehensive logging.
