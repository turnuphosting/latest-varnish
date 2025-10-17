#!/bin/bash

# cPanel Varnish Cache Manager Plugin Installation Script
# This script installs the cPanel plugin for user-level Varnish management

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_NAME="varnish_user"
CPANEL_PLUGINS_DIR="/usr/local/cpanel/base/frontend/paper_lantern"
PLUGIN_DIR="$CPANEL_PLUGINS_DIR/$PLUGIN_NAME"

echo "Installing cPanel Varnish Cache Manager Plugin..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root" 
   exit 1
fi

# Check if cPanel is installed
if [[ ! -d "/usr/local/cpanel/base/frontend" ]]; then
    echo "Error: cPanel not found. Please install cPanel first."
    exit 1
fi

# Create plugin directory
echo "Creating plugin directory..."
mkdir -p "$PLUGIN_DIR"
mkdir -p "$PLUGIN_DIR/templates"
mkdir -p "$PLUGIN_DIR/lib"

# Copy plugin files
echo "Copying plugin files..."
cp -r "$SCRIPT_DIR/cpanel_varnish/"* "$PLUGIN_DIR/"

# Copy shared libraries
echo "Copying shared libraries..."
cp -r "$SCRIPT_DIR/shared_lib/"* "$PLUGIN_DIR/lib/"

# Set proper permissions
echo "Setting permissions..."
chmod 755 "$PLUGIN_DIR/cgi/"*.cgi
chmod 644 "$PLUGIN_DIR/templates/"*.tt
chmod 644 "$PLUGIN_DIR/lib/"*.pm
chown -R root:wheel "$PLUGIN_DIR"

# Create cPanel integration files
echo "Creating cPanel integration..."

# Create dynamicui configuration
cat > "/var/cpanel/apps/varnish_cache_manager.conf" << 'EOF'
---
group: Software
name: Varnish Cache Manager
version: 1.0
vendor: YourCompany
description: "Manage Varnish cache for improved website performance"
url: varnish_user/cgi/varnish_user.cgi
help: https://example.com/help/varnish
icon: icon-performance.png
feature_requires:
  - allow_cache_management
EOF

# Create feature list entry
if [[ ! -f "/var/cpanel/features/default" ]]; then
    echo "Warning: Could not find cPanel features file"
else
    # Add cache management feature if not present
    if ! grep -q "allow_cache_management" "/var/cpanel/features/default"; then
        echo "allow_cache_management=1" >> "/var/cpanel/features/default"
        echo "Added cache management feature to default feature list"
    fi
fi

# Register with cPanel
/usr/local/cpanel/bin/register_appconfig "/var/cpanel/apps/varnish_cache_manager.conf"

echo "cPanel plugin installed successfully!"
echo ""
echo "Users can now access the Varnish Cache Manager from their cPanel interface."
echo ""
echo "To complete the setup:"
echo "1. Ensure Varnish and Hitch are properly installed (use WHM plugin)"
echo "2. Users will see 'Varnish Cache Manager' in the Software section of cPanel"
echo "3. Users can manage cache for their domains through the interface"
echo ""

echo "cPanel Varnish Cache Manager Plugin installation completed!"