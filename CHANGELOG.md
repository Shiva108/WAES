# WAES Modernization Changelog

All notable changes to the WAES project.

## [1.1.0] - 2026-01-04

### Added - Advanced Security Features

- **SSL/TLS Scanner Module** (`lib/ssl_scanner.sh`)

  - Certificate validation and expiration checking
  - Protocol support testing (SSLv2-TLSv1.3)
  - Cipher suite enumeration
  - Vulnerability checks (Heartbleed, POODLE, BEAST, weak ciphers)
  - Integration with sslscan and testssl.sh

- **XSS Scanner Module** (`lib/xss_scanner.sh`)

  - Comprehensive payload library (basic, encoded, advanced, DOM-based)
  - Form detection and analysis
  - Reflected payload detection
  - Integration with XSSer

- **CMS Scanner Module** (`lib/cms_scanner.sh`)

  - WordPress: version, themes, plugins, users, vulnerable files
  - Drupal: version, modules, info files, Droopescan integration
  - Joomla: version, components, admin panel, JoomScan integration

- **HTML Report Generator** (`lib/report_generator.sh`)

  - Professional HTML reports with modern CSS styling
  - Automatic table of contents
  - Severity-based color coding
  - Executive summary and recommendations

- **Scan State Manager** (`lib/state_manager.sh`)
  - JSON-based state persistence
  - Scan resumption capability (`-r` flag)
  - Progress tracking and stage completion
  - Error logging

### Changed

- **waes.sh** - Integrated advanced modules
  - Added "advanced" scan type (deep + SSL/TLS + XSS + CMS)
  - Added `-r` flag for resume capability
  - Added `-H` flag for HTML report generation
  - Increased from 365 to 438 lines

### Verified

- All 5 new modules pass bash syntax validation
- Standalone execution mode for each module
- Integration testing with main waes.sh
- Documentation updated with new features

## [1.0.0] - 2024

### Added

- **New library system** (`lib/` directory)
  - `colors.sh` - Consistent color output and formatting
  - `validation.sh` - IP, domain, URL, and port validation
  - `progress.sh` - Progress bar with ETA calculation
- **Central configuration** (`config.sh`)
  - Customizable wordlist paths
  - Timeout and threading settings
  - Tool and extension definitions
- **HTTPS support** - Use `-s` flag for SSL/TLS scanning
- **Scan type selection** - `-t fast|full|deep` options
- **Concurrent DNS resolution** in resolveip.py
- **Multiple output formats** - plain, CSV, JSON for resolveip.py
- **Archive option** for cleanrf.sh
- **Days-based filtering** for report cleanup
- **Dry-run mode** for safe previews

### Changed

- **waes.sh** - Complete refactor
  - Removed duplicate code (40+ lines)
  - Added proper argument parsing with getopts
  - Modular scanning functions
  - Better error handling and validation
- **supergobuster.sh** - Auto-detects wordlist paths
  - Falls back from local SecLists to Kali defaults
  - Added threading and extension options
- **install.sh** - Multi-distro support
  - Detects apt/yum/pacman
  - Clones dependencies properly
  - Verification of installed tools
- **cleanrf.sh** - Fixed variable bug
  - Proper confirmation handling
  - Safe deletion with archive option
- **resolveip.py** - Enhanced with type hints
  - ThreadPoolExecutor for concurrent resolution
  - argparse for proper CLI
  - Multiple output formats

### Removed

- `supergobuster.old` - Deprecated backup
- `testscript.sh` - Debug script not needed

### Fixed

- Variable quoting throughout scripts
- Hardcoded paths now auto-detected
- `cleanrf.sh` response variable bug
- Missing `dirb` in install.sh

## [0.0.37-alpha] - Previous

- Initial release
