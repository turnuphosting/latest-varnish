#!/bin/bash

# WHM Varnish Cache Manager Plugin Installation Script
# This script installs the WHM plugin for Varnish management

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_NAME="varnish_manager"
WHM_PLUGINS_DIR="/usr/local/cpanel/whostmgr/docroot/cgi"
PLUGIN_DIR="$WHM_PLUGINS_DIR/$PLUGIN_NAME"

echo "Installing WHM Varnish Cache Manager Plugin..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root" 
   exit 1
fi

# Check if WHM is installed
if [[ ! -d "/usr/local/cpanel/whostmgr" ]]; then
    echo "Error: WHM/cPanel not found. Please install cPanel/WHM first."
    exit 1
fi

# Create plugin directory
echo "Creating plugin directory..."
mkdir -p "$PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR/templates"
mkdir -p "$PLUGIN_DIR/lib"

# Copy plugin files
echo "Copying plugin files..."
cp -r "$SCRIPT_DIR/whm_varnish/"* "$PLUGIN_DIR/"

# Copy shared libraries
echo "Copying shared libraries..."
cp -r "$SCRIPT_DIR/shared_lib/"* "$PLUGIN_DIR/lib/"

# Set proper permissions
echo "Setting permissions..."
chmod 755 "$PLUGIN_DIR/cgi/"*.cgi
chmod 644 "$PLUGIN_DIR/templates/"*.tt
chmod 644 "$PLUGIN_DIR/lib/"*.pm
chown -R root:wheel "$PLUGIN_DIR"

# Create symlink for main CGI script
echo "Creating WHM integration..."
ln -sf "$PLUGIN_DIR/cgi/varnish_manager.cgi" "$WHM_PLUGINS_DIR/addon_varnish_manager.cgi"

# Add to WHM navigation (optional - requires WHM API integration)
if [[ -f "/usr/local/cpanel/whostmgr/docroot/cgi/addon_varnish_manager.cgi" ]]; then
    echo "Plugin installed successfully!"
    echo ""
    echo "Access the plugin at: https://yourdomain:2087/cgi/addon_varnish_manager.cgi"
    echo ""
    echo "To complete the setup:"
    echo "1. Log into WHM as root"
    echo "2. Navigate to the Varnish Cache Manager"
    echo "3. Run the installation wizard to install Varnish and Hitch"
    echo ""
else
    echo "Error: Plugin installation failed"
    exit 1
fi

echo "WHM Varnish Cache Manager Plugin installation completed!"