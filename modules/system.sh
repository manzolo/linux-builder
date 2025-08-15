#!/bin/bash

# =============================================================================
# 🛠️ SYSTEM MANAGEMENT MODULE
# =============================================================================

# Check prerequisites with interactive installation
check_prerequisites_interactive() {
    print_header "System Prerequisites Check"
    
    local missing_packages=()
    local packages=(
        "build-essential:Essential compilation tools"
        "flex:Lexical analyzer generator"
        "bison:Parser generator"
        "libncurses5-dev:Terminal handling library" # Keep this for legacy systems
        "libssl-dev:SSL/TLS library"
        "bc:Basic calculator for kernel build"
        "libelf-dev:ELF library for kernel modules"
        "grub-pc-bin:GRUB bootloader tools"
        "xorriso:ISO image creation tool"
        "mtools:MS-DOS filesystem tools"
        "wget:File downloader"
        "curl:HTTP client library"
        "qemu-system-x86:x86 system emulator"
        "gzip:Compression utility"
        "cpio:Archive utility"
        "git:Version control system"
    )
    
    print_step "Checking installed packages..."
    
    for package_info in "${packages[@]}"; do
        local package=$(echo "$package_info" | cut -d: -f1)
        local description=$(echo "$package_info" | cut -d: -f2)
        
        # Check for the package using a more robust method
        if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "ok installed"; then
            echo -e "✅ $package - $description"
        # Special case for libncurses5-dev which is now libncurses-dev
        elif [[ "$package" == "libncurses5-dev" ]]; then
            if dpkg-query -W -f='${Status}' "libncurses-dev" 2>/dev/null | grep -q "ok installed"; then
                echo -e "✅ $package - $description (using libncurses-dev)"
            else
                echo -e "❌ $package - $description"
                missing_packages+=("$package")
            fi
        else
            echo -e "❌ $package - $description"
            missing_packages+=("$package")
        fi
    done
    
    echo
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        print_success "All prerequisites are installed!"
        
        # Additional checks
        print_section "System Information"
        echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || uname -s)"
        echo "Kernel: $(uname -r)"
        echo "Architecture: $(uname -m)"
        echo "CPU Cores: $(nproc)"
        echo "Available Memory: $(free -h | awk '/^Mem:/ {print $7}')"
        echo "Available Disk Space: $(df -h . | awk 'NR==2 {print $4}')"
        
        print_section "Tool Versions"
        echo "GCC: $(gcc --version | head -1)"
        echo "Make: $(make --version | head -1)"
        echo "QEMU: $(qemu-system-x86_64 --version | head -1)"
        
    else
        print_warning "Missing packages detected!"
        echo
        print_info "The following packages need to be installed:"
        for package in "${missing_packages[@]}"; do
            local description=$(grep "^$package:" <<< "${packages[@]}" | cut -d: -f2)
            echo "  • $package - $description"
        done
        echo
        
        if ask_yes_no "Install missing packages automatically?" "y"; then
            install_prerequisites "${missing_packages[@]}"
        else
            print_info "Manual installation command:"
            echo "sudo apt update && sudo apt install -y ${missing_packages[*]}"
            echo
            print_warning "Cannot continue without prerequisites."
            return 1
        fi
    fi
    
    read -p "Press ENTER to continue..."
}

# Install prerequisites with progress
install_prerequisites() {
    local packages=("$@")
    
    print_step "Updating package list..."
    if sudo apt update; then
        print_success "Package list updated"
    else
        print_error "Failed to update package list. Please run 'sudo apt update' manually to check for errors."
        return 1
    fi
    
    print_step "Installing packages..."
    print_info "This may take several minutes depending on your internet connection"

    if sudo apt install -y "${packages[@]}"; then
        print_success "All packages installed successfully!"
    else
        print_error "Package installation failed. Check the output above for specific errors."
        return 1
    fi
}

# Clean build directory with options
clean_build_directory() {
    print_header "Clean Build Directory"
    
    if [[ ! -d "$BUILD_DIR" ]]; then
        print_info "Build directory doesn't exist"
        return 0
    fi
    
    # Show current contents
    print_section "Current Build Directory Contents"
    du -sh "$BUILD_DIR"/* 2>/dev/null | head -10 || echo "Directory is empty"
    
    echo
    cat << 'EOF'
    🧹 Cleanup Options:
    ┌─────────────────────────────────────────────────────────────┐
    │  1. 🗑️  Clean build outputs only                           │
    │  2. 🔄 Clean build outputs and logs                        │
    │  3. 💾 Clean everything except downloads                   │
    │  4. 💣 Clean everything (including downloads)              │
    │  5. 📦 Clean only specific components                      │
    │  6. ⬅️  Return                                              │
    └─────────────────────────────────────────────────────────────┘
    
EOF
    
    read -rp "$(echo -e "${CYAN}Select cleanup option [1-6]: ${NC}")" choice
    
    case $choice in
        1)
            clean_build_outputs
            ;;
        2)
            clean_build_outputs
            clean_logs
            ;;
        3)
            clean_everything_except_downloads
            ;;
        4)
            clean_everything
            ;;
        5)
            clean_specific_components
            ;;
        6)
            return 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

# Clean build outputs
clean_build_outputs() {
    print_step "Cleaning build outputs..."
    
    local cleaned=0
    local patterns=("*.o" "*.ko" ".*.cmd" "vmlinux" "bzImage" "initramfs.cpio.gz" "*.iso")
    
    for pattern in "${patterns[@]}"; do
        while IFS= read -r -d '' file; do
            rm -f "$file"
            ((cleaned++))
        done < <(find "$BUILD_DIR" -name "$pattern" -type f -print0 2>/dev/null)
    done
    
    # Clean build directories
    rm -rf "$BUILD_DIR"/kernel-build/* 2>/dev/null
    rm -rf "$BUILD_DIR"/busybox-build/* 2>/dev/null
    
    print_success "Cleaned $cleaned build output files"
}

# Clean logs
clean_logs() {
    print_step "Cleaning log files..."
    
    local log_files=(
        "$LOG_FILE"
        "$BUILD_DIR"/*.log
        "$BUILD_DIR"/performance-*.log
    )
    
    local cleaned=0
    for log_pattern in "${log_files[@]}"; do
        for log_file in $log_pattern; do
            if [[ -f "$log_file" ]]; then
                rm -f "$log_file"
                ((cleaned++))
            fi
        done
    done
    
    print_success "Cleaned $cleaned log files"
}

# Clean everything except downloads
clean_everything_except_downloads() {
    if ask_yes_no "This will remove all build files but keep downloads. Continue?"; then
        print_step "Cleaning build directory (keeping downloads)..."
        
        find "$BUILD_DIR" -mindepth 1 -maxdepth 1 ! -name "downloads" -exec rm -rf {} +
        
        print_success "Build directory cleaned (downloads preserved)"
    fi
}

# Clean everything
clean_everything() {
    if ask_yes_no "This will remove ALL files in the build directory. Continue?"; then
        print_step "Cleaning entire build directory..."
        
        rm -rf "$BUILD_DIR"/*
        
        print_success "Build directory completely cleaned"
    fi
}

# Clean specific components
clean_specific_components() {
    local components=()
    
    # Check what components exist
    [[ -d "$BUILD_DIR/kernel-source" ]] && components+=("Kernel source")
    [[ -d "$BUILD_DIR/kernel-build" ]] && components+=("Kernel build")
    [[ -d "$BUILD_DIR/busybox-source" ]] && components+=("BusyBox source")
    [[ -d "$BUILD_DIR/busybox-build" ]] && components+=("BusyBox build")
    [[ -d "$BUILD_DIR/rootfs" ]] && components+=("Root filesystem")
    [[ -d "$BUILD_DIR/downloads" ]] && components+=("Downloads")
    [[ -f "$BUILD_DIR"/*.iso ]] && components+=("ISO files")
    [[ -f "$LOG_FILE" ]] && components+=("Log files")
    
    if [[ ${#components[@]} -eq 0 ]]; then
        print_info "No components found to clean"
        return 0
    fi
    
    print_info "Available components to clean:"
    for i in "${!components[@]}"; do
        echo "  $((i+1)). ${components[i]}"
    done
    
    echo
    read -rp "Enter component numbers to clean (space-separated): " selection
    
    for num in $selection; do
        if [[ $num =~ ^[0-9]+$ ]] && ((num >= 1 && num <= ${#components[@]})); then
            local component="${components[$((num-1))]}"
            clean_component "$component"
        fi
    done
}

# Clean specific component
clean_component() {
    local component="$1"
    
    case "$component" in
        "Kernel source")
            rm -rf "$BUILD_DIR/kernel-source"
            print_success "Kernel source cleaned"
            ;;
        "Kernel build")
            rm -rf "$BUILD_DIR/kernel-build"
            rm -f "$BUILD_DIR/bzImage"
            print_success "Kernel build cleaned"
            ;;
        "BusyBox source")
            rm -rf "$BUILD_DIR/busybox-source"
            print_success "BusyBox source cleaned"
            ;;
        "BusyBox build")
            rm -rf "$BUILD_DIR/busybox-build"
            print_success "BusyBox build cleaned"
            ;;
        "Root filesystem")
            rm -rf "$BUILD_DIR/rootfs"
            rm -f "$BUILD_DIR/initramfs.cpio.gz"
            print_success "Root filesystem cleaned"
            ;;
        "Downloads")
            rm -rf "$BUILD_DIR/downloads"
            print_success "Downloads cleaned"
            ;;
        "ISO files")
            rm -f "$BUILD_DIR"/*.iso
            print_success "ISO files cleaned"
            ;;
        "Log files")
            rm -f "$LOG_FILE" "$BUILD_DIR"/*.log
            print_success "Log files cleaned"
            ;;
    esac
}

# Clean all build artifacts, logs, and downloads
clean_all() {
    print_header "Comprehensive Cleanup"
    
    if [[ ! -d "$BUILD_DIR" ]]; then
        print_info "The build directory does not exist. Nothing to clean."
        return 0
    fi
    
    print_warning "⚠️  ATTENZIONE! This action will remove ALL files in the build directory, including sources, build artifacts, logs, and downloads."
    print_warning "This will reset the project to its initial state."
    
    if ask_yes_no "Do you want to proceed with a complete cleanup?"; then
        print_step "Starting comprehensive cleanup of the build directory..."
        
        # Use a robust and safe method to remove everything inside BUILD_DIR
        # This prevents accidental deletion of the project's root directory
        if rm -rf "$BUILD_DIR"/*; then
            print_success "✅ The build directory has been completely cleaned."
            
            # Recreate the build directory to ensure it exists for future operations
            mkdir -p "$BUILD_DIR"
            print_info "Recreated an empty build directory."
        else
            print_error "❌ Failed to perform the comprehensive cleanup."
            return 1
        fi
    else
        print_info "Cleanup operation aborted."
        return 0
    fi
    
    read -p "Press ENTER to continue..."
}

# Clean downloads with selective options
clean_downloads() {
    local downloads_dir="$BUILD_DIR/downloads"
    
    if [[ ! -d "$downloads_dir" ]]; then
        print_info "No downloads directory found"
        return 0
    fi
    
    print_header "Clean Downloads"
    
    print_section "Current Downloads"
    if [[ -n "$(ls -A "$downloads_dir" 2>/dev/null)" ]]; then
        du -sh "$downloads_dir"/* | head -10
        echo "Total: $(du -sh "$downloads_dir" | cut -f1)"
    else
        echo "Downloads directory is empty"
        return 0
    fi
    
    echo
    cat << 'EOF'
    🗑️  Download Cleanup Options:
    ┌─────────────────────────────────────────────────────────────┐
    │  1. 🐧 Clean kernel archives only                          │
    │  2. 📦 Clean BusyBox archives only                         │
    │  3. 🔄 Clean all archives                                  │
    │  4. 📊 Show download details                               │
    │  5. ⬅️  Return                                              │
    └─────────────────────────────────────────────────────────────┘
    
EOF
    
    read -rp "$(echo -e "${CYAN}Select option [1-5]: ${NC}")" choice
    
    case $choice in
        1)
            rm -f "$downloads_dir"/linux-*.tar.*
            print_success "Kernel archives cleaned"
            ;;
        2)
            rm -f "$downloads_dir"/busybox-*.tar.*
            print_success "BusyBox archives cleaned"
            ;;
        3)
            if ask_yes_no "Remove all downloaded archives?"; then
                rm -rf "$downloads_dir"/*
                print_success "All downloads cleaned"
            fi
            ;;
        4)
            show_download_details
            ;;
        5)
            return 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
    
    read -p "Press ENTER to continue..."
}

# Show download details
show_download_details() {
    local downloads_dir="$BUILD_DIR/downloads"
    
    print_section "Download Details"
    
    if [[ -d "$downloads_dir" ]]; then
        echo "Location: $downloads_dir"
        echo "Total size: $(du -sh "$downloads_dir" | cut -f1)"
        echo
        
        if [[ -n "$(ls -A "$downloads_dir" 2>/dev/null)" ]]; then
            echo "Files:"
            ls -lh "$downloads_dir" | tail -n +2 | while read line; do
                echo "  $line"
            done
        else
            echo "No files in downloads directory"
        fi
    else
        echo "Downloads directory doesn't exist"
    fi
}

# Show disk usage analysis
show_disk_usage() {
    print_header "Disk Usage Analysis"
    
    if [[ ! -d "$BUILD_DIR" ]]; then
        print_info "Build directory doesn't exist"
        return 0
    fi
    
    print_section "Overall Usage"
    echo "Build directory: $(du -sh "$BUILD_DIR" | cut -f1)"
    echo "Available space: $(df -h "$BUILD_DIR" | awk 'NR==2 {print $4}')"
    echo "Used space: $(df -h "$BUILD_DIR" | awk 'NR==2 {print $3}')"
    echo "Total space: $(df -h "$BUILD_DIR" | awk 'NR==2 {print $2}')"
    
    print_section "Component Breakdown"
    for dir in "$BUILD_DIR"/*/; do
        if [[ -d "$dir" ]]; then
            local size=$(du -sh "$dir" | cut -f1)
            local name=$(basename "$dir")
            echo "  $name: $size"
        fi
    done
    
    print_section "Largest Files"
    find "$BUILD_DIR" -type f -exec du -h {} + 2>/dev/null | sort -hr | head -10
    
    print_section "File Type Distribution"
    find "$BUILD_DIR" -type f -name "*.*" | sed 's/.*\.//' | sort | uniq -c | sort -nr | head -10
    
    read -p "Press ENTER to continue..."
}

# Show build log
show_build_log() {
    print_header "Build Log Viewer"
    
    if [[ ! -f "$LOG_FILE" ]]; then
        print_warning "No build log found at $LOG_FILE"
        return 0
    fi
    
    local log_size=$(du -h "$LOG_FILE" | cut -f1)
    local log_lines=$(wc -l < "$LOG_FILE")
    
    print_info "Log file: $LOG_FILE"
    print_info "Size: $log_size"
    print_info "Lines: $log_lines"
    echo
    
    cat << 'EOF'
    📋 Log Viewing Options:
    ┌─────────────────────────────────────────────────────────────┐
    │  1. 📄 View last 50 lines                                  │
    │  2. 📜 View last 100 lines                                 │
    │  3. 🔍 Search for errors                                   │
    │  4. 🔎 Search for warnings                                 │
    │  5. 📝 View full log (pager)                               │
    │  6. 💾 Export log section                                  │
    │  7. ⬅️  Return                                              │
    └─────────────────────────────────────────────────────────────┘
    
EOF
    
    read -rp "$(echo -e "${CYAN}Select option [1-7]: ${NC}")" choice
    
    case $choice in
        1)
            print_section "Last 50 Lines"
            tail -50 "$LOG_FILE"
            ;;
        2)
            print_section "Last 100 Lines"
            tail -100 "$LOG_FILE"
            ;;
        3)
            print_section "Error Messages"
            grep -i "error\|failed\|fatal" "$LOG_FILE" | tail -20 || echo "No errors found"
            ;;
        4)
            print_section "Warning Messages"
            grep -i "warning\|warn" "$LOG_FILE" | tail -20 || echo "No warnings found"
            ;;
        5)
            if command -v less &> /dev/null; then
                less "$LOG_FILE"
            elif command -v more &> /dev/null; then
                more "$LOG_FILE"
            else
                cat "$LOG_FILE"
            fi
            ;;
        6)
            export_log_section
            ;;
        7)
            return 0
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
    
    read -p "Press ENTER to continue..."
}

# Export log section
export_log_section() {
    print_step "Export log section..."
    read -rp "Enter search pattern (or press ENTER for full log): " pattern
    
    local export_file="$BUILD_DIR/exported-log-$(date +%Y%m%d-%H%M%S).txt"
    
    if [[ -n "$pattern" ]]; then
        grep -i "$pattern" "$LOG_FILE" > "$export_file"
        print_success "Log section exported to $export_file ($(wc -l < "$export_file") lines)"
    else
        cp "$LOG_FILE" "$export_file"
        print_success "Full log exported to $export_file"
    fi
}

# Backup build
backup_build() {
    print_header "Backup Build"
    
    if [[ ! -d "$BUILD_DIR" ]]; then
        print_error "No build directory to backup"
        return 1
    fi
    
    local backup_dir="$CUR_DIR/backups"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="manzolo-backup-$timestamp"
    
    mkdir -p "$backup_dir"
    
    print_section "Backup Options"
    cat << 'EOF'
    
    💾 Backup Types:
    ┌─────────────────────────────────────────────────────────────┐
    │  1. 🎯 Quick backup (configs and outputs only)             │
    │  2. 📦 Standard backup (exclude source code)               │
    │  3. 💾 Full backup (everything)                            │
    │  4. 🔧 Custom backup (select components)                   │
    │  5. ⬅️  Return                                              │
    └─────────────────────────────────────────────────────────────┘
    
EOF
    
    read -rp "$(echo -e "${CYAN}Select backup type [1-5]: ${NC}")" choice
    
    case $choice in
        1) create_quick_backup "$backup_dir/$backup_name-quick.tar.gz" ;;
        2) create_standard_backup "$backup_dir/$backup_name-standard.tar.gz" ;;
        3) create_full_backup "$backup_dir/$backup_name-full.tar.gz" ;;
        4) create_custom_backup "$backup_dir/$backup_name-custom.tar.gz" ;;
        5) return 0 ;;
        *) print_error "Invalid option" ;;
    esac
}

# Create quick backup
create_quick_backup() {
    local backup_file="$1"
    
    print_step "Creating quick backup..."
    
    # Include only essential files
    tar -czf "$backup_file" \
        -C "$BUILD_DIR" \
        --exclude="*-source" \
        --exclude="downloads" \
        . 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        local size=$(du -h "$backup_file" | cut -f1)
        print_success "Quick backup created: $backup_file ($size)"
    else
        print_error "Failed to create backup"
    fi
}

# Create standard backup
create_standard_backup() {
    local backup_file="$1"
    
    print_step "Creating standard backup..."
    
    # Exclude source directories and downloads
    tar -czf "$backup_file" \
        -C "$BUILD_DIR" \
        --exclude="kernel-source" \
        --exclude="busybox-source" \
        --exclude="downloads" \
        . 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        local size=$(du -h "$backup_file" | cut -f1)
        print_success "Standard backup created: $backup_file ($size)"
    else
        print_error "Failed to create backup"
    fi
}

# Create full backup
create_full_backup() {
    local backup_file="$1"
    
    print_step "Creating full backup..."
    print_warning "This may take several minutes for large builds"
    
    tar -czf "$backup_file" -C "$BUILD_DIR" . 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        local size=$(du -h "$backup_file" | cut -f1)
        print_success "Full backup created: $backup_file ($size)"
    else
        print_error "Failed to create backup"
    fi
}

# Create custom backup
create_custom_backup() {
    local backup_file="$1"
    
    print_step "Custom backup configuration..."
    
    local components=()
    local include_paths=()
    
    # Available components
    [[ -d "$BUILD_DIR/kernel-source" ]] && components+=("Kernel source")
    [[ -d "$BUILD_DIR/kernel-build" ]] && components+=("Kernel build")
    [[ -d "$BUILD_DIR/busybox-source" ]] && components+=("BusyBox source")
    [[ -d "$BUILD_DIR/busybox-build" ]] && components+=("BusyBox build")
    [[ -d "$BUILD_DIR/rootfs" ]] && components+=("Root filesystem")
    [[ -d "$BUILD_DIR/downloads" ]] && components+=("Downloads")
    [[ -f "$BUILD_DIR/bzImage" ]] && components+=("Kernel image")
    [[ -f "$BUILD_DIR/initramfs.cpio.gz" ]] && components+=("Initramfs")
    [[ -f "$BUILD_DIR"/*.iso ]] && components+=("ISO files")
    [[ -d "$CONFIG_DIR" ]] && components+=("Configuration files")
    
    print_info "Select components to include in backup:"
    for i in "${!components[@]}"; do
        echo "  $((i+1)). ${components[i]}"
    done
    
    echo
    read -rp "Enter component numbers (space-separated): " selection
    
    # Build include list
    for num in $selection; do
        if [[ $num =~ ^[0-9]+$ ]] && ((num >= 1 && num <= ${#components[@]})); then
            case "${components[$((num-1))]}" in
                "Kernel source") include_paths+=("kernel-source") ;;
                "Kernel build") include_paths+=("kernel-build") ;;
                "BusyBox source") include_paths+=("busybox-source") ;;
                "BusyBox build") include_paths+=("busybox-build") ;;
                "Root filesystem") include_paths+=("rootfs") ;;
                "Downloads") include_paths+=("downloads") ;;
                "Kernel image") include_paths+=("bzImage") ;;
                "Initramfs") include_paths+=("initramfs.cpio.gz") ;;
                "ISO files") include_paths+=("*.iso") ;;
                "Configuration files") include_paths+=("../config") ;;
            esac
        fi
    done
    
    if [[ ${#include_paths[@]} -eq 0 ]]; then
        print_warning "No components selected"
        return 1
    fi
    
    print_step "Creating custom backup..."
    
    # Create backup with selected components
    tar -czf "$backup_file" -C "$BUILD_DIR" "${include_paths[@]}" 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        local size=$(du -h "$backup_file" | cut -f1)
        print_success "Custom backup created: $backup_file ($size)"
    else
        print_error "Failed to create backup"
    fi
}

# Create archive for distribution
create_archive() {
    print_header "Create Distribution Archive"
    
    if [[ ! -f "$BUILD_DIR/bzImage" ]] || [[ ! -f "$BUILD_DIR/initramfs.cpio.gz" ]]; then
        print_error "Complete build required. Please compile kernel and create filesystem first."
        return 1
    fi
    
    local archive_dir="$BUILD_DIR/manzolo-linux-distribution"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local archive_name="manzolo-linux-$timestamp"
    
    print_step "Preparing distribution archive..."
    
    # Create distribution directory
    rm -rf "$archive_dir"
    mkdir -p "$archive_dir"/{boot,docs,tools,scripts}
    
    # Copy essential files
    cp "$BUILD_DIR/bzImage" "$archive_dir/boot/"
    cp "$BUILD_DIR/initramfs.cpio.gz" "$archive_dir/boot/"
    
    # Copy ISO if available
    if [[ -f "$BUILD_DIR"/*.iso ]]; then
        cp "$BUILD_DIR"/*.iso "$archive_dir/"
    fi
    
    # Copy configuration
    if [[ -d "$CONFIG_DIR" ]]; then
        cp -r "$CONFIG_DIR" "$archive_dir/"
    fi
    
    # Create documentation
    cat > "$archive_dir/README.md" << EOF
# Manzolo Linux Distribution

Custom Linux distribution created with Manzolo Linux Builder.

## Build Information
- Build Date: $(date)
- Kernel Version: $KERNEL_VERSION
- BusyBox Version: $BUSYBOX_VERSION
- Architecture: $KERNEL_ARCH

## Files Included
- boot/bzImage - Linux kernel
- boot/initramfs.cpio.gz - Root filesystem
- config/ - Build configuration files
$(if [[ -f "$BUILD_DIR"/*.iso ]]; then echo "- *.iso - Bootable ISO image"; fi)

## Usage
1. Boot from ISO image in virtual machine or real hardware
2. Use kernel and initramfs for custom boot configurations
3. Modify configuration files for custom builds

## System Requirements
- x86_64 compatible processor
- Minimum 512MB RAM
- VGA compatible display

For more information, visit: https://github.com/manzolo/linux-builder
EOF
    
    # Create quick start script
    cat > "$archive_dir/scripts/qemu-test.sh" << 'EOF'
#!/bin/bash
# Quick QEMU test script for Manzolo Linux

KERNEL="boot/bzImage"
INITRAMFS="boot/initramfs.cpio.gz"

if [[ ! -f "$KERNEL" ]] || [[ ! -f "$INITRAMFS" ]]; then
    echo "Error: Required files not found"
    echo "Make sure you're running this from the distribution directory"
    exit 1
fi

echo "Starting Manzolo Linux in QEMU..."
qemu-system-x86_64 \
    -kernel "$KERNEL" \
    -initrd "$INITRAMFS" \
    -m 512M \
    -enable-kvm \
    -display gtk \
    -name "Manzolo Linux"
EOF
    chmod +x "$archive_dir/scripts/qemu-test.sh"
    
    # Create checksums
    print_step "Generating checksums..."
    cd "$archive_dir" || return 1
    find . -type f -exec sha256sum {} \; > checksums.sha256
    cd "$BUILD_DIR" || return 1
    
    # Create final archive
    print_step "Creating final archive..."
    
    local archive_formats=("tar.gz" "tar.xz" "zip")
    echo "Select archive format:"
    for i in "${!archive_formats[@]}"; do
        echo "  $((i+1)). ${archive_formats[i]}"
    done
    
    read -rp "$(echo -e "${CYAN}Select format [1-${#archive_formats[@]}]: ${NC}")" format_choice
    
    if [[ $format_choice =~ ^[0-9]+$ ]] && ((format_choice >= 1 && format_choice <= ${#archive_formats[@]})); then
        local format="${archive_formats[$((format_choice-1))]}"
        local archive_file="$CUR_DIR/$archive_name.$format"
        
        case $format in
            "tar.gz")
                tar -czf "$archive_file" -C "$BUILD_DIR" "$(basename "$archive_dir")"
                ;;
            "tar.xz")
                tar -cJf "$archive_file" -C "$BUILD_DIR" "$(basename "$archive_dir")"
                ;;
            "zip")
                (cd "$BUILD_DIR" && zip -r "$archive_file" "$(basename "$archive_dir")")
                ;;
        esac
        
        if [[ $? -eq 0 ]]; then
            local size=$(du -h "$archive_file" | cut -f1)
            print_success "Distribution archive created: $archive_file ($size)"
            
            print_section "Archive Contents"
            echo "📁 Directory structure:"
            tree "$archive_dir" 2>/dev/null || find "$archive_dir" -type d | sed 's/^/  /'
            
        else
            print_error "Failed to create archive"
        fi
    else
        print_error "Invalid format selection"
    fi
    
    # Cleanup
    rm -rf "$archive_dir"
    
    read -p "Press ENTER to continue..."
}