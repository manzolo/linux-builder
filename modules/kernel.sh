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