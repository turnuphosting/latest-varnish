#!/bin/bash

# Varnish Cache Manager - Release Management Script
# This script automates version updates and releases

set -euo pipefail

# Configuration
CURRENT_VERSION="1.0.0"
REPO_URL="https://github.com/turnuphosting/latest-varnish.git"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Check if we're in the right directory
check_repository() {
    if [[ ! -f "quick-install.sh" ]] || [[ ! -f "quick-uninstall.sh" ]]; then
        error "This script must be run from the repository root directory"
    fi
    
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "This is not a git repository"
    fi
}

# Get current version from files
get_current_version() {
    if [[ -f "VERSION" ]]; then
        cat VERSION
    else
        echo "$CURRENT_VERSION"
    fi
}

# Update version in all files
update_version() {
    local new_version="$1"
    
    log "Updating version to $new_version in all files..."
    
    # Update VERSION file
    echo "$new_version" > VERSION
    
    # Update quick-install.sh
    sed -i "s/VERSION=\".*\"/VERSION=\"$new_version\"/" quick-install.sh
    
    # Update quick-uninstall.sh
    sed -i "s/VERSION=\".*\"/VERSION=\"$new_version\"/" quick-uninstall.sh
    
    # Update README files
    sed -i "s/Version: [0-9]\+\.[0-9]\+\.[0-9]\+/Version: $new_version/g" README.md
    sed -i "s/Version: [0-9]\+\.[0-9]\+\.[0-9]\+/Version: $new_version/g" README_GITHUB.md
    
    # Update any other version references
    find . -name "*.pm" -exec sed -i "s/\$VERSION = '[0-9]\+\.[0-9]\+\.[0-9]\+'/\$VERSION = '$new_version'/g" {} \;
    
    log "Version updated successfully"
}

# Validate version format
validate_version() {
    local version="$1"
    
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        error "Invalid version format. Use semantic versioning (e.g., 1.2.3)"
    fi
}

# Generate changelog entry
generate_changelog() {
    local version="$1"
    local changelog_file="CHANGELOG.md"
    
    if [[ ! -f "$changelog_file" ]]; then
        cat > "$changelog_file" << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

EOF
    fi
    
    # Create temporary file with new entry
    local temp_file=$(mktemp)
    local date=$(date '+%Y-%m-%d')
    
    # Add new version entry
    cat > "$temp_file" << EOF
## [$version] - $date

### Added
- 

### Changed
- 

### Fixed
- 

### Removed
- 

EOF
    
    # Insert new entry after the header
    if grep -q "^## \[" "$changelog_file"; then
        # Insert before first existing entry
        sed -i "/^## \[/i\\$(cat "$temp_file")" "$changelog_file"
    else
        # Append to end of file
        cat "$temp_file" >> "$changelog_file"
    fi
    
    rm "$temp_file"
    
    info "Please edit $changelog_file to add release notes"
    
    # Open changelog for editing if editor is available
    if command -v "${EDITOR:-nano}" &> /dev/null; then
        read -p "Edit changelog now? (y/N): " edit_now
        if [[ "$edit_now" =~ ^[Yy]$ ]]; then
            "${EDITOR:-nano}" "$changelog_file"
        fi
    fi
}

# Create git tag and commit
create_release_commit() {
    local version="$1"
    
    log "Creating release commit and tag..."
    
    # Add all changes
    git add .
    
    # Create commit
    git commit -m "Release v$version

- Updated version numbers
- Updated documentation
- See CHANGELOG.md for detailed changes"
    
    # Create annotated tag
    git tag -a "v$version" -m "Release v$version"
    
    log "Release commit and tag created successfully"
}

# Push to repository
push_release() {
    local version="$1"
    
    log "Pushing release to repository..."
    
    # Push commits
    git push origin main
    
    # Push tags
    git push origin "v$version"
    
    log "Release pushed successfully"
    
    info "Release v$version is now available at:"
    info "https://github.com/turnuphosting/latest-varnish/releases/tag/v$version"
}

# Test installation scripts
test_scripts() {
    log "Testing installation scripts..."
    
    # Test script syntax
    bash -n quick-install.sh || error "Syntax error in quick-install.sh"
    bash -n quick-uninstall.sh || error "Syntax error in quick-uninstall.sh"
    
    # Test help output
    bash quick-install.sh --help > /dev/null || error "quick-install.sh --help failed"
    bash quick-uninstall.sh --help > /dev/null || error "quick-uninstall.sh --help failed"
    
    log "Script tests passed"
}

# Generate GitHub release
create_github_release() {
    local version="$1"
    
    log "Creating GitHub release..."
    
    # Check if gh CLI is available
    if ! command -v gh &> /dev/null; then
        warn "GitHub CLI (gh) not found. Please create the release manually at:"
        warn "https://github.com/turnuphosting/latest-varnish/releases/new?tag=v$version"
        return 0
    fi
    
    # Extract changelog for this version
    local release_notes=""
    if [[ -f "CHANGELOG.md" ]]; then
        release_notes=$(sed -n "/^## \[$version\]/,/^## \[/p" CHANGELOG.md | sed '$d')
    fi
    
    if [[ -z "$release_notes" ]]; then
        release_notes="Release v$version

See CHANGELOG.md for detailed changes."
    fi
    
    # Create GitHub release
    gh release create "v$version" \
        --title "v$version" \
        --notes "$release_notes" \
        --repo turnuphosting/latest-varnish
    
    log "GitHub release created successfully"
}

# Main release function
release() {
    local new_version="$1"
    local current_version
    
    check_repository
    current_version=$(get_current_version)
    
    log "Current version: $current_version"
    log "New version: $new_version"
    
    validate_version "$new_version"
    
    # Check if version is newer
    if [[ "$new_version" == "$current_version" ]]; then
        error "New version must be different from current version"
    fi
    
    # Confirm release
    echo ""
    warn "This will create a new release with version $new_version"
    read -p "Continue? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Release cancelled"
        exit 0
    fi
    
    # Perform release steps
    update_version "$new_version"
    generate_changelog "$new_version"
    test_scripts
    create_release_commit "$new_version"
    push_release "$new_version"
    create_github_release "$new_version"
    
    echo ""
    log "🎉 Release v$new_version completed successfully!"
    echo ""
    info "Installation command:"
    info "curl -fsSL https://raw.githubusercontent.com/turnuphosting/latest-varnish/main/quick-install.sh | bash"
    echo ""
    info "Release page:"
    info "https://github.com/turnuphosting/latest-varnish/releases/tag/v$new_version"
}

# Helper functions for different types of releases
patch_release() {
    local current_version
    current_version=$(get_current_version)
    
    # Extract major.minor.patch
    local major minor patch
    IFS='.' read -r major minor patch <<< "$current_version"
    
    # Increment patch
    ((patch++))
    
    local new_version="$major.$minor.$patch"
    release "$new_version"
}

minor_release() {
    local current_version
    current_version=$(get_current_version)
    
    # Extract major.minor.patch
    local major minor patch
    IFS='.' read -r major minor patch <<< "$current_version"
    
    # Increment minor, reset patch
    ((minor++))
    patch=0
    
    local new_version="$major.$minor.$patch"
    release "$new_version"
}

major_release() {
    local current_version
    current_version=$(get_current_version)
    
    # Extract major.minor.patch
    local major minor patch
    IFS='.' read -r major minor patch <<< "$current_version"
    
    # Increment major, reset minor and patch
    ((major++))
    minor=0
    patch=0
    
    local new_version="$major.$minor.$patch"
    release "$new_version"
}

# Show usage
usage() {
    echo "Varnish Cache Manager - Release Management"
    echo ""
    echo "Usage: $0 <command> [version]"
    echo ""
    echo "Commands:"
    echo "  release <version>    Create release with specific version (e.g., 1.2.3)"
    echo "  patch               Create patch release (increment patch version)"
    echo "  minor               Create minor release (increment minor version)"
    echo "  major               Create major release (increment major version)"
    echo "  version             Show current version"
    echo "  test                Test installation scripts"
    echo ""
    echo "Examples:"
    echo "  $0 release 1.2.3    # Create release v1.2.3"
    echo "  $0 patch             # Create patch release (e.g., 1.0.0 -> 1.0.1)"
    echo "  $0 minor             # Create minor release (e.g., 1.0.1 -> 1.1.0)"
    echo "  $0 major             # Create major release (e.g., 1.1.0 -> 2.0.0)"
}

# Handle command line arguments
case "${1:-}" in
    release)
        if [[ -z "${2:-}" ]]; then
            error "Version required for release command"
        fi
        release "$2"
        ;;
    patch)
        patch_release
        ;;
    minor)
        minor_release
        ;;
    major)
        major_release
        ;;
    version)
        echo "Current version: $(get_current_version)"
        ;;
    test)
        check_repository
        test_scripts
        log "All tests passed"
        ;;
    --help|-h|help)
        usage
        ;;
    *)
        usage
        exit 1
        ;;
esac