# Email Compliance Testing - User Guide

## Overview

The Email Compliance module validates domain email authentication by testing SPF, DKIM, and DMARC DNS records. This helps identify email security misconfigurations and provides actionable recommendations.

## Quick Start

### Standalone Usage

```bash
# Test a single domain
./lib/email_compliance.sh google.com

# Save report to file
./lib/email_compliance.sh example.com -o report.md
```

### Integrated with WAES

```bash
# Add email compliance to a scan
sudo ./waes.sh -u example.com --email-compliance

# Combine with other scans
sudo ./waes.sh -u example.com -t fast --email-compliance --owasp
```

## Output Format

The module generates an easy-to-copy table showing results at a glance:

```markdown
## Summary Table

| Protocol | Status     | Record Found | Issues | Score |
| -------- | ---------- | ------------ | ------ | ----- |
| SPF      | ✅ PASS    | Yes          | 0      | 35/35 |
| DKIM     | ⚠️ WARNING | Yes          | 1      | 30/30 |
| DMARC    | ✅ PASS    | Yes          | 0      | 35/35 |
```

Each protocol section includes:

- **Status Icons**: ✅ (Pass), ⚠️ (Warning), ❌ (Fail)
- **Record Details**: Full DNS record content
- **Configuration**: Policy settings, alignment modes, etc.
- **Findings**: Specific validation results
- **Recommendations**: Action items for improvement

## What It Checks

### SPF (Sender Policy Framework)

- ✅ Record presence and syntax
- ✅ Policy strength (-all vs ~all vs +all)
- ✅ DNS lookup count (RFC 7208 limit: 10)
- ✅ Deprecated mechanisms (ptr)
- ✅ Multiple record detection

### DKIM (DomainKeys Identified Mail)

- ✅ Selector discovery (auto-detects common selectors)
- ✅ Public key presence and format
- ✅ Key algorithm validation (RSA/ed25519)
- ✅ RSA key size strength (minimum 1024-bit, recommends 2048+)
- ✅ Version tag validation

### DMARC

- ✅ Record presence at `_dmarc.domain`
- ✅ Policy enforcement level (none/quarantine/reject)
- ✅ Subdomain policy configuration
- ✅ Alignment modes (SPF and DKIM)
- ✅ Percentage deployment
- ✅ Aggregate and forensic reporting addresses

## Scoring System

- **SPF**: 35 points (critical for basic protection)
- **DKIM**: 30 points (authentication signature)
- **DMARC**: 35 points (policy enforcement)

**Total**: 100 points

### Score Interpretation

- **85-100**: ✅ Excellent - Strong email authentication
- **70-84**: ⚠️ Good - Minor improvements needed
- **<70**: ❌ Needs Attention - Critical issues present

## Dependencies

The module requires at least one DNS query tool:

- `dig` (preferred - most reliable)
- `nslookup` (fallback 1)
- `host` (fallback 2)

The script automatically tries all three in order.

## Troubleshooting

### No DNS Tools Available

```
Error: No DNS query tools available
```

**Solution**: Install dig (dnsutils package)

```bash
# Debian/Ubuntu
sudo apt install dnsutils

# RedHat/CentOS
sudo yum install bind-utils
```

### Selector Not Found

```
No DKIM selectors discovered
```

**Note**: The module tests common selectors: default, google, dkim, mail, k1, selector1, selector2, s1, s2.

If your domain uses a custom selector, test it directly:

```bash
./lib/email_compliance/dkim_validator.sh example.com custom-selector
```

## Example Output

```markdown
# Email Compliance Report

**Domain:** example.com
**Scan Date:** 2026-01-04 17:23:20
**Overall Score:** 85/100 (85%)
**Status:** WARNING

## Summary Table

| Protocol | Status     | Record Found | Issues | Score |
| -------- | ---------- | ------------ | ------ | ----- |
| SPF      | ✅ PASS    | Yes          | 0      | 35/35 |
| DKIM     | ✅ PASS    | Yes          | 0      | 30/30 |
| DMARC    | ⚠️ WARNING | Yes          | 1      | 35/35 |

## SPF Analysis

Domain: example.com
Status: PASS

### Record

`v=spf1 include:_spf.google.com -all`

### Configuration

- Policy: hard fail (-all)
- DNS Lookups: 1/10

### Findings

- ✅ Valid SPF record found
- ✅ DNS lookup count within limits
- ✅ Strong enforcement policy

## DKIM Analysis

...

## DMARC Analysis

...

### Issues

- ⚠️ Policy set to 'none' (monitoring only)

### Recommendations

- 📌 Progress to 'quarantine' or 'reject' policy

## Compliance Summary

⚠️ **GOOD** - Domain has email authentication with some improvements needed
```

## Advanced Usage

### Batch Testing

Create a domains file:

```
example.com
google.com
github.com
```

Test all domains:

```bash
while read domain; do
    ./lib/email_compliance.sh "$domain" -o "reports/${domain}.md"
done < domains.txt
```

### Integration with CI/CD

```bash
# Exit codes:
# 0 = Pass
# 2 = Warning
# 1 = Fail

./lib/email_compliance.sh yourdomain.com
if [ $? -eq 1 ]; then
    echo "Email compliance check FAILED"
    exit 1
fi
```

## Best Practices

1. **Start with SPF**: Easiest to implement, provides immediate protection
2. **Add DKIM**: Implement email signing for authentication
3. **Enable DMARC**: Start with `p=none` to monitor, then progress to `p=quarantine` or `p=reject`
4. **Monitor Reports**: Configure `rua=` address to receive aggregate reports
5. **Test Regularly**: Re-run compliance checks after DNS changes

## References

- [RFC 7208](https://tools.ietf.org/html/rfc7208) - SPF Specification
- [RFC 6376](https://tools.ietf.org/html/rfc6376) - DKIM Specification
- [RFC 7489](https://tools.ietf.org/html/rfc7489) - DMARC Specification
