# Varnish Cache Manager for WHM/cPanel

A comprehensive Varnish cache management solution with Hitch SSL proxy integration for cPanel/WHM environments. This plugin provides both administrator-level control through WHM and user-level cache management through cPanel.

## Features

### WHM Plugin (Administrator)
- **Real-time Performance Monitoring**: Live metrics, cache hit rates, response times
- **Service Management**: Start, stop, restart Varnish and Hitch services
- **Configuration Management**: VCL configuration editor, service settings
- **SSL Certificate Integration**: Automated Hitch configuration with SSL certificates
- **Domain Statistics**: Per-domain cache performance analytics
- **Installation Wizard**: Automated Varnish and Hitch installation
- **Comprehensive Logging**: Service logs and error monitoring

### cPanel Plugin (End Users)
- **Domain Cache Management**: Per-domain cache control for users
- **URL-specific Purging**: Clear cache for specific pages or resources
- **Pattern-based Purging**: Clear cache by URL patterns (e.g., all images)
- **Real-time Statistics**: Cache hit rates, bandwidth saved, performance metrics
- **URL Monitoring**: Track which URLs are cached and their performance
- **User-friendly Interface**: Intuitive dashboard with visual analytics

### Core Functionality
- **Varnish 7.5 Support**: Latest Varnish cache server
- **Hitch SSL Proxy**: TLS termination and HTTPS handling
- **Apache Integration**: Seamless port reconfiguration (80→8080, 443→8443)
- **Security**: CSRF protection, input validation, proper access controls
- **Performance Analytics**: Charts, graphs, and detailed metrics
- **Automated Installation**: One-click setup following best practices

## 🚀 One-Line Installation

Install everything (Varnish + Hitch + Plugins) with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash
```

Alternative using wget:
```bash
wget -qO- https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash
```

## 🗑️ One-Line Uninstallation

Remove everything completely with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-uninstall.sh | bash
```

## Installation

### Prerequisites
- cPanel/WHM server (RHEL/CentOS/Rocky/AlmaLinux)
- Root access
- Internet connectivity for package downloads

### Manual Installation (Alternative)

1. **Download and extract the plugin files**:
   ```bash
   git clone https://github.com/turnuphosting/latest-varnish.git
   cd latest-varnish
   ```

2. **Run the complete installation**:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Choose installation option**:
   - Option 1: Install plugins only (manual Varnish/Hitch setup)
   - Option 2: Install everything (plugins + automated Varnish/Hitch setup) **[Recommended]**
   - Option 3: Install Varnish/Hitch only (no plugins)

### Manual Installation

#### Install Plugins Only
```bash
# Install WHM plugin
chmod +x install_whm_plugin.sh
./install_whm_plugin.sh

# Install cPanel plugin
chmod +x install_cpanel_plugin.sh
./install_cpanel_plugin.sh
```

#### Install Varnish and Hitch (follows your installation instructions)
```bash
# System update
dnf update -y

# Install Varnish 7.5
curl -s https://packagecloud.io/install/repositories/varnishcache/varnish75/script.rpm.sh | bash
dnf install varnish -y

# Install Hitch
dnf install hitch -y

# Configure Apache ports (automated by plugin)
# Configure Varnish VCL (automated by plugin)
# Configure Hitch SSL proxy (automated by plugin)
```

## Post-Installation Configuration

### 1. Access WHM Plugin
- URL: `https://yourdomain:2087/cgi/addon_varnish_manager.cgi`
- Use the installation wizard if you chose "plugins only" installation

### 2. Configure SSL Certificates
- The plugin automatically detects and configures SSL certificates from cPanel
- Additional certificates can be added through the WHM interface

### 3. WordPress Integration
Add to wp-config.php for WordPress sites:
```php
if( strpos( $_SERVER['HTTP_X_FORWARDED_PROTO'], 'https') !== false )
    $_SERVER['HTTPS'] = 'on';
```

### 4. User Access
- Users can access the cache manager through cPanel → Software → Varnish Cache Manager
- Users can only manage cache for their own domains

## 🔄 Updates and GitHub Repository

This project is now available on GitHub: [https://github.com/turnuphosting/latest-varnish](https://github.com/turnuphosting/latest-varnish)

### Update to Latest Version
```bash
curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash
```

### Check for Updates
```bash
curl -s https://api.github.com/repos/turnuphosting/latest-varnish/releases/latest | grep tag_name
```

## Architecture

### Port Configuration
- **Port 80**: Varnish (HTTP traffic)
- **Port 443**: Hitch (HTTPS traffic)
- **Port 8080**: Apache (HTTP backend)
- **Port 8443**: Apache (HTTPS backend)
- **Port 4443**: Varnish-Hitch communication (internal)

### Service Stack
```
Internet → Hitch (443) → Varnish (4443) → Apache (8080/8443)
Internet → Varnish (80) → Apache (8080)
```

### Data Flow
1. **HTTPS requests**: Browser → Hitch → Varnish → Apache
2. **HTTP requests**: Browser → Varnish → Apache
3. **Cache hits**: Varnish serves content directly
4. **Cache misses**: Varnish fetches from Apache, caches response

## File Structure

```
plugins/
├── install.sh                          # Main installation script
├── install_whm_plugin.sh              # WHM plugin installer
├── install_cpanel_plugin.sh           # cPanel plugin installer
├── whm_varnish/                        # WHM plugin files
│   ├── cgi/
│   │   └── varnish_manager.cgi         # Main WHM CGI script
│   ├── templates/
│   │   ├── main.tt                     # Main WHM interface
│   │   ├── header.tt                   # Template header
│   │   └── footer.tt                   # Template footer
│   └── plugin.config                   # WHM plugin configuration
├── cpanel_varnish/                     # cPanel plugin files
│   ├── cgi/
│   │   └── varnish_user.cgi           # Main cPanel CGI script
│   ├── templates/
│   │   ├── main_user.tt               # Main cPanel interface
│   │   ├── cpanel_header.tt           # cPanel header
│   │   └── cpanel_footer.tt           # cPanel footer
│   └── plugin.config                   # cPanel plugin configuration
└── shared_lib/                         # Shared Perl modules
    ├── VarnishManager.pm               # Core Varnish management
    ├── HitchManager.pm                 # Hitch SSL proxy management
    ├── VarnishUserManager.pm           # User-level Varnish operations
    └── InstallationManager.pm          # Automated installation
```

## API Endpoints

### WHM Plugin AJAX Endpoints
- `getStats`: Real-time service statistics
- `getAnalytics`: Historical performance data
- `getDomainStats`: Per-domain statistics
- `purgeCache`: Cache purging operations
- `purgeAll`: Full cache purge
- `restartVarnish`: Restart Varnish service
- `restartHitch`: Restart Hitch service
- `getConfig`: Get service configurations
- `saveConfig`: Save service configurations

### cPanel Plugin AJAX Endpoints
- `getDomainStats`: User domain statistics
- `getUrlStats`: URL-level cache information
- `purgeUrl`: Purge specific URL cache
- `purgeDomain`: Purge entire domain cache
- `getRealTimeStats`: Live performance metrics
- `getTopUrls`: Most accessed cached URLs

## Security Features

### Access Control
- **WHM Plugin**: Root access only
- **cPanel Plugin**: User can only manage their own domains
- **Domain Validation**: Strict domain ownership verification
- **CSRF Protection**: All state-changing operations protected

### Input Validation
- URL validation and sanitization
- Pattern validation for regex-based purging
- Configuration file validation
- Service command validation

### Logging
- All administrative actions logged
- Security events tracked
- Installation process logged
- Service status changes recorded

## Troubleshooting

### Common Issues

#### 1. Varnish won't start
```bash
# Check configuration
varnishd -C -f /etc/varnish/default.vcl

# Check port conflicts
netstat -tlnp | grep :80

# Check logs
journalctl -u varnish -f
```

#### 2. Hitch SSL issues
```bash
# Test configuration
hitch --config=/etc/hitch/hitch.conf --test

# Check certificates
ls -la /etc/hitch/certs/

# Check logs
journalctl -u hitch -f
```

#### 3. Apache connection issues
```bash
# Verify Apache is running on correct ports
netstat -tlnp | grep apache2

# Check Apache configuration
/scripts/rebuildhttpdconf
```

#### 4. Cache not working
- Verify Varnish is receiving requests: `varnishlog`
- Check VCL configuration in WHM plugin
- Verify cache headers: `curl -I http://yourdomain.com`

### Log Files
- **Installation**: `/var/log/varnish_hitch_install_*.log`
- **Plugin actions**: `/var/log/varnish_plugin.log`
- **Varnish**: `journalctl -u varnish`
- **Hitch**: `journalctl -u hitch`
- **Apache**: `/usr/local/apache/logs/error_log`

## Performance Optimization

### Recommended VCL Tweaks
- Increase cache TTL for static assets
- Customize cache exclusions for dynamic content
- Implement custom cache purging rules
- Add cache warming strategies

### System Tuning
- Adjust Varnish memory allocation
- Configure Hitch worker processes
- Optimize Apache backend settings
- Monitor system resources

## Support and Documentation

### Official Documentation
- [Varnish Documentation](https://varnish-cache.org/docs/)
- [Hitch Documentation](https://hitch-tls.org/)
- [cPanel Plugin Development](https://documentation.cpanel.net/)

### Plugin Support
- Check plugin logs for detailed error information
- Use WHM plugin diagnostic tools
- Review installation logs for setup issues

## License

This plugin is provided as-is for educational and production use. Please ensure compliance with Varnish and Hitch licensing terms.

## Version History

### v1.0.0
- Initial release
- Full WHM and cPanel integration
- Automated installation
- SSL certificate management
- Real-time monitoring
- Comprehensive cache management

---

**Note**: This plugin automates the exact installation steps provided in your installation instructions, ensuring consistency and reliability in the setup process.