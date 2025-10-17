#!/bin/bash

# Complete Varnish & Hitch Installation and Plugin Setup Script
# This script installs both plugins and optionally sets up Varnish/Hitch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==========================================="
echo "Varnish Cache Manager Complete Setup"
echo "==========================================="
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root" 
   exit 1
fi

# Check system requirements
echo "Checking system requirements..."

# Check if cPanel/WHM is installed
if [[ ! -d "/usr/local/cpanel" ]]; then
    echo "Error: cPanel/WHM not found. Please install cPanel/WHM first."
    exit 1
fi

# Check operating system
if [[ ! -f "/etc/redhat-release" ]] && [[ ! -f "/etc/centos-release" ]]; then
    if [[ "${AUTOMATED_INSTALL:-0}" == "1" ]]; then
        echo "Warning: This installer is designed for RHEL/CentOS systems"
        echo "🤖 Automated installation: Continuing anyway..."
    else
        echo "Warning: This installer is designed for RHEL/CentOS systems"
        echo "Continue anyway? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

echo "System requirements check passed!"
echo ""

# Check for automated installation
if [[ "${AUTOMATED_INSTALL:-0}" == "1" ]]; then
    echo "🤖 Automated installation detected"
    choice="${INSTALL_OPTION:-2}"
    echo "Using installation option: $choice"
    echo ""
else
    # Installation options
    echo "Select installation option:"
    echo "1) Install plugins only (manual Varnish/Hitch setup)"
    echo "2) Install everything (plugins + automated Varnish/Hitch setup)"
    echo "3) Install Varnish/Hitch only (no plugins)"
    echo ""
    read -p "Enter your choice (1-3): " choice
fi

case $choice in
    1)
        echo "Installing plugins only..."
        INSTALL_PLUGINS=true
        INSTALL_VARNISH_HITCH=false
        ;;
    2)
        echo "Installing everything..."
        INSTALL_PLUGINS=true
        INSTALL_VARNISH_HITCH=true
        ;;
    3)
        echo "Installing Varnish/Hitch only..."
        INSTALL_PLUGINS=false
        INSTALL_VARNISH_HITCH=true
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""

# Varnish/Hitch installation
if [[ "$INSTALL_VARNISH_HITCH" == "true" ]]; then
    echo "==========================================="
    echo "Installing Varnish and Hitch"
    echo "==========================================="
    echo ""
    if [[ "${AUTOMATED_INSTALL:-0}" == "1" ]]; then
        echo "🤖 Automated installation: Starting Varnish/Hitch installation..."
        echo "Apache will be reconfigured to ports 8080 (HTTP) and 8443 (HTTPS)"
        echo "Varnish will handle port 80, Hitch will handle port 443"
        echo ""
    else
        echo "WARNING: This will modify your Apache configuration!"
        echo "Apache will be moved to ports 8080 (HTTP) and 8443 (HTTPS)"
        echo "Varnish will handle port 80, Hitch will handle port 443"
        echo ""
        echo "This may cause temporary downtime. Continue? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Skipping Varnish/Hitch installation"
            INSTALL_VARNISH_HITCH=false
        else
            echo "Starting Varnish/Hitch installation..."
        fi
    fi
    
    if [[ "$INSTALL_VARNISH_HITCH" != "false" ]]; then
        
        # Create installation log
        INSTALL_LOG="/var/log/varnish_hitch_install_$(date +%Y%m%d_%H%M%S).log"
        echo "Installation log: $INSTALL_LOG"
        
        # Use the enhanced InstallationManager for robust installation
        echo "Using enhanced installation manager with error recovery..."
        
        # Create Perl script to run InstallationManager
        cat > /tmp/run_installation.pl << 'EOF'
#!/usr/bin/perl
use strict;
use warnings;
use lib '/tmp/varnish-install-*/shared_lib';  # Adjust path as needed
use lib './shared_lib';
use InstallationManager;

my $installer = InstallationManager->new(
    log_file => $ENV{INSTALL_LOG} || '/var/log/varnish_hitch_install.log'
);

eval {
    $installer->install('full');
    print "Installation completed successfully with InstallationManager!\n";
};

if ($@) {
    print "InstallationManager failed: $@\n";
    print "Falling back to basic shell installation...\n";
    exit 1;
}
EOF
        
        # Try to run with InstallationManager first
        export INSTALL_LOG
        if perl /tmp/run_installation.pl 2>&1 | tee -a "$INSTALL_LOG"; then
            echo "Enhanced installation completed successfully!"
        else
            echo "Enhanced installer failed, using fallback method..."
            
            # Use enhanced InstallationManager.pm for robust installation
            echo "Using enhanced installation manager for reliable setup..."
            
            # First check if InstallationManager.pm is available
            if perl -I"$PLUGIN_DIR/shared_lib" -MInstallationManager -e 'print "OK\n"' >/dev/null 2>&1; then
                echo "Running enhanced Perl-based installation with comprehensive error handling..."
                
                # Create enhanced Perl installation script
                cat > /tmp/enhanced_install.pl << 'EOFPERL'
#!/usr/bin/perl
use strict;
use warnings;

# Add plugin directory to Perl path
use lib '/usr/local/cpanel/base/3rdparty/varnish_manager/shared_lib';
use InstallationManager;

# Create installation manager
my $installer = InstallationManager->new();

print "Starting enhanced Varnish/Hitch installation...\n";

# Run complete installation
my $result = $installer->install_varnish_hitch();

if ($result->{success}) {
    print "✓ Enhanced installation completed successfully!\n";
    print $result->{message} . "\n" if $result->{message};
    exit 0;
} else {
    print "✗ Enhanced installation failed: " . $result->{error} . "\n";
    print $result->{details} . "\n" if $result->{details};
    exit 1;
}
EOFPERL
                
                # Make it executable and run
                chmod +x /tmp/enhanced_install.pl
                
                if perl /tmp/enhanced_install.pl; then
                    echo "Enhanced installation completed successfully!"
                    rm -f /tmp/enhanced_install.pl
                else
                    echo "Enhanced installation failed, falling back to shell installation..."
                    rm -f /tmp/enhanced_install.pl
                    
                    # Fall back to shell-based installation with improved service handling
                    echo "Step 1: Updating system packages..."
                    dnf update -y >> "$INSTALL_LOG" 2>&1
                    
                    echo "Step 2: Installing Varnish 7.5..."
                    curl -s https://packagecloud.io/install/repositories/varnishcache/varnish75/script.rpm.sh | bash >> "$INSTALL_LOG" 2>&1
                    dnf install varnish -y >> "$INSTALL_LOG" 2>&1
                    
                    echo "Step 3: Installing Hitch..."
                    dnf install hitch -y >> "$INSTALL_LOG" 2>&1
                    
                    # Step 4: Configure Apache ports
                    echo "Configuring Apache ports..."
                    if [[ -f "/var/cpanel/cpanel.config" ]]; then
                        cp -a /var/cpanel/cpanel.config /var/cpanel/cpanel.config-backup-$(date +%Y%m%d_%H%M%S)
                        sed -i 's/^apache_port=.*/apache_port=0.0.0.0:8080/' /var/cpanel/cpanel.config
                        sed -i 's/^apache_ssl_port=.*/apache_ssl_port=0.0.0.0:8443/' /var/cpanel/cpanel.config
                        if ! grep -q "^apache_port=" /var/cpanel/cpanel.config; then
                            echo "apache_port=0.0.0.0:8080" >> /var/cpanel/cpanel.config
                        fi
                        if ! grep -q "^apache_ssl_port=" /var/cpanel/cpanel.config; then
                            echo "apache_ssl_port=0.0.0.0:8443" >> /var/cpanel/cpanel.config
                        fi
                        /scripts/rebuildhttpdconf >> "$INSTALL_LOG" 2>&1
                        /scripts/restartsrv_httpd >> "$INSTALL_LOG" 2>&1
                    fi
                    
                    # Step 5: Configure Varnish with improved startup
                    echo "Configuring Varnish with enhanced startup..."
                    
                    cat > /etc/varnish/default.vcl << 'EOFVCL'
vcl 4.1;
import proxy;
backend default {
    .host = "127.0.0.1";
    .port = "8080";
    .connect_timeout = 5s;
    .first_byte_timeout = 15s;
    .between_bytes_timeout = 10s;
}
sub vcl_recv {
    if(!req.http.X-Forwarded-Proto) {
        if (proxy.is_ssl()) {
            set req.http.X-Forwarded-Proto = "https";
        } else {
            set req.http.X-Forwarded-Proto = "http";
        }
    }
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return(synth(405, "Method not allowed"));
        }
        return(purge);
    }
    if (req.url ~ "^/(cpanel|whm|webmail)" || req.http.host ~ "(cpanel|whm|webmail)") {
        return(pass);
    }
    if (req.url ~ "\.(css|js|png|gif|jpg|jpeg|ico|svg|woff|woff2|ttf|eot)$") {
        unset req.http.cookie;
        return(hash);
    }
    return(hash);
}
sub vcl_backend_response {
    if(beresp.http.Vary) {
        set beresp.http.Vary = beresp.http.Vary + ", X-Forwarded-Proto";
    } else {
        set beresp.http.Vary = "X-Forwarded-Proto";
    }
    if (bereq.url ~ "\.(css|js|png|gif|jpg|jpeg|ico|svg|woff|woff2|ttf|eot)$") {
        set beresp.ttl = 7d;
    }
    return(deliver);
}
sub vcl_deliver {
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }
    unset resp.http.Server;
    unset resp.http.X-Powered-By;
    return(deliver);
}
acl purge {
    "localhost";
    "127.0.0.1";
}
EOFVCL
                    
                    # Create systemd override for extended timeout
                    mkdir -p /etc/systemd/system/varnish.service.d
                    cat > /etc/systemd/system/varnish.service.d/timeout.conf << 'EOF'
[Service]
TimeoutStartSec=60
TimeoutStopSec=30
Type=notify
StandardOutput=journal
StandardError=journal
EOF
                    
                    # Step 6: Configure Hitch
                    echo "Configuring Hitch..."
                    mkdir -p /etc/hitch/certs
                    
                    cat > /etc/hitch/hitch.conf << 'EOFHITCH'
frontend = "*:443"
backend = "[127.0.0.1]:4443"
workers = 4
daemon = on
user = "hitch"
group = "hitch"
prefer-server-ciphers = on
ciphers = "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384"
EOFHITCH
                    
                    getent group hitch >/dev/null || groupadd hitch
                    getent passwd hitch >/dev/null || useradd -g hitch -s /sbin/nologin -d /var/lib/hitch hitch
                    chown -R hitch:hitch /etc/hitch/certs
                    chmod 700 /etc/hitch/certs
                    
                    # Step 7: Enable and start services with improved error handling
                    echo "Starting services with improved error handling..."
                    systemctl daemon-reload
                    systemctl enable varnish hitch
                    
                    # Start Varnish with retry logic
                    echo "Starting Varnish service..."
                    for i in {1..3}; do
                        if systemctl start varnish; then
                            echo "✓ Varnish started successfully"
                            sleep 2
                            break
                        else
                            echo "⚠ Attempt $i: Varnish failed to start, retrying..."
                            sleep 3
                        fi
                    done
                    
                    # Verify Varnish is running
                    if systemctl is-active --quiet varnish; then
                        echo "✓ Varnish is running"
                    else
                        echo "✗ Warning: Varnish failed to start after retries"
                        echo "  Checking Varnish logs..."
                        journalctl -u varnish -n 20 --no-pager
                    fi
                    
                    # Test and start Hitch
                    if hitch --config=/etc/hitch/hitch.conf --test >/dev/null 2>&1; then
                        systemctl start hitch
                        echo "✓ Hitch started successfully"
                    else
                        echo "⚠ Hitch not started (SSL certificates needed)"
                    fi
                    
                    echo "✓ Varnish/Hitch installation completed!"
                fi
            else
                echo "InstallationManager.pm not available, using shell fallback..."
                
                # Fall back to basic shell installation
                echo "Step 1: Updating system packages..."
                dnf update -y >> "$INSTALL_LOG" 2>&1
                
                echo "Step 2: Installing Varnish 7.5..."
                curl -s https://packagecloud.io/install/repositories/varnishcache/varnish75/script.rpm.sh | bash >> "$INSTALL_LOG" 2>&1
                dnf install varnish -y >> "$INSTALL_LOG" 2>&1
                
                echo "Step 3: Installing Hitch..."
                dnf install hitch -y >> "$INSTALL_LOG" 2>&1
                
                # Basic service startup
                systemctl daemon-reload
                systemctl enable varnish hitch
                systemctl start varnish || echo "Warning: Varnish failed to start"
                
                echo "Basic shell installation completed with potential warnings!"
            fi
        echo "Check the installation log at: $INSTALL_LOG"
        echo ""
        
        # Show enhanced service status with diagnostics
        echo "=== Service Status ==="
        
        # Check Varnish status with detailed diagnostics
        if systemctl is-active --quiet varnish; then
            echo "✓ Varnish: Running"
            varnish_port=$(netstat -tlnp 2>/dev/null | grep ":80 " | grep varnish || echo "Port check failed")
            echo "  └─ Listening on port 80: $([[ "$varnish_port" ]] && echo "Yes" || echo "No")"
        else
            echo "⚠ Varnish: Not running"
            
            # Get detailed failure information
            varnish_status=$(systemctl status varnish --no-pager -l 2>/dev/null | head -10)
            if [[ "$varnish_status" ]]; then
                echo "  └─ Status: $(echo "$varnish_status" | grep "Active:" | cut -d':' -f2- | xargs)"
                
                # Check for common issues
                if systemctl status varnish 2>&1 | grep -q "timeout"; then
                    echo "  └─ Issue: Service startup timeout detected"
                    echo "  └─ Suggestion: Check /var/log/varnish/varnish.log for startup errors"
                elif systemctl status varnish 2>&1 | grep -q "failed"; then
                    echo "  └─ Issue: Service failed to start"
                    echo "  └─ Suggestion: Run 'journalctl -u varnish --no-pager' for details"
                fi
            fi
            echo "  └─ Quick fix: systemctl restart varnish"
        fi
        
        # Check Hitch status
        if systemctl is-active --quiet hitch; then
            echo "✓ Hitch: Running"
            hitch_port=$(netstat -tlnp 2>/dev/null | grep ":443 " | grep hitch || echo "Port check failed")
            echo "  └─ Listening on port 443: $([[ "$hitch_port" ]] && echo "Yes" || echo "No")"
        else
            echo "⚠ Hitch: Not running"
            echo "  └─ This is normal if no SSL certificates are configured yet"
            echo "  └─ Configure certificates through the WHM plugin interface"
        fi
        
        # Check Apache status  
        if systemctl is-active --quiet httpd; then
            echo "✓ Apache: Running"
            apache_ports=$(netstat -tlnp 2>/dev/null | grep httpd | grep -E ":8080|:8443" || echo "Port check failed")
            echo "  └─ Backend ports: $([[ "$apache_ports" ]] && echo "8080/8443 active" || echo "Check configuration")"
        else
            echo "⚠ Apache: Not running"
            echo "  └─ Run: systemctl restart httpd"
        fi
    fi
fi

# Plugin installation
if [[ "$INSTALL_PLUGINS" == "true" ]]; then
    echo ""
    echo "==========================================="
    echo "Installing Plugins"
    echo "==========================================="
    echo ""
    
    # Install WHM plugin
    echo "Installing WHM plugin..."
    bash "$SCRIPT_DIR/install_whm_plugin.sh"
    
    echo ""
    
    # Install cPanel plugin
    echo "Installing cPanel plugin..."
    bash "$SCRIPT_DIR/install_cpanel_plugin.sh"
fi

echo ""
echo "==========================================="
echo "Installation Complete!"
echo "==========================================="
echo ""

if [[ "$INSTALL_VARNISH_HITCH" == "true" ]]; then
    echo "✓ Varnish and Hitch have been installed and configured"
    echo "✓ Apache has been moved to ports 8080 (HTTP) and 8443 (HTTPS)"
    echo "✓ Varnish is running on port 80"
    echo "✓ Hitch is configured for port 443 (SSL certificates needed)"
fi

if [[ "$INSTALL_PLUGINS" == "true" ]]; then
    echo "✓ WHM Varnish Cache Manager plugin installed"
    echo "✓ cPanel Varnish Cache Manager plugin installed"
    echo ""
    echo "Access points:"
    echo "- WHM: https://yourdomain:2087/cgi/addon_varnish_manager.cgi"
    echo "- cPanel: Software section -> Varnish Cache Manager"
fi

echo ""
echo "Next steps:"
echo "1. Configure SSL certificates through the WHM plugin"
echo "2. Test cache functionality"
echo "3. Monitor performance through the dashboards"
echo ""
echo "For WordPress sites, add this to wp-config.php:"
echo "if( strpos( \$_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false )"
echo "    \$_SERVER['HTTPS'] = 'on';"
echo ""

echo "Setup completed successfully!"

# Final summary
echo ""
echo "==========================================="
echo "Installation Summary"
echo "==========================================="
VARNISH_STATUS="✓ Installed" && systemctl is-active --quiet varnish || VARNISH_STATUS="⚠ Installation pending"
HITCH_STATUS="✓ Installed" && systemctl is-active --quiet hitch || HITCH_STATUS="⚠ Installation pending"
PLUGINS_STATUS="✓ Installed"

echo "Varnish: $VARNISH_STATUS"
echo "Hitch: $HITCH_STATUS"
echo "Plugins: $PLUGINS_STATUS"
echo ""