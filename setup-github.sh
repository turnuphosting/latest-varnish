# Initialize Git repository and push to GitHub
# Repository: https://github.com/turnuphosting/latest-varnish.git

echo "Initializing Git repository..."

# Initialize git repository
git init

# Add .gitignore file
cat > .gitignore << 'EOF'
# Log files
*.log
/var/log/

# Temporary files
*.tmp
*.temp
*~
.#*

# Backup files
*.bak
*.backup
backup_*/

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db
desktop.ini

# Installation temporary files
/tmp/
install_*.tmp

# Runtime files
*.pid
*.sock

# Compiled files
*.o
*.so
*.dylib

# Package manager files
node_modules/
vendor/

# Environment files
.env
.env.local
.env.*.local

# Cache directories
.cache/
cache/
EOF

# Create initial commit
git add .
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

# Create and push to main branch
git branch -M main

echo ""
echo "Git repository initialized successfully!"
echo ""
echo "To push to GitHub:"
echo "1. Create the repository at https://github.com/turnuphosting/latest-varnish"
echo "2. Run: git push -u origin main"
echo ""
echo "One-line installation will be available at:"
echo "curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash"
echo ""
echo "One-line uninstallation will be available at:"
echo "curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-uninstall.sh | bash"