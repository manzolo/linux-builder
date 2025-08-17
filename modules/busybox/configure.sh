# Configure BusyBox
configure_busybox() {
    print_header "BusyBox Configuration"
    
    if [[ ! -d "$BUSYBOX_SOURCE_DIR" ]] || [[ -z "$(ls -A "$BUSYBOX_SOURCE_DIR")" ]]; then
        print_error "BusyBox source not found. Please prepare BusyBox first."
        read -p "Press ENTER to continue..."
        return 1
    fi
    
    cd "$BUSYBOX_SOURCE_DIR" || return 1
    
    local config_choice
    cat << 'EOF'
    
    🎯 BusyBox Configuration Options:
    ┌─────────────────────────────────────────────────────────────┐
    │  1. 🔧 Default Configuration (defconfig)                   │
    │  2. 🎮 Interactive Configuration (menuconfig)              │
    │  3. 📋 Minimal Configuration                               │
    │  4. 🖥️  Desktop Configuration                              │
    │  5. 📥 Import Custom Configuration                         │
    │  6. ⬅️  Return                                              │
    └─────────────────────────────────────────────────────────────┘
    
EOF
    
    read -rp "$(echo -e "${CYAN}Select option [1-6]: ${NC}")" config_choice
    
    case $config_choice in
        1)
            print_step "Applying default configuration..."
            if make defconfig O="$BUSYBOX_BUILD_DIR" &>> "$LOG_FILE"; then
                apply_static_build
                print_success "Default configuration applied"
            else
                print_error "Failed to apply default configuration"
                return 1
            fi
            ;;
        2)
            print_step "Opening interactive configuration..."
            print_info "Use arrow keys to navigate, space to select, '?' for help"
            print_info "Make sure to enable static build for minimal dependencies"
            echo
            read -p "Press ENTER to open menuconfig..."
            
            # Start with defconfig
            make defconfig O="$BUSYBOX_BUILD_DIR" &>> "$LOG_FILE"
            apply_static_build
            
            if make menuconfig O="$BUSYBOX_BUILD_DIR"; then
                print_success "Interactive configuration completed"
            else
                print_error "Configuration was cancelled or failed"
                return 1
            fi
            ;;
        3)
            # Controllo il risultato della funzione
            if apply_minimal_config; then
                print_success "Minimal configuration applied"
            else
                print_error "Failed to apply minimal configuration"
                return 1
            fi
            ;;
        4)
            # Controllo il risultato della funzione
            if apply_desktop_config; then
                print_success "Desktop configuration applied"
            else
                print_error "Failed to apply desktop configuration"
                return 1
            fi
            ;;
        5)
            # Controllo il risultato della funzione
            if import_busybox_config; then
                print_success "Custom configuration imported"
            else
                print_error "Failed to import custom configuration"
                return 1
            fi
            ;;
        6)
            cd "$CUR_DIR" || return 1
            return 0
            ;;
        *)
            print_error "Invalid option"
            cd "$CUR_DIR" || return 1
            return 1
            ;;
    esac
    
    cd "$CUR_DIR" || return 1
    read -p "Press ENTER to continue..."
}

# Apply static build configuration
apply_static_build() {
    local config_file="$BUSYBOX_BUILD_DIR/.config"
    
    print_step "Configuring for static build..."
    
    # Enable static compilation
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' "$config_file"
    
    # Disable problematic applets for minimal systems
    sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' "$config_file" 2>/dev/null || true
    sed -i 's/CONFIG_INOTIFYD=y/# CONFIG_INOTIFYD is not set/' "$config_file" 2>/dev/null || true
    
    print_success "Static build configuration applied"
}

# Apply minimal configuration
apply_minimal_config() {
    print_step "Applying minimal configuration..."
    
    cd "$BUSYBOX_SOURCE_DIR" || return 1
    
    # Start with allnoconfig for truly minimal
    make allnoconfig O="$BUSYBOX_BUILD_DIR" &>> "$LOG_FILE"
    
    # Enable only essential applets
    local config_file="$BUSYBOX_BUILD_DIR/.config"
    
    # Core utilities
    cat >> "$config_file" << 'EOF'
CONFIG_STATIC=y
CONFIG_BUSYBOX=y
CONFIG_FEATURE_INSTALLER=y
CONFIG_FEATURE_SUID=y
CONFIG_FEATURE_PREFER_APPLETS=y
CONFIG_LONG_OPTS=y

# Shell
CONFIG_SH_IS_ASH=y
CONFIG_ASH=y
CONFIG_ASH_OPTIMIZE_FOR_SIZE=y
CONFIG_ASH_BUILTIN_ECHO=y
CONFIG_ASH_BUILTIN_PRINTF=y
CONFIG_ASH_BUILTIN_TEST=y

# Core commands
CONFIG_CAT=y
CONFIG_CP=y
CONFIG_LS=y
CONFIG_MV=y
CONFIG_RM=y
CONFIG_MKDIR=y
CONFIG_RMDIR=y
CONFIG_PWD=y
CONFIG_ECHO=y
CONFIG_PRINTF=y
CONFIG_TEST=y
CONFIG_TRUE=y
CONFIG_FALSE=y

# System commands
CONFIG_MOUNT=y
CONFIG_UMOUNT=y
CONFIG_PS=y
CONFIG_KILL=y
CONFIG_INIT=y
CONFIG_HALT=y
CONFIG_REBOOT=y
CONFIG_CHMOD=y
CONFIG_CHOWN=y

# File utilities
CONFIG_FIND=y
CONFIG_GREP=y
CONFIG_HEAD=y
CONFIG_TAIL=y
CONFIG_WC=y
CONFIG_SORT=y
CONFIG_UNIQ=y

# Network utilities (minimal)
CONFIG_PING=y
EOF
    
    # Resolve dependencies
    make olddefconfig O="$BUSYBOX_BUILD_DIR" &>> "$LOG_FILE"
    
    print_success "Minimal configuration applied"
    cd "$CUR_DIR" || return 1
}

# Apply desktop configuration
apply_desktop_config() {
    print_step "Applying desktop configuration..."
    
    cd "$BUSYBOX_SOURCE_DIR" || return 1
    
    # Start with defconfig for a solid base
    make defconfig O="$BUSYBOX_BUILD_DIR" &>> "$LOG_FILE"
    
    local config_file="$BUSYBOX_BUILD_DIR/.config"

    print_step "Configuring for static build and desktop features..."
    
    # Abilita la compilazione statica
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' "$config_file"
    
    # === CONFIGURAZIONE HTTPD ===
    # Abilita httpd e le sue funzionalità essenziali
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
    
    # === CONFIGURAZIONE RETE ===
    # udhcpc client - configurazione completa
    sed -i 's/# CONFIG_UDHCPC is not set/CONFIG_UDHCPC=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_UDHCPC_ARPING is not set/CONFIG_FEATURE_UDHCPC_ARPING=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_UDHCP_RFC3397 is not set/CONFIG_FEATURE_UDHCP_RFC3397=y/' "$config_file"
    
    # Funzionalità di rete essenziali
    sed -i 's/# CONFIG_IFCONFIG is not set/CONFIG_IFCONFIG=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_IFCONFIG_STATUS is not set/CONFIG_FEATURE_IFCONFIG_STATUS=y/' "$config_file"
    sed -i 's/# CONFIG_ROUTE is not set/CONFIG_ROUTE=y/' "$config_file"
    sed -i 's/# CONFIG_IP is not set/CONFIG_IP=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_IP_ADDRESS is not set/CONFIG_FEATURE_IP_ADDRESS=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_IP_LINK is not set/CONFIG_FEATURE_IP_LINK=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_IP_ROUTE is not set/CONFIG_FEATURE_IP_ROUTE=y/' "$config_file"
    
    # Networking utilities
    sed -i 's/# CONFIG_PING is not set/CONFIG_PING=y/' "$config_file"
    sed -i 's/# CONFIG_PING6 is not set/CONFIG_PING6=y/' "$config_file"
    sed -i 's/# CONFIG_WGET is not set/CONFIG_WGET=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_WGET_STATUSBAR is not set/CONFIG_FEATURE_WGET_STATUSBAR=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_WGET_AUTHENTICATION is not set/CONFIG_FEATURE_WGET_AUTHENTICATION=y/' "$config_file"
    
    # TTY
    sed -i 's/# CONFIG_ASH_JOB_CONTROL is not set/CONFIG_ASH_JOB_CONTROL=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_USE_TERMIOS is not set/CONFIG_FEATURE_USE_TERMIOS=y/' "$config_file"
    sed -i 's/# CONFIG_FEATURE_SH_STANDALONE is not set/CONFIG_FEATURE_SH_STANDALONE=y/' "$config_file"

    # Abilita le altre funzionalità desktop
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
    
    # Disabilita le funzionalità problematiche
    sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' "$config_file" 2>/dev/null || true
    sed -i 's/CONFIG_INOTIFYD=y/# CONFIG_INOTIFYD is not set/' "$config_file" 2>/dev/null || true
    
    # Risolvi le dipendenze
    print_step "Resolving feature dependencies..."
    make olddefconfig O="$BUSYBOX_BUILD_DIR" &>> "$LOG_FILE"
    
    print_success "Desktop configuration applied with HTTPD support"
    cd "$CUR_DIR" || return 1
}

# Import BusyBox configuration
import_busybox_config() {
    print_step "Import BusyBox configuration..."
    read -rp "Enter path to .config file: " config_path
    
    if [[ ! -f "$config_path" ]]; then
        print_error "Configuration file not found: $config_path"
        return 1
    fi
    
    print_step "Importing configuration..."
    
    cd "$BUSYBOX_SOURCE_DIR" || return 1
    
    # Copy configuration
    mkdir -p "$BUSYBOX_BUILD_DIR"
    cp "$config_path" "$BUSYBOX_BUILD_DIR/.config"
    
    # Ensure static build
    apply_static_build
    
    # Update configuration for current BusyBox version
    make olddefconfig O="$BUSYBOX_BUILD_DIR" &>> "$LOG_FILE"
    
    print_success "Configuration imported successfully"
    
    cd "$CUR_DIR" || return 1
}