# Compile kernel
compile_kernel() {
    print_header "Compiling Linux Kernel"
    
    if [[ ! -f "$KERNEL_BUILD_DIR/.config" ]]; then
        print_error "Kernel not configured. Please configure kernel first."
        read -p "Press ENTER to continue..."
        return 1
    fi
    
    cd "$KERNEL_SOURCE_DIR" || return 1
    
    # Check memory and disk space
    if ! check_memory 2048; then
        print_warning "Low memory detected. Compilation may be slow."
        if ! ask_yes_no "Continue anyway?"; then
            return 1
        fi
    fi
    
    if ! check_disk_space 3; then
        return 1
    fi
    
    local cores=$(nproc)
    local start_time=$(date +%s)
    
    print_step "Starting kernel compilation..."
    print_info "Using $cores parallel jobs"
    print_info "This may take 15-60 minutes depending on your system"
    print_warning "Do not interrupt the process!"
    echo
    
    # Start performance monitoring
    monitor_performance 3600 30 &
    local monitor_pid=$!
    
    # Compile kernel with progress indication
    {
        echo "Kernel compilation started at $(date)"
        echo "Version: $KERNEL_VERSION"
        echo "Architecture: $KERNEL_ARCH"
        echo "Parallel jobs: $cores"
        echo "========================================"
    } >> "$LOG_FILE"
    
    if make -j"$cores" O="$KERNEL_BUILD_DIR" 2>&1 | tee -a "$LOG_FILE" | \
       stdbuf -o0 grep -E "(CC|LD|OBJCOPY)" | \
       while read line; do
           echo -ne "\r${CYAN}Compiling: ${line:0:60}...${NC}\033[K"
       done; then
        
        echo -ne "\r\033[K" # Pulisce la riga finale
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
        echo
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
    read -p "Press ENTER to continue..."
}

# Create default presets
create_default_presets() {
    local presets_dir="$CONFIG_DIR/presets"
    
    # Minimal preset
    if [[ ! -f "$presets_dir/minimal.config" ]]; then
        cat > "$presets_dir/minimal.config" << 'EOF'
# Minimal kernel configuration for embedded systems
CONFIG_64BIT=y
CONFIG_X86_64=y
CONFIG_SMP=n
CONFIG_MODULES=n
CONFIG_BLOCK=y
CONFIG_TTY=y
CONFIG_SERIAL_8250=y
CONFIG_SERIAL_8250_CONSOLE=y
CONFIG_EXT4_FS=y
CONFIG_PROC_FS=y
CONFIG_SYSFS=y
CONFIG_DEVTMPFS=y
CONFIG_PRINTK=y
# Disable graphics
CONFIG_VT=n
CONFIG_DRM=n
CONFIG_FB=n
# Disable audio
CONFIG_SOUND=n
# Disable USB
CONFIG_USB=n
# Disable networking
CONFIG_NET=n
EOF
    fi
    
    # Desktop preset
    if [[ ! -f "$presets_dir/desktop.config" ]]; then
        cat > "$presets_dir/desktop.config" << 'EOF'
# Desktop kernel configuration
CONFIG_64BIT=y
CONFIG_X86_64=y
CONFIG_SMP=y
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
# Graphics support
CONFIG_DRM=y
CONFIG_DRM_I915=y
CONFIG_DRM_RADEON=y
CONFIG_DRM_AMDGPU=y
CONFIG_FB=y
CONFIG_FB_VESA=y
CONFIG_FRAMEBUFFER_CONSOLE=y
# Audio support
CONFIG_SOUND=y
CONFIG_SND=y
CONFIG_SND_HDA_INTEL=y
CONFIG_SND_USB_AUDIO=y
# USB support
CONFIG_USB=y
CONFIG_USB_EHCI_HCD=y
CONFIG_USB_OHCI_HCD=y
CONFIG_USB_STORAGE=y
# Network support
CONFIG_NET=y
CONFIG_ETHERNET=y
CONFIG_WIRELESS=y
# Filesystem support
CONFIG_EXT4_FS=y
CONFIG_NTFS_FS=y
CONFIG_FAT_FS=y
CONFIG_VFAT_FS=y
EOF
    fi
    
    # Server preset
    if [[ ! -f "$presets_dir/server.config" ]]; then
        cat > "$presets_dir/server.config" << 'EOF'
# Server kernel configuration
CONFIG_64BIT=y
CONFIG_X86_64=y
CONFIG_SMP=y
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
# No graphics needed
CONFIG_VT=n
CONFIG_DRM=n
CONFIG_FB=n
# No audio needed
CONFIG_SOUND=n
# Advanced networking
CONFIG_NET=y
CONFIG_ETHERNET=y
CONFIG_NETFILTER=y
CONFIG_IP_NF_IPTABLES=y
CONFIG_BRIDGE=y
CONFIG_VLAN_8021Q=y
CONFIG_BONDING=y
# Server filesystems
CONFIG_EXT4_FS=y
CONFIG_XFS_FS=y
CONFIG_BTRFS_FS=y
CONFIG_NFS_FS=y
CONFIG_NFS_V4=y
# Virtualization support
CONFIG_KVM=y
CONFIG_KVM_INTEL=y
CONFIG_KVM_AMD=y
CONFIG_VIRTIO=y
EOF
    fi
    
    # Development preset
    if [[ ! -f "$presets_dir/development.config" ]]; then
        cat > "$presets_dir/development.config" << 'EOF'
# Development kernel configuration
CONFIG_64BIT=y
CONFIG_X86_64=y
CONFIG_SMP=y
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
# Debug support
CONFIG_DEBUG_KERNEL=y
CONFIG_DEBUG_INFO=y
CONFIG_KGDB=y
CONFIG_MAGIC_SYSRQ=y
CONFIG_KALLSYMS=y
CONFIG_KALLSYMS_ALL=y
CONFIG_DEBUG_FS=y
# Tracing support
CONFIG_FTRACE=y
CONFIG_FUNCTION_TRACER=y
CONFIG_STACK_TRACER=y
CONFIG_DYNAMIC_FTRACE=y
# Performance profiling
CONFIG_PERF_EVENTS=y
CONFIG_PROFILING=y
# Basic hardware support
CONFIG_NET=y
CONFIG_USB=y
CONFIG_DRM=y
CONFIG_FB=y
CONFIG_FRAMEBUFFER_CONSOLE=y
EOF
    fi
    
    # Gaming preset
    if [[ ! -f "$presets_dir/gaming.config" ]]; then
        cat > "$presets_dir/gaming.config" << 'EOF'
# Gaming optimized kernel configuration
CONFIG_64BIT=y
CONFIG_X86_64=y
CONFIG_SMP=y
CONFIG_MODULES=y
CONFIG_MODULE_UNLOAD=y
# High resolution timers
CONFIG_HIGH_RES_TIMERS=y
CONFIG_NO_HZ=y
CONFIG_PREEMPT=y
# CPU frequency scaling
CONFIG_CPU_FREQ=y
CONFIG_CPU_FREQ_DEFAULT_GOV_PERFORMANCE=y
# Graphics acceleration
CONFIG_DRM=y
CONFIG_DRM_I915=y
CONFIG_DRM_RADEON=y
CONFIG_DRM_AMDGPU=y
CONFIG_FB=y
CONFIG_FRAMEBUFFER_CONSOLE=y
# Audio for gaming
CONFIG_SOUND=y
CONFIG_SND=y
CONFIG_SND_HDA_INTEL=y
CONFIG_SND_USB_AUDIO=y
# Gaming input devices
CONFIG_INPUT_JOYDEV=y
CONFIG_JOYSTICK_XPAD=y
CONFIG_HID_GENERIC=y
CONFIG_USB_HID=y
EOF
    fi
}