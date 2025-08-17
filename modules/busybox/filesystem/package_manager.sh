create_package_manager() {
    print_step "Setting up ManzoloPkg package manager..."
    
    cat > usr/bin/manzolopkg << 'EOF'
#!/bin/sh
# ManzoloPkg - Minimal Package Manager for Manzolo Linux

readonly PKG_DIR="/manzolopkg/packages"
readonly DB_DIR="/manzolopkg/db"
readonly REPO_FILE="/manzolopkg/repo.txt"
readonly INDEX_FILE="/manzolopkg/index.txt"

# Initialize directories
mkdir -p "$PKG_DIR" "$DB_DIR"
[ -f "$REPO_FILE" ] || echo "http://127.0.0.1/repo" > "$REPO_FILE"

usage() {
    echo "ManzoloPkg - Package Manager for Manzolo Linux"
    echo "Usage:"
    echo "  $0 list                    - List installed packages"
    echo "  $0 install <pkg|url>       - Install package"
    echo "  $0 remove <pkg>            - Remove package"
    echo "  $0 update                  - Update package index"
    echo "  $0 search [term]           - Search packages"
    echo "  $0 help                    - Show this help"
    exit 1
}

list_packages() {
    echo "Installed packages:"
    if [ "$(ls -A "$DB_DIR" 2>/dev/null)" ]; then
        for pkg in "$DB_DIR"/*.files; do
            [ -f "$pkg" ] && basename "$pkg" .files
        done
    else
        echo "  (none installed)"
    fi
}

update_repo() {
    local repo_url=$(cat "$REPO_FILE")
    echo "Updating repository from $repo_url..."
    
    if wget -q "$repo_url/index.txt" -O "$INDEX_FILE"; then
        echo "Repository index updated successfully."
    else
        echo "Failed to update repository index."
        return 1
    fi
}

search_packages() {
    if [ ! -f "$INDEX_FILE" ]; then
        echo "Package index not found. Run 'manzolopkg update' first."
        return 1
    fi
    
    if [ -n "$1" ]; then
        echo "Searching for '$1':"
        grep -i "$1" "$INDEX_FILE" || echo "  No packages found."
    else
        echo "Available packages:"
        cat "$INDEX_FILE"
    fi
}

install_package() {
    local src="$1"
    local pkg_name pkg_file repo_url
    
    if echo "$src" | grep -qE '^https?://'; then
        # Full URL provided
        pkg_name=$(basename "$src" .tar.gz)
        pkg_file="$PKG_DIR/$pkg_name.tar.gz"
        echo "Downloading from $src..."
        wget -q "$src" -O "$pkg_file" || {
            echo "Download failed."
            return 1
        }
    else
        # Package name - use repository
        pkg_name="$src"
        pkg_file="$PKG_DIR/$pkg_name.tar.gz"
        repo_url=$(cat "$REPO_FILE")
        echo "Installing $pkg_name from repository..."
        wget -q "$repo_url/$pkg_name.tar.gz" -O "$pkg_file" || {
            echo "Package '$pkg_name' not found in repository."
            return 1
        }
    fi
    
    if [ -f "$DB_DIR/$pkg_name.files" ]; then
        echo "Package '$pkg_name' is already installed."
        return 0
    fi
    
    echo "Installing $pkg_name..."
    local tmp_dir=$(mktemp -d)
    
    if tar -xzf "$pkg_file" -C "$tmp_dir"; then
        # Record installed files
        find "$tmp_dir" -type f | sed "s|$tmp_dir||" > "$DB_DIR/$pkg_name.files"
        # Install files
        (cd "$tmp_dir" && tar -cf - .) | (cd / && tar -xf -)
        echo "Package '$pkg_name' installed successfully."
    else
        echo "Failed to extract package."
        rm -rf "$tmp_dir"
        return 1
    fi
    
    rm -rf "$tmp_dir"
}

remove_package() {
    local pkg_name="$1"
    local db_file="$DB_DIR/$pkg_name.files"
    
    if [ ! -f "$db_file" ]; then
        echo "Package '$pkg_name' is not installed."
        return 1
    fi
    
    echo "Removing $pkg_name..."
    while read -r file; do
        [ -n "$file" ] && rm -f "$file" 2>/dev/null
    done < "$db_file"
    
    rm -f "$db_file"
    echo "Package '$pkg_name' removed successfully."
}

# Main command dispatcher
case "${1:-help}" in
    list) list_packages ;;
    install) 
        [ $# -ne 2 ] && usage
        install_package "$2" ;;
    remove) 
        [ $# -ne 2 ] && usage
        remove_package "$2" ;;
    update) update_repo ;;
    search) search_packages "$2" ;;
    help|--help|-h) usage ;;
    *) usage ;;
esac
EOF
    chmod +x usr/bin/manzolopkg
}

create_sample_packages() {
    print_step "Creating sample packages..."
    
    # Create hello-world package
    local pkg_tmp=$(mktemp -d)
    mkdir -p "$pkg_tmp/usr/bin"
    
    cat > "$pkg_tmp/usr/bin/manzolo-hello-world" << 'EOF'
#!/bin/sh
echo "🚀 Welcome to Manzolo Linux!"
echo "Crafted with love by Manzolo Industries™"
echo "Version: $(uname -r)"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime)"
EOF
    chmod +x "$pkg_tmp/usr/bin/manzolo-hello-world"
    
    # Create package archives
    mkdir -p www/repo manzolopkg/packages
    tar -czf "www/repo/manzolo-hello-world.tar.gz" -C "$pkg_tmp" .
    tar -czf "manzolopkg/packages/manzolo-hello-world.tar.gz" -C "$pkg_tmp" .
    
    # Create repository index
    echo "manzolo-hello-world" > www/repo/index.txt
    
    rm -rf "$pkg_tmp"
    print_success "Sample packages created"
}
