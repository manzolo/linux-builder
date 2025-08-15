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