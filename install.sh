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
        
        # Step 1: System update
        echo "Updating system packages..."
        dnf update -y >> "$INSTALL_LOG" 2>&1
        
        # Step 2: Install Varnish
        echo "Installing Varnish 7.5..."
        curl -s https://packagecloud.io/install/repositories/varnishcache/varnish75/script.rpm.sh | bash >> "$INSTALL_LOG" 2>&1
        dnf install varnish -y >> "$INSTALL_LOG" 2>&1
        
        # Step 3: Install Hitch
        echo "Installing Hitch..."
        dnf install hitch -y >> "$INSTALL_LOG" 2>&1
        
        # Step 4: Configure Apache ports
        echo "Configuring Apache ports..."
        if [[ -f "/var/cpanel/cpanel.config" ]]; then
            cp -a /var/cpanel/cpanel.config /var/cpanel/cpanel.config-backup-$(date +%Y%m%d_%H%M%S)
            
            # Update Apache ports in cPanel config
            sed -i 's/^apache_port=.*/apache_port=0.0.0.0:8080/' /var/cpanel/cpanel.config
            sed -i 's/^apache_ssl_port=.*/apache_ssl_port=0.0.0.0:8443/' /var/cpanel/cpanel.config
            
            # Add ports if they don't exist
            if ! grep -q "^apache_port=" /var/cpanel/cpanel.config; then
                echo "apache_port=0.0.0.0:8080" >> /var/cpanel/cpanel.config
            fi
            if ! grep -q "^apache_ssl_port=" /var/cpanel/cpanel.config; then
                echo "apache_ssl_port=0.0.0.0:8443" >> /var/cpanel/cpanel.config
            fi
            
            # Rebuild Apache configuration
            /scripts/rebuildhttpdconf >> "$INSTALL_LOG" 2>&1
            /scripts/restartsrv_httpd >> "$INSTALL_LOG" 2>&1
        fi
        
        # Step 5: Configure Varnish
        echo "Configuring Varnish..."
        
        # Create Varnish VCL configuration
        cat > /etc/varnish/default.vcl << 'EOFVCL'
vcl 4.1;

import proxy;

backend default {
    .host = "127.0.0.1";
    .port = "8080";
}

sub vcl_recv {
    if(!req.http.X-Forwarded-Proto) {
        if (proxy.is_ssl()) {
            set req.http.X-Forwarded-Proto = "https";
        } else {
            set req.http.X-Forwarded-Proto = "http";
        }
    }
    
    # Handle purge requests
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return(synth(405, "Method not allowed"));
        }
        return(purge);
    }
    
    # Don't cache cPanel/WHM
    if (req.url ~ "^/(cpanel|whm|webmail)" ||
        req.http.host ~ "(cpanel|whm|webmail)") {
        return(pass);
    }
    
    # Cache static files
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
    
    # Cache static files for 1 week
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
    
    # Remove server info for security
    unset resp.http.Server;
    unset resp.http.X-Powered-By;
    
    return(deliver);
}

acl purge {
    "localhost";
    "127.0.0.1";
}
EOFVCL
        
        # Configure Varnish service
        cp /usr/lib/systemd/system/varnish.service /etc/systemd/system/
        sed -i 's|^ExecStart=.*|ExecStart=/usr/sbin/varnishd -a :80 -a 127.0.0.1:4443,proxy -f /etc/varnish/default.vcl -s malloc,256m|' /etc/systemd/system/varnish.service
        
        # Step 6: Configure Hitch
        echo "Configuring Hitch..."
        
        # Create Hitch directories
        mkdir -p /etc/hitch/certs
        
        # Basic Hitch configuration
        cat > /etc/hitch/hitch.conf << 'EOFHITCH'
# Frontend (listening) IP and port
frontend = "*:443"

# Backend (backend) IP and port where Hitch will send the requests
backend = "[127.0.0.1]:4443"

# Number of worker processes
workers = 4

# Run as daemon
daemon = on

# User and group to run as
user = "hitch"
group = "hitch"

# SSL/TLS settings
prefer-server-ciphers = on
ciphers = "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384"

# Certificate files will be added here by the plugin
# pem-file = "/etc/hitch/certs/example.pem"
EOFHITCH
        
        # Create hitch user
        getent group hitch >/dev/null || groupadd hitch
        getent passwd hitch >/dev/null || useradd -g hitch -s /sbin/nologin -d /var/lib/hitch hitch
        
        # Set permissions
        chown -R hitch:hitch /etc/hitch/certs
        chmod 700 /etc/hitch/certs
        
        # Step 7: Enable and start services
        echo "Starting services..."
        systemctl daemon-reload
        systemctl enable varnish hitch
        
        # Start Varnish first
        systemctl start varnish
        sleep 2
        
        # Test and start Hitch (may fail if no certificates)
        if hitch --config=/etc/hitch/hitch.conf --test >/dev/null 2>&1; then
            systemctl start hitch
        else
            echo "Warning: Hitch not started due to missing SSL certificates"
            echo "Configure SSL certificates through the plugin interface"
        fi
        
        echo "Varnish/Hitch installation completed!"
        echo "Check the installation log at: $INSTALL_LOG"
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