# CREAZIONE FILESYSTEM 
create_filesystem() {
    print_header "Creating Root Filesystem"
    
    if [[ ! -f "$BUSYBOX_BUILD_DIR/busybox" ]]; then
        print_error "BusyBox not compiled. Please compile BusyBox first."
        read -p "Press ENTER to continue..."
        return 1
    fi
    
    print_step "Installing BusyBox to filesystem..."
    
    # Clean and create rootfs
    rm -rf "$BUSYBOX_INSTALL_DIR"
    mkdir -p "$BUSYBOX_INSTALL_DIR"
    
    # Install BusyBox
    cd "$BUSYBOX_SOURCE_DIR" || return 1
    if make install O="$BUSYBOX_BUILD_DIR" CONFIG_PREFIX="$BUSYBOX_INSTALL_DIR" &>> "$LOG_FILE"; then
        print_success "BusyBox installed to filesystem"
    else
        print_error "Failed to install BusyBox"
        cd "$CUR_DIR" || return 1
        return 1
    fi
    
    cd "$BUSYBOX_INSTALL_DIR" || return 1
    
    print_step "Creating filesystem structure and essential files..."
    
    # Create essential directories with correct permissions
    mkdir -p {dev,proc,sys,tmp,var/log,var/run,etc,root,home,usr/lib,usr/share}
    mkdir -p www/cgi-bin  # Directory for httpd
    
    # Set correct permissions
    chmod 755 {dev,proc,sys,var,etc,root,home,usr}
    chmod 1777 tmp  # sticky bit for /tmp
    chmod 755 www www/cgi-bin
    
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
    
    # /etc/passwd - ADD www-data user
    cat > etc/passwd << 'EOF'
root:x:0:0:root:/root:/bin/sh
daemon:x:1:1:daemon:/usr/sbin:/bin/false
bin:x:2:2:bin:/bin:/bin/false
sys:x:3:3:sys:/dev:/bin/false
www-data:x:33:33:www-data:/var/www:/bin/false
nobody:x:65534:65534:nobody:/nonexistent:/bin/false
EOF
    
    # /etc/group - ADD www-data group
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
    
    # /etc/shadow (basic) - ADD www-data
    cat > etc/shadow << 'EOF'
root:*:19000:0:99999:7:::
daemon:*:19000:0:99999:7:::
bin:*:19000:0:99999:7:::
sys:*:19000:0:99999:7:::
www-data:*:19000:0:99999:7:::
nobody:*:19000:0:99999:7:::
EOF
    
    # /etc/hosts
    cat > etc/hosts << 'EOF'
127.0.0.1    localhost manzolo-linux
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
tmpfs           /tmp          tmpfs  defaults,mode=1777 0     0
tmpfs           /var/run      tmpfs  defaults          0      0
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

    # === HTTPD CONFIGURATION ===
    print_step "Creating httpd configuration..."
    
    # httpd configuration file (optional but useful for debugging)
    cat > etc/httpd.conf << 'EOF'
# BusyBox httpd configuration
# Uncomment and modify as needed

# Set document root
#H:/www

# Enable CGI scripts in /cgi-bin/
#*.cgi:/cgi-bin

# Default index files
#I:index.html
#I:index.htm
#I:index.cgi

# MIME types
.html:text/html
.htm:text/html
.css:text/css
.js:application/javascript
.png:image/png
.jpg:image/jpeg
.gif:image/gif
.ico:image/x-icon
EOF

    # CGI test script
    cat > www/cgi-bin/test.cgi << 'EOF'
#!/bin/sh
echo "Content-Type: text/html"
echo ""
echo "<html><head><meta charset="UTF-8">
<title>CGI Test</title></head><body>"
echo "<h1>CGI works!</h1>"
echo "<p>Server: $SERVER_SOFTWARE</p>"
echo "<p>Date: $(date)</p>"
echo "<p>Client IP: $REMOTE_ADDR</p>"
echo "<p>User Agent: $HTTP_USER_AGENT</p>"
echo "</body></html>"
EOF
    chmod +x www/cgi-bin/test.cgi

    # Improved web server content
    cat > www/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Welcome to Manzolo Linux</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; text-align: center; }
        .status { background: #e8f5e8; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .info { background: #e8f4f8; padding: 10px; border-radius: 5px; margin: 10px 0; }
        ul { list-style-type: none; padding: 0; }
        li { padding: 5px 0; }
        a { color: #0066cc; text-decoration: none; }
        a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Manzolo Linux is online!</h1>
        
        <div class="status">
            <strong>✅ Operating System:</strong> Manzolo Linux v2.0<br>
            <strong>✅ Web Server:</strong> BusyBox httpd<br>
            <strong>✅ Date/Time:</strong> <script>document.write(new Date().toLocaleString());</script>
        </div>
        
        <h2>🔧 Tests and Features</h2>
        <ul>
            <li>📄 <a href="/cgi-bin/test.cgi">Test CGI script</a></li>
            <li>🔍 <a href="/test404.html">Test 404 page</a></li>
        </ul>
        
        <div class="info">
            <h3>💡 How to use the web server:</h3>
            <ul>
                <li>Web documents: <code>/www/</code></li>
                <li>CGI scripts: <code>/www/cgi-bin/</code></li>
                <li>Server logs: visible in the console</li>
            </ul>
        </div>
        
        <div class="info">
            <h3>🌐 Useful network commands:</h3>
            <ul>
                <li><code>ip addr show</code> - Show network interfaces</li>
                <li><code>ping 8.8.8.8</code> - Test connectivity</li>
                <li><code>wget http://localhost/</code> - Test the web server</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF

    # Custom error page
    cat > www/404.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>404 - Page Not Found</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; text-align: center; background: #f5f5f5; }
        .error { background: #ffe6e6; padding: 30px; border-radius: 10px; display: inline-block; }
        h1 { color: #cc0000; }
    </style>
</head>
<body>
    <div class="error">
        <h1>404 - Page Not Found</h1>
        <p>The requested resource is not available.</p>
        <p><a href="/">Back to home</a></p>
    </div>
</body>
</html>
EOF

    # udhcpc - Improved script (unchanged from your original code)
    mkdir -p etc/udhcpc
    cat > etc/udhcpc/default.script << 'EOF'
#!/bin/sh
# udhcpc script edited by Tim Riker <Tim@Rikers.org>

[ -z "$1" ] && echo "Error: should be called from udhcpc" && exit 1

RESOLV_CONF="/etc/resolv.conf"
RESOLV_CONF_BAK="/etc/resolv.conf.bak"

[ -n "$broadcast" ] && BROADCAST="broadcast $broadcast"
[ -n "$subnet" ] && NETMASK="netmask $subnet"

case "$1" in
    deconfig)
        echo "Deconfiguring network interface $interface"
        /sbin/ifconfig $interface 0.0.0.0
        while route del default gw 0.0.0.0 dev $interface 2>/dev/null; do
            :
        done
        ;;

    renew|bound)
        echo "Configuring network interface $interface"
        /sbin/ifconfig $interface $ip $BROADCAST $NETMASK

        if [ -n "$router" ] ; then
            echo "Setting default gateway to $router"
            while route del default gw 0.0.0.0 dev $interface 2>/dev/null; do
                :
            done
            route add default gw $router dev $interface
        fi

        echo "Updating DNS configuration"
        [ -f "$RESOLV_CONF" ] && mv "$RESOLV_CONF" "$RESOLV_CONF_BAK"
        
        [ -n "$domain" ] && echo "search $domain" > "$RESOLV_CONF"
        
        for i in $dns ; do
            echo "nameserver $i" >> "$RESOLV_CONF"
        done
        
        echo "Network configured: IP=$ip, Gateway=$router, DNS=$dns"
        ;;
esac

exit 0
EOF
    chmod +x etc/udhcpc/default.script

    # Create init scripts directory
    mkdir -p etc/init.d
    
    # Basic rcS script
    cat > etc/init.d/rcS << 'EOF'
#!/bin/sh
# Basic system initialization
echo "Starting system init..."
mount -a
hostname -F /etc/hostname
echo "System init done."
EOF
    chmod +x etc/init.d/rcS
    
    # Set correct ownership and permissions for www
    chown -R root:root www/ 2>/dev/null || true
    chmod -R 755 www/
    chmod 755 www/cgi-bin/*.cgi
    
    print_success "Filesystem structure created successfully with httpd support"

    # Show filesystem statistics
    print_section "Filesystem Statistics"
    echo "Total size: $(du -sh . | cut -f1)"
    echo "Number of files: $(find . -type f | wc -l)"
    echo "Number of directories: $(find . -type d | wc -l)"
    echo "Web server content: $(du -sh www | cut -f1)"
    
    cd "$CUR_DIR" || return 1
    read -p "Press ENTER to continue..."
}