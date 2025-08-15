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