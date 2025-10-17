#!/bin/bash

# Varnish + Hitch + cPanel/WHM Plugins - One-Line Uninstaller
# Version: 1.0.0
# Repository: https://github.com/turnuphosting/latest-varnish
# 
# Usage: curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-uninstall.sh | bash
# Or:    wget -qO- https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-uninstall.sh | bash

set -euo pipefail

# Configuration
LOG_FILE="/var/log/varnish_quick_uninstall_$(date +%Y%m%d_%H%M%S).log"
VERSION="1.0.1"
BACKUP_DIR="/root/varnish_backup_$(date +%Y%m%d_%H%M%S)"

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

# Confirmation prompt
confirm_uninstall() {
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                        WARNING!                             ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}This will completely remove:${NC}"
    echo -e "  • Varnish Cache Server and all configurations"
    echo -e "  • Hitch SSL Proxy and certificates"
    echo -e "  • WHM and cPanel plugins"
    echo -e "  • All cache data and statistics"
    echo -e "  • Apache port configurations will be restored"
    echo ""
    echo -e "${YELLOW}Your website content and cPanel accounts will NOT be affected.${NC}"
    echo ""
    
    # Check for automated uninstall environment variable
    if [[ "${AUTOMATED_UNINSTALL:-0}" == "1" ]]; then
        log "Automated uninstall confirmed via environment variable."
        return 0
    fi
    
    read -p "Are you sure you want to continue? (Type 'YES' to confirm): " confirmation
    
    if [[ "$confirmation" != "YES" ]]; then
        echo "Uninstallation cancelled."
        exit 0
    fi
    
    log "Uninstallation confirmed by user."
}

# Create backup of configurations
create_backup() {
    log "Creating backup of configurations..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup Varnish configuration
    if [[ -f /etc/varnish/default.vcl ]]; then
        cp /etc/varnish/default.vcl "$BACKUP_DIR/varnish_default.vcl" 2>/dev/null || true
    fi
    
    # Backup Hitch configuration
    if [[ -f /etc/hitch/hitch.conf ]]; then
        cp /etc/hitch/hitch.conf "$BACKUP_DIR/hitch.conf" 2>/dev/null || true
    fi
    
    # Backup Apache configuration
    if [[ -f /usr/local/apache/conf/httpd.conf ]]; then
        cp /usr/local/apache/conf/httpd.conf "$BACKUP_DIR/httpd.conf" 2>/dev/null || true
    fi
    
    # Backup any custom VCL files
    if [[ -d /etc/varnish ]]; then
        cp -r /etc/varnish "$BACKUP_DIR/varnish_configs" 2>/dev/null || true
    fi
    
    log "Backup created at: $BACKUP_DIR"
}

# Stop services
stop_services() {
    log "Stopping services..."
    
    local services=("varnish" "hitch")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            log "Stopping $service service..."
            systemctl stop "$service" || warn "Failed to stop $service"
            systemctl disable "$service" || warn "Failed to disable $service"
        else
            info "$service service is not running"
        fi
    done
}

# Remove Varnish
remove_varnish() {
    log "Removing Varnish Cache..."
    
    # Remove packages
    if command -v dnf &> /dev/null; then
        dnf remove -y varnish varnish-devel varnish-docs 2>/dev/null || true
    elif command -v yum &> /dev/null; then
        yum remove -y varnish varnish-devel varnish-docs 2>/dev/null || true
    fi
    
    # Remove configuration files
    rm -rf /etc/varnish
    rm -rf /var/lib/varnish
    rm -rf /usr/share/varnish
    
    # Remove systemd files
    rm -f /etc/systemd/system/varnish.service
    rm -f /usr/lib/systemd/system/varnish.service
    
    # Remove user and group
    if id -u varnish >/dev/null 2>&1; then
        userdel varnish 2>/dev/null || true
    fi
    if getent group varnish >/dev/null 2>&1; then
        groupdel varnish 2>/dev/null || true
    fi
    
    log "Varnish removed successfully."
}

# Remove Hitch
remove_hitch() {
    log "Removing Hitch SSL Proxy..."
    
    # Remove packages
    if command -v dnf &> /dev/null; then
        dnf remove -y hitch 2>/dev/null || true
    elif command -v yum &> /dev/null; then
        yum remove -y hitch 2>/dev/null || true
    fi
    
    # Remove configuration files
    rm -rf /etc/hitch
    rm -rf /var/lib/hitch
    
    # Remove systemd files
    rm -f /etc/systemd/system/hitch.service
    rm -f /usr/lib/systemd/system/hitch.service
    
    # Remove user and group
    if id -u hitch >/dev/null 2>&1; then
        userdel hitch 2>/dev/null || true
    fi
    if getent group hitch >/dev/null 2>&1; then
        groupdel hitch 2>/dev/null || true
    fi
    
    log "Hitch removed successfully."
}

# Remove plugins
remove_plugins() {
    log "Removing cPanel/WHM plugins..."
    
    # Remove WHM plugin
    local whm_plugin_dir="/usr/local/cpanel/whostmgr/docroot/cgi"
    if [[ -f "$whm_plugin_dir/addon_varnish_manager.cgi" ]]; then
        rm -f "$whm_plugin_dir/addon_varnish_manager.cgi"
        log "WHM plugin removed."
    fi
    
    # Remove WHM plugin templates
    rm -rf /usr/local/cpanel/whostmgr/docroot/templates/varnish
    
    # Remove cPanel plugin files
    local cpanel_themes=("paper_lantern" "jupiter" "x3")
    for theme in "${cpanel_themes[@]}"; do
        local plugin_dir="/usr/local/cpanel/base/frontend/$theme/varnish_user"
        if [[ -d "$plugin_dir" ]]; then
            rm -rf "$plugin_dir"
            log "cPanel plugin removed from $theme theme."
        fi
    done
    
    # Remove shared libraries
    local lib_dir="/usr/local/cpanel/perl5/lib"
    rm -f "$lib_dir/VarnishManager.pm"
    rm -f "$lib_dir/HitchManager.pm"
    rm -f "$lib_dir/VarnishUserManager.pm"
    rm -f "$lib_dir/InstallationManager.pm"
    
    # Remove plugin registry entries
    local cpanel_config="/var/cpanel/apps"
    rm -f "$cpanel_config/varnish_user.conf"
    
    log "Plugins removed successfully."
}

# Restore Apache configuration
restore_apache() {
    log "Restoring Apache configuration..."
    
    # Backup current Apache config
    if [[ -f /usr/local/apache/conf/httpd.conf ]]; then
        cp /usr/local/apache/conf/httpd.conf "$BACKUP_DIR/httpd.conf.before_restore" 2>/dev/null || true
    fi
    
    # Restore original ports
    if [[ -f /usr/local/apache/conf/httpd.conf ]]; then
        # Change Listen ports back to 80 and 443
        sed -i 's/^Listen 8080$/Listen 80/' /usr/local/apache/conf/httpd.conf 2>/dev/null || true
        sed -i 's/^Listen 8443$/Listen 443/' /usr/local/apache/conf/httpd.conf 2>/dev/null || true
        
        # Remove any Varnish-related configurations
        sed -i '/# Varnish configuration/,/# End Varnish configuration/d' /usr/local/apache/conf/httpd.conf 2>/dev/null || true
    fi
    
    # Rebuild httpd configuration using cPanel tools
    if command -v /scripts/rebuildhttpdconf &> /dev/null; then
        /scripts/rebuildhttpdconf
        log "Apache configuration rebuilt using cPanel tools."
    fi
    
    # Restart Apache
    if systemctl is-active --quiet httpd; then
        systemctl restart httpd
        log "Apache restarted successfully."
    else
        systemctl start httpd
        log "Apache started successfully."
    fi
}

# Clean up repositories
cleanup_repositories() {
    log "Cleaning up package repositories..."
    
    # Remove Varnish repository
    rm -f /etc/yum.repos.d/varnishcache_varnish75.repo
    rm -f /etc/yum.repos.d/varnish*.repo
    
    # Clean package cache
    if command -v dnf &> /dev/null; then
        dnf clean all 2>/dev/null || true
    elif command -v yum &> /dev/null; then
        yum clean all 2>/dev/null || true
    fi
    
    log "Repository cleanup completed."
}

# Remove log files and data
cleanup_logs() {
    log "Cleaning up log files and data..."
    
    # Remove plugin logs
    rm -f /var/log/varnish_plugin.log
    rm -f /var/log/varnish_hitch_install_*.log
    
    # Remove any remaining cache data
    rm -rf /var/cache/varnish
    rm -rf /tmp/varnish*
    
    # Remove systemd journal entries (optional)
    journalctl --vacuum-time=1d 2>/dev/null || true
    
    log "Log cleanup completed."
}

# Verify removal
verify_removal() {
    log "Verifying removal..."
    
    local issues=0
    
    # Check services
    local services=("varnish" "hitch")
    for service in "${services[@]}"; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            warn "✗ $service service is still running"
            ((issues++))
        else
            info "✓ $service service removed"
        fi
    done
    
    # Check packages
    if command -v varnishd &> /dev/null; then
        warn "✗ Varnish binary still found"
        ((issues++))
    else
        info "✓ Varnish binary removed"
    fi
    
    if command -v hitch &> /dev/null; then
        warn "✗ Hitch binary still found"
        ((issues++))
    else
        info "✓ Hitch binary removed"
    fi
    
    # Check plugin files
    if [[ -f /usr/local/cpanel/whostmgr/docroot/cgi/addon_varnish_manager.cgi ]]; then
        warn "✗ WHM plugin still found"
        ((issues++))
    else
        info "✓ WHM plugin removed"
    fi
    
    # Check ports
    local expected_ports=("80" "443")
    for port in "${expected_ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":$port.*httpd"; then
            info "✓ Apache is listening on port $port"
        else
            warn "✗ Apache is not listening on port $port"
            ((issues++))
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        log "Removal verification completed successfully."
    else
        warn "Removal completed with $issues potential issues. Check the log for details."
    fi
}

# Display success message
show_success() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   UNINSTALLATION COMPLETE!                  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}🗑️  Varnish Cache Manager has been completely removed!${NC}"
    echo ""
    echo -e "${YELLOW}📋 What was removed:${NC}"
    echo -e "   • ✓ Varnish Cache Server"
    echo -e "   • ✓ Hitch SSL Proxy"
    echo -e "   • ✓ WHM Administration Plugin"
    echo -e "   • ✓ cPanel User Plugin"
    echo -e "   • ✓ All configuration files"
    echo -e "   • ✓ Apache port configuration restored"
    echo ""
    echo -e "${YELLOW}💾 Backup created at:${NC} $BACKUP_DIR"
    echo -e "${YELLOW}📝 Log file:${NC} $LOG_FILE"
    echo ""
    echo -e "${YELLOW}🔧 Reinstall command:${NC}"
    echo -e "   curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash"
    echo ""
    echo -e "${GREEN}Your website is now running directly on Apache (ports 80/443).${NC}"
    echo ""
}

# Main uninstallation function
main() {
    echo ""
    echo -e "${RED}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║        Varnish Cache + Hitch SSL + cPanel/WHM Plugins       ║${NC}"
    echo -e "${RED}║                  One-Line Uninstaller v$VERSION                  ║${NC}"
    echo -e "${RED}║              https://github.com/turnuphosting               ║${NC}"
    echo -e "${RED}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log "Starting one-line uninstallation process..."
    
    # Run uninstallation steps
    check_root
    confirm_uninstall
    create_backup
    stop_services
    remove_varnish
    remove_hitch
    remove_plugins
    restore_apache
    cleanup_repositories
    cleanup_logs
    verify_removal
    show_success
    
    log "One-line uninstallation completed successfully!"
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Varnish Cache + Hitch SSL + cPanel/WHM Plugins - One-Line Uninstaller"
        echo ""
        echo "Usage:"
        echo "  curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-uninstall.sh | bash"
        echo "  wget -qO- https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-uninstall.sh | bash"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --version, -v  Show version information"
        echo ""
        echo "Environment Variables:"
        echo "  AUTOMATED_UNINSTALL=1  Skip confirmation prompt"
        echo ""
        exit 0
        ;;
    --version|-v)
        echo "Varnish Quick Uninstaller v$VERSION"
        echo "Repository: https://github.com/turnuphosting/latest-varnish"
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac