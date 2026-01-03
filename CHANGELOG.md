# WAES Modernization Changelog

All notable changes to the WAES project.

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
