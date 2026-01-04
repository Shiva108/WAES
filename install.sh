#!/usr/bin/env bash
#==============================================================================
# WAES Installation Script
# Installs all required tools and dependencies
#==============================================================================

set -e

#==============================================================================
# CONFIGURATION
#==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Required packages
APT_PACKAGES=(
    "nmap"
    "nikto"
    "gobuster"
    "dirb"
    "whatweb"
    "wafw00f"
    "python3"
    "python3-pip"
)

# Optional packages
OPTIONAL_PACKAGES=(
    "uniscan"
    "feroxbuster"
    "sslscan"
)

#==============================================================================
# FUNCTIONS
#==============================================================================

log_info() {
    echo -e "${BLUE}[*]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[+]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[~]${NC} $*"
}

log_error() {
    echo -e "${RED}[!]${NC} $*" >&2
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        echo "Usage: sudo ./install.sh"
        exit 1
    fi
}

detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    else
        echo "unknown"
    fi
}

install_apt() {
    log_info "Updating package lists..."
    apt-get update -qq
    
    log_info "Installing required packages..."
    for pkg in "${APT_PACKAGES[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            log_success "$pkg is already installed"
        else
            log_info "Installing $pkg..."
            apt-get install -y -qq "$pkg" || log_warn "Failed to install $pkg"
        fi
    done
    
    # Optional packages
    log_info "Installing optional packages..."
    for pkg in "${OPTIONAL_PACKAGES[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            log_success "$pkg is already installed"
        else
            apt-get install -y -qq "$pkg" 2>/dev/null || log_warn "Optional: $pkg not available"
        fi
    done
}

install_yum() {
    log_info "Installing with yum..."
    yum install -y nmap nikto python3 python3-pip 2>/dev/null || true
    log_warn "Some tools may need manual installation on RHEL-based systems"
}

install_pacman() {
    log_info "Installing with pacman..."
    pacman -Sy --noconfirm nmap nikto python python-pip 2>/dev/null || true
    log_warn "Some tools may need installation from AUR"
}

setup_directories() {
    log_info "Setting up directories..."
    
    # Create report directory
    mkdir -p "${SCRIPT_DIR}/report"
    log_success "Created report directory"
    
    # Create lib directory
    mkdir -p "${SCRIPT_DIR}/lib"
    log_success "Created lib directory"
    
    # Create external directory
    mkdir -p "${SCRIPT_DIR}/external"
    log_success "Created external directory"
}

clone_dependencies() {
    log_info "Cloning/updating dependencies..."
    
    # SecLists
    if [[ -d "${SCRIPT_DIR}/external/SecLists/.git" ]]; then
        log_info "Updating SecLists..."
        cd "${SCRIPT_DIR}/external/SecLists"
        git fetch origin --quiet
        git reset --hard origin/master --quiet
    elif [[ ! -d "${SCRIPT_DIR}/external/SecLists" ]] || [[ -z "$(ls -A "${SCRIPT_DIR}/external/SecLists" 2>/dev/null)" ]]; then
        log_info "Cloning SecLists (this may take a while)..."
        git clone --depth 1 https://github.com/danielmiessler/SecLists.git "${SCRIPT_DIR}/external/SecLists"
    else
        log_success "SecLists already present"
    fi
    
    # Vulscan
    if [[ -d "${SCRIPT_DIR}/external/vulscan/.git" ]]; then
        log_info "Updating vulscan..."
        cd "${SCRIPT_DIR}/external/vulscan"
        git fetch origin --quiet
        git reset --hard origin/master --quiet
    elif [[ ! -d "${SCRIPT_DIR}/external/vulscan" ]] || [[ ! -f "${SCRIPT_DIR}/external/vulscan/vulscan.nse" ]]; then
        log_info "Cloning vulscan..."
        rm -rf "${SCRIPT_DIR}/external/vulscan"
        git clone https://github.com/scipag/vulscan.git "${SCRIPT_DIR}/external/vulscan"
    else
        log_success "Vulscan already present"
    fi
}

init_submodules() {
    log_info "Initializing Git submodules..."
    cd "${SCRIPT_DIR}"
    
    if [[ -f ".gitmodules" ]]; then
        git submodule update --init --recursive 2>/dev/null || log_warn "Some submodules failed to initialize"
    fi
}

set_permissions() {
    log_info "Setting script permissions..."
    
    chmod +x "${SCRIPT_DIR}/waes.sh" 2>/dev/null || true
    chmod +x "${SCRIPT_DIR}/tools/supergobuster.sh" 2>/dev/null || true
    chmod +x "${SCRIPT_DIR}/tools/cleanrf.sh" 2>/dev/null || true
    chmod +x "${SCRIPT_DIR}/tools/resolveip.py" 2>/dev/null || true
    
    log_success "Permissions set"
}

verify_installation() {
    log_info "Verifying installation..."
    echo ""
    
    local all_ok=true
    local tools=("nmap" "nikto" "gobuster" "dirb" "whatweb" "wafw00f")
    
    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            local version
            version=$($tool --version 2>&1 | head -1 || echo "unknown")
            log_success "$tool: $version"
        else
            log_error "$tool: NOT FOUND"
            all_ok=false
        fi
    done
    
    echo ""
    
    # Check directories
    [[ -d "${SCRIPT_DIR}/external/SecLists" ]] && log_success "SecLists: OK" || log_warn "SecLists: Missing"
    [[ -f "${SCRIPT_DIR}/external/vulscan/vulscan.nse" ]] && log_success "Vulscan: OK" || log_warn "Vulscan: Missing"
    [[ -d "${SCRIPT_DIR}/report" ]] && log_success "Report dir: OK" || log_warn "Report dir: Missing"
    
    echo ""
    
    if [[ "$all_ok" == "true" ]]; then
        log_success "Installation complete! Run: sudo ./waes.sh -h"
    else
        log_warn "Some tools are missing. You may need to install them manually."
    fi
}

show_banner() {
    echo ""
    echo -e "${GREEN}#############################################################${NC}"
    echo ""
    echo -e "        ${GREEN}WAES Installer${NC}"
    echo ""
    echo -e "        Web Auto Enum & Scanner"
    echo ""
    echo -e "${GREEN}#############################################################${NC}"
    echo ""
}

#==============================================================================
# MAIN
#==============================================================================

main() {
    show_banner
    check_root
    
    # Detect package manager
    local pkg_mgr
    pkg_mgr=$(detect_package_manager)
    log_info "Detected package manager: $pkg_mgr"
    
    # Install packages
    case "$pkg_mgr" in
        apt)
            install_apt
            ;;
        yum|dnf)
            install_yum
            ;;
        pacman)
            install_pacman
            ;;
        *)
            log_error "Unknown package manager. Please install packages manually."
            ;;
    esac
    
    echo ""
    setup_directories
    clone_dependencies
    init_submodules
    set_permissions
    
    echo ""
    verify_installation
}

main "$@"
