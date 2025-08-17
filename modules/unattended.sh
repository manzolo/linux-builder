#!/bin/bash

# =============================================================================
# UNATTENDED BUILD FUNCTIONS - Modified to remove all user prompts
# =============================================================================

# Global flag to control unattended mode
UNATTENDED_MODE=false

# Set unattended mode
set_unattended_mode() {
    UNATTENDED_MODE=true
    export UNATTENDED_MODE
}

# Helper function to skip read prompts in unattended mode
unattended_read() {
    if [[ "$UNATTENDED_MODE" == "true" ]]; then
        return 0
    else
        read -p "$@"
    fi
}

prepare_busybox_unattended() {
    print_header "Preparing BusyBox v$BUSYBOX_VERSION"
    
    local busybox_archive="busybox-$BUSYBOX_VERSION.tar.bz2"
    local busybox_url=$(get_busybox_url "$BUSYBOX_VERSION")
    local download_dir="$BUILD_DIR/downloads"
    
    # Create directories
    mkdir -p "$download_dir" "$BUSYBOX_SOURCE_DIR" "$BUSYBOX_BUILD_DIR" "$BUSYBOX_INSTALL_DIR"
    
    print_info "📖 About BusyBox:"
    print_info "BusyBox combines many common Unix utilities into a single"
    print_info "executable. It's perfect for embedded systems and minimal distributions."
    echo
    
    # Check if already downloaded
    if [[ -f "$download_dir/$busybox_archive" ]]; then
        print_success "BusyBox archive already exists"
    else
        # Check internet and disk space
        if ! check_internet; then
            print_error "Internet connection required to download BusyBox"
            return 1
        fi
        
        if ! check_disk_space 1; then
            return 1
        fi
        
        # Download BusyBox
        if ! download_file "$busybox_url" "$download_dir/$busybox_archive" "BusyBox v$BUSYBOX_VERSION"; then
            return 1
        fi
    fi
    
    # Extract BusyBox
    print_step "Extracting BusyBox source..."
    rm -rf "$BUSYBOX_SOURCE_DIR"/*
    
    if ! extract_archive "$download_dir/$busybox_archive" "$BUSYBOX_SOURCE_DIR" "BusyBox source"; then
        return 1
    fi
    
    # Move extracted contents to the right place
    local extracted_dir=$(find "$BUSYBOX_SOURCE_DIR" -maxdepth 1 -type d -name "busybox-*" | head -1)
    if [[ -n "$extracted_dir" ]]; then
        mv "$extracted_dir"/* "$BUSYBOX_SOURCE_DIR/"
        rm -rf "$extracted_dir"
    fi
    
    print_success "BusyBox source prepared successfully"
}

# Configure BusyBox (unattended version)
configure_busybox_unattended() {
    print_header "BusyBox Configuration (Unattended)"
    
    if [[ ! -d "$BUSYBOX_SOURCE_DIR" ]] || [[ -z "$(ls -A "$BUSYBOX_SOURCE_DIR")" ]]; then
        print_error "BusyBox source not found. Please prepare BusyBox first."
        return 1
    fi
    
    cd "$BUSYBOX_SOURCE_DIR" || return 1
    
    # Use desktop configuration by default for unattended mode
    print_step "Applying desktop configuration (unattended)..."
    if apply_desktop_config; then
        print_success "Desktop configuration applied"
    else
        print_error "Failed to apply desktop configuration"
        return 1
    fi
    
    cd "$CUR_DIR" || return 1
    return 0
}

# Apply desktop configuration (modified to be silent)
apply_desktop_config() {
    print_step "Applying desktop configuration..."
    
    cd "$BUSYBOX_SOURCE_DIR" || return 1
    
    # Start with defconfig for a solid base
    make defconfig O="$BUSYBOX_BUILD_DIR" &>> "$LOG_FILE"
    
    local config_file="$BUSYBOX_BUILD_DIR/.config"

    print_step "Configuring for static build and desktop features..."
    
    # Enable static compilation
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' "$config_file"
    
    # === HTTPD CONFIGURATION ===
    sed -i 's/# CONFIG_HTTPD is not set/CONFIG_HTTPD=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_HTTPD_RANGES is not set/CONFIG_FEATURE_HTTPD_RANGES=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_HTTPD_SETUID is not set/CONFIG_FEATURE_HTTPD_SETUID=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_HTTPD_BASIC_AUTH is not set/CONFIG_FEATURE_HTTPD_BASIC_AUTH=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_HTTPD_AUTH_MD5 is not set/CONFIG_FEATURE_HTTPD_AUTH_MD5=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_HTTPD_CGI is not set/CONFIG_FEATURE_HTTPD_CGI=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_HTTPD_CONFIG_WITH_SCRIPT_NAMES is not set/CONFIG_FEATURE_HTTPD_CONFIG_WITH_SCRIPT_NAMES=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_HTTPD_SET_REMOTE_PORT_TO_ENV is not set/CONFIG_FEATURE_HTTPD_SET_REMOTE_PORT_TO_ENV=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_HTTPD_ENCODE_URL_STR is not set/CONFIG_FEATURE_HTTPD_ENCODE_URL_STR=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_HTTPD_ERROR_PAGES is not set/CONFIG_FEATURE_HTTPD_ERROR_PAGES=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_HTTPD_PROXY is not set/CONFIG_FEATURE_HTTPD_PROXY=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_HTTPD_GZIP is not set/CONFIG_FEATURE_HTTPD_GZIP=y/' "$config_file"
    
    # === NETWORK CONFIGURATION ===
    sed -i 's/# CONFIG_UDHCPC is not set/CONFIG_UDHCPC=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_UDHCPC_ARPING is not set/CONFIG_FEATURE_UDHCPC_ARPING=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_UDHCP_RFC3397 is not set/CONFIG_FEATURE_UDHCP_RFC3397=y/' "$config_file"
    
    sed -i 's/# CONFIG_IFCONFIG is not set/CONFIG_IFCONFIG=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_IFCONFIG_STATUS is not set/CONFIG_FEATURE_IFCONFIG_STATUS=y/' "$config_file"
    sed -i 's/# CONFIG_ROUTE is not set/CONFIG_ROUTE=y/' "$config_file"
    sed -i 's/# CONFIG_IP is not set/CONFIG_IP=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_IP_ADDRESS is not set/CONFIG_FEATURE_IP_ADDRESS=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_IP_LINK is not set/CONFIG_FEATURE_IP_LINK=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_IP_ROUTE is not set/CONFIG_FEATURE_IP_ROUTE=y/' "$config_file"
    
    sed -i 's/# CONFIG_PING is not set/CONFIG_PING=y/' "$config_file"
    sed -i 's/# CONFIG_PING6 is not set/CONFIG_PING6=y/' "$config_file"
    sed -i 's/# CONFIG_WGET is not set/CONFIG_WGET=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_WGET_STATUSBAR is not set/CONFIG_FEATURE_WGET_STATUSBAR=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_WGET_AUTHENTICATION is not set/CONFIG_FEATURE_WGET_AUTHENTICATION=y/' "$config_file"
    
    # TTY features
    sed -i 's/# CONFIG_ASH_JOB_CONTROL is not set/CONFIG_ASH_JOB_CONTROL=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_USE_TERMIOS is not set/CONFIG_FEATURE_USE_TERMIOS=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_SH_STANDALONE is not set/CONFIG_FEATURE_SH_STANDALONE=y/' "$config_file"

    # Enable other desktop features
    for feature in \
        ASH_GETOPTS \
        FEATURE_EDITING \
        FEATURE_TAB_COMPLETION \
        FEATURE_VI_EDITING \
        FEATURE_FANCY_READLINE \
        FEATURE_LS_COLOR \
        TOP \
        FREE \
        UPTIME \
        CLEAR \
        LSOF \
        FIND_PRINT0 \
        VI
    do
        sed -i "s/# CONFIG_${feature} is not set/CONFIG_${feature}=y/" "$config_file"
        sed -i "s/CONFIG_${feature}=n/CONFIG_${feature}=y/" "$config_file"
    done
    
    # Disable problematic features
    sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' "$config_file" 2>/dev/null || true
    sed -i 's/CONFIG_INOTIFYD=y/# CONFIG_INOTIFYD is not set/' "$config_file" 2>/dev/null || true
    
    # Resolve dependencies
    print_step "Resolving feature dependencies..."
    make olddefconfig O="$BUSYBOX_BUILD_DIR" &>> "$LOG_FILE"
    
    print_success "Desktop configuration applied with HTTPD support"
    cd "$CUR_DIR" || return 1
}

# Compile kernel (unattended version)
compile_kernel_unattended() {
    print_header "Compiling Linux Kernel (Unattended)"
    
    if [[ ! -f "$KERNEL_BUILD_DIR/.config" ]]; then
        print_error "Kernel not configured. Please configure kernel first."
        return 1
    fi
    
    cd "$KERNEL_SOURCE_DIR" || return 1
    
    # Check memory and disk space (non-interactive)
    if ! check_memory 2048; then
        print_warning "Low memory detected. Continuing anyway in unattended mode."
    fi
    
    if ! check_disk_space 3; then
        print_error "Insufficient disk space. Cannot continue."
        return 1
    fi
    
    local cores=$(nproc)
    local start_time=$(date +%s)
    
    print_step "Starting kernel compilation..."
    print_info "Using $cores parallel jobs"
    print_info "This may take 15-60 minutes depending on your system"
    echo
    
    # Start performance monitoring
    monitor_performance 3600 30 &
    local monitor_pid=$!
    
    # Log compilation info
    {
        echo "Kernel compilation started at $(date)"
        echo "Version: $KERNEL_VERSION"
        echo "Architecture: $KERNEL_ARCH"
        echo "Parallel jobs: $cores"
        echo "========================================"
    } >> "$LOG_FILE"
    
    # Compile with silent progress for unattended mode
    if make -j"$cores" O="$KERNEL_BUILD_DIR" &>> "$LOG_FILE"; then
        print_success "Kernel compiled successfully!"
        
        # Copy kernel image
        if [[ -f "$KERNEL_BUILD_DIR/arch/x86/boot/bzImage" ]]; then
            cp "$KERNEL_BUILD_DIR/arch/x86/boot/bzImage" "$BUILD_DIR/"
            local kernel_size=$(du -h "$BUILD_DIR/bzImage" | cut -f1)
            print_success "Kernel image copied to $BUILD_DIR/bzImage ($kernel_size)"
        else
            print_error "Kernel image not found after compilation"
            return 1
        fi
    else
        print_error "Kernel compilation failed!"
        print_info "Check $LOG_FILE for detailed error information"
        return 1
    fi
    
    # Stop performance monitoring
    kill $monitor_pid 2>/dev/null || true
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    print_success "Compilation completed in ${minutes}m ${seconds}s"
    
    cd "$CUR_DIR" || return 1
    return 0
}

# Compile BusyBox (unattended version)
compile_busybox_unattended() {
    print_header "Compiling BusyBox (Unattended)"
    
    if [[ ! -f "$BUSYBOX_BUILD_DIR/.config" ]]; then
        print_error "BusyBox not configured. Cannot continue."
        return 1
    fi
    
    cd "$BUSYBOX_SOURCE_DIR" || return 1
    
    # Check disk space
    if ! check_disk_space 1; then
        print_error "Insufficient disk space. Cannot continue."
        return 1
    fi
    
    local cores=$(nproc)
    local start_time=$(date +%s)
    
    print_step "Starting BusyBox compilation..."
    print_info "Using $cores parallel jobs"
    echo
    
    # Log compilation info
    {
        echo "BusyBox compilation started at $(date)"
        echo "Version: $BUSYBOX_VERSION"
        echo "Parallel jobs: $cores"
        echo "========================================"
    } >> "$LOG_FILE"
    
    # Compile silently for unattended mode
    if make -j"$cores" O="$BUSYBOX_BUILD_DIR" &>> "$LOG_FILE"; then
        print_success "BusyBox compiled successfully!"
        
        # Verify static linking
        if file "$BUSYBOX_BUILD_DIR/busybox" | grep -qi static; then
            print_success "BusyBox is statically linked (excellent!)"
        else
            print_warning "BusyBox is not statically linked"
            print_info "This might cause issues in minimal environments"
        fi
        
        # Count available applets
        if [[ -x "$BUSYBOX_BUILD_DIR/busybox" ]]; then
            applet_count=$("$BUSYBOX_BUILD_DIR/busybox" --list 2>/dev/null | wc -l || echo 0)
            print_info "📦 BusyBox applets available: $applet_count"
        else
            print_warning "Cannot count applets: binary not found"
        fi
    else
        print_error "BusyBox compilation failed!"
        print_info "Check $LOG_FILE for detailed error information"
        cd "$CUR_DIR" || return 1
        return 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    print_success "Compilation completed in ${minutes}m ${seconds}s"
    
    cd "$CUR_DIR" || return 1
    return 0
}

# Create filesystem (unattended version)
create_filesystem_unattended() {
    print_header "Creating Root Filesystem (Unattended)"
    
    # Validation
    if [[ ! -f "$BUSYBOX_BUILD_DIR/busybox" ]]; then
        print_error "BusyBox not compiled. Cannot continue."
        return 1
    fi
    
    # Core filesystem setup
    setup_base_filesystem || return 1
    create_directory_structure || return 1
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
    create_tty_test_script

    # Final touches
    set_permissions
    
    print_success "Filesystem structure created successfully"
    show_filesystem_stats
    
    cd "$CUR_DIR" || return 1
    return 0
}

# Generate initramfs (unattended version)
generate_initramfs_unattended() {
    print_header "Generating Initramfs (Unattended)"
    
    if [[ ! -d "$BUSYBOX_INSTALL_DIR" ]] || [[ -z "$(ls -A "$BUSYBOX_INSTALL_DIR")" ]]; then
        print_error "Filesystem not created. Cannot continue."
        return 1
    fi
    
    cd "$BUSYBOX_INSTALL_DIR" || return 1
    
    print_step "Creating init script..."
    # Use default init for unattended mode
    create_default_init
    chmod +x init
    
    print_step "Generating initramfs archive..."
    # Create initramfs with compression
    local compression_level="${COMPRESSION_LEVEL:-9}"
    if find . -print0 | cpio --null -ov --format=newc 2>/dev/null | \
       gzip -${compression_level} > "$BUILD_DIR/initramfs.cpio.gz"; then
        local initramfs_size=$(du -h "$BUILD_DIR/initramfs.cpio.gz" | cut -f1)
        print_success "Initramfs created successfully: $initramfs_size"
        
        # Verify initramfs
        print_step "Verifying initramfs..."
        if gzip -t "$BUILD_DIR/initramfs.cpio.gz"; then
            print_success "Initramfs integrity verified"
        else
            print_error "Initramfs verification failed"
            return 1
        fi
    else
        print_error "Failed to create initramfs"
        cd "$CUR_DIR" || return 1
        return 1
    fi
    
    print_section "Initramfs Information"
    echo "Size: $(du -h "$BUILD_DIR/initramfs.cpio.gz" | cut -f1)"
    echo "Compression: gzip level $compression_level"
    echo "Format: newc cpio"
    
    cd "$CUR_DIR" || return 1
    return 0
}

# Create ISO (unattended version)
create_standard_iso_unattended() {
    print_header "Creating Standard ISO (Unattended)"
    
    # Check for necessary files
    if [[ ! -f "$BUILD_DIR/bzImage" ]]; then
        print_error "Kernel (bzImage) not found. Cannot continue."
        return 1
    fi
    
    if [[ ! -f "$BUILD_DIR/initramfs.cpio.gz" ]]; then
        print_error "Initramfs not found. Cannot continue."
        return 1
    fi
    
    # Create the ISO directory structure
    ISO_ROOT="$BUILD_DIR/iso_root"
    mkdir -p "$ISO_ROOT/boot/grub"
    
    # Copy the kernel and initramfs
    cp "$BUILD_DIR/bzImage" "$ISO_ROOT/boot/vmlinuz"
    cp "$BUILD_DIR/initramfs.cpio.gz" "$ISO_ROOT/boot/initrd.img"
    
    # Create GRUB configuration
    cat << 'EOF' > "$ISO_ROOT/boot/grub/grub.cfg"
set timeout=5
set default=0

menuentry "Manzolo Linux" {
    linux /boot/vmlinuz
    initrd /boot/initrd.img
}

menuentry "Manzolo Linux (Debug Mode)" {
    linux /boot/vmlinuz debug
    initrd /boot/initrd.img
}
EOF
    
    # Check for grub-mkrescue
    if ! command -v grub-mkrescue &> /dev/null; then
        print_error "grub-mkrescue not found. Please install grub-pc-bin and xorriso."
        print_info "Example: sudo apt install grub-pc-bin xorriso"
        return 1
    fi
    
    local iso_label="${ISO_LABEL:-MANZOLO_LINUX}"
    local iso_file="$BUILD_DIR/${iso_label// /-}.iso"
    
    print_step "Generating ISO image: $iso_file"
    if grub-mkrescue -o "$iso_file" "$ISO_ROOT" &>> "$LOG_FILE"; then
        local iso_size=$(du -h "$iso_file" | cut -f1)
        print_success "ISO image created successfully! ($iso_size)"
        print_info "ISO saved to: $iso_file"
    else
        print_error "Failed to create the ISO image."
        return 1
    fi
    
    return 0
}

# Show filesystem statistics (helper function)
show_filesystem_stats() {
    print_section "Filesystem Statistics"
    echo "Total size: $(du -sh . | cut -f1)"
    echo "Number of files: $(find . -type f | wc -l)"
    echo "Number of directories: $(find . -type d | wc -l)"
    echo "Web server content: $(du -sh www 2>/dev/null | cut -f1 || echo 'N/A')"
}

# Main unattended build function
unattended_build() {
    print_header "🚀 Starting Unattended Build Process"
    
    # Set unattended mode
    set_unattended_mode
    
    local start_time=$(date +%s)
    local build_failed=false
    
    print_info "Build process will run without user interaction"
    print_info "Check $LOG_FILE for detailed progress"
    echo
    
    # Step 1: Prerequisites check
    print_step "Checking prerequisites..."
    if ! check_prerequisites_quiet; then
        print_error "Prerequisites check failed. Exiting unattended build."
        return 1
    fi
    print_success "Prerequisites check passed"
    
    # Step 2: Kernel preparation and compilation
    print_step "Building kernel..."
    if ! (prepare_kernel_unattended && configure_kernel_unattended && compile_kernel_unattended); then
        print_error "Kernel build failed. Exiting unattended build."
        build_failed=true
    else
        print_success "Kernel build completed"
    fi
    
    # Step 3: BusyBox preparation and compilation
    if [[ "$build_failed" != "true" ]]; then
        print_step "Building BusyBox..."
        if ! (prepare_busybox_unattended && configure_busybox_unattended && compile_busybox_unattended); then
            print_error "BusyBox build failed. Exiting unattended build."
            build_failed=true
        else
            print_success "BusyBox build completed"
        fi
    fi
    
    # Step 4: Filesystem and initramfs creation
    if [[ "$build_failed" != "true" ]]; then
        print_step "Creating filesystem and initramfs..."
        if ! (create_filesystem_unattended && generate_initramfs_unattended); then
            print_error "Filesystem/initramfs creation failed. Exiting unattended build."
            build_failed=true
        else
            print_success "Filesystem and initramfs created"
        fi
    fi
    
    # Step 5: ISO creation (optional)
    if [[ "$build_failed" != "true" ]]; then
        print_step "Creating bootable ISO..."
        if create_standard_iso_unattended; then
            print_success "ISO creation completed"
        else
            print_warning "ISO creation failed, but build artifacts are available"
        fi
    fi
    
    # Build summary
    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))
    local hours=$((total_duration / 3600))
    local minutes=$(((total_duration % 3600) / 60))
    local seconds=$((total_duration % 60))
    
    echo
    print_section "🎉 BUILD SUMMARY"
    
    if [[ "$build_failed" == "true" ]]; then
        print_error "❌ Build failed!"
        print_info "Check $LOG_FILE for error details"
        return 1
    else
        print_success "✅ Unattended build completed successfully!"
        printf "⏱️  Total build time: "
        if [[ $hours -gt 0 ]]; then
            printf "${hours}h "
        fi
        printf "${minutes}m ${seconds}s\n"
        
        echo
        print_info "🔧 Build artifacts:"
        [[ -f "$BUILD_DIR/bzImage" ]] && echo "   - Kernel: $BUILD_DIR/bzImage"
        [[ -f "$BUILD_DIR/initramfs.cpio.gz" ]] && echo "   - Initramfs: $BUILD_DIR/initramfs.cpio.gz"
        [[ -f "$BUILD_DIR"/*.iso ]] && echo "   - ISO: $(ls "$BUILD_DIR"/*.iso 2>/dev/null | head -1)"
        
        echo
        print_info "🚀 Ready to test with QEMU or deploy to hardware!"
        
        # Auto-launch QEMU if available and requested
        if command -v qemu-system-x86_64 &>/dev/null; then
            if [[ "${AUTO_LAUNCH_QEMU:-true}" == "true" ]]; then
                print_step "Auto-launching QEMU test..."
                launch_qemu_standard &
            fi
        fi
    fi
    
    read -p "Press ENTER to continue..."
    return 0
}

# Quiet prerequisites check for unattended mode
check_prerequisites_quiet() {
    local missing_tools=()
    local required_tools=("make" "gcc" "git" "cpio" "gzip")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    return 0
}

# Configure kernel for unattended mode (uses default config)
configure_kernel_unattended() {
    print_step "Configuring kernel (unattended)..."
    
    if [[ ! -d "$KERNEL_SOURCE_DIR" ]]; then
        print_error "Kernel source not found."
        return 1
    fi
    
    cd "$KERNEL_SOURCE_DIR" || return 1
    
    # Use defconfig for unattended mode
    if make defconfig O="$KERNEL_BUILD_DIR" &>> "$LOG_FILE"; then
        print_success "Default kernel configuration applied"
        cd "$CUR_DIR" || return 1
        return 0
    else
        print_error "Failed to configure kernel"
        cd "$CUR_DIR" || return 1
        return 1
    fi
}

prepare_kernel_unattended() {
    print_header "Preparing Linux Kernel v$KERNEL_VERSION"
    
    local kernel_archive="linux-$KERNEL_VERSION.tar.xz"
    local kernel_url=$(get_kernel_url "$KERNEL_VERSION")
    local download_dir="$BUILD_DIR/downloads"
    
    # Create directories
    mkdir -p "$download_dir" "$KERNEL_SOURCE_DIR" "$KERNEL_BUILD_DIR"
    
    print_info "📖 About the Linux Kernel:"
    print_info "The kernel is the core of your operating system. It manages"
    print_info "hardware, processes, memory, and provides system calls."
    echo
    
    # Check if already downloaded
    if [[ -f "$download_dir/$kernel_archive" ]]; then
        print_success "Kernel archive already exists"
    else
        # Check internet and disk space
        if ! check_internet; then
            print_error "Internet connection required to download kernel"
            return 1
        fi
        
        if ! check_disk_space 2; then
            return 1
        fi
        
        # Download kernel
        if ! download_file "$kernel_url" "$download_dir/$kernel_archive" "Linux kernel v$KERNEL_VERSION"; then
            return 1
        fi
    fi
    
    # Extract kernel
    print_step "Extracting kernel source..."
    rm -rf "$KERNEL_SOURCE_DIR"/*
    
    if ! extract_archive "$download_dir/$kernel_archive" "$KERNEL_SOURCE_DIR" "kernel source"; then
        return 1
    fi
    
    # Move extracted contents to the right place
    local extracted_dir=$(find "$KERNEL_SOURCE_DIR" -maxdepth 1 -type d -name "linux-*" | head -1)
    if [[ -n "$extracted_dir" ]]; then
        mv "$extracted_dir"/* "$KERNEL_SOURCE_DIR/"
        rm -rf "$extracted_dir"
    fi
    
    print_success "Kernel source prepared successfully"
}