# GitHub Repository Setup Instructions

## 1. Initialize Local Repository

```bash
# Navigate to the project directory
cd /path/to/varnish-cpanel-plugin

# Initialize git repository
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Varnish Cache Manager with Hitch SSL Proxy for cPanel/WHM

Features:
- Complete Varnish 7.5 integration
- Hitch SSL proxy support  
- WHM administrator plugin
- cPanel user plugin
- One-line installation/uninstallation
- Automated configuration
- Real-time monitoring
- Cache management tools

Version: 1.0.0"

# Add remote repository
git remote add origin https://github.com/turnuphosting/latest-varnish.git

# Create and switch to main branch
git branch -M main
```

## 2. Create GitHub Repository

1. Go to [GitHub](https://github.com)
2. Click "New repository"
3. Repository name: `latest-varnish`
4. Owner: `turnuphosting`
5. Description: "Varnish Cache Manager with Hitch SSL Proxy for cPanel/WHM - One-line installation"
6. Keep it public
7. Don't initialize with README (we have our own)
8. Click "Create repository"

## 3. Push to GitHub

```bash
# Push to GitHub
git push -u origin main

# Push tags (if any)
git push origin --tags
```

## 4. Set File Permissions (Linux/macOS)

```bash
# Make shell scripts executable
chmod +x *.sh
chmod +x install_*.sh
chmod +x setup-github.sh
chmod +x release.sh

# Commit permission changes
git add .
git commit -m "Set executable permissions on shell scripts"
git push
```

## 5. Create First Release

```bash
# Use the release script
./release.sh release 1.0.0

# Or manually create a release on GitHub
```

## 6. Verify Installation Commands

After pushing to GitHub, test the one-line installation:

```bash
# Test the installation command (in a test environment)
curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash

# Test the uninstallation command
curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-uninstall.sh | bash
```

## 7. Repository URLs

- **Repository**: https://github.com/turnuphosting/latest-varnish
- **Install Script**: https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh  
- **Uninstall Script**: https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-uninstall.sh
- **Releases**: https://github.com/turnuphosting/latest-varnish/releases

## 8. Installation Commands for Users

### One-Line Installation
```bash
curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash
```

### One-Line Uninstallation  
```bash
curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-uninstall.sh | bash
```

## 9. Future Updates

To release new versions:

```bash
# For patch releases (bug fixes)
./release.sh patch

# For minor releases (new features)
./release.sh minor  

# For major releases (breaking changes)
./release.sh major

# For specific version
./release.sh release 1.2.3
```

## 10. Repository Features

✅ **One-line installation** - Complete automation  
✅ **One-line uninstallation** - Clean removal with backups  
✅ **GitHub Actions** - Automated testing and releases  
✅ **Semantic versioning** - Proper version management  
✅ **Comprehensive documentation** - README, CHANGELOG, CONTRIBUTING  
✅ **MIT License** - Open source friendly  
✅ **Issue templates** - Community support  

## Success Verification

After setup, users should be able to:

1. **Install with one command**: The curl command downloads and runs the installer
2. **Access WHM plugin**: Available at `/cgi/addon_varnish_manager.cgi`  
3. **Access cPanel plugin**: Available in user cPanels under "Software"
4. **Uninstall cleanly**: The uninstall command removes everything and restores Apache
5. **Get support**: Through GitHub issues and documentation

Your Varnish Cache Manager is now ready for production use! 🚀