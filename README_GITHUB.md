# Varnish Cache Manager for cPanel/WHM

![Varnish Logo](https://varnish-cache.org/img/varnish-cache-white-logo.svg)

A comprehensive Varnish cache management solution with Hitch SSL proxy integration for cPanel/WHM environments. This plugin provides both administrator-level control through WHM and user-level cache management through cPanel.

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

Alternative using wget:
```bash
wget -qO- https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-uninstall.sh | bash
```

## ✨ Features

### 🔧 WHM Plugin (Administrator)
- **Real-time Performance Monitoring**: Live metrics, cache hit rates, response times
- **Service Management**: Start, stop, restart Varnish and Hitch services
- **Configuration Management**: VCL configuration editor, service settings
- **SSL Certificate Integration**: Automated Hitch configuration with SSL certificates
- **Domain Statistics**: Per-domain cache performance analytics
- **Installation Wizard**: Automated Varnish and Hitch installation
- **Comprehensive Logging**: Service logs and error monitoring

### 👤 cPanel Plugin (End Users)
- **Domain Cache Management**: Per-domain cache control for users
- **URL-specific Purging**: Clear cache for specific pages or resources
- **Pattern-based Purging**: Clear cache by URL patterns (e.g., all images)
- **Real-time Statistics**: Cache hit rates, bandwidth saved, performance metrics
- **URL Monitoring**: Track which URLs are cached and their performance
- **User-friendly Interface**: Intuitive dashboard with visual analytics

### ⚡ Core Functionality
- **Varnish 7.5 Support**: Latest Varnish cache server
- **Hitch SSL Proxy**: TLS termination and HTTPS handling
- **Apache Integration**: Seamless port reconfiguration (80→8080, 443→8443)
- **Security**: CSRF protection, input validation, proper access controls
- **Performance Analytics**: Charts, graphs, and detailed metrics
- **Automated Installation**: One-click setup following best practices

## 📋 Requirements

- cPanel/WHM server (RHEL/CentOS/Rocky/AlmaLinux)
- Root access
- Internet connectivity for package downloads

## 🏗️ Architecture

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

## 📊 What Gets Installed

### Automated Installation Includes:
- ✅ **Varnish Cache 7.5** - High-performance HTTP accelerator
- ✅ **Hitch SSL Proxy** - TLS termination proxy
- ✅ **WHM Plugin** - Administrator interface for service management
- ✅ **cPanel Plugin** - User interface for cache management
- ✅ **Apache Reconfiguration** - Automatic port adjustment
- ✅ **SSL Integration** - Automatic certificate detection and configuration
- ✅ **VCL Configuration** - Optimized Varnish configuration
- ✅ **Service Management** - Systemd integration and auto-start
- ✅ **Monitoring Tools** - Real-time statistics and logging

## 📱 Screenshots

### WHM Plugin Interface
- Real-time dashboard with live metrics
- Service control panel
- Configuration management
- SSL certificate management
- Domain analytics

### cPanel Plugin Interface  
- User-friendly cache management
- URL purging tools
- Performance statistics
- Domain-specific controls

## 🔧 Manual Installation

If you prefer to install components separately:

### Install Plugins Only
```bash
git clone https://github.com/turnuphosting/latest-varnish.git
cd latest-varnish
chmod +x install_whm_plugin.sh install_cpanel_plugin.sh
./install_whm_plugin.sh
./install_cpanel_plugin.sh
```

### Install Varnish and Hitch Only
```bash
git clone https://github.com/turnuphosting/latest-varnish.git  
cd latest-varnish
chmod +x install.sh
./install.sh
# Choose option 3: Install Varnish/Hitch only
```

## 🌐 Access Points

After installation:

- **WHM Plugin**: `https://yourdomain:2087/cgi/addon_varnish_manager.cgi`
- **cPanel Plugin**: Available in all user cPanels under "Software" section

## 🔒 Security Features

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

## 📈 Performance Benefits

- **Cache Hit Ratio**: Typically 80-95% for static content
- **Page Load Speed**: 2-10x faster page loading
- **Server Load**: Reduced CPU and memory usage
- **Bandwidth Savings**: Significant reduction in origin server requests
- **SSL Performance**: Hardware-accelerated SSL termination

## 🛠️ Troubleshooting

### Quick Diagnostic Commands
```bash
# Check service status
systemctl status varnish hitch httpd

# Check ports
netstat -tlnp | grep -E ':(80|443|8080|8443|4443)'

# Check Varnish logs
journalctl -u varnish -f

# Check Hitch logs  
journalctl -u hitch -f

# Test Varnish configuration
varnishd -C -f /etc/varnish/default.vcl
```

### Common Issues

#### Varnish won't start
```bash
# Check configuration syntax
varnishd -C -f /etc/varnish/default.vcl

# Check port conflicts
netstat -tlnp | grep :80
```

#### SSL issues
```bash
# Test Hitch configuration
hitch --config=/etc/hitch/hitch.conf --test

# Check certificate files
ls -la /etc/hitch/certs/
```

#### Cache not working
```bash
# Check if Varnish is receiving requests
varnishlog -q 'ReqURL ~ "."'

# Check cache headers
curl -I http://yourdomain.com
```

## 📁 File Structure

```
latest-varnish/
├── quick-install.sh                    # One-line installer
├── quick-uninstall.sh                  # One-line uninstaller  
├── install.sh                          # Main installation script
├── install_whm_plugin.sh              # WHM plugin installer
├── install_cpanel_plugin.sh           # cPanel plugin installer
├── setup-github.sh                    # GitHub repository setup
├── whm_varnish/                        # WHM plugin files
│   ├── cgi/varnish_manager.cgi         # Main WHM interface
│   ├── templates/                      # Template files
│   └── plugin.config                   # Plugin configuration
├── cpanel_varnish/                     # cPanel plugin files  
│   ├── cgi/varnish_user.cgi           # Main cPanel interface
│   ├── templates/                      # Template files
│   └── plugin.config                   # Plugin configuration
└── shared_lib/                         # Shared Perl modules
    ├── VarnishManager.pm               # Core Varnish management
    ├── HitchManager.pm                 # Hitch SSL proxy management
    ├── VarnishUserManager.pm           # User-level operations
    └── InstallationManager.pm          # Installation automation
```

## 🔄 Updates and Versioning

### Check for Updates
```bash
curl -s https://api.github.com/repos/turnuphosting/latest-varnish/releases/latest | grep tag_name
```

### Update Installation
```bash
# Automated update (preserves configurations)
curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup
```bash
git clone https://github.com/turnuphosting/latest-varnish.git
cd latest-varnish
# Make changes
git commit -am "Description of changes"
git push origin main
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/turnuphosting/latest-varnish/issues)
- **Documentation**: [Wiki](https://github.com/turnuphosting/latest-varnish/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/turnuphosting/latest-varnish/discussions)

## 🏢 About Turnup Hosting

This plugin is developed and maintained by [Turnup Hosting](https://turnuphosting.com), providing high-performance web hosting solutions.

## ⭐ Star History

[![Star History Chart](https://api.star-history.com/svg?repos=turnuphosting/latest-varnish&type=Date)](https://star-history.com/#turnuphosting/latest-varnish&Date)

---

**Made with ❤️ by Turnup Hosting**