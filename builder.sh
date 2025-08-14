#!/bin/bash

# =============================================================================
# 🐧 MANZOLO LINUX BUILDER - Educational Script to Create a Linux Distribution
# =============================================================================
# This script guides you in creating a personalized Linux distribution
# starting from the Linux kernel and BusyBox, with detailed explanations for each step.
#
# Based on: https://medium.com/@ThyCrow/compiling-the-linux-kernel-and-creating-a-bootable-iso-from-it-6afb8d23ba22
# =============================================================================

# 🎨 Colors for a more attractive output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 🛠️ Script directories and files
CUR_DIR="$PWD"
BUILD_DIR="$CUR_DIR/build"
LOG_FILE="$BUILD_DIR/build.log"
CONFIG_FILE="$CUR_DIR/config.sh"

# Load or create configuration file
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    print_warning "Configuration file not found. Creating a new one with default values."
    cat << EOF > "$CONFIG_FILE"
# Manzolo Linux Builder - Configuration file
KERNEL_VERSION="6.6.12"
BUSYBOX_VERSION="1.36.1"
EOF
    source "$CONFIG_FILE"
fi

# 🎯 Utility functions for colored output
print_header() {
    echo -e "\n${BOLD}${CYAN}=== $1 ===${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_step() {
    echo -e "${PURPLE}🔄 $1${NC}"
}

# ⚙️ Function to configure versions
configure_versions() {
    print_header "Configure Kernel and BusyBox Versions"

    while true; do
        clear
        cat << EOF
        ╔═══════════════════════════════════════════════════════════════╗
        ║                      VERSION CONFIGURATION                    ║
        ╚═══════════════════════════════════════════════════════════════╝
EOF
        echo -e "        Current Kernel Version:  ${YELLOW}${KERNEL_VERSION}${NC}"
        echo -e "        Current BusyBox Version: ${YELLOW}${BUSYBOX_VERSION}${NC}"

        cat << EOF

        Choose an option to change a version or return to the main menu.

        1. 🐧 Change Kernel Version
        2. 📦 Change BusyBox Version
        3. ⬅️  Return to Main Menu
EOF
        echo
        read -rp "$(echo -e "${CYAN}Select an option (1-3): ${NC}")" choice

        case $choice in
            1)
                read -rp "$(echo -e "${BLUE}Enter new kernel version (e.g., 6.6.12): ${NC}")" new_version
                if [[ -n "$new_version" ]]; then
                    sed -i "s/^KERNEL_VERSION=.*/KERNEL_VERSION=\"$new_version\"/" "$CONFIG_FILE"
                    source "$CONFIG_FILE" # Reload configuration
                    print_success "Kernel version updated to $KERNEL_VERSION!"
                fi
                ;;
            2)
                read -rp "$(echo -e "${BLUE}Enter new BusyBox version (e.g., 1.36.1): ${NC}")" new_version
                if [[ -n "$new_version" ]]; then
                    sed -i "s/^BUSYBOX_VERSION=.*/BUSYBOX_VERSION=\"$new_version\"/" "$CONFIG_FILE"
                    source "$CONFIG_FILE" # Reload configuration
                    print_success "BusyBox version updated to $BUSYBOX_VERSION!"
                fi
                ;;
            3)
                break
                ;;
            *)
                print_error "Invalid option. Please choose a number from 1 to 3."
                ;;
        esac
        read -p "Press ENTER to continue..."
    done
}

# 📋 Function to show project information
show_info() {
    clear
    cat << 'EOF'
    ┌─────────────────────────────────────────────────────────────┐
    │               🐧 MANZOLO LINUX BUILDER                      │
    │                                                             │
    │        Create your own personalized Linux distribution!     │
    │                                                             │
    │ 📚 What you will learn:                                     │
    │ • How to compile the Linux kernel                           │
    │ • Create a minimal filesystem with BusyBox                  │
    │ • Generate an initramfs                                     │
    │ • Create a bootable ISO image                               │
    │ • Test the system with QEMU                                 │
    │                                                             │
    │ 🎯 Result: A functional Linux distribution!                 │
    └─────────────────────────────────────────────────────────────┘
EOF
    echo
    read -p "Press ENTER to continue..."
}

# 🧹 Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_packages=()
    local packages=("build-essential" "flex" "libncurses5-dev" "bc" "libelf-dev"
                    "bison" "libssl-dev" "grub-pc-bin" "xorriso" "mtools" "wget" "qemu-system-x86")
    
    for package in "${packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -gt 0 ]; then
        print_warning "Missing packages detected!"
        echo "Automatically installing the following packages:"
        printf '  • %s\n' "${missing_packages[@]}"
        echo
        read -p "Do you want to proceed with the installation? (y/N): " install_choice
        
        if [[ $install_choice =~ ^[Yy]$ ]]; then
            print_step "Installing packages..."
            sudo apt update && sudo apt install -y "${missing_packages[@]}"
            print_success "Packages installed correctly!"
        else
            print_error "Cannot continue without the prerequisites."
            exit 1
        fi
    else
        print_success "All prerequisites are met!"
    fi
}

# 🗑️ Function to clean the build directory
clean_build_dir() {
    print_step "Cleaning build directory..."
    mkdir -p "$BUILD_DIR"
    rm -rf "$BUILD_DIR"/*
    mkdir -p "$BUILD_DIR"
    print_success "Directory cleaned!"
}

# 🔧 Function to prepare the Linux kernel
prepare_kernel() {
    print_header "Preparing Linux Kernel v$KERNEL_VERSION"

    local KERNEL_SOURCE="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-$KERNEL_VERSION.tar.xz"
    local KERNEL_DIR="linux-$KERNEL_VERSION"
    
    print_info "📖 WHAT WE ARE DOING:"
    print_info "The Linux kernel is the heart of the operating system. It manages hardware,"
    print_info "processes, memory, and provides interfaces for applications."
    echo
    
    clean_build_dir
    
    # Cleaning existing kernel directory
    rm -rf "$KERNEL_DIR"
    
    # Downloading the kernel
    print_step "Downloading Linux kernel v$KERNEL_VERSION..."
    if wget -q --show-progress "$KERNEL_SOURCE" -P "$CUR_DIR"; then
        print_success "Download completed!"
    else
        print_error "Error downloading the kernel! Check the version number."
        return 1
    fi
    
    # Extraction
    print_step "Extracting kernel archive..."
    tar xf "$CUR_DIR/linux-$KERNEL_VERSION.tar.xz" -C "$CUR_DIR"
    rm "$CUR_DIR/linux-$KERNEL_VERSION.tar.xz"
    
    cd "$KERNEL_DIR" || exit
    
    # Configuration
    print_step "Configuring kernel (defconfig)..."
    if ! make defconfig &> "$LOG_FILE"; then
        print_error "Error during kernel defconfig! Check $LOG_FILE"
        return 1
    fi
    
    print_warning "IMPORTANT: Manual kernel configuration"
    print_info "To avoid black screen issues after GRUB:"
    print_info "Go to: Device Drivers → Graphics Support → Console display driver support"
    print_info "       → Framebuffer Console Support (enable it)"
    echo
    read -p "Press ENTER to open the kernel configuration..."
    
    make menuconfig
    
    # Compilation
    print_step "Compiling the kernel... (this may take some time)"
    print_info "Compilation uses all available cores: $(nproc) cores"
    
    if ! make -j"$(nproc)" &> "$LOG_FILE"; then
        print_error "Error compiling the kernel! Check $LOG_FILE for details."
        return 1
    fi
    
    print_success "Kernel compiled successfully!"
    
    # Copying the kernel
    cp "arch/x86/boot/bzImage" "$BUILD_DIR/"
    print_success "Kernel copied to $BUILD_DIR/bzImage"
    
    # Information on the compiled kernel
    local kernel_size=$(du -h "$BUILD_DIR/bzImage" | cut -f1)
    print_info "Kernel size: $kernel_size"
    
    cd "$CUR_DIR" || exit
}

# 📦 Function to prepare BusyBox
prepare_busybox() {
    print_header "Preparing BusyBox v$BUSYBOX_VERSION"

    local BUSYBOX_SOURCE="https://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2"
    local BUSYBOX_DIR="busybox-$BUSYBOX_VERSION"
    
    print_info "📖 WHAT IS BUSYBOX:"
    print_info "BusyBox is a software that combines simplified versions of many"
    print_info "common Unix utilities into a single executable. It's perfect for"
    print_info "embedded systems or minimal distributions."
    echo
    
    rm -rf "$BUSYBOX_DIR"
    mkdir -p "$BUILD_DIR"
    
    # Downloading BusyBox
    print_step "Downloading BusyBox v$BUSYBOX_VERSION..."
    if wget -q --show-progress "$BUSYBOX_SOURCE" -P "$CUR_DIR"; then
        print_success "Download completed!"
    else
        print_error "Error downloading BusyBox! Check the version number."
        return 1
    fi
    
    # Extraction
    print_step "Extracting BusyBox archive..."
    tar xf "$CUR_DIR/busybox-$BUSYBOX_VERSION.tar.bz2" -C "$CUR_DIR"
    rm "$CUR_DIR/busybox-$BUSYBOX_VERSION.tar.bz2"
    
    cd "$BUSYBOX_DIR" || exit
    
    # Configuration
    print_step "Configuring BusyBox..."
    if ! make defconfig &> "$LOG_FILE"; then
        print_error "Error during BusyBox defconfig! Check $LOG_FILE"
        return 1
    fi
    
    # Auto-fix: ensure static compilation and disable problematic applets for minimal build
    sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
    sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' .config
    
    # Compilation
    print_step "Compiling BusyBox..."
    if ! make -j"$(nproc)" &> "$LOG_FILE"; then
        print_error "Error compiling BusyBox! Check $LOG_FILE for details."
        return 1
    fi
    
    print_success "BusyBox compiled!"
    
    # Verifying static compilation
    if file busybox | grep -qi static; then
        print_success "BusyBox compiled statically (correct!)"
    else
        print_error "BusyBox is not static!"
        return 1
    fi
    
    # Installation
    print_step "Installing BusyBox..."
    if ! make install &> "$LOG_FILE"; then
        print_error "Error installing BusyBox! Check $LOG_FILE"
        return 1
    fi
    
    # Creating filesystem
    cd "_install" || exit
    print_step "Creating filesystem structure..."
    
    mkdir -p dev proc sys tmp var/log etc
    
    # Improved init script
    print_step "Creating initialization script..."
    cat << 'EOF' > init
#!/bin/sh

# Initialization script for Manzolo Linux
echo "🐧 Welcome to Manzolo Linux!"
echo "================================"

# Mounting virtual filesystems
echo "Mounting virtual filesystems..."
mount -t devtmpfs none /dev
mount -t proc none /proc  
mount -t sysfs none /sys
mount -t tmpfs none /tmp

# Creating essential devices
mknod /dev/null c 1 3
mknod /dev/zero c 1 5
mknod /dev/random c 1 8

# System information
echo
echo "📊 System Information:"
echo "Kernel: $(uname -r)"
echo "Architettura: $(uname -m)"
echo "Uptime: $(cat /proc/uptime | cut -d' ' -f1)s"
echo

# Welcome message
cat << 'WELCOME'
╔══════════════════════════════════════════════════════════════╗
║                    🎉 MANZOLO LINUX v1.0                     ║
║                                                              ║
║ Congratulations! You have successfully created your          ║
║ personalized Linux distribution!                             ║
║                                                              ║
║ 💡 Available commands: ls, cat, ps, top, free, df, help      ║
║                                                              ║
║ 🚀 Have fun exploring your system!                           ║
╚══════════════════════════════════════════════════════════════╝
WELCOME

echo
exec /bin/sh
EOF
    
    chmod +x init
    
    # Creating initramfs
    print_step "Creating initramfs..."
    if ! find . -print0 | cpio --null -ov --format=newc 2>/dev/null | gzip -9 > "$BUILD_DIR/initramfs.cpio.gz"; then
        print_error "Error creating initramfs!"
        return 1
    fi
    
    local initramfs_size=$(du -h "$BUILD_DIR/initramfs.cpio.gz" | cut -f1)
    print_success "Initramfs created! Size: $initramfs_size"
    
    cd "$CUR_DIR" || exit
}

# 🖥️ Function to launch QEMU with improved options
launch_qemu() {
    print_header "Starting System with QEMU"
    
    # Checking for necessary files
    if [ ! -f "$BUILD_DIR/bzImage" ]; then
        print_error "bzImage file missing! Compile the kernel first."
        return 1
    fi
    
    if [ ! -f "$BUILD_DIR/initramfs.cpio.gz" ]; then
        print_error "initramfs file missing! Prepare BusyBox first."
        return 1
    fi
    
    print_info "📖 STARTING THE SYSTEM:"
    print_info "QEMU is an emulator that allows us to test our personalized Linux"
    print_info "system without having to reboot the computer."
    echo
    
    print_step "Starting QEMU..."
    print_info "VM configuration: 512MB RAM, 1 CPU, accelerated graphics"
    print_warning "To exit QEMU: Ctrl+Alt+G to release the mouse, then close the window"
    echo
    
    sleep 2
    
    # Starting with improved options
    qemu-system-x86_64 \
        -kernel "$BUILD_DIR/bzImage" \
        -initrd "$BUILD_DIR/initramfs.cpio.gz" \
        -m 512M \
        -smp 1 \
        -enable-kvm \
        -display gtk \
        -name "Manzolo Linux" \
        -boot order=c
}

# 💿 Function to prepare the ISO
prepare_iso() {
    print_header "Creating Bootable ISO Image"
    
    print_info "📖 CREATING THE ISO:"
    print_info "An ISO image is a file that contains everything needed to"
    print_info "boot an operating system. It can be burned to a CD/DVD"
    print_info "or used to create bootable USB drives."
    echo
    
    # Checking for necessary files
    if [ ! -f "$BUILD_DIR/bzImage" ] || [ ! -f "$BUILD_DIR/initramfs.cpio.gz" ]; then
        print_error "Missing files! Compile the kernel and BusyBox first."
        return 1
    fi
    
    local ISO_DIR="$BUILD_DIR/iso"
    local ISOBOOT_DIR="$ISO_DIR/boot"
    local ISOGRUB_DIR="$ISOBOOT_DIR/grub"
    
    cd "$BUILD_DIR" || exit
    
    # Preparing the ISO directory
    print_step "Preparing ISO structure..."
    rm -rf "$ISO_DIR"
    mkdir -p "$ISOBOOT_DIR" "$ISOGRUB_DIR"
    
    # Copying boot files
    cp bzImage "$ISOBOOT_DIR/"
    cp initramfs.cpio.gz "$ISOBOOT_DIR/"
    
    # Improved GRUB configuration
    print_step "Configuring GRUB bootloader..."
    cat << 'EOF' > "$ISOGRUB_DIR/grub.cfg"
# GRUB configuration for Manzolo Linux
set default=0
set timeout=10

# Load EFI video drivers
insmod efi_gop
insmod font

if loadfont /boot/grub/fonts/unicode.pf2
then
    insmod gfxterm
    set gfxmode=auto
    set gfxpayload=keep
    terminal_output gfxterm
fi

# Bootloader background
insmod png
background_image /boot/grub/background.png

menuentry '🐧 Manzolo Linux - Normal Boot' --class os {
    echo 'Loading Manzolo Linux...'
    insmod gzio
    insmod part_msdos
    linux /boot/bzImage quiet splash
    initrd /boot/initramfs.cpio.gz
}

menuentry '🔧 Manzolo Linux - Debug Mode' --class os {
    echo 'Loading Manzolo Linux (debug)...'
    insmod gzio
    insmod part_msdos
    linux /boot/bzImage debug
    initrd /boot/initramfs.cpio.gz
}

menuentry '💾 Memory Test (Memtest86+)' --class tool {
    echo 'Memtest86+ not available in this build'
    sleep 2
}

menuentry '🔄 Reboot System' --class restart {
    reboot
}

menuentry '⚡ Shutdown System' --class shutdown {
    halt
}
EOF
    
    # Creating the ISO
    print_step "Generating ISO image..."
    if ! grub-mkrescue -o manzolo-linux-v1.0.iso "$ISO_DIR/" &> "$LOG_FILE"; then
        print_error "Error creating the ISO! Check $LOG_FILE"
        return 1
    fi
    
    local iso_size=$(du -h manzolo-linux-v1.0.iso | cut -f1)
    print_success "ISO created successfully!"
    print_info "File name: manzolo-linux-v1.0.iso"
    print_info "Size: $iso_size"
    print_info "Path: $BUILD_DIR/manzolo-linux-v1.0.iso"
    echo
    print_info "💡 How to use the ISO:"
    print_info "• Burn it to a CD/DVD"
    print_info "• Create a bootable USB with dd or Rufus"
    print_info "• Use it in virtual machines"
    
    cd "$CUR_DIR" || exit
}

# 🧹 Function for complete cleanup
cleanup_all() {
    print_header "Complete Cleanup"
    print_warning "This operation will delete all compiled files!"
    read -p "Are you sure? (y/N): " confirm
    
    if [[ $confirm =~ ^[Yy]$ ]]; then
        print_step "Deleting temporary files..."
        rm -rf "$BUILD_DIR" "linux-"* "busybox-"*
        print_success "Cleanup completed!"
    fi
}

# 📈 Function to show statistics
show_stats() {
    print_header "Project Statistics"
    
    if [ -d "$BUILD_DIR" ]; then
        print_info "📁 Build directory: $(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1)"
        
        if [ -f "$BUILD_DIR/bzImage" ]; then
            print_info "🔧 Compiled kernel: $(du -h "$BUILD_DIR/bzImage" | cut -f1)"
        fi
        
        if [ -f "$BUILD_DIR/initramfs.cpio.gz" ]; then
            print_info "📦 Initramfs: $(du -h "$BUILD_DIR/initramfs.cpio.gz" | cut -f1)"
        fi
        
        if [ -f "$BUILD_DIR/manzolo-linux-v1.0.iso" ]; then
            print_info "💿 Final ISO: $(du -h "$BUILD_DIR/manzolo-linux-v1.0.iso" | cut -f1)"
        fi
        print_info "📝 Build log: $LOG_FILE"
    else
        print_warning "No compiled files found."
    fi
}

# 🎯 Improved main menu
show_menu() {
    clear
    cat << EOF
    ╔═══════════════════════════════════════════════════════════════╗
    ║                     🐧 MANZOLO LINUX BUILDER                  ║
    ║                          Main Menu                            ║
    ╚═══════════════════════════════════════════════════════════════╝
    
    📋 MAIN OPERATIONS:
    ┌─────────────────────────────────────────────────────────────┐
    │ 1. 🔍 Check prerequisites                                   │
    │ 2. 🔧 Prepare Linux kernel                                  │
    │ 3. 📦 Prepare BusyBox (filesystem)                          │
    │ 4. 🖥️  Test system with QEMU                                 │
    │ 5. 💿 Create bootable ISO image                             │
    └─────────────────────────────────────────────────────────────┘
    
    🛠️  UTILITIES:
    ┌─────────────────────────────────────────────────────────────┐
    │ 6. 📊 Show statistics                                       │
    │ 7. 🧹 Complete cleanup                                      │
    │ 8. ℹ️  Project information                                  │
    │ 9. ⚙️  Configure versions                                   │
    │ 10. ❌ Exit                                                 │
    └─────────────────────────────────────────────────────────────┘

EOF
}

# 🚀 Main function
main() {
    # Check if we are on a Debian/Ubuntu system
    if ! command -v apt &> /dev/null; then
        print_error "This script is designed for Debian/Ubuntu systems!"
        exit 1
    fi
    
    # Show initial information
    show_info
    
    # Main loop
    while true; do
        show_menu
        read -rp "$(echo -e "${CYAN}Select an option (1-10): ${NC}")" choice
        
        case $choice in
            1) check_prerequisites ;;
            2) prepare_kernel ;;
            3) prepare_busybox ;;
            4) launch_qemu ;;
            5) prepare_iso ;;
            6) show_stats ;;
            7) cleanup_all ;;
            8) show_info ;;
            9) configure_versions ;;
            10)
                print_success "Thanks for using Manzolo Linux Builder! 🐧"
                exit 0 ;;
            *)
                print_error "Invalid option. Please choose a number from 1 to 10."
                read -p "Press ENTER to continue..."
                ;;
        esac
        
        echo
        read -p "Press ENTER to return to the menu..."
    done
}

# 🎬 Start the script
main "$@"