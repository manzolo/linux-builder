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