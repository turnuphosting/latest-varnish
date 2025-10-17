# Contributing to Varnish Cache Manager

Thank you for your interest in contributing to the Varnish Cache Manager for cPanel/WHM! This document provides guidelines for contributing to the project.

## 🚀 Getting Started

### Prerequisites
- cPanel/WHM development environment
- Basic knowledge of Perl, Bash, and web technologies
- Git and GitHub account
- Understanding of Varnish and web caching concepts

### Development Setup
```bash
# Fork the repository on GitHub
# Clone your fork
git clone https://github.com/YOUR_USERNAME/latest-varnish.git
cd latest-varnish

# Add upstream remote
git remote add upstream https://github.com/turnuphosting/latest-varnish.git

# Create a development branch
git checkout -b feature/your-feature-name
```

## 📝 How to Contribute

### 1. Types of Contributions

We welcome the following types of contributions:

#### 🐛 Bug Reports
- Use the GitHub issue tracker
- Include detailed reproduction steps
- Provide system information (OS, cPanel version, etc.)
- Include relevant log files

#### ✨ Feature Requests
- Describe the feature and its use case
- Explain how it would benefit users
- Consider backward compatibility

#### 🔧 Code Contributions
- Bug fixes
- New features
- Performance improvements
- Documentation updates
- Test improvements

#### 📚 Documentation
- README improvements
- Code comments
- Installation guides
- Troubleshooting guides

### 2. Development Process

#### Branch Naming Convention
- `feature/description` - New features
- `bugfix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring

#### Coding Standards

**Perl Code:**
```perl
# Use strict and warnings
use strict;
use warnings;

# Proper indentation (4 spaces)
sub example_function {
    my ($param1, $param2) = @_;
    
    if ($param1) {
        return $param2;
    }
    
    return 0;
}

# Use meaningful variable names
my $domain_name = $cgi->param('domain');
my @user_domains = get_user_domains($username);

# Add comments for complex logic
# Parse VCL configuration and validate syntax
my $vcl_content = parse_vcl_file($vcl_path);
```

**Bash Scripts:**
```bash
#!/bin/bash
set -euo pipefail

# Use functions for reusable code
install_package() {
    local package_name="$1"
    
    if command -v dnf &> /dev/null; then
        dnf install -y "$package_name"
    elif command -v yum &> /dev/null; then
        yum install -y "$package_name"
    else
        error "No supported package manager found"
    fi
}

# Use proper error handling
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}
```

**Template Files (Template Toolkit):**
```html
<!-- Use proper indentation -->
<div class="container">
    [% IF user_has_permission %]
        <div class="admin-panel">
            [% INCLUDE admin_controls.tt %]
        </div>
    [% END %]
</div>

<!-- Use meaningful variable names -->
[% FOREACH domain IN user_domains %]
    <tr>
        <td>[% domain.name | html %]</td>
        <td>[% domain.cache_hit_ratio %]%</td>
    </tr>
[% END %]
```

### 3. Testing Guidelines

#### Manual Testing
Before submitting a pull request, ensure:

1. **Installation Testing:**
   ```bash
   # Test clean installation
   ./quick-install.sh
   
   # Test uninstallation
   ./quick-uninstall.sh
   
   # Test reinstallation
   ./quick-install.sh
   ```

2. **Plugin Testing:**
   - Test WHM plugin functionality
   - Test cPanel plugin functionality
   - Test with different user permission levels
   - Test error handling and edge cases

3. **Service Testing:**
   ```bash
   # Test service management
   systemctl status varnish hitch httpd
   
   # Test cache functionality
   curl -I http://testdomain.com
   varnishlog -q 'ReqURL ~ "."'
   ```

#### Automated Testing
We encourage adding tests for new features:

```bash
# Example test script structure
#!/bin/bash
test_varnish_installation() {
    # Test Varnish installation
    assert_command_exists "varnishd"
    assert_service_running "varnish"
    assert_port_listening "80"
}

test_plugin_installation() {
    # Test plugin files
    assert_file_exists "/usr/local/cpanel/whostmgr/docroot/cgi/addon_varnish_manager.cgi"
    assert_file_executable "/usr/local/cpanel/whostmgr/docroot/cgi/addon_varnish_manager.cgi"
}
```

### 4. Commit Guidelines

#### Commit Message Format
```
type(scope): brief description

Longer description explaining the changes made and why.

Fixes #123
```

#### Commit Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

#### Examples
```
feat(whm): add real-time cache statistics dashboard

- Add WebSocket connection for live metrics
- Implement Chart.js integration
- Add cache hit ratio visualization
- Include bandwidth savings calculator

Fixes #45

fix(install): resolve Apache port conflict during installation

- Check for existing port bindings before configuration
- Add retry logic for Apache restart
- Improve error messages for port conflicts

Fixes #67

docs(readme): update installation instructions

- Add troubleshooting section
- Include system requirements
- Fix formatting issues
```

### 5. Pull Request Process

#### Before Submitting
1. Ensure your branch is up to date:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. Run tests and verify functionality
3. Update documentation if necessary
4. Add/update changelog entries

#### Pull Request Template
When creating a pull request, include:

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Code refactoring

## Testing
- [ ] Manual testing performed
- [ ] Installation tested
- [ ] Uninstallation tested
- [ ] Plugin functionality verified

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes (or clearly documented)

## Related Issues
Fixes #(issue number)
```

#### Review Process
1. Automated checks will run
2. Maintainers will review the code
3. Address any feedback
4. Once approved, the PR will be merged

### 6. Security Considerations

When contributing, consider:

#### Input Validation
```perl
# Always validate user input
sub validate_domain {
    my ($domain) = @_;
    
    # Check domain format
    return 0 unless $domain =~ /^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
    
    # Check domain ownership
    return verify_domain_ownership($domain);
}
```

#### CSRF Protection
```perl
# Include CSRF tokens in forms
my $csrf_token = generate_csrf_token();

# Validate tokens on submission
validate_csrf_token($cgi->param('csrf_token')) || die "Invalid CSRF token";
```

#### File Permissions
```bash
# Set appropriate permissions
chmod 755 /usr/local/cpanel/whostmgr/docroot/cgi/addon_varnish_manager.cgi
chmod 644 /etc/varnish/default.vcl
```

### 7. Documentation Standards

#### Code Comments
```perl
# Function: get_cache_statistics
# Purpose: Retrieve real-time cache performance metrics
# Parameters: 
#   - $domain (optional): specific domain to get stats for
# Returns: hashref with cache statistics
sub get_cache_statistics {
    my ($domain) = @_;
    # Implementation...
}
```

#### README Updates
When adding features, update:
- Feature list
- Installation instructions (if changed)
- Configuration examples
- Troubleshooting section

### 8. Release Process

#### Version Numbering
We use Semantic Versioning (SemVer):
- `MAJOR.MINOR.PATCH`
- Major: Breaking changes
- Minor: New features (backward compatible)
- Patch: Bug fixes

#### Release Checklist
1. Update version numbers
2. Update CHANGELOG.md
3. Test installation/uninstallation
4. Create release tag
5. Update documentation

## 🤝 Community Guidelines

### Code of Conduct
- Be respectful and inclusive
- Provide constructive feedback
- Help newcomers
- Focus on what's best for the community

### Communication
- Use clear, descriptive issue titles
- Provide minimal reproducible examples
- Be patient with response times
- Search existing issues before creating new ones

## 📞 Getting Help

- **Issues**: For bugs and feature requests
- **Discussions**: For questions and general discussion
- **Email**: For security issues or private matters

## 🎉 Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- Project documentation

Thank you for contributing to the Varnish Cache Manager! 🚀