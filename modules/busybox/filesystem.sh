#!/bin/bash

# =============================================================================
# Manzolo Linux - Root Filesystem Creation
# =============================================================================

# -----------------------------------------------------------------------------
# Configuration and Constants
# -----------------------------------------------------------------------------
readonly FILESYSTEM_VERSION="2.0"
readonly HOSTNAME="manzolo-linux"
readonly WEB_ROOT="/www"
readonly CGI_BIN="/www/cgi-bin"

# -----------------------------------------------------------------------------
# Core Functions
# -----------------------------------------------------------------------------

validate_prerequisites() {
    if [[ ! -f "$BUSYBOX_BUILD_DIR/busybox" ]]; then
        print_error "BusyBox not compiled. Please compile BusyBox first."
        read -p "Press ENTER to continue..."
        return 1
    fi
    return 0
}

setup_base_filesystem() {
    print_step "Installing BusyBox to filesystem..."
    
    # Clean and create rootfs
    rm -rf "$BUSYBOX_INSTALL_DIR"
    mkdir -p "$BUSYBOX_INSTALL_DIR"
    
    # Install BusyBox
    cd "$BUSYBOX_SOURCE_DIR" || return 1
    if make install O="$BUSYBOX_BUILD_DIR" CONFIG_PREFIX="$BUSYBOX_INSTALL_DIR" &>> "$LOG_FILE"; then
        print_success "BusyBox installed to filesystem"
    else
        print_error "Failed to install BusyBox"
        cd "$CUR_DIR" || return 1
        return 1
    fi
    
    cd "$BUSYBOX_INSTALL_DIR" || return 1
}

create_directory_structure() {
    print_step "Creating filesystem structure..."
    
    # Create essential directories
    mkdir -p {dev,proc,sys,tmp,var/log,var/run,etc,root,home,usr/lib,usr/share}
    mkdir -p www/cgi-bin etc/init.d manzolopkg/{packages,db} usr/bin
    
    # Set correct permissions
    chmod 755 {dev,proc,sys,var,etc,root,home,usr,www} www/cgi-bin etc/init.d
    chmod 1777 tmp  # sticky bit for /tmp
}

create_device_nodes() {
    print_step "Creating essential device nodes..."
    
    local devices=(
        "dev/null c 1 3"
        "dev/zero c 1 5"
        "dev/random c 1 8"
        "dev/urandom c 1 9"
        "dev/console c 5 1"
        "dev/tty c 5 0"
    )
    
    for device_spec in "${devices[@]}"; do
        sudo mknod $device_spec 2>/dev/null || true
    done
}

create_system_users() {
    print_step "Creating system users and groups..."
    
    # /etc/passwd
    cat > etc/passwd << 'EOF'
root:x:0:0:root:/root:/bin/sh
daemon:x:1:1:daemon:/usr/sbin:/bin/false
bin:x:2:2:bin:/bin:/bin/false
sys:x:3:3:sys:/dev:/bin/false
www-data:x:33:33:www-data:/var/www:/bin/false
nobody:x:65534:65534:nobody:/nonexistent:/bin/false
EOF

    # /etc/group
    cat > etc/group << 'EOF'
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
tty:x:5:
www-data:x:33:
users:x:100:
nogroup:x:65534:
EOF

    # /etc/shadow
    cat > etc/shadow << 'EOF'
root:*:19000:0:99999:7:::
daemon:*:19000:0:99999:7:::
bin:*:19000:0:99999:7:::
sys:*:19000:0:99999:7:::
www-data:*:19000:0:99999:7:::
nobody:*:19000:0:99999:7:::
EOF
}

create_network_config() {
    print_step "Creating network configuration..."
    
    # /etc/hosts
    cat > etc/hosts << EOF
127.0.0.1    localhost $HOSTNAME
127.0.1.1    $HOSTNAME
::1          localhost ip6-localhost ip6-loopback
ff02::1      ip6-allnodes
ff02::2      ip6-allrouters
EOF

    # /etc/hostname
    echo "$HOSTNAME" > etc/hostname
    
    # DHCP client script
    create_dhcp_script
}

create_dhcp_script() {
    mkdir -p etc/udhcpc
    cat > etc/udhcpc/default.script << 'EOF'
#!/bin/sh
# DHCP client configuration script

[ -z "$1" ] && echo "Error: should be called from udhcpc" && exit 1

RESOLV_CONF="/etc/resolv.conf"
RESOLV_CONF_BAK="/etc/resolv.conf.bak"

[ -n "$broadcast" ] && BROADCAST="broadcast $broadcast"
[ -n "$subnet" ] && NETMASK="netmask $subnet"

case "$1" in
    deconfig)
        echo "Deconfiguring network interface $interface"
        /sbin/ifconfig $interface 0.0.0.0
        while route del default gw 0.0.0.0 dev $interface 2>/dev/null; do :; done
        ;;
    renew|bound)
        echo "Configuring network interface $interface"
        /sbin/ifconfig $interface $ip $BROADCAST $NETMASK
        
        if [ -n "$router" ]; then
            echo "Setting default gateway to $router"
            while route del default gw 0.0.0.0 dev $interface 2>/dev/null; do :; done
            route add default gw $router dev $interface
        fi
        
        echo "Updating DNS configuration"
        [ -f "$RESOLV_CONF" ] && mv "$RESOLV_CONF" "$RESOLV_CONF_BAK"
        [ -n "$domain" ] && echo "search $domain" > "$RESOLV_CONF"
        for dns_server in $dns; do
            echo "nameserver $dns_server" >> "$RESOLV_CONF"
        done
        
        echo "Network configured: IP=$ip, Gateway=$router, DNS=$dns"
        ;;
esac
exit 0
EOF
    chmod +x etc/udhcpc/default.script
}

create_system_config() {
    print_step "Creating system configuration files..."
    
    # /etc/fstab
    cat > etc/fstab << 'EOF'
# <file system> <mount point> <type> <options> <dump> <pass>
proc            /proc         proc   defaults          0      0
sysfs           /sys          sysfs  defaults          0      0
devtmpfs        /dev          devtmpfs defaults        0      0
tmpfs           /tmp          tmpfs  defaults,mode=1777 0     0
tmpfs           /var/run      tmpfs  defaults          0      0
EOF

    # /etc/inittab
    cat > etc/inittab << 'EOF'
# System initialization
::sysinit:/etc/init.d/rcS
::askfirst:-/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/swapoff -a
::shutdown:/bin/umount -a -r
::restart:/sbin/init
EOF
}

create_web_server_config() {
    print_step "Setting up web server..."
    
    # HTTP server configuration
    cat > etc/httpd.conf << 'EOF'
# BusyBox httpd configuration
.html:text/html
.htm:text/html
.css:text/css
.js:application/javascript
.png:image/png
.jpg:image/jpeg
.gif:image/gif
.ico:image/x-icon
EOF

    # Create web content
    create_web_content
    create_cgi_scripts
}

create_web_content() {
    # Main index page
    cat > www/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Welcome to Manzolo Linux</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; text-align: center; }
        .status { background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .info { background: #e8f4f8; padding: 10px; border-radius: 5px; margin: 10px 0; }
        ul { list-style-type: none; padding: 0; }
        li { padding: 5px 0; }
        a { color: #0066cc; text-decoration: none; }
        a:hover { text-decoration: underline; }
        code { background: #f0f0f0; padding: 2px 5px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Manzolo Linux v$FILESYSTEM_VERSION</h1>
        
        <div class="status">
            <strong>✅ Operating System:</strong> Manzolo Linux v$FILESYSTEM_VERSION<br>
            <strong>✅ Web Server:</strong> BusyBox httpd<br>
            <strong>✅ Date/Time:</strong> <script>document.write(new Date().toLocaleString());</script>
        </div>
        
        <h2>🔧 Tests and Features</h2>
        <ul>
            <li>📄 <a href="/cgi-bin/test.cgi">Test CGI script</a></li>
            <li>📄 <a href="/cgi-bin/info.cgi">System information</a></li>
            <li>🔍 <a href="/test404.html">Test 404 page</a></li>
        </ul>
        
        <div class="info">
            <h3>💡 Package Manager Commands:</h3>
            <ul>
                <li><code>manzolopkg list</code> - List installed packages</li>
                <li><code>manzolopkg update</code> - Update package index</li>
                <li><code>manzolopkg install manzolo-hello-world</code> - Install sample package</li>
            </ul>
        </div>
        
        <div class="info">
            <h3>🌐 Network Commands:</h3>
            <ul>
                <li><code>ip addr show</code> - Show network interfaces</li>
                <li><code>ping 8.8.8.8</code> - Test connectivity</li>
                <li><code>httpd -p 8080 -h /www</code> - Start web server</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF

    # 404 error page
    cat > www/404.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>404 - Page Not Found</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; text-align: center; background: #f5f5f5; }
        .error { background: #ffe6e6; padding: 30px; border-radius: 10px; display: inline-block; }
        h1 { color: #cc0000; }
    </style>
</head>
<body>
    <div class="error">
        <h1>404 - Page Not Found</h1>
        <p>The requested resource is not available.</p>
        <p><a href="/">Back to home</a></p>
    </div>
</body>
</html>
EOF
}

create_cgi_scripts() {
    # Basic CGI test script
    cat > www/cgi-bin/test.cgi << 'EOF'
#!/bin/sh
echo "Content-Type: text/html"
echo ""
echo "<!DOCTYPE html><html><head><title>CGI Test</title></head><body>"
echo "<h1>CGI works!</h1>"
echo "<p><strong>Server:</strong> $SERVER_SOFTWARE</p>"
echo "<p><strong>Date:</strong> $(date)</p>"
echo "<p><strong>Client IP:</strong> $REMOTE_ADDR</p>"
echo "<p><strong>User Agent:</strong> $HTTP_USER_AGENT</p>"
echo "</body></html>"
EOF

    # System info CGI script
    cat > www/cgi-bin/info.cgi << 'EOF'
#!/bin/sh
echo "Content-Type: text/html"
echo ""
echo "<!DOCTYPE html><html><head><title>System Info</title></head><body>"
echo "<h1>System Information</h1>"
echo "<h2>Uptime</h2><pre>$(uptime)</pre>"
echo "<h2>Memory</h2><pre>$(free)</pre>"
echo "<h2>Disk Usage</h2><pre>$(df -h)</pre>"
echo "<h2>Network Interfaces</h2><pre>$(ip addr show 2>/dev/null || ifconfig)</pre>"
echo "</body></html>"
EOF

    # Make CGI scripts executable
    chmod +x www/cgi-bin/*.cgi
}

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

create_init_script() {
    print_step "Creating system initialization script..."
    
    cat > etc/init.d/rcS << EOF
#!/bin/sh
# Manzolo Linux System Initialization

echo "╔══════════════════════════════════════════════════╗"
echo "║              🚀 Manzolo Linux v$FILESYSTEM_VERSION               ║"
echo "║           Starting system services...            ║"
echo "╚══════════════════════════════════════════════════╝"

# Mount filesystems
echo "📁 Mounting filesystems..."
mount -a

# Set hostname
echo "🏷️  Setting hostname..."
hostname -F /etc/hostname 2>/dev/null || hostname $HOSTNAME

# Initialize network
echo "🌐 Initializing network interfaces..."
for iface in eth0 enp0s3 enp0s8; do
    if [ -e "/sys/class/net/\$iface" ]; then
        echo "   Found interface: \$iface"
        ifconfig "\$iface" up 2>/dev/null || true
        udhcpc -i "\$iface" -b -q 2>/dev/null &
        break
    fi
done

echo ""
echo "✅ System initialization completed!"
echo ""
echo "💡 Quick start commands:"
echo "   • manzolopkg install manzolo-hello-world  (install sample package)"
echo "   • httpd -p 8080 -h /www                   (start web server)"
echo "   • ip addr show                            (check network)"
echo "   • ping 8.8.8.8                           (test connectivity)"
echo ""
echo "🌟 Welcome to Manzolo Linux! Ready for action."
echo "═══════════════════════════════════════════════════"
EOF
    chmod +x etc/init.d/rcS
}

set_permissions() {
    print_step "Setting correct permissions..."
    
    # Web server permissions
    chown -R root:root www/ 2>/dev/null || true
    chmod -R 755 www/
    find www/cgi-bin -name "*.cgi" -exec chmod +x {} \;
    
    # System file permissions
    chmod 640 etc/shadow
    chmod 644 etc/passwd etc/group etc/hosts etc/hostname etc/fstab
    chmod 755 etc/init.d/rcS
}

show_statistics() {
    print_section "Filesystem Statistics"
    echo "Total size: $(du -sh . | cut -f1)"
    echo "Number of files: $(find . -type f | wc -l)"
    echo "Number of directories: $(find . -type d | wc -l)"
    echo "Web server content: $(du -sh www | cut -f1)"
}

# -----------------------------------------------------------------------------
# Main Function
# -----------------------------------------------------------------------------

create_filesystem() {
    print_header "Creating Root Filesystem"
    
    # Validation
    validate_prerequisites || return 1
    
    # Core filesystem setup
    setup_base_filesystem || return 1
    create_directory_structure
    create_device_nodes
    
    # System configuration
    create_system_users
    create_network_config
    create_system_config
    create_init_script
    
    # Services setup
    create_web_server_config
    create_package_manager
    create_sample_packages
    
    # Final touches
    set_permissions
    
    print_success "Filesystem structure created successfully"
    show_statistics
    
    cd "$CUR_DIR" || return 1
    read -p "Press ENTER to continue..."
}