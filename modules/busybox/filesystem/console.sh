create_tty_test_script() {
    print_step "Creating TTY and job control test script..."
    
    cat > usr/bin/test-tty << 'EOF'
#!/bin/sh
# Test script per TTY e job control

echo "=== TTY and Job Control Test ==="
echo ""

# Test basic TTY info
echo "Current TTY: $(tty 2>/dev/null || echo 'Not a TTY')"
echo "Terminal type: $TERM"
echo ""

# Test TTY properties
if [ -t 0 ]; then
    echo "✓ Standard input is a TTY"
else
    echo "✗ Standard input is NOT a TTY"
fi

if [ -t 1 ]; then
    echo "✓ Standard output is a TTY"
else
    echo "✗ Standard output is NOT a TTY"
fi

# Test stty command
echo ""
echo "TTY settings:"
stty -a 2>/dev/null || echo "stty command failed"

# Test job control
echo ""
echo "Testing job control:"
if set -m 2>/dev/null; then
    echo "✓ Job control is available"
    echo "  You can use Ctrl+Z, bg, fg commands"
else
    echo "✗ Job control is NOT available"
fi

# Show process info
echo ""
echo "Process information:"
echo "PID: $$"
echo "PPID: $(cut -d' ' -f4 /proc/$$/stat 2>/dev/null || echo 'unknown')"

# Test available shells and their features
echo ""
echo "Available shells:"
for shell in /bin/sh /bin/ash /bin/bash; do
    if [ -x "$shell" ]; then
        echo "✓ $shell"
    else
        echo "✗ $shell (not available)"
    fi
done

echo ""
echo "=== Test completed ==="
EOF
    
    chmod +x usr/bin/test-tty
    print_success "TTY test script created"
}