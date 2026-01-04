![GitHub Logo](banner.png)

# WAES - Web Auto Enum & Scanner

## Version 1.0.0

A comprehensive bash-based web enumeration toolkit for CTF and penetration testing. WAES automates the tedious process of running multiple scanning tools against web targets, saving time and ensuring comprehensive coverage.

## Features

- 🔍 **Multi-stage scanning**: Fast recon, in-depth analysis, and comprehensive fuzzing
- 🔐 **HTTPS support**: Automatic detection and SSL/TLS scanning
- 📊 **Organized reports**: All results saved to dedicated report directory
- 🎨 **Color-coded output**: Easy-to-read results with progress tracking
- ⚙️ **Configurable**: Customizable wordlists, timeouts, and scan types

## Installation

```bash
git clone https://github.com/Shiva108/WAES.git
cd WAES
sudo ./install.sh
```

The installer will:

- Detect your package manager (apt/yum/pacman)
- Install required tools (nmap, nikto, gobuster, dirb, whatweb, wafw00f)
- Clone SecLists wordlist collection
- Set up vulscan NSE scripts
- Configure permissions

## Quick Start

```bash
# Basic scan
sudo ./waes.sh -u 10.10.10.130

# Scan specific port
sudo ./waes.sh -u 10.10.10.130 -p 8080

# HTTPS with deep scan
sudo ./waes.sh -u example.com -s -t deep

# Advanced scan with SSL/TLS, XSS, CMS detection + HTML report
sudo ./waes.sh -u example.com -s -t advanced -H

# Resume a previous scan
sudo ./waes.sh -u example.com -r

# Fast reconnaissance only
sudo ./waes.sh -u 10.10.10.130 -t fast
```

## Usage

```test
Usage: waes.sh [OPTIONS] -u <target>

Options:
    -u <target>     Target IP or domain (required)
    -p <port>       Port number (default: 80, or 443 with -s)
    -s              Use HTTPS protocol
    -t <type>       Scan type: fast, full, deep, advanced (default: full)
    -r              Resume previous scan
    -H              Generate HTML report
    -v              Verbose output
    -q              Quiet mode (minimal output)
    -h              Show this help message

Scan Types:
    fast     - Quick reconnaissance (wafw00f, nmap http-enum)
    full     - Standard scan (adds nikto, nmap scripts) [default]
    deep     - Comprehensive (adds vulscan, uniscan, fuzzing)
    advanced - Deep + SSL/TLS, XSS testing, CMS-specific scans
```

## Scan Stages

### Fast Scan (`-t fast`)

- **wafw00f**: Web Application Firewall detection
- **nmap http-enum**: Quick directory/file enumeration

### Full Scan (`-t full`) [Default]

Everything in fast, plus:

- **nmap HTTP scripts**: Headers, cookies, XSS detection
- **nikto**: Web server vulnerability scanner
- **Standard nmap**: Service version detection

### Deep Scan (`-t deep`)

Everything in full, plus:

- **whatweb**: CMS and technology detection
- **vulscan**: CVE vulnerability matching (CVSS 5.0+)
- **uniscan**: Additional vulnerability checks
- **supergobuster**: Multi-wordlist directory fuzzing

### Advanced Scan (`-t advanced`)

Everything in deep, plus:

- **SSL/TLS scanner**: Certificate validation, cipher analysis, vulnerability checks
- **XSS scanner**: Cross-Site Scripting payload testing
- **CMS scanner**: WordPress, Drupal, Joomla detection and enumeration
- **HTML report**: Professional formatted report generation

## Additional Tools

### supergobuster.sh

Multi-wordlist directory enumeration using gobuster:

```bash
./supergobuster.sh http://10.10.10.130:8080
./supergobuster.sh http://10.10.10.130 -t 20 -x php,bak
```

### resolveip.py

Bulk DNS resolution with concurrent processing:

```bash
./resolveip.py domains.txt                  # Basic resolution
./resolveip.py domains.txt -f json          # JSON output
./resolveip.py domains.txt --ip-only        # IPs only
./resolveip.py domains.txt -t 20 -T 3       # 20 threads, 3s timeout
```

### cleanrf.sh

Safely manage report files:

```bash
./cleanrf.sh                    # Interactive cleanup
./cleanrf.sh -a                 # Archive before deleting
./cleanrf.sh -d 7               # Delete files older than 7 days
./cleanrf.sh --dry-run          # Preview without deleting
```

## Configuration

Edit `config.sh` to customize:

- Wordlist paths
- Default timeouts
- Threading settings
- Nmap script selection
- Gobuster status codes

## Project Structure

```text
WAES/
├── waes.sh              # Main scanner script
├── supergobuster.sh     # Directory fuzzing
├── install.sh           # Installer
├── cleanrf.sh           # Report cleanup
├── resolveip.py         # DNS resolution
├── config.sh            # Configuration
├── lib/                 # Library scripts
│   ├── colors.sh        # Color output
│   ├── validation.sh    # Input validation
│   └── progress.sh      # Progress bar
├── report/              # Scan results
├── SecLists/            # Wordlists
└── vulscan/             # Nmap vulscan scripts
```

## Requirements

**Required Tools:**

- nmap
- nikto
- gobuster
- dirb
- whatweb
- wafw00f

**Optional Tools:**

- uniscan
- feroxbuster
- sslscan

## Changelog

### v1.0.0 (2024)

- Complete refactor of all scripts
- Added modular library system (colors, validation, progress)
- Added HTTPS support with `-s` flag
- Added scan type selection (`-t fast|full|deep`)
- Fixed wordlist path auto-detection
- Added concurrent DNS resolution to resolveip.py
- Improved install script with multi-distro support
- Enhanced cleanrf.sh with archive and days filter options
- Removed deprecated scripts (supergobuster.old, testscript.sh)

### v0.0.37 (Previous)

- Initial alpha release

## License

GPL-2.0 License - See [LICENSE](LICENSE) for details.

## Author

**Shiva @ CPH:SEC**

- GitHub: [Shiva108](https://github.com/Shiva108)

## Contributing

Pull requests welcome! For major changes, please open an issue first.

## TODO

- [x] Add SSL/TLS certificate scanning
- [x] Add XSS payload testing
- [x] Add CMS-specific scan modules
- [x] Add HTML report generation
- [x] Add scan resumption capability
