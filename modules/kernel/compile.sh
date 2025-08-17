# compile_kernel()
# Add this new function to your script
clean_build_dir() {
    print_warning "A different kernel version was previously configured in this build directory."
    if ask_yes_no "Do you want to clean the build directory now? This is highly recommended."; then
        print_step "Cleaning build directory..."
        make O="$KERNEL_BUILD_DIR" clean > /dev/null
        if [[ $? -eq 0 ]]; then
            print_success "Build directory cleaned successfully."
        else
            print_error "Failed to clean the build directory. Please check permissions."
            return 1
        fi
    else
        print_info "Skipping clean-up. Compilation may fail due to leftover files."
        read -p "Press ENTER to continue anyway..."
    fi
}
# End of new function
#--------------------------------------------------------------------------------
# compile_kernel()
compile_kernel() {
    print_header "Compiling Linux Kernel"

    # Check if a .config file exists
    if [[ ! -f "$KERNEL_BUILD_DIR/.config" ]]; then
        print_error "Kernel not configured. Please configure kernel first."
        read -p "Press ENTER to continue..."
        return 1
    fi
    
    cd "$KERNEL_SOURCE_DIR" || return 1

    # Check for previous build and clean if necessary
    local last_build_version_file="$KERNEL_BUILD_DIR/.kernel_version_configured"
    if [[ -f "$last_build_version_file" ]]; then
        local last_build_version=$(cat "$last_build_version_file")
        if [[ "$last_build_version" != "$KERNEL_VERSION" ]]; then
            clean_build_dir
        fi
    fi

    # Check kernel version for compatibility
    local kernel_major=$(echo "$KERNEL_VERSION" | cut -d. -f1)
    local kernel_minor=$(echo "$KERNEL_VERSION" | cut -d. -f2)

    # Version-specific adjustments
    if [[ "$kernel_major" -ge 6 && "$kernel_minor" -ge 10 ]]; then
        print_warning "Using kernel 6.10+ - applying compatibility adjustments"
        
        # Check for removed options in .config
        sed -i '/CONFIG_DEBUG_FS/d' "$KERNEL_BUILD_DIR/.config"
        sed -i '/CONFIG_KGDB/d' "$KERNEL_BUILD_DIR/.config"
        sed -i '/CONFIG_MAGIC_SYSRQ/d' "$KERNEL_BUILD_DIR/.config"
        
        # Add new required options for 6.10+
        echo "CONFIG_DEBUG_KERNEL=y" >> "$KERNEL_BUILD_DIR/.config"
        echo "CONFIG_DEBUG_INFO=y" >> "$KERNEL_BUILD_DIR/.config"
    fi

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
    print_info "See detailed log in $LOG_FILE"
    
    if make -j"$cores" O="$KERNEL_BUILD_DIR" 2>&1 | tee -a "$LOG_FILE" | grep -E --line-buffered "(CC|LD|OBJCOPY)"; then
        echo
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

    # Stop performance monitoring and wait for it to finish
    kill $monitor_pid 2>/dev/null || true
    wait $monitor_pid 2>/dev/null

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    print_success "Compilation completed in ${minutes}m ${seconds}s"

    cd "$CUR_DIR" || return 1
    read -p "Press ENTER to continue..."
}

# create_default_presets()
create_default_presets() {
    local presets_dir="$CONFIG_DIR/presets"
    
    # Helper function to add version-specific options
    add_version_specific_options() {
        local config_file="$1"
        local kernel_major="$2"
        local kernel_minor="$3"
        
        if [[ "$kernel_major" -ge 6 && "$kernel_minor" -ge 10 ]]; then
            cat >> "$config_file" << 'EOF'
# 6.10+ specific options
CONFIG_DEBUG_BOOT_PARAMS=y
CONFIG_PAHOLE_HAS_SPLIT_BTF=y
CONFIG_DEBUG_INFO_BTF=y
EOF
        else
            cat >> "$config_file" << 'EOF'
# Legacy options for pre-6.10 kernels
CONFIG_DEBUG_FS=y
CONFIG_KGDB=y
CONFIG_MAGIC_SYSRQ=y
EOF
        fi
    }

    # Helper function to update presets for new kernel version
    update_presets_for_version() {
        local current_major="$1"
        local current_minor="$2"
        
        for preset in "$presets_dir"/*.config; do
            # Remove old version-specific options using a single sed command
            sed -i -E '/# (6.10+|Legacy) options|CONFIG_DEBUG_BOOT_PARAMS|CONFIG_PAHOLE_HAS_SPLIT_BTF|CONFIG_DEBUG_INFO_BTF|CONFIG_DEBUG_FS|CONFIG_KGDB|CONFIG_MAGIC_SYSRQ/d' "$preset"
            
            # Add new version-specific options
            add_version_specific_options "$preset" "$current_major" "$current_minor"
        done
    }

    mkdir -p "$presets_dir"

    # Create presets only if they don't exist
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

    # Check if we need to update presets
    if [[ -f "$presets_dir/version.info" ]]; then
        local last_major=$(awk -F. '{print $1}' "$presets_dir/version.info")
        local last_minor=$(awk -F. '{print $2}' "$presets_dir/version.info")
        local current_major=$(echo "$KERNEL_VERSION" | cut -d. -f1)
        local current_minor=$(echo "$KERNEL_VERSION" | cut -d. -f2)

        if [[ "$last_major" -ne "$current_major" ]] || [[ "$last_minor" -ne "$current_minor" ]]; then
            print_warning "Kernel version changed from $last_major.$last_minor to $current_major.$current_minor - updating presets"
            update_presets_for_version "$current_major" "$current_minor"
        fi
    else
        # If version file doesn't exist, update all presets to current version
        local current_major=$(echo "$KERNEL_VERSION" | cut -d. -f1)
        local current_minor=$(echo "$KERNEL_VERSION" | cut -d. -f2)
        print_info "No version info found, applying current kernel version options to presets."
        update_presets_for_version "$current_major" "$current_minor"
    fi
    
    # Save current version info
    echo "$KERNEL_VERSION" > "$presets_dir/version.info"
}