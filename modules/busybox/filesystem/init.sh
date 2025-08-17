create_init_script() {
    print_step "Creating system initialization script..."
    
    cat > etc/init.d/rcS << EOF
#!/bin/sh
# Manzolo Linux System Initialization

echo "╔══════════════════════════════════════════════════╗"
echo "║              🚀 Manzolo Linux v$FILESYSTEM_VERSION               ║"
echo "║           Starting system services...            ║"
echo "╚══════════════════════════════════════════════════╝"

# Mount essential filesystems
# Mount essential filesystems
echo "Mounting filesystems..."
mount -a

# Setup TTY devices if not mounted by devtmpfs
if [ ! -c /dev/tty1 ]; then
    echo "Creating TTY devices..."
    mknod /dev/tty1 c 4 1 2>/dev/null || true
    mknod /dev/tty2 c 4 2 2>/dev/null || true
    mknod /dev/tty3 c 4 3 2>/dev/null || true
    mknod /dev/tty4 c 4 4 2>/dev/null || true
    chmod 622 /dev/tty* 2>/dev/null || true
fi

# Set up proper TTY permissions
chmod 666 /dev/tty 2>/dev/null || true
chmod 622 /dev/tty[0-9]* 2>/dev/null || true
chmod 600 /dev/console 2>/dev/null || true

# Initialize TTY settings
for tty_dev in /dev/tty[1-6]; do
    if [ -c "\$tty_dev" ]; then
        # Reset TTY to sane state
        stty -F "\$tty_dev" sane 2>/dev/null || true
        # Enable job control features
        stty -F "\$tty_dev" -clocal crtscts 2>/dev/null || true
    fi
done

# Set hostname
hostname -F /etc/hostname 2>/dev/null || hostname manzolo-linux

# Network initialization
echo "Initializing network..."
for iface in eth0 enp0s3 enp0s8; do
    if [ -e "/sys/class/net/\$iface" ]; then
        echo "Configuring interface: \$iface"
        ifconfig "\$iface" up 2>/dev/null || true
        udhcpc -i "\$iface" -b -q 2>/dev/null &
        break
    fi
done

# Set up console keymap for TTY switching
if [ -f /usr/share/keymaps/console.map ]; then
    loadkeys /usr/share/keymaps/console.map 2>/dev/null || true
    echo "Console keymap loaded (Ctrl+Alt+F1-F6 available)"
fi

echo ""
echo "✅ System initialization completed!"
echo ""
echo "💡 Quick start commands:"
echo "   • manzolopkg install manzolo-hello-world  (install sample package)"
echo "   • httpd -p 8080 -h /www                   (start web server)"
echo "   • ip addr show                            (check network)"
echo "   • ping 8.8.8.8                           (test connectivity)"
echo ""
echo "🌟 Welcome to Manzolo Linux! Ready for action."
echo "═══════════════════════════════════════════════════"
EOF
    chmod +x etc/init.d/rcS
}