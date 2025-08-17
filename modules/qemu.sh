#!/bin/bash

# =============================================================================
# 🖥️ QEMU TESTING MODULE
# =============================================================================

# QEMU configuration
QEMU_MEMORY="512M"
QEMU_CPU_CORES="1"
QEMU_DISPLAY="gtk"
QEMU_AUDIO="none"
QEMU_NETWORK="user"

# Launch QEMU with standard configuration
launch_qemu_standard() {
    print_header "Launch QEMU - Standard Mode"
    
    if ! check_qemu_requirements; then
        return 1
    fi
    
    print_info "🎯 Starting Manzolo Linux in QEMU..."
    print_info "Configuration: ${QEMU_MEMORY} RAM, ${QEMU_CPU_CORES} CPU, ${QEMU_DISPLAY} display"
    print_warning "Press Ctrl+Alt+G to release mouse cursor"
    echo
    
    sleep 2
    
    # Standard QEMU launch
    $QEMU_SYSTEM \
        -kernel "$BUILD_DIR/bzImage" \
        -initrd "$BUILD_DIR/initramfs.cpio.gz" \
        -m "$QEMU_MEMORY" \
        -smp "$QEMU_CPU_CORES" \
        -enable-kvm \
        -display "$QEMU_DISPLAY" \
        -name "Manzolo Linux" \
        -boot order=c \
        -no-reboot
    
    print_success "QEMU session ended"
    read -p "Press ENTER to continue..."
}

# Launch QEMU with debug mode
launch_qemu_debug() {
    print_header "Launch QEMU - Debug Mode"
    
    if ! check_qemu_requirements; then
        return 1
    fi
    
    print_info "🐛 Starting Manzolo Linux in debug mode..."
    print_info "Debug features: serial console, kernel debugging, verbose output"
    echo
    
    # Create debug script
    local debug_script="$BUILD_DIR/qemu-debug.sh"
    cat > "$debug_script" << EOF
#!/bin/bash
echo "QEMU Debug Session Started at \$(date)" >> "$BUILD_DIR/qemu-debug.log"
$QEMU_SYSTEM \\
    -kernel "$BUILD_DIR/bzImage" \\
    -initrd "$BUILD_DIR/initramfs.cpio.gz" \\
    -m "$QEMU_MEMORY" \\
    -smp "$QEMU_CPU_CORES" \\
    -enable-kvm \\
    -display "$QEMU_DISPLAY" \\
    -name "Manzolo Linux (Debug)" \\
    -serial stdio \\
    -append "debug loglevel=8 ignore_loglevel" \\
    -monitor telnet:127.0.0.1:55555,server,nowait \\
    -no-reboot \\
    -d guest_errors 2>&1 | tee -a "$BUILD_DIR/qemu-debug.log"
EOF
    chmod +x "$debug_script"
    
    print_info "Debug output will be saved to: $BUILD_DIR/qemu-debug.log"
    print_info "QEMU monitor available on: telnet 127.0.0.1 55555"
    echo
    
    sleep 2
    "$debug_script"
    
    print_success "Debug session ended"
    read -p "Press ENTER to continue..."
}

# Launch QEMU with graphics testing
launch_qemu_graphics() {
    print_header "Launch QEMU - Graphics Mode"
    
    if ! check_qemu_requirements; then
        return 1
    fi
    
    print_info "🖼️ Starting with enhanced graphics support..."
    
    cat << 'EOF'
    
    🎮 Graphics Options:
    ┌─────────────────────────────────────────────────────────────┐
    │  1. 🖥️  Standard VGA                                        │
    │  2. 🎨 QXL (SPICE)                                          │
    │  3. 🚀 VirtIO GPU                                           │
    │  4. 📺 VMware SVGA                                          │
    │  5. ⬅️  Return                                              │
    └─────────────────────────────────────────────────────────────┘
    
EOF
    
    read -rp "$(echo -e "${CYAN}Select graphics mode [1-5]: ${NC}")" gfx_choice
    
    local vga_option=""
    case $gfx_choice in
        1) vga_option="-vga std" ;;
        2) vga_option="-vga qxl -spice port=5930,disable-ticketing" ;;
        3) vga_option="-device virtio-gpu-pci" ;;
        4) vga_option="-vga vmware" ;;
        5) return 0 ;;
        *) 
            print_error "Invalid option"
            return 1
            ;;
    esac
    
    print_step "Starting with graphics optimization..."
    
    $QEMU_SYSTEM \
        -kernel "$BUILD_DIR/bzImage" \
        -initrd "$BUILD_DIR/initramfs.cpio.gz" \
        -m "$QEMU_MEMORY" \
        -smp "$QEMU_CPU_CORES" \
        -enable-kvm \
        $vga_option \
        -display "$QEMU_DISPLAY" \
        -name "Manzolo Linux (Graphics)" \
        -boot order=c \
        -no-reboot
    
    print_success "Graphics session ended"
    read -p "Press ENTER to continue..."
}

# Launch QEMU with network testing
launch_qemu_network() {
    print_header "Launch QEMU - Network Mode"
    
    if ! check_qemu_requirements; then
        return 1
    fi
    
    print_info "🌐 Starting with network configuration..."
    
    cat << 'EOF'
    
    🌐 Network Options:
    ┌─────────────────────────────────────────────────────────────┐
    │  1. 👤 User mode (NAT)                                      │
    │  2. 🌉 Bridge mode                                          │
    │  3. 🔗 TAP interface                                        │
    │  4. 🚫 No network                                           │
    │  5. ⬅️  Return                                              │
    └─────────────────────────────────────────────────────────────┘
    
EOF
    
    read -rp "$(echo -e "${CYAN}Select network mode [1-5]: ${NC}")" net_choice
    
    local net_option=""
    case $net_choice in
        1) net_option="-netdev user,id=net0 -device e1000,netdev=net0" ;;
        2) net_option="-netdev bridge,id=net0,br=br0 -device e1000,netdev=net0" ;;
        3) net_option="-netdev tap,id=net0,ifname=tap0,script=no,downscript=no -device e1000,netdev=net0" ;;
        4) net_option="-nic none" ;;
        5) return 0 ;;
        *) 
            print_error "Invalid option"
            return 1
            ;;
    esac
    
    print_step "Starting with network configuration..."
    
    $QEMU_SYSTEM \
        -kernel "$BUILD_DIR/bzImage" \
        -initrd "$BUILD_DIR/initramfs.cpio.gz" \
        -m "$QEMU_MEMORY" \
        -smp "$QEMU_CPU_CORES" \
        -enable-kvm \
        -display "$QEMU_DISPLAY" \
        $net_option \
        -name "Manzolo Linux (Network)" \
        -boot order=c \
        -no-reboot
    
    print_success "Network session ended"
    read -p "Press ENTER to continue..."
}

# QEMU performance test
qemu_performance_test() {
    print_header "QEMU Performance Test"
    
    if ! check_qemu_requirements; then
        return 1
    fi
    
    print_info "🚀 Running performance benchmarks..."
    
    local test_results="$BUILD_DIR/qemu-performance-$(date +%Y%m%d-%H%M%S).log"
    
    # Test different configurations
    local configs=(
        "512M:1:Basic configuration"
        "1G:2:Enhanced configuration"  
        "2G:4:High performance"
    )
    
    {
        echo "QEMU Performance Test Report"
        echo "Generated: $(date)"
        echo "Kernel: $KERNEL_VERSION"
        echo "BusyBox: $BUSYBOX_VERSION"
        echo "========================================="
        echo
    } > "$test_results"
    
    for config in "${configs[@]}"; do
        local memory=$(echo "$config" | cut -d: -f1)
        local cpus=$(echo "$config" | cut -d: -f2)
        local desc=$(echo "$config" | cut -d: -f3)
        
        print_step "Testing: $desc ($memory RAM, $cpus CPUs)"
        
        {
            echo "Test: $desc"
            echo "Memory: $memory"
            echo "CPUs: $cpus"
            echo "Start time: $(date)"
        } >> "$test_results"
        
        # Quick boot test (timeout after 30 seconds)
        local start_time=$(date +%s)
        
        timeout 30s $QEMU_SYSTEM \
            -kernel "$BUILD_DIR/bzImage" \
            -initrd "$BUILD_DIR/initramfs.cpio.gz" \
            -m "$memory" \
            -smp "$cpus" \
            -enable-kvm \
            -nographic \
            -serial none \
            -append "quiet" \
            -no-reboot &>/dev/null
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        {
            echo "Boot time: ${duration}s"
            echo "Status: $(if [[ $duration -lt 30 ]]; then echo 'SUCCESS'; else echo 'TIMEOUT'; fi)"
            echo "---"
            echo
        } >> "$test_results"
        
        print_info "Boot time: ${duration}s"
    done
    
    print_success "Performance test completed"
    print_info "Results saved to: $test_results"
    
    # Show summary
    print_section "Performance Summary"
    grep -E "(Test:|Boot time:)" "$test_results" | paste - - | while read test boot; do
        echo "$test - $boot"
    done
    
    read -p "Press ENTER to continue..."
}

# Configure QEMU options
configure_qemu_options() {
    print_header "Configure QEMU Options"
    
    print_section "Current Configuration"
    echo "Memory: $QEMU_MEMORY"
    echo "CPU Cores: $QEMU_CPU_CORES"
    echo "Display: $QEMU_DISPLAY"
    echo "System: $QEMU_SYSTEM"
    echo
    
    cat << 'EOF'
    ⚙️ Configuration Options:
    ┌─────────────────────────────────────────────────────────────┐
    │  1. 💾 Configure Memory                                     │
    │  2. 🔧 Configure CPU                                        │
    │  3. 🖥️  Configure Display                                   │
    │  4. 🎵 Configure Audio                                      │
    │  5. 💾 Save Configuration                                   │
    │  6. 🔄 Reset to Defaults                                    │
    │  7. ⬅️  Return                                              │
    └─────────────────────────────────────────────────────────────┘
    
EOF
    
    read -rp "$(echo -e "${CYAN}Select option [1-7]: ${NC}")" choice
    
    case $choice in
        1) configure_qemu_memory ;;
        2) configure_qemu_cpu ;;
        3) configure_qemu_display ;;
        4) configure_qemu_audio ;;
        5) save_qemu_config ;;
        6) reset_qemu_config ;;
        7) return 0 ;;
        *) 
            print_error "Invalid option"
            read -p "Press ENTER to continue..."
            ;;
    esac
    
    # Recursive call to show menu again
    configure_qemu_options
}

# Configure QEMU memory
configure_qemu_memory() {
    print_step "Configure QEMU Memory"
    
    local memory_options=("256M" "512M" "1G" "2G" "4G" "Custom")
    
    echo "Available memory options:"
    for i in "${!memory_options[@]}"; do
        echo "  $((i+1)). ${memory_options[i]}"
    done
    
    read -rp "$(echo -e "${CYAN}Select memory [1-${#memory_options[@]}]: ${NC}")" mem_choice
    
    if [[ $mem_choice =~ ^[0-9]+$ ]] && ((mem_choice >= 1 && mem_choice <= ${#memory_options[@]})); then
        if [[ $mem_choice -eq ${#memory_options[@]} ]]; then
            read -rp "Enter custom memory (e.g., 1.5G, 3072M): " custom_memory
            if [[ -n "$custom_memory" ]]; then
                QEMU_MEMORY="$custom_memory"
                print_success "Memory set to $QEMU_MEMORY"
            fi
        else
            QEMU_MEMORY="${memory_options[$((mem_choice-1))]}"
            print_success "Memory set to $QEMU_MEMORY"
        fi
    else
        print_error "Invalid choice"
    fi
}

# Configure QEMU CPU
configure_qemu_cpu() {
    print_step "Configure QEMU CPU"
    
    local max_cpus=$(nproc)
    echo "Host CPU cores: $max_cpus"
    echo "Current setting: $QEMU_CPU_CORES"
    
    read -rp "Enter number of CPU cores (1-$max_cpus): " cpu_cores
    
    if [[ $cpu_cores =~ ^[0-9]+$ ]] && ((cpu_cores >= 1 && cpu_cores <= max_cpus)); then
        QEMU_CPU_CORES="$cpu_cores"
        print_success "CPU cores set to $QEMU_CPU_CORES"
    else
        print_error "Invalid number of CPU cores"
    fi
}

# Configure QEMU display
configure_qemu_display() {
    print_step "Configure QEMU Display"
    
    local display_options=("gtk" "sdl" "vnc" "none" "curses")
    
    echo "Available display options:"
    for i in "${!display_options[@]}"; do
        echo "  $((i+1)). ${display_options[i]}"
    done
    
    read -rp "$(echo -e "${CYAN}Select display [1-${#display_options[@]}]: ${NC}")" disp_choice
    
    if [[ $disp_choice =~ ^[0-9]+$ ]] && ((disp_choice >= 1 && disp_choice <= ${#display_options[@]})); then
        QEMU_DISPLAY="${display_options[$((disp_choice-1))]}"
        print_success "Display set to $QEMU_DISPLAY"
    else
        print_error "Invalid choice"
    fi
}

# Configure QEMU audio
configure_qemu_audio() {
    print_step "Configure QEMU Audio"
    
    local audio_options=("none" "alsa" "pulse" "oss" "pa")
    
    echo "Available audio options:"
    for i in "${!audio_options[@]}"; do
        echo "  $((i+1)). ${audio_options[i]}"
    done
    
    read -rp "$(echo -e "${CYAN}Select audio [1-${#audio_options[@]}]: ${NC}")" audio_choice
    
    if [[ $audio_choice =~ ^[0-9]+$ ]] && ((audio_choice >= 1 && audio_choice <= ${#audio_options[@]})); then
        QEMU_AUDIO="${audio_options[$((audio_choice-1))]}"
        print_success "Audio set to $QEMU_AUDIO"
    else
        print_error "Invalid choice"
    fi
}

# Save QEMU configuration
save_qemu_config() {
    local qemu_config="$CONFIG_DIR/qemu.conf"
    
    print_step "Saving QEMU configuration..."
    
    cat > "$qemu_config" << EOF
# QEMU Configuration for Manzolo Linux
# Generated on $(date)

QEMU_MEMORY="$QEMU_MEMORY"
QEMU_CPU_CORES="$QEMU_CPU_CORES"
QEMU_DISPLAY="$QEMU_DISPLAY"
QEMU_AUDIO="$QEMU_AUDIO"
QEMU_NETWORK="$QEMU_NETWORK"
QEMU_SYSTEM="$QEMU_SYSTEM"
EOF
    
    print_success "Configuration saved to $qemu_config"
}

# Reset QEMU configuration
reset_qemu_config() {
    if ask_yes_no "Reset QEMU configuration to defaults?"; then
        QEMU_MEMORY="512M"
        QEMU_CPU_CORES="1"
        QEMU_DISPLAY="gtk"
        QEMU_AUDIO="none"
        QEMU_NETWORK="user"
        
        print_success "QEMU configuration reset to defaults"
    fi
}

# Check QEMU requirements
check_qemu_requirements() {
    # Check if files exist
    if [[ ! -f "$BUILD_DIR/bzImage" ]]; then
        print_error "Kernel image not found. Please compile kernel first."
        return 1
    fi
    
    if [[ ! -f "$BUILD_DIR/initramfs.cpio.gz" ]]; then
        print_error "Initramfs not found. Please create filesystem first."
        return 1
    fi
    
    # Check QEMU availability
    if ! command -v "$QEMU_SYSTEM" &> /dev/null; then
        print_error "QEMU not found: $QEMU_SYSTEM"
        print_info "Install with: sudo apt install qemu-system-x86"
        return 1
    fi
    
    # Check KVM support
    if [[ -r /dev/kvm ]]; then
        print_info "✅ KVM acceleration available"
    else
        print_warning "⚠️  KVM acceleration not available (will be slower)"
        if ! ask_yes_no "Continue without KVM acceleration?"; then
            return 1
        fi
    fi
    
    return 0
}

# Advanced QEMU launcher with custom options
launch_qemu_advanced() {
    print_header "Advanced QEMU Launcher"
    
    if ! check_qemu_requirements; then
        return 1
    fi
    
    # Build QEMU command interactively
    local qemu_cmd="$QEMU_SYSTEM"
    local qemu_args=()
    
    # Basic required arguments
    qemu_args+=("-kernel" "$BUILD_DIR/bzImage")
    qemu_args+=("-initrd" "$BUILD_DIR/initramfs.cpio.gz")
    qemu_args+=("-m" "$QEMU_MEMORY")
    qemu_args+=("-smp" "$QEMU_CPU_CORES")
    
    # KVM if available
    if [[ -r /dev/kvm ]]; then
        qemu_args+=("-enable-kvm")
    fi
    
    # Display
    qemu_args+=("-display" "$QEMU_DISPLAY")
    
    # Name
    qemu_args+=("-name" "Manzolo Linux")
    
    print_info "🔧 Advanced Options:"
    
    # Additional storage
    if ask_yes_no "Add virtual hard disk?"; then
        local disk_size
        read -rp "Disk size (e.g., 1G, 500M): " disk_size
        if [[ -n "$disk_size" ]]; then
            local disk_file="$BUILD_DIR/virtual-disk.img"
            if [[ ! -f "$disk_file" ]]; then
                print_step "Creating virtual disk..."
                qemu-img create -f qcow2 "$disk_file" "$disk_size"
            fi
            qemu_args+=("-drive" "file=$disk_file,format=qcow2")
        fi
    fi
    
    # Network configuration
    if ask_yes_no "Configure network?"; then
        qemu_args+=("-netdev" "user,id=net0")
        qemu_args+=("-device" "e1000,netdev=net0")
    else
        qemu_args+=("-nic" "none")
    fi
    
    # Audio
    if [[ "$QEMU_AUDIO" != "none" ]]; then
        qemu_args+=("-audiodev" "$QEMU_AUDIO,id=audio0")
        qemu_args+=("-device" "ac97,audiodev=audio0")
    fi
    
    # USB support
    if ask_yes_no "Enable USB support?"; then
        qemu_args+=("-usb")
        qemu_args+=("-device" "usb-tablet")
    fi
    
    # Serial console
    if ask_yes_no "Enable serial console?"; then
        qemu_args+=("-serial" "stdio")
    fi
    
    # Monitor interface
    if ask_yes_no "Enable QEMU monitor?"; then
        qemu_args+=("-monitor" "telnet:127.0.0.1:55555,server,nowait")
        print_info "Monitor will be available on: telnet 127.0.0.1 55555"
    fi
    
    # Show final command
    print_section "QEMU Command"
    echo "$qemu_cmd ${qemu_args[*]}"
    echo
    
    if ask_yes_no "Launch with these settings?"; then
        print_step "Starting advanced QEMU session..."
        "$qemu_cmd" "${qemu_args[@]}"
        print_success "QEMU session ended"
    fi
    
    read -p "Press ENTER to continue..."
}

# QEMU snapshot management
manage_qemu_snapshots() {
    print_header "QEMU Snapshot Management"
    
    local snapshot_dir="$BUILD_DIR/snapshots"
    mkdir -p "$snapshot_dir"
    
    cat << 'EOF'
    
    📸 Snapshot Options:
    ┌─────────────────────────────────────────────────────────────┐
    │  1. 📷 Create snapshot                                      │
    │  2. 📂 List snapshots                                       │
    │  3. 🔄 Load snapshot                                        │
    │  4. 🗑️  Delete snapshot                                     │
    │  5. ⬅️  Return                                              │
    └─────────────────────────────────────────────────────────────┘
    
EOF
    
    read -rp "$(echo -e "${CYAN}Select option [1-5]: ${NC}")" choice
    
    case $choice in
        1) create_qemu_snapshot ;;
        2) list_qemu_snapshots ;;
        3) load_qemu_snapshot ;;
        4) delete_qemu_snapshot ;;
        5) return 0 ;;
        *) 
            print_error "Invalid option"
            read -p "Press ENTER to continue..."
            ;;
    esac
    
    # Recursive call for continued management
    manage_qemu_snapshots
}

# Create QEMU snapshot
create_qemu_snapshot() {
    local snapshot_dir="$BUILD_DIR/snapshots"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    print_step "Creating system snapshot..."
    
    read -rp "Enter snapshot name (or press ENTER for timestamp): " snapshot_name
    snapshot_name=${snapshot_name:-"snapshot-$timestamp"}
    
    local snapshot_path="$snapshot_dir/$snapshot_name"
    mkdir -p "$snapshot_path"
    
    # Copy current system state
    cp "$BUILD_DIR/bzImage" "$snapshot_path/" 2>/dev/null || true
    cp "$BUILD_DIR/initramfs.cpio.gz" "$snapshot_path/" 2>/dev/null || true
    cp "$BUILD_DIR"/*.iso "$snapshot_path/" 2>/dev/null || true
    
    # Copy configuration
    if [[ -d "$CONFIG_DIR" ]]; then
        cp -r "$CONFIG_DIR" "$snapshot_path/"
    fi
    
    # Create metadata
    cat > "$snapshot_path/metadata.txt" << EOF
Snapshot: $snapshot_name
Created: $(date)
Kernel Version: $KERNEL_VERSION
BusyBox Version: $BUSYBOX_VERSION
Architecture: $KERNEL_ARCH
Host: $(hostname)
User: $(whoami)
EOF
    
    print_success "Snapshot created: $snapshot_name"
}

# List QEMU snapshots
list_qemu_snapshots() {
    local snapshot_dir="$BUILD_DIR/snapshots"
    
    print_section "Available Snapshots"
    
    if [[ ! -d "$snapshot_dir" ]] || [[ -z "$(ls -A "$snapshot_dir" 2>/dev/null)" ]]; then
        print_info "No snapshots found"
        return 0
    fi
    
    local count=0
    for snapshot in "$snapshot_dir"/*; do
        if [[ -d "$snapshot" ]]; then
            local name=$(basename "$snapshot")
            local size=$(du -sh "$snapshot" | cut -f1)
            
            echo "📸 $name ($size)"
            
            if [[ -f "$snapshot/metadata.txt" ]]; then
                echo "   $(grep "Created:" "$snapshot/metadata.txt")"
                echo "   $(grep "Kernel Version:" "$snapshot/metadata.txt")"
            fi
            echo
            ((count++))
        fi
    done
    
    echo "Total snapshots: $count"
}

# Load QEMU snapshot
load_qemu_snapshot() {
    local snapshot_dir="$BUILD_DIR/snapshots"
    
    if [[ ! -d "$snapshot_dir" ]] || [[ -z "$(ls -A "$snapshot_dir" 2>/dev/null)" ]]; then
        print_warning "No snapshots available"
        return 0
    fi
    
    print_step "Select snapshot to load:"
    
    local snapshots=()
    local count=1
    
    for snapshot in "$snapshot_dir"/*; do
        if [[ -d "$snapshot" ]]; then
            local name=$(basename "$snapshot")
            snapshots+=("$name")
            echo "  $count. $name"
            ((count++))
        fi
    done
    
    read -rp "$(echo -e "${CYAN}Select snapshot [1-${#snapshots[@]}]: ${NC}")" choice
    
    if [[ $choice =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#snapshots[@]})); then
        local selected="${snapshots[$((choice-1))]}"
        local snapshot_path="$snapshot_dir/$selected"
        
        if ask_yes_no "Load snapshot '$selected'? This will overwrite current build."; then
            print_step "Loading snapshot..."
            
            # Restore files
            cp "$snapshot_path/bzImage" "$BUILD_DIR/" 2>/dev/null || true
            cp "$snapshot_path/initramfs.cpio.gz" "$BUILD_DIR/" 2>/dev/null || true
            cp "$snapshot_path"/*.iso "$BUILD_DIR/" 2>/dev/null || true
            
            # Restore configuration
            if [[ -d "$snapshot_path/config" ]]; then
                rm -rf "$CONFIG_DIR"
                cp -r "$snapshot_path/config" "$CONFIG_DIR"
                source "$MAIN_CONFIG_FILE"
            fi
            
            print_success "Snapshot '$selected' loaded successfully"
        fi
    else
        print_error "Invalid selection"
    fi
}

# Delete QEMU snapshot
delete_qemu_snapshot() {
    local snapshot_dir="$BUILD_DIR/snapshots"
    
    if [[ ! -d "$snapshot_dir" ]] || [[ -z "$(ls -A "$snapshot_dir" 2>/dev/null)" ]]; then
        print_warning "No snapshots available"
        return 0
    fi
    
    print_step "Select snapshot to delete:"
    
    local snapshots=()
    local count=1
    
    for snapshot in "$snapshot_dir"/*; do
        if [[ -d "$snapshot" ]]; then
            local name=$(basename "$snapshot")
            snapshots+=("$name")
            echo "  $count. $name"
            ((count++))
        fi
    done
    
    read -rp "$(echo -e "${CYAN}Select snapshot [1-${#snapshots[@]}]: ${NC}")" choice
    
    if [[ $choice =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#snapshots[@]})); then
        local selected="${snapshots[$((choice-1))]}"
        local snapshot_path="$snapshot_dir/$selected"
        
        if ask_yes_no "Delete snapshot '$selected'? This cannot be undone."; then
            rm -rf "$snapshot_path"
            print_success "Snapshot '$selected' deleted"
        fi
    else
        print_error "Invalid selection"
    fi
}