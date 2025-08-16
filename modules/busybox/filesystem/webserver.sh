create_web_server_config() {
    print_step "Setting up web server..."
    
    # HTTP server configuration
    cat > etc/httpd.conf << 'EOF'
# BusyBox httpd configuration
.html:text/html
.htm:text/html
.css:text/css
.js:application/javascript
.png:image/png
.jpg:image/jpeg
.gif:image/gif
.ico:image/x-icon
EOF

    # Create web content
    create_web_content
    create_cgi_scripts
}

create_web_content() {
    # Main index page
    cat > www/index.html << EOF
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
        code { background: #f0f0f0; padding: 2px 5px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Manzolo Linux v$FILESYSTEM_VERSION</h1>
        
        <div class="status">
            <strong>✅ Operating System:</strong> Manzolo Linux v$FILESYSTEM_VERSION<br>
            <strong>✅ Web Server:</strong> BusyBox httpd<br>
            <strong>✅ Date/Time:</strong> <script>document.write(new Date().toLocaleString());</script>
        </div>
        
        <h2>🔧 Tests and Features</h2>
        <ul>
            <li>📄 <a href="/cgi-bin/test.cgi">Test CGI script</a></li>
            <li>📄 <a href="/cgi-bin/info.cgi">System information</a></li>
            <li>🔍 <a href="/test404.html">Test 404 page</a></li>
        </ul>
        
        <div class="info">
            <h3>💡 Package Manager Commands:</h3>
            <ul>
                <li><code>manzolopkg list</code> - List installed packages</li>
                <li><code>manzolopkg update</code> - Update package index</li>
                <li><code>manzolopkg install manzolo-hello-world</code> - Install sample package</li>
            </ul>
        </div>
        
        <div class="info">
            <h3>🌐 Network Commands:</h3>
            <ul>
                <li><code>ip addr show</code> - Show network interfaces</li>
                <li><code>ping 8.8.8.8</code> - Test connectivity</li>
                <li><code>httpd -p 8080 -h /www</code> - Start web server</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF

    # 404 error page
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
}

create_cgi_scripts() {
    # Basic CGI test script
    cat > www/cgi-bin/test.cgi << 'EOF'
#!/bin/sh
echo "Content-Type: text/html"
echo ""
echo "<!DOCTYPE html><html><head><title>CGI Test</title></head><body>"
echo "<h1>CGI works!</h1>"
echo "<p><strong>Server:</strong> $SERVER_SOFTWARE</p>"
echo "<p><strong>Date:</strong> $(date)</p>"
echo "<p><strong>Client IP:</strong> $REMOTE_ADDR</p>"
echo "<p><strong>User Agent:</strong> $HTTP_USER_AGENT</p>"
echo "</body></html>"
EOF

    # System info CGI script
    cat > www/cgi-bin/info.cgi << 'EOF'
#!/bin/sh
echo "Content-Type: text/html"
echo ""
echo "<!DOCTYPE html><html><head><title>System Info</title></head><body>"
echo "<h1>System Information</h1>"
echo "<h2>Uptime</h2><pre>$(uptime)</pre>"
echo "<h2>Memory</h2><pre>$(free)</pre>"
echo "<h2>Disk Usage</h2><pre>$(df -h)</pre>"
echo "<h2>Network Interfaces</h2><pre>$(ip addr show 2>/dev/null || ifconfig)</pre>"
echo "</body></html>"
EOF

    # Make CGI scripts executable
    chmod +x www/cgi-bin/*.cgi
}