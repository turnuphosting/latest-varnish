#!/bin/bash

# Varnish + Hitch + cPanel/WHM Plugins - One-Line Installer
# Version: 1.0.0
# Repository: https://github.com/turnuphosting/latest-varnish
# 
# Usage: curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash
# Or:    wget -qO- https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash

set -euo pipefail

# Enable debug mode if requested
if [[ "${DEBUG:-0}" == "1" ]]; then
    set -x
    echo "Debug mode enabled"
fi

# Configuration
REPO_URL="https://github.com/turnuphosting/latest-varnish.git"
REPO_BRANCH="main"
INSTALL_DIR="/tmp/varnish-install-$$"
LOG_FILE="/var/log/varnish_quick_install_$(date +%Y%m%d_%H%M%S).log"
VERSION="1.0.1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Please use: sudo $0"
    fi
}

# Check system requirements
check_requirements() {
    log "Checking system requirements..."
    
    # Check if cPanel/WHM is installed
    if [[ ! -f /usr/local/cpanel/cpanel ]] && [[ ! -f /usr/local/cpanel/whostmgr/bin/whostmgr ]]; then
        error "cPanel/WHM not found. This installer requires cPanel/WHM to be installed."
    fi
    
    # Check OS compatibility
    if [[ ! -f /etc/redhat-release ]]; then
        error "This installer only supports RHEL/CentOS/Rocky/AlmaLinux systems."
    fi
    
    # Check required commands
    local required_commands=("curl" "git" "systemctl" "dnf")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            if [[ "$cmd" == "dnf" ]]; then
                if command -v "yum" &> /dev/null; then
                    continue
                fi
            fi
            error "Required command '$cmd' not found. Please install it first."
        fi
    done
    
    log "System requirements check passed."
}

# Download and extract installation files
download_files() {
    log "Downloading installation files from GitHub..."
    
    # Create temporary directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Clone the repository
    if ! git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" .; then
        error "Failed to download files from GitHub repository."
    fi
    
    # Verify essential files exist
    local essential_files=(
        "install.sh"
        "shared_lib/InstallationManager.pm"
        "whm_varnish/cgi/varnish_manager.cgi"
        "cpanel_varnish/cgi/varnish_user.cgi"
    )
    
    for file in "${essential_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            error "Essential file '$file' not found in repository."
        fi
        log "✓ Found: $file"
    done
    
    log "All essential files verified successfully."
}

# Run the installation
run_installation() {
    log "Starting Varnish + Hitch + Plugins installation..."
    
    # Make all shell scripts executable
    chmod +x *.sh
    chmod +x install_*.sh
    
    # Verify the main installation script is executable
    if [[ ! -x "install.sh" ]]; then
        error "Failed to make install.sh executable"
    fi
    
    # Set environment variable for automated installation
    export AUTOMATED_INSTALL=1
    export INSTALL_OPTION=2  # Complete installation with Varnish + Hitch + Plugins
    
    # Run the main installer with verbose output
    log "Executing main installation script..."
    if ! bash -x ./install.sh 2>&1 | tee -a "$LOG_FILE"; then
        error "Installation failed. Check the log file at $LOG_FILE for details."
    fi
    
    log "Installation completed successfully!"
}

# Cleanup function
cleanup() {
    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        log "Cleaned up temporary files."
    fi
}

# Verify installation
verify_installation() {
    log "Verifying installation..."
    
    # Check services
    local services=("varnish" "hitch" "httpd")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service"; then
            info "✓ $service service is running"
        else
            warn "✗ $service service is not running"
        fi
    done
    
    # Check ports
    local ports=("80" "443" "8080" "8443")
    for port in "${ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            info "✓ Port $port is in use"
        else
            warn "✗ Port $port is not in use"
        fi
    done
    
    # Check plugin files
    if [[ -f /usr/local/cpanel/whostmgr/docroot/cgi/addon_varnish_manager.cgi ]]; then
        info "✓ WHM plugin installed"
    else
        warn "✗ WHM plugin not found"
    fi
    
    if [[ -f /usr/local/cpanel/base/frontend/paper_lantern/varnish_user/index.cgi ]]; then
        info "✓ cPanel plugin installed"
    else
        warn "✗ cPanel plugin not found"
    fi
    
    log "Installation verification complete."
}

# Display success message
show_success() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                    INSTALLATION COMPLETE!                   ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}🚀 Varnish Cache Manager with Hitch SSL Proxy is now installed!${NC}"
    echo ""
    echo -e "${YELLOW}📋 Access Points:${NC}"
    echo -e "   • WHM Plugin: https://$(hostname):2087/cgi/addon_varnish_manager.cgi"
    echo -e "   • cPanel Plugin: Available in all user cPanels under 'Software'"
    echo ""
    echo -e "${YELLOW}📊 Service Status:${NC}"
    systemctl is-active --quiet varnish && echo -e "   • ${GREEN}✓${NC} Varnish Cache: Running" || echo -e "   • ${RED}✗${NC} Varnish Cache: Stopped"
    systemctl is-active --quiet hitch && echo -e "   • ${GREEN}✓${NC} Hitch SSL Proxy: Running" || echo -e "   • ${RED}✗${NC} Hitch SSL Proxy: Stopped"
    systemctl is-active --quiet httpd && echo -e "   • ${GREEN}✓${NC} Apache Web Server: Running" || echo -e "   • ${RED}✗${NC} Apache Web Server: Stopped"
    echo ""
    echo -e "${YELLOW}📁 Configuration Files:${NC}"
    echo -e "   • Varnish: /etc/varnish/default.vcl"
    echo -e "   • Hitch: /etc/hitch/hitch.conf"
    echo -e "   • Apache: /usr/local/apache/conf/httpd.conf"
    echo ""
    echo -e "${YELLOW}📝 Log Files:${NC}"
    echo -e "   • Installation: $LOG_FILE"
    echo -e "   • Plugin Actions: /var/log/varnish_plugin.log"
    echo -e "   • Varnish: journalctl -u varnish"
    echo -e "   • Hitch: journalctl -u hitch"
    echo ""
    echo -e "${YELLOW}🔧 Uninstall Command:${NC}"
    echo -e "   curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-uninstall.sh | bash"
    echo ""
    echo -e "${GREEN}Thank you for using Turnup Hosting's Varnish Cache Manager!${NC}"
    echo ""
}

# Main installation function
main() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        Varnish Cache + Hitch SSL + cPanel/WHM Plugins       ║${NC}"
    echo -e "${BLUE}║                   One-Line Installer v$VERSION                   ║${NC}"
    echo -e "${BLUE}║              https://github.com/turnuphosting               ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log "Starting one-line installation process..."
    
    # Set trap for cleanup
    trap cleanup EXIT
    
    # Run installation steps
    check_root
    check_requirements
    download_files
    run_installation
    verify_installation
    show_success
    
    log "One-line installation completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Varnish Cache + Hitch SSL + cPanel/WHM Plugins - One-Line Installer"
        echo ""
        echo "Usage:"
        echo "  curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash"
        echo "  wget -qO- https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --version, -v  Show version information"
        echo ""
        echo "Environment Variables:"
        echo "  DEBUG=1        Enable debug mode with verbose output"
        echo "  AUTOMATED_INSTALL=1  Skip confirmation prompts (set automatically)"
        echo ""
        echo "Debug Installation:"
        echo "  DEBUG=1 curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash"
        echo ""
        exit 0
        ;;
    --version|-v)
        echo "Varnish Quick Installer v$VERSION"
        echo "Repository: $REPO_URL"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac