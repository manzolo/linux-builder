#!/bin/bash

# =============================================================================
# 💿 ISO CREATION & PACKAGING MODULE
# =============================================================================

# This module provides functions to create, configure, and manage bootable ISO images.

# -----------------------------------------------------------------------------
# ISO Creation Functions
# -----------------------------------------------------------------------------

create_standard_iso() {
    print_header "Creating Standard ISO"

    # Check for necessary files
    if [[ ! -f "$BUILD_DIR/bzImage" ]]; then
        print_error "Kernel (bzImage) not found. Please compile the kernel first."
        return 1
    fi

    if [[ ! -f "$BUILD_DIR/initramfs.cpio.gz" ]]; then
        print_error "Initramfs not found. Please create the filesystem and initramfs first."
        return 1
    fi

    # Create the ISO directory structure
    ISO_ROOT="$BUILD_DIR/iso_root"
    mkdir -p "$ISO_ROOT/boot/grub"

    # Copy the kernel and initramfs
    cp "$BUILD_DIR/bzImage" "$ISO_ROOT/boot/vmlinuz"
    cp "$BUILD_DIR/initramfs.cpio.gz" "$ISO_ROOT/boot/initrd.img"

    # Create a simple GRUB configuration file
    cat << EOF > "$ISO_ROOT/boot/grub/grub.cfg"
set timeout=5
set default=0

menuentry "Manzolo Linux" {
    linux /boot/vmlinuz
    initrd /boot/initrd.img
}
EOF

    # Check for `grub-mkrescue`
    if ! command -v grub-mkrescue &> /dev/null; then
        print_error "grub-mkrescue not found. Please install grub-pc-bin and xorriso."
        print_info "Example: sudo apt install grub-pc-bin xorriso"
        return 1
    fi

    local iso_label="${ISO_LABEL:-MANZOLO_LINUX}"
    local iso_file="$BUILD_DIR/${iso_label// /-}.iso"

    print_step "Generating ISO image: $iso_file"
    if grub-mkrescue -o "$iso_file" "$ISO_ROOT"; then
        print_success "ISO image created successfully!"
        print_info "ISO saved to: $iso_file"
    else
        print_error "Failed to create the ISO image."
        return 1
    fi

    read -p "Press ENTER to continue..."

}

# -----------------------------------------------------------------------------
# ISO Configuration Functions
# -----------------------------------------------------------------------------

configure_iso_labels() {
    print_header "Configure ISO Labels"
    echo "Current ISO Label: ${ISO_LABEL:-MANZOLO_LINUX}"
    read -rp "Enter new ISO label (e.g., Manzolo v3.0): " new_label
    
    if [[ -n "$new_label" ]]; then
        ISO_LABEL="$new_label"
        # Save the new label to the configuration file
        sed -i '/^ISO_LABEL=/d' "$MAIN_CONFIG_FILE"
        echo "ISO_LABEL=\"$ISO_LABEL\"" >> "$MAIN_CONFIG_FILE"
        print_success "ISO label updated to: $ISO_LABEL"
    else
        print_warning "No changes made. Using default label."
    fi
    read -p "Press ENTER to continue..."
}
