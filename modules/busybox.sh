#!/bin/bash

# =============================================================================
# 📦 BUSYBOX MANAGEMENT MODULE
# =============================================================================

# BusyBox URLs and paths
BUSYBOX_BASE_URL="https://busybox.net/downloads"
BUSYBOX_SOURCE_DIR="$BUILD_DIR/busybox-source"
BUSYBOX_BUILD_DIR="$BUILD_DIR/busybox-build"
BUSYBOX_INSTALL_DIR="$BUILD_DIR/rootfs"

# Get BusyBox download URL
get_busybox_url() {
    local version="$1"
    echo "$BUSYBOX_BASE_URL/busybox-${version}.tar.bz2"
}

# Prepare BusyBox source
prepare_busybox() {
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
    read -p "Press ENTER to continue..."
}

# Configure BusyBox
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
    
    # Start with defconfig for a solid base, instead of allnoconfig
    # This includes most dependencies needed for desktop features
    make defconfig O="$BUSYBOX_BUILD_DIR" &>> "$LOG_FILE"
    
    local config_file="$BUSYBOX_BUILD_DIR/.config"

    print_step "Configuring for static build and desktop features..."
    
    # Abilita la compilazione statica
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' "$config_file"
    
    # Abilita le funzionalità desktop essenziali
    for feature in \
        ASH_GETOPTS \
        FEATURE_EDITING \
        FEATURE_EDITING_MAX_LEN=256 \
        FEATURE_TAB_COMPLETION \
        FEATURE_VI_EDITING \
        FEATURE_FANCY_READLINE \
        FEATURE_LS_COLOR \
        WGET \
        TOP \
        FREE \
        UPTIME \
        CLEAR \
        LSOF \
        FIND_PRINT0
    do
        # Abilita la funzionalità se non è già attiva
        sed -i "s/# CONFIG_${feature} is not set/CONFIG_${feature}=y/" "$config_file"
        # Forziamo a 'y' anche se è impostata su 'n'
        sed -i "s/CONFIG_${feature}=n/CONFIG_${feature}=y/" "$config_file"
    done

    # Abilita Nano e Vi separatamente, poiché hanno sottomenu e dipendenze complesse
    # L'opzione 'NANO' abilita l'editor Nano, mentre le sue feature dipendono
    # da CONFIG_FEATURE_EDITING. Non tutte le feature di Nano che hai elencato
    # sono opzioni di primo livello e potrebbero causare un errore di compilazione.
    sed -i 's/# CONFIG_NANO is not set/CONFIG_NANO=y/' "$config_file"
    sed -i 's/# CONFIG_VI is not set/CONFIG_VI=y/' "$config_file"

    # Disabilita le funzionalità problematiche per i sistemi minimali
    sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' "$config_file" 2>/dev/null || true
    sed -i 's/CONFIG_INOTIFYD=y/# CONFIG_INOTIFYD is not set/' "$config_file" 2>/dev/null || true
    
    # Risolvi le dipendenze in modo non interattivo
    print_step "Resolving feature dependencies..."
    make olddefconfig O="$BUSYBOX_BUILD_DIR" &>> "$LOG_FILE"
    
    print_success "Desktop configuration applied"
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

# Compile BusyBox
compile_busybox() {
    print_header "Compiling BusyBox"

    if [[ ! -f "$BUSYBOX_BUILD_DIR/.config" ]]; then
        print_error "BusyBox non è stato configurato. Si prega di configurarlo prima."
        read -p "Premi INVIO per continuare..."
        return 1
    fi

    cd "$BUSYBOX_SOURCE_DIR" || return 1

    # Controlla lo spazio su disco
    if ! check_disk_space 1; then
        return 1
    fi

    local cores=$(nproc)
    local start_time=$(date +%s)

    print_step "Avvio della compilazione di BusyBox..."
    print_info "Utilizzo di $cores job paralleli"
    print_info "Questa operazione dovrebbe richiedere solo pochi minuti"
    echo

    # Log della compilazione
    {
        echo "Compilazione di BusyBox iniziata il $(date)"
        echo "Versione: $BUSYBOX_VERSION"
        echo "Job paralleli: $cores"
        echo "========================================"
    } >> "$LOG_FILE"

    # Nuova pipeline con visualizzazione su una sola riga
    if make -j"$cores" O="$BUSYBOX_BUILD_DIR" 2>&1 | tee -a "$LOG_FILE" | \
        stdbuf -o0 grep -E ' (CC|AR|LD|GEN|SYMLINK).*' | \
        while read -r line; do
            # Pulisce la riga precedente e stampa la nuova
            echo -ne "\r${CYAN}Building BusyBox: ${line:0:70}...${NC}\033[K"
        done; then

        echo -ne "\r\033[K" # Pulisce la riga dopo la barra di avanzamento
        print_success "BusyBox compilato con successo!"

        # Verifica il linking statico
        if file "$BUSYBOX_BUILD_DIR/busybox" | grep -qi static; then
            print_success "BusyBox è collegato in modo statico (ottimo!)"
        else
            print_warning "BusyBox non è collegato in modo statico"
            print_info "Questo potrebbe causare problemi in ambienti minimali"
        fi
        # Conta gli applet disponibili subito dopo la compilazione
        if [[ -x "$BUSYBOX_BUILD_DIR/busybox" ]]; then
            applet_count=$("$BUSYBOX_BUILD_DIR/busybox" --list 2>/dev/null | wc -l || echo 0)
            print_info "📦 BusyBox applets disponibili: $applet_count"
        else
            print_warning "Impossibile contare gli applet: binario non trovato"
        fi        

    else
        echo -ne "\r\033[K" # Pulisce la riga anche in caso di errore
        print_error "La compilazione di BusyBox è fallita!"
        print_info "Controlla il file $LOG_FILE per informazioni dettagliate sull'errore"
        cd "$CUR_DIR" || return 1
        return 1
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    print_success "Compilazione completata in ${minutes}m ${seconds}s"

    cd "$CUR_DIR" || return 1
    read -p "Premi INVIO per continuare..."
}

# Create filesystem
create_filesystem() {
    print_header "Creating Root Filesystem"
    
    if [[ ! -f "$BUSYBOX_BUILD_DIR/busybox" ]]; then
        print_error "BusyBox not compiled. Please compile BusyBox first."
        read -p "Press ENTER to continue..."
        return 1
    fi
    
    cd "$BUSYBOX_SOURCE_DIR" || return 1
    
    print_step "Installing BusyBox to filesystem..."
    
    # Clean and create rootfs
    rm -rf "$BUSYBOX_INSTALL_DIR"
    mkdir -p "$BUSYBOX_INSTALL_DIR"
    
    # Install BusyBox
    if make install O="$BUSYBOX_BUILD_DIR" CONFIG_PREFIX="$BUSYBOX_INSTALL_DIR" &>> "$LOG_FILE"; then
        print_success "BusyBox installed to filesystem"
    else
        print_error "Failed to install BusyBox"
        cd "$CUR_DIR" || return 1
        return 1
    fi
    
    cd "$BUSYBOX_INSTALL_DIR" || return 1
    
    print_step "Creating filesystem structure..."
    
    # Create essential directories
    mkdir -p {dev,proc,sys,tmp,var/log,etc,root,home,usr/lib,usr/share}
    
    # Create device nodes
    print_step "Creating essential device nodes..."
    sudo mknod dev/null c 1 3 2>/dev/null || true
    sudo mknod dev/zero c 1 5 2>/dev/null || true
    sudo mknod dev/random c 1 8 2>/dev/null || true
    sudo mknod dev/urandom c 1 9 2>/dev/null || true
    sudo mknod dev/console c 5 1 2>/dev/null || true
    sudo mknod dev/tty c 5 0 2>/dev/null || true
    
    # Create basic configuration files
    print_step "Creating configuration files..."
    
    # /etc/passwd
    cat > etc/passwd << 'EOF'
root:x:0:0:root:/root:/bin/sh
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
bin:x:2:2:bin:/bin:/usr/sbin/nologin
sys:x:3:3:sys:/dev:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
EOF
    
    # /etc/group
    cat > etc/group << 'EOF'
root:x:0:
daemon:x:1:
bin:x:2:
sys:x:3:
tty:x:5:
disk:x:6:
lp:x:7:
mail:x:8:
news:x:9:
uucp:x:10:
man:x:12:
proxy:x:13:
kmem:x:15:
dialout:x:20:
fax:x:21:
voice:x:22:
cdrom:x:24:
floppy:x:25:
tape:x:26:
sudo:x:27:
audio:x:29:
dip:x:30:
www-data:x:33:
backup:x:34:
operator:x:37:
list:x:38:
irc:x:39:
src:x:40:
gnats:x:41:
shadow:x:42:
utmp:x:43:
video:x:44:
sasl:x:45:
plugdev:x:46:
staff:x:50:
games:x:60:
users:x:100:
nogroup:x:65534:
EOF
    
    # /etc/shadow (basic)
    cat > etc/shadow << 'EOF'
root:*:19000:0:99999:7:::
daemon:*:19000:0:99999:7:::
bin:*:19000:0:99999:7:::
sys:*:19000:0:99999:7:::
nobody:*:19000:0:99999:7:::
EOF
    
    # /etc/hosts
    cat > etc/hosts << 'EOF'
127.0.0.1    localhost
127.0.1.1    manzolo-linux
::1          localhost ip6-localhost ip6-loopback
ff02::1      ip6-allnodes
ff02::2      ip6-allrouters
EOF
    
    # /etc/hostname
    echo "manzolo-linux" > etc/hostname
    
    # /etc/fstab
    cat > etc/fstab << 'EOF'
# <file system> <mount point> <type> <options> <dump> <pass>
proc            /proc         proc   defaults          0      0
sysfs           /sys          sysfs  defaults          0      0
devtmpfs        /dev          devtmpfs defaults        0      0
tmpfs           /tmp          tmpfs  defaults          0      0
EOF
    
    # /etc/inittab
    cat > etc/inittab << 'EOF'
# /etc/inittab
::sysinit:/etc/init.d/rcS
::askfirst:-/bin/sh
::ctrlaltdel:/sbin/reboot
::shutdown:/sbin/swapoff -a
::shutdown:/bin/umount -a -r
::restart:/sbin/init
EOF
    
    # Create init scripts directory
    mkdir -p etc/init.d
    
    # Basic rcS script
    cat > etc/init.d/rcS << 'EOF'
#!/bin/sh
# Basic system initialization

echo "Starting Manzolo Linux..."

# Mount filesystems
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mount -t tmpfs tmpfs /tmp

# Set hostname
hostname -F /etc/hostname

# Enable loopback interface
ip link set lo up

echo "System initialization completed."
EOF
    chmod +x etc/init.d/rcS
    
    print_success "Filesystem structure created successfully"

    # Show filesystem statistics
    print_section "Filesystem Statistics"
    echo "Total size: $(du -sh . | cut -f1)"
    echo "Number of files: $(find . -type f | wc -l)"
    echo "Number of directories: $(find . -type d | wc -l)"
    
    # Aggiungi un cd alla cartella di installazione prima di eseguire il comando
    cd "$BUSYBOX_INSTALL_DIR" || return 1 
    
    # Ora il comando BusyBox funzionerà
    
    cd "$CUR_DIR" || return 1
    read -p "Press ENTER to continue..."
}

# Generate initramfs
generate_initramfs() {
    print_header "Generating Initramfs"
    
    if [[ ! -d "$BUSYBOX_INSTALL_DIR" ]] || [[ -z "$(ls -A "$BUSYBOX_INSTALL_DIR")" ]]; then
        print_error "Filesystem not created. Please create filesystem first."
        read -p "Press ENTER to continue..."
        return 1
    fi
    
    cd "$BUSYBOX_INSTALL_DIR" || return 1
    
    print_step "Creating init script..."
    
    # Check for custom init templates
    local init_template=""
    local templates_dir="$CONFIG_DIR/templates"
    
    if [[ -f "$templates_dir/init" ]]; then
        init_template="$templates_dir/init"
        print_info "Using custom init template"
    else
        create_default_init
        init_template="./init"
    fi
    
    # Copy or create init script
    if [[ "$init_template" != "./init" ]]; then
        cp "$init_template" ./init
    fi
    
    chmod +x init
    
    print_step "Generating initramfs archive..."
    
    # Create initramfs with better compression
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
    read -p "Press ENTER to continue..."
}

# Create default init script
create_default_init() {
    cat > init << 'EOF'
#!/bin/sh

# Manzolo Linux Init Script
clear

echo "🐧 Welcome to Manzolo Linux!"
echo "============================="
echo

# Mount essential filesystems
echo "📂 Mounting filesystems..."
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null
mount -t tmpfs tmpfs /tmp 2>/dev/null

# Create additional device nodes if needed
[ ! -e /dev/null ] && mknod /dev/null c 1 3
[ ! -e /dev/zero ] && mknod /dev/zero c 1 5
[ ! -e /dev/random ] && mknod /dev/random c 1 8

# Set hostname
[ -f /etc/hostname ] && hostname -F /etc/hostname

# Configure network (loopback)
ip link set lo up 2>/dev/null

echo "✅ System initialization completed"
echo

# Show system information
echo "📊 System Information:"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Memory: $(free -h | awk '/^Mem:/ {print $2}' 2>/dev/null || echo 'N/A')"
echo "Hostname: $(hostname)"
echo

# Welcome message
cat << 'WELCOME'
╔══════════════════════════════════════════════════════════════╗
║                  🎉 MANZOLO LINUX v2.0                       ║
║                                                              ║
║ Welcome to your custom Linux distribution!                   ║
║                                                              ║
║ 💡 Available commands:                                       ║
║ • ls, cat, cp, mv, rm    - File operations                  ║
║ • ps, top, free, df      - System monitoring                ║
║ • mount, umount          - Filesystem operations            ║
║ • ping, wget             - Network utilities                ║
║ • vi                     - Text editors (if enabled)        ║
║                                                              ║
║ 🚀 Type 'busybox --list' to see all available commands      ║
║                                                              ║
║ 🎯 Have fun exploring your system!                          ║
╚══════════════════════════════════════════════════════════════╝

WELCOME

echo
echo "🔧 Type 'help' for more information or just start exploring!"
echo

# Start shell
while true; do
    /bin/sh
done
EOF
}

# Clean BusyBox build
clean_busybox() {
    print_header "Clean BusyBox Build"
    
    cat << 'EOF'
    
    🧹 Cleanup Options:
    ┌─────────────────────────────────────────────────────────────┐
    │  1. 🗑️  Clean build files only                             │
    │  2. 🔄 Clean build and filesystem                          │
    │  3. 💣 Clean everything (including source)                 │
    │  4. ⬅️  Return                                              │
    └─────────────────────────────────────────────────────────────┘
    
EOF
    
    read -rp "$(echo -e "${CYAN}Select cleanup option [1-4]: ${NC}")" choice
    
    case $choice in
        1)
            if [[ -d "$BUSYBOX_BUILD_DIR" ]]; then
                print_step "Cleaning build files..."
                rm -rf "$BUSYBOX_BUILD_DIR"/{*.o,.*.cmd,busybox_unstripped}
                print_success "Build files cleaned"
            else
                print_info "No build files to clean"
            fi
            ;;
        2)
            if [[ -d "$BUSYBOX_BUILD_DIR" ]] || [[ -d "$BUSYBOX_INSTALL_DIR" ]]; then
                print_step "Cleaning build and filesystem..."
                rm -rf "$BUSYBOX_BUILD_DIR" "$BUSYBOX_INSTALL_DIR"
                rm -f "$BUILD_DIR/initramfs.cpio.gz"
                print_success "Build and filesystem cleaned"
            else
                print_info "No build files to clean"
            fi
            ;;
        3)
            if ask_yes_no "This will delete all BusyBox source, build and filesystem files. Continue?"; then
                print_step "Cleaning everything..."
                rm -rf "$BUSYBOX_SOURCE_DIR" "$BUSYBOX_BUILD_DIR" "$BUSYBOX_INSTALL_DIR"
                rm -f "$BUILD_DIR/initramfs.cpio.gz"
                print_success "All BusyBox files cleaned"
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

# Show BusyBox information
show_busybox_info() {
    print_header "BusyBox Information"
    
    print_section "Current Configuration"
    echo "Version: $BUSYBOX_VERSION"
    echo "Source Directory: $BUSYBOX_SOURCE_DIR"
    echo "Build Directory: $BUSYBOX_BUILD_DIR"
    echo "Install Directory: $BUSYBOX_INSTALL_DIR"
    
    print_section "Build Status"
    if [[ -f "$BUSYBOX_BUILD_DIR/.config" ]]; then
        print_success "BusyBox configured"
        
        # Show configuration details
        if grep -q "CONFIG_STATIC=y" "$BUSYBOX_BUILD_DIR/.config" 2>/dev/null; then
            echo "✅ Static build: enabled"
        else
            echo "❌ Static build: disabled"
        fi
        
        local applet_count=$(grep "^CONFIG_.*=y$" "$BUSYBOX_BUILD_DIR/.config" 2>/dev/null | wc -l)
        echo "📦 Enabled applets: approximately $applet_count"
        
    else
        print_warning "BusyBox not configured"
    fi
    
    if [[ -f "$BUSYBOX_BUILD_DIR/busybox" ]]; then
        local busybox_size=$(du -h "$BUSYBOX_BUILD_DIR/busybox" | cut -f1)
        print_success "BusyBox compiled: $busybox_size"
        
        print_section "Binary Information"
        file "$BUSYBOX_BUILD_DIR/busybox"
        
        if [[ -x "$BUSYBOX_BUILD_DIR/busybox" ]]; then
            echo "Available applets: $("$BUSYBOX_BUILD_DIR/busybox" --list 2>/dev/null | wc -l)"
        fi
    else
        print_warning "BusyBox not compiled"
    fi
    
    if [[ -d "$BUSYBOX_INSTALL_DIR" ]]; then
        local rootfs_size=$(du -sh "$BUSYBOX_INSTALL_DIR" | cut -f1)
        print_success "Filesystem created: $rootfs_size"
        
        print_section "Filesystem Details"
        echo "Total files: $(find "$BUSYBOX_INSTALL_DIR" -type f 2>/dev/null | wc -l)"
        echo "Total directories: $(find "$BUSYBOX_INSTALL_DIR" -type d 2>/dev/null | wc -l)"
    else
        print_warning "Filesystem not created"
    fi
    
    if [[ -f "$BUILD_DIR/initramfs.cpio.gz" ]]; then
        local initramfs_size=$(du -h "$BUILD_DIR/initramfs.cpio.gz" | cut -f1)
        print_success "Initramfs generated: $initramfs_size"
    else
        print_warning "Initramfs not generated"
    fi
    
    read -p "Press ENTER to continue..."
}