#!/bin/bash

# =============================================================================
# ⚙️ CONFIGURATION MANAGEMENT
# =============================================================================

# Default configuration
DEFAULT_KERNEL_VERSION="6.6.12"
DEFAULT_BUSYBOX_VERSION="1.36.1"
DEFAULT_KERNEL_ARCH="x86_64"
DEFAULT_QEMU_SYSTEM="qemu-system-x86_64"
DEFAULT_CROSS_COMPILE=""

# Directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CUR_DIR="$PWD"
BUILD_DIR="$CUR_DIR/build"
CONFIG_DIR="$CUR_DIR/config"
LOG_FILE="$BUILD_DIR/build.log"
MAIN_CONFIG_FILE="$CONFIG_DIR/manzolo.conf"

# Initialize environment
init_environment() {
    # Create necessary directories
    mkdir -p "$BUILD_DIR" "$CONFIG_DIR" "$CONFIG_DIR/presets" "$CONFIG_DIR/modules"

    # Load or create main configuration
    load_config

    # Save the loaded/default configuration back to the file
    save_config

    print_info "Environment initialized successfully"
}

# Load configuration
load_config() {
    if [[ -f "$MAIN_CONFIG_FILE" ]]; then
        source "$MAIN_CONFIG_FILE"
        print_success "Configuration loaded from $MAIN_CONFIG_FILE"
    else
        create_default_config
    fi
    
    # Set defaults if not defined
    KERNEL_VERSION=${KERNEL_VERSION:-$DEFAULT_KERNEL_VERSION}
    BUSYBOX_VERSION=${BUSYBOX_VERSION:-$DEFAULT_BUSYBOX_VERSION}
    KERNEL_ARCH=${KERNEL_ARCH:-$DEFAULT_KERNEL_ARCH}
    QEMU_SYSTEM=${QEMU_SYSTEM:-$DEFAULT_QEMU_SYSTEM}
    CROSS_COMPILE=${CROSS_COMPILE:-$DEFAULT_CROSS_COMPILE}
}

# Create default configuration
create_default_config() {
    print_warning "Configuration file not found. Creating default configuration..."
    
    cat > "$MAIN_CONFIG_FILE" << EOF
# Manzolo Linux Builder - Main Configuration
# Generated on $(date)

# Software versions
KERNEL_VERSION="$DEFAULT_KERNEL_VERSION"
BUSYBOX_VERSION="$DEFAULT_BUSYBOX_VERSION"

# Architecture settings
KERNEL_ARCH="$DEFAULT_KERNEL_ARCH"
QEMU_SYSTEM="$DEFAULT_QEMU_SYSTEM"
CROSS_COMPILE="$DEFAULT_CROSS_COMPILE"

# Build settings
PARALLEL_JOBS="\$(nproc)"
COMPRESSION_LEVEL="9"
DEBUG_MODE="false"

# Paths
BUILD_DIR="$BUILD_DIR"
DOWNLOAD_DIR="$BUILD_DIR/downloads"
KERNEL_SOURCE_DIR="$BUILD_DIR/kernel"
BUSYBOX_SOURCE_DIR="$BUILD_DIR/busybox"

# ISO settings
ISO_LABEL="Manzolo Linux"
ISO_PUBLISHER="Manzolo Project"
ISO_VERSION="1.0"
EOF
    
    print_success "Default configuration created at $MAIN_CONFIG_FILE"
}

# Save configuration
save_config() {
    print_step "Saving configuration..."
    
    cat > "$MAIN_CONFIG_FILE" << EOF
# Manzolo Linux Builder - Main Configuration
# Last modified: $(date)

# Software versions
KERNEL_VERSION="$KERNEL_VERSION"
BUSYBOX_VERSION="$BUSYBOX_VERSION"

# Architecture settings
KERNEL_ARCH="$KERNEL_ARCH"
QEMU_SYSTEM="$QEMU_SYSTEM"
CROSS_COMPILE="$CROSS_COMPILE"

# Build settings
PARALLEL_JOBS="${PARALLEL_JOBS:-\$(nproc)}"
COMPRESSION_LEVEL="${COMPRESSION_LEVEL:-9}"
DEBUG_MODE="${DEBUG_MODE:-false}"

# Paths
BUILD_DIR="$BUILD_DIR"
DOWNLOAD_DIR="${DOWNLOAD_DIR:-$BUILD_DIR/downloads}"
KERNEL_SOURCE_DIR="${KERNEL_SOURCE_DIR:-$BUILD_DIR/kernel}"
BUSYBOX_SOURCE_DIR="${BUSYBOX_SOURCE_DIR:-$BUILD_DIR/busybox}"

# ISO settings
ISO_LABEL="${ISO_LABEL:-Manzolo Linux}"
ISO_PUBLISHER="${ISO_PUBLISHER:-Manzolo Project}"
ISO_VERSION="${ISO_VERSION:-1.0}"
EOF
    source "$MAIN_CONFIG_FILE"
    
    print_success "Configuration saved successfully"
}

# Configuration wizard
config_wizard() {
    print_header "Configuration Wizard"
    
    print_info "Let's configure your Manzolo Linux build"
    echo
    
    # Kernel version
    print_section "Kernel Configuration"
    echo -e "Current kernel version: ${YELLOW}$KERNEL_VERSION${NC}"
    if ask_yes_no "Change kernel version?"; then
        read -rp "$(echo -e "${CYAN}Enter new kernel version: ${NC}")" new_kernel
        if [[ -n "$new_kernel" ]]; then
            KERNEL_VERSION="$new_kernel"
            print_success "Kernel version updated to $KERNEL_VERSION"
        fi
    fi
    
    # BusyBox version
    print_section "BusyBox Configuration"
    echo -e "Current BusyBox version: ${YELLOW}$BUSYBOX_VERSION${NC}"
    if ask_yes_no "Change BusyBox version?"; then
        read -rp "$(echo -e "${CYAN}Enter new BusyBox version: ${NC}")" new_busybox
        if [[ -n "$new_busybox" ]]; then
            BUSYBOX_VERSION="$new_busybox"
            print_success "BusyBox version updated to $BUSYBOX_VERSION"
        fi
    fi
    
    # Architecture
    print_section "Architecture Configuration"
    echo -e "Current architecture: ${YELLOW}$KERNEL_ARCH${NC}"
    if ask_yes_no "Change architecture?"; then
        local archs=("x86_64" "i386" "arm64" "armv7")
        ask_choice "Select architecture:" "${archs[@]}"
        local choice=$?
        KERNEL_ARCH="${archs[$choice]}"
        print_success "Architecture updated to $KERNEL_ARCH"
    fi
    
    # Build options
    print_section "Build Options"
    echo -e "Parallel jobs: ${YELLOW}${PARALLEL_JOBS:-$(nproc)}${NC}"
    if ask_yes_no "Enable debug mode?"; then
        DEBUG_MODE="true"
        print_success "Debug mode enabled"
    else
        DEBUG_MODE="false"
        print_info "Debug mode disabled"
    fi
    
    # Save configuration
    save_config
    
    print_success "Configuration wizard completed!"
    read -p "Press ENTER to continue..."
}

# Show current configuration
show_config() {
    print_header "Current Configuration"
    
    # Method 1: Using echo statements (recommended)
    echo -e "📦 ${BOLD}Software Versions:${NC}"
    echo -e "   Kernel: ${YELLOW}$KERNEL_VERSION${NC}"
    echo -e "   BusyBox: ${YELLOW}$BUSYBOX_VERSION${NC}"
    echo
    echo -e "🏗️ ${BOLD}Build Settings:${NC}"
    echo -e "   Architecture: ${YELLOW}$KERNEL_ARCH${NC}"
    echo -e "   Parallel Jobs: ${YELLOW}${PARALLEL_JOBS:-$(nproc)}${NC}"
    echo -e "   Debug Mode: ${YELLOW}${DEBUG_MODE:-false}${NC}"
    echo -e "   Compression: ${YELLOW}${COMPRESSION_LEVEL:-9}${NC}"
    echo
    echo -e "📂 ${BOLD}Directories:${NC}"
    echo -e "   Build Dir: ${YELLOW}$BUILD_DIR${NC}"
    echo -e "   Config Dir: ${YELLOW}$CONFIG_DIR${NC}"
    echo
    echo -e "💿 ${BOLD}ISO Settings:${NC}"
    echo -e "   Label: ${YELLOW}${ISO_LABEL:-Manzolo Linux}${NC}"
    echo -e "   Version: ${YELLOW}${ISO_VERSION:-1.0}${NC}"
    echo -e "   Publisher: ${YELLOW}${ISO_PUBLISHER:-Manzolo Project}${NC}"
    echo
    echo -e "📄 ${BOLD}Configuration File:${NC}"
    echo -e "   ${YELLOW}$MAIN_CONFIG_FILE${NC}"
    
    read -p "Press ENTER to continue..."
}

# Export build configuration
export_config() {
    local export_file="$BUILD_DIR/manzolo-build-$(date +%Y%m%d-%H%M%S).conf"
    
    print_step "Exporting build configuration..."
    
    cat > "$export_file" << EOF
# Manzolo Linux Build Configuration Export
# Generated on $(date)
# Host: $(hostname)
# User: $(whoami)

# Software Versions
KERNEL_VERSION="$KERNEL_VERSION"
BUSYBOX_VERSION="$BUSYBOX_VERSION"

# Build Configuration
KERNEL_ARCH="$KERNEL_ARCH"
PARALLEL_JOBS="${PARALLEL_JOBS:-$(nproc)}"
DEBUG_MODE="${DEBUG_MODE:-false}"

# Build Statistics
$(if [[ -f "$BUILD_DIR/bzImage" ]]; then
    echo "KERNEL_SIZE=\"$(du -h "$BUILD_DIR/bzImage" | cut -f1)\""
fi)
$(if [[ -f "$BUILD_DIR/initramfs.cpio.gz" ]]; then
    echo "INITRAMFS_SIZE=\"$(du -h "$BUILD_DIR/initramfs.cpio.gz" | cut -f1)\""
fi)
$(if [[ -f "$BUILD_DIR"/*.iso ]]; then
    echo "ISO_SIZE=\"$(du -h "$BUILD_DIR"/*.iso | cut -f1)\""
fi)

# Build Environment
BUILD_DATE="$(date)"
BUILD_HOST="$(hostname)"
BUILD_USER="$(whoami)"
KERNEL_VERSION_RUNNING="$(uname -r)"
COMPILER_VERSION="$(gcc --version | head -1)"
EOF
    
    print_success "Configuration exported to $export_file"
    read -p "Press ENTER to continue..."
}