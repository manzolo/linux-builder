#!/bin/bash

# =============================================================================
# 🐧 KERNEL MANAGEMENT MODULE
# =============================================================================

# Kernel URLs and paths
KERNEL_BASE_URL="https://cdn.kernel.org/pub/linux/kernel"
KERNEL_SOURCE_DIR="$BUILD_DIR/kernel-source"
KERNEL_BUILD_DIR="$BUILD_DIR/kernel-build"

# Get kernel download URL
get_kernel_url() {
    local version="$1"
    local major=$(echo "$version" | cut -d. -f1)
    echo "$KERNEL_BASE_URL/v${major}.x/linux-${version}.tar.xz"
}

# Prepare kernel source
prepare_kernel() {
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
    read -p "Press ENTER to continue..."
}

# Configure kernel
configure_kernel() {
    print_header "Kernel Configuration"
    
    if [[ ! -d "$KERNEL_SOURCE_DIR" ]] || [[ -z "$(ls -A "$KERNEL_SOURCE_DIR")" ]]; then
        print_error "Kernel source not found. Please prepare kernel first."
        read -p "Press ENTER to continue..."
        return 1
    fi
    
    cd "$KERNEL_SOURCE_DIR" || return 1
    
    local config_choice
    cat << 'EOF'
    
    🎯 Kernel Configuration Options:
    ┌─────────────────────────────────────────────────────────────┐
    │  1. 🔧 Default Configuration (defconfig)                   │
    │  2. 🎮 Interactive Configuration (menuconfig)              │
    │  3. 📋 Load Preset Configuration                           │
    │  4. 📥 Import Custom Configuration                         │
    │  5. ⬅️  Return                                              │
    └─────────────────────────────────────────────────────────────┘
    
EOF
    
    read -rp "$(echo -e "${CYAN}Select option [1-5]: ${NC}")" config_choice
    
    case $config_choice in
        1)
            print_step "Applying default configuration..."
            if make defconfig O="$KERNEL_BUILD_DIR" &>> "$LOG_FILE"; then
                print_success "Default configuration applied"
            else
                print_error "Failed to apply default configuration"
                return 1
            fi
            ;;
        2)
            print_step "Opening interactive configuration..."
            print_info "Use arrow keys to navigate, space to select, '?' for help"
            print_info "Important: Enable framebuffer console support to avoid black screen"
            echo
            read -p "Press ENTER to open menuconfig..."
            
            if make menuconfig O="$KERNEL_BUILD_DIR"; then
                print_success "Interactive configuration completed"
            else
                print_error "Configuration was cancelled or failed"
                return 1
            fi
            ;;
        3)
            load_kernel_preset
            ;;
        4)
            import_kernel_config
            ;;
        5)
            return 0
            ;;
        *)
            print_error "Invalid option"
            return 1
            ;;
    esac
    
    cd "$CUR_DIR" || return 1
    read -p "Press ENTER to continue..."
}

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

# Load kernel preset
load_kernel_preset() {
    local presets_dir="$CONFIG_DIR/presets"
    mkdir -p "$presets_dir"
    
    print_header "Kernel Configuration Presets"
    
    # Create default presets if they don't exist
    create_default_presets
    
    cat << 'EOF'
    
    🎯 Available Presets:
    ┌─────────────────────────────────────────────────────────────┐
    │  1. 🔬 Minimal      - Bare minimum (embedded systems)      │
    │  2. 🖥️  Desktop     - Full desktop support                 │
    │  3. 🖧 Server      - Network-focused server                │
    │  4. 👨‍💻 Development - Debug tools and features             │
    │  5. 🎮 Gaming      - Performance optimized                 │
    │  6. 🔧 Custom      - Load custom preset                    │
    │  7. ⬅️  Return     - Back to configuration menu            │
    └─────────────────────────────────────────────────────────────┘
    
EOF
    
    read -rp "$(echo -e "${CYAN}Select preset [1-7]: ${NC}")" preset_choice
    
    case $preset_choice in
        1) apply_preset "minimal" ;;
        2) apply_preset "desktop" ;;
        3) apply_preset "server" ;;
        4) apply_preset "development" ;;
        5) apply_preset "gaming" ;;
        6) load_custom_preset ;;
        7) return 0 ;;
        *) 
            print_error "Invalid option"
            return 1
            ;;
    esac
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

# Apply preset configuration
apply_preset() {
    local preset_name="$1"
    local preset_file="$CONFIG_DIR/presets/${preset_name}.config"
    
    if [[ ! -f "$preset_file" ]]; then
        print_error "Preset not found: $preset_name"
        return 1
    fi
    
    print_step "Applying $preset_name preset configuration..."
    
    cd "$KERNEL_SOURCE_DIR" || return 1
    
    # Start with defconfig
    make defconfig O="$KERNEL_BUILD_DIR" &>> "$LOG_FILE"
    
    # Apply preset overrides
    cat "$preset_file" >> "$KERNEL_BUILD_DIR/.config"
    
    # Resolve dependencies
    make olddefconfig O="$KERNEL_BUILD_DIR" &>> "$LOG_FILE"
    
    print_success "$preset_name preset applied successfully"
    print_info "You can still run menuconfig to fine-tune the configuration"
    
    cd "$CUR_DIR" || return 1
}

# Load custom preset
load_custom_preset() {
    print_step "Load custom preset..."
    read -rp "Enter path to custom config file: " config_path
    
    if [[ ! -f "$config_path" ]]; then
        print_error "File not found: $config_path"
        return 1
    fi
    
    local preset_name
    read -rp "Enter name for this preset: " preset_name
    
    if [[ -z "$preset_name" ]]; then
        print_error "Preset name cannot be empty"
        return 1
    fi
    
    # Copy to presets directory
    cp "$config_path" "$CONFIG_DIR/presets/${preset_name}.config"
    
    # Apply the preset
    apply_preset "$preset_name"
}

# Import kernel configuration
import_kernel_config() {
    print_step "Import kernel configuration..."
    read -rp "Enter path to .config file: " config_path
    
    if [[ ! -f "$config_path" ]]; then
        print_error "Configuration file not found: $config_path"
        return 1
    fi
    
    print_step "Importing configuration..."
    
    cd "$KERNEL_SOURCE_DIR" || return 1
    
    # Copy configuration
    mkdir -p "$KERNEL_BUILD_DIR"
    cp "$config_path" "$KERNEL_BUILD_DIR/.config"
    
    # Update configuration for current kernel version
    make olddefconfig O="$KERNEL_BUILD_DIR" &>> "$LOG_FILE"
    
    print_success "Configuration imported successfully"
    
    cd "$CUR_DIR" || return 1
}

# Show kernel information
show_kernel_info() {
    print_header "Kernel Information"
    
    print_section "Current Configuration"
    echo "Version: $KERNEL_VERSION"
    echo "Architecture: $KERNEL_ARCH"
    echo "Source Directory: $KERNEL_SOURCE_DIR"
    echo "Build Directory: $KERNEL_BUILD_DIR"
    
    print_section "Build Status"
    if [[ -f "$KERNEL_BUILD_DIR/.config" ]]; then
        print_success "Kernel configured"
        
        # Show some key config options
        if grep -q "CONFIG_MODULES=y" "$KERNEL_BUILD_DIR/.config" 2>/dev/null; then
            echo "✅ Loadable modules support: enabled"
        else
            echo "❌ Loadable modules support: disabled"
        fi
        
        if grep -q "CONFIG_SMP=y" "$KERNEL_BUILD_DIR/.config" 2>/dev/null; then
            echo "✅ SMP support: enabled"
        else
            echo "❌ SMP support: disabled"
        fi
        
        if grep -q "CONFIG_NET=y" "$KERNEL_BUILD_DIR/.config" 2>/dev/null; then
            echo "✅ Networking: enabled"
        else
            echo "❌ Networking: disabled"
        fi
        
    else
        print_warning "Kernel not configured"
    fi
    
    if [[ -f "$BUILD_DIR/bzImage" ]]; then
        local kernel_size=$(du -h "$BUILD_DIR/bzImage" | cut -f1)
        print_success "Kernel compiled: $kernel_size"
        
        print_section "Kernel Image Details"
        file "$BUILD_DIR/bzImage"
    else
        print_warning "Kernel not compiled"
    fi
    
    print_section "Source Information"
    if [[ -d "$KERNEL_SOURCE_DIR" ]]; then
        echo "Source size: $(du -sh "$KERNEL_SOURCE_DIR" | cut -f1)"
        if [[ -f "$KERNEL_SOURCE_DIR/Makefile" ]]; then
            local version=$(grep "^VERSION =" "$KERNEL_SOURCE_DIR/Makefile" | head -1 | cut -d= -f2 | xargs)
            local patchlevel=$(grep "^PATCHLEVEL =" "$KERNEL_SOURCE_DIR/Makefile" | head -1 | cut -d= -f2 | xargs)
            local sublevel=$(grep "^SUBLEVEL =" "$KERNEL_SOURCE_DIR/Makefile" | head -1 | cut -d= -f2 | xargs)
            echo "Makefile version: ${version}.${patchlevel}.${sublevel}"
        fi
    else
        print_warning "Source not downloaded"
    fi
    
    read -p "Press ENTER to continue..."
}

# Clean kernel build
clean_kernel() {
    print_header "Clean Kernel Build"
    
    cat << 'EOF'
    
    🧹 Cleanup Options:
    ┌─────────────────────────────────────────────────────────────┐
    │  1. 🗑️  Clean build files only                               │
    │  2. 🔄 Clean build and configuration                        │
    │  3. 💣 Clean everything (including source)                  │
    │  4. ⬅️  Return                                               │
    └─────────────────────────────────────────────────────────────┘
    
EOF
    
    read -rp "$(echo -e "${CYAN}Select cleanup option [1-4]: ${NC}")" choice
    
    case $choice in
        1)
            if [[ -d "$KERNEL_BUILD_DIR" ]]; then
                print_step "Cleaning build files..."
                rm -rf "$KERNEL_BUILD_DIR"/{*.o,*.ko,.*.cmd,modules.builtin,modules.order,System.map,vmlinux}
                print_success "Build files cleaned"
            else
                print_info "No build files to clean"
            fi
            ;;
        2)
            if [[ -d "$KERNEL_BUILD_DIR" ]]; then
                print_step "Cleaning build directory..."
                rm -rf "$KERNEL_BUILD_DIR"/*
                print_success "Build directory cleaned"
            else
                print_info "No build directory to clean"
            fi
            ;;
        3)
            if ask_yes_no "This will delete all kernel source and build files. Continue?"; then
                print_step "Cleaning everything..."
                rm -rf "$KERNEL_SOURCE_DIR" "$KERNEL_BUILD_DIR"
                rm -f "$BUILD_DIR/bzImage"
                print_success "All kernel files cleaned"
            fi
            ;;
        4)
            return 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
    
    read -p "Press ENTER to continue..."
}