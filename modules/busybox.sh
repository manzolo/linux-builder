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

# Create default init script
create_default_init() {
    cat > init << 'EOF'
#!/bin/sh

# Manzolo Linux Init Script - Network & Web Server Version
clear

echo "🐧 Welcome to Manzolo Linux!"
echo "============================="
echo

# Mount essential filesystems
echo "📂 Mounting filesystems..."
mount -t proc proc /proc 2>/dev/null
mount -t sysfs sysfs /sys 2>/dev/null
mount -t devtmpfs devtmpfs /dev 2>/dev/null || {
    # Fallback device creation
    [ ! -e /dev/null ] && mknod /dev/null c 1 3
    [ ! -e /dev/zero ] && mknod /dev/zero c 1 5
    [ ! -e /dev/random ] && mknod /dev/random c 1 8
    [ ! -e /dev/console ] && mknod /dev/console c 5 1
}
mount -t tmpfs tmpfs /tmp 2>/dev/null
mount -t tmpfs tmpfs /var/run 2>/dev/null

# Set hostname
[ -f /etc/hostname ] && hostname -F /etc/hostname

# Configure loopback
echo "🔄 Setting up loopback..."
ip link set lo up 2>/dev/null

# Network configuration
echo "🌐 Configuring network..."
INTERFACE=$(ls /sys/class/net/ 2>/dev/null | grep -v lo | head -1)
if [ -n "$INTERFACE" ]; then
    echo "   Found interface: $INTERFACE"
    ip link set $INTERFACE up 2>/dev/null
    
    if command -v udhcpc >/dev/null; then
        echo "   Starting DHCP client..."
        # Run DHCP in background with more verbose output
        udhcpc -i $INTERFACE -b -s /etc/udhcpc/default.script -v &
        DHCP_PID=$!
        
        # Wait for DHCP with timeout
        echo "   Waiting for network configuration..."
        for i in 1 2 3 4 5; do
            sleep 1
            echo -n "."
        done
        echo
    else
        echo "   ❌ udhcpc not found, trying static fallback..."
        # Fallback to static IP for testing
        ip addr add 192.168.1.100/24 dev $INTERFACE 2>/dev/null || true
        ip route add default via 192.168.1.1 2>/dev/null || true
    fi
else
    echo "   ❌ No network interface found"
fi

# Check network status
if [ -n "$INTERFACE" ]; then
    IP_ADDR=$(ip addr show $INTERFACE 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
    if [ -n "$IP_ADDR" ] && [ "$IP_ADDR" != "0.0.0.0" ]; then
        GATEWAY=$(ip route show default 2>/dev/null | awk '{print $3}' | head -1)
        echo "✅ Network configured:"
        echo "   Interface: $INTERFACE"
        echo "   IP Address: $IP_ADDR"
        echo "   Gateway: ${GATEWAY:-none}"
        
        # Test connectivity
        if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
            echo "   Internet: ✅ Connected"
        else
            echo "   Internet: ❌ No connectivity"
        fi
        
        NETWORK_OK=1
    else
        echo "❌ Failed to get IP address for $INTERFACE"
        echo "   Interface status:"
        ip addr show $INTERFACE 2>/dev/null | grep -E "(state|inet )"
        NETWORK_OK=0
    fi
else
    echo "❌ No network interface available"
    NETWORK_OK=0
fi

# Start web server with detailed debugging
echo
echo "🌐 Starting web server..."

# Check if httpd is available
if ! command -v httpd >/dev/null; then
    echo "❌ httpd command not found!"
    echo "   Checking BusyBox applets..."
    if command -v busybox >/dev/null; then
        if busybox --list | grep -q httpd; then
            echo "   ✅ httpd found in BusyBox applets"
            HTTPD_CMD="busybox httpd"
        else
            echo "   ❌ httpd NOT found in BusyBox applets"
            echo "   Available network applets:"
            busybox --list | grep -E "(http|wget|ping|telnet)" | head -5
            HTTPD_CMD=""
        fi
    else
        echo "   ❌ busybox command not found!"
        HTTPD_CMD=""
    fi
else
    echo "✅ httpd command found"
    HTTPD_CMD="httpd"
fi

# Check web directory
if [ ! -d /www ]; then
    echo "❌ Web directory /www not found!"
    echo "   Creating basic web directory..."
    mkdir -p /www
    echo "<h1>Manzolo Linux - Emergency Web Page</h1><p>Web server is running!</p>" > /www/index.html
    WEB_DIR_OK=1
elif [ ! -f /www/index.html ]; then
    echo "⚠️  /www exists but index.html missing"
    echo "<h1>Manzolo Linux</h1><p>Default page created by init</p>" > /www/index.html
    WEB_DIR_OK=1
else
    echo "✅ Web directory /www found with content"
    WEB_DIR_OK=1
fi

# Actually start the web server
if [ -n "$HTTPD_CMD" ] && [ "$WEB_DIR_OK" = "1" ]; then
    echo "   Attempting to start httpd..."
    
    # Try different httpd configurations
    if $HTTPD_CMD -h /www -p 80 -f 2>/tmp/httpd.log &
    then
        HTTPD_PID=$!
        sleep 1
        
        # Check if httpd is still running
        if kill -0 $HTTPD_PID 2>/dev/null; then
            echo "✅ Web server started successfully (PID: $HTTPD_PID)"
            
            if [ "$NETWORK_OK" = "1" ]; then
                echo "   🌍 Access your server at:"
                echo "      http://$IP_ADDR/"
                echo "      http://localhost/"
            else
                echo "   🔧 Server running on localhost only (no network)"
            fi
            
            # Test the web server
            if command -v wget >/dev/null; then
                echo "   Testing web server..."
                if wget -q -O /tmp/test.html http://localhost/ 2>/dev/null; then
                    echo "   ✅ Web server test successful"
                else
                    echo "   ⚠️  Web server test failed"
                fi
            fi
            
        else
            echo "❌ Web server started but died immediately"
            if [ -f /tmp/httpd.log ]; then
                echo "   Error log:"
                cat /tmp/httpd.log | head -5
            fi
        fi
    else
        echo "❌ Failed to start web server"
        echo "   Trying alternative port 8080..."
        
        if $HTTPD_CMD -h /www -p 8080 -f 2>/tmp/httpd8080.log &
        then
            HTTPD_PID=$!
            sleep 1
            if kill -0 $HTTPD_PID 2>/dev/null; then
                echo "✅ Web server started on port 8080 (PID: $HTTPD_PID)"
                [ "$NETWORK_OK" = "1" ] && echo "   Access: http://$IP_ADDR:8080/"
            else
                echo "❌ Web server failed on port 8080 too"
            fi
        fi
    fi
else
    echo "❌ Cannot start web server (missing httpd or web directory)"
    
    # Diagnostic information
    echo
    echo "🔍 Diagnostic Information:"
    echo "   BusyBox location: $(which busybox 2>/dev/null || echo 'not found')"
    echo "   httpd in PATH: $(which httpd 2>/dev/null || echo 'not found')"
    echo "   Available commands containing 'http':"
    compgen -c 2>/dev/null | grep http | head -3 || echo "   none"
    echo "   /www directory: $(ls -ld /www 2>/dev/null || echo 'missing')"
fi

echo
echo "✅ System initialization completed"
echo

# Show system information
echo "📊 System Information:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Memory: $(free -h 2>/dev/null | awk '/^Mem:/ {print $2}' || echo 'N/A')"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime 2>/dev/null | cut -d',' -f1 || echo 'N/A')"
echo

# Welcome message
cat << 'WELCOME'
╔══════════════════════════════════════════════════════════════╗
║                  🎉 MANZOLO LINUX v2.0                       ║
║                                                              ║
║ Welcome to your custom Linux distribution!                   ║
║                                                              ║
║ 💡 Network commands:                                         ║
║ • ip addr show       - Show network interfaces              ║
║ • ping 8.8.8.8       - Test connectivity                    ║
║ • udhcpc -i eth0     - Renew DHCP lease                     ║
║ • route              - Show routing table                    ║
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