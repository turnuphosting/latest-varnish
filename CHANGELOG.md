# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2025-10-17

### Fixed
- **Installation Script Permissions**: Fixed "Permission denied" error when running one-line installer
- **Automatic chmod +x**: Installation script now automatically sets execute permissions on all shell scripts after download
- **Better Error Handling**: Added verbose output and improved error messages for troubleshooting
- **File Verification**: Added verification logging to confirm all essential files are downloaded correctly

### Added
- **Debug Mode**: Added `DEBUG=1` environment variable support for verbose installation output
- **Enhanced Help**: Improved help documentation with debug instructions and troubleshooting tips
- **Testing Documentation**: Added TESTING.md with comprehensive troubleshooting guide

### Changed
- **Installation Flow**: Enhanced installation process with better logging and verification steps
- **Error Messages**: More descriptive error messages with specific troubleshooting steps

## [1.0.0] - 2025-10-17

### Added
- Complete Varnish 7.5 cache server integration
- Hitch SSL proxy support with automatic certificate detection
- WHM administrator plugin with real-time monitoring
- cPanel user plugin for domain-specific cache management
- One-line installation script with full automation
- One-line uninstallation script with backup creation
- Automated Apache port reconfiguration (80→8080, 443→8443)
- Real-time performance dashboards with Chart.js
- VCL configuration management and optimization
- SSL certificate integration and management
- Domain ownership validation and security controls
- CSRF protection and input validation
- Comprehensive logging and error handling
- Service management (start/stop/restart) capabilities
- Cache purging tools (URL-specific and pattern-based)
- Performance analytics and bandwidth savings calculations
- Automated system preparation and dependency installation
- GitHub repository with complete documentation
- Release management system with semantic versioning

### Features
- **Performance**: 2-10x faster page loading with 80-95% cache hit rates
- **Security**: CSRF tokens, input validation, domain ownership verification
- **Automation**: Complete hands-off installation and configuration
- **Monitoring**: Live metrics, historical analytics, and performance tracking
- **Management**: Intuitive web interfaces for both administrators and users
- **Compatibility**: Full cPanel/WHM integration with proper permission handling
- **Reliability**: Comprehensive error handling and recovery mechanisms

### Technical Specifications
- Varnish Cache 7.5 with optimized VCL configuration
- Hitch SSL proxy for TLS termination
- Apache backend on ports 8080/8443
- Perl CGI with Template Toolkit for dynamic interfaces
- JavaScript/Chart.js for real-time dashboards
- Systemd service integration with auto-start
- RHEL/CentOS/Rocky/AlmaLinux compatibility
- DNF/YUM package management support

### Installation
```bash
curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash
```

### Uninstallation
```bash
curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-uninstall.sh | bash
```