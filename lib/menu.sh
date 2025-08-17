#!/bin/bash

# =============================================================================
# 🎯 INTERACTIVE MENU SYSTEM
# =============================================================================

# Load other modules
source "$SCRIPT_DIR/modules/kernel/configure.sh"
source "$SCRIPT_DIR/modules/kernel/compile.sh"
source "$SCRIPT_DIR/modules/kernel.sh"
source "$SCRIPT_DIR/modules/busybox/configure.sh"
source "$SCRIPT_DIR/modules/busybox/filesystem/init.sh"
source "$SCRIPT_DIR/modules/busybox/filesystem/console.sh"
source "$SCRIPT_DIR/modules/busybox/filesystem/user.sh"
source "$SCRIPT_DIR/modules/busybox/filesystem/network.sh"
source "$SCRIPT_DIR/modules/busybox/filesystem/package_manager.sh"
source "$SCRIPT_DIR/modules/busybox/filesystem/webserver.sh"
source "$SCRIPT_DIR/modules/busybox/filesystem.sh"
source "$SCRIPT_DIR/modules/busybox/compile.sh"
source "$SCRIPT_DIR/modules/busybox/initram.sh"
source "$SCRIPT_DIR/modules/busybox.sh"
source "$SCRIPT_DIR/modules/iso.sh"
source "$SCRIPT_DIR/modules/qemu.sh"
source "$SCRIPT_DIR/modules/system.sh"
source "$SCRIPT_DIR/modules/unattended.sh"

# Show welcome screen
show_welcome() {
    clear
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                                                                              ║
    ║    🐧  ███╗   ███╗ █████╗ ███╗   ██╗███████╗ ██████╗ ██╗      ██████╗        ║
    ║        ████╗ ████║██╔══██╗████╗  ██║╚══███╔╝██╔═══██╗██║     ██╔═══██╗       ║
    ║        ██╔████╔██║███████║██╔██╗ ██║  ███╔╝ ██║   ██║██║     ██║   ██║       ║
    ║        ██║╚██╔╝██║██╔══██║██║╚██╗██║ ███╔╝  ██║   ██║██║     ██║   ██║       ║
    ║        ██║ ╚═╝ ██║██║  ██║██║ ╚████║███████╗╚██████╔╝███████╗╚██████╔╝       ║
    ║        ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝ ╚═════╝ ╚══════╝ ╚═════╝        ║
    ║                                                                              ║
    ║                        🚀 LINUX DISTRIBUTION BUILDER                         ║
    ║                                                                              ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
EOF

    echo -e "\n${CYAN}Welcome to Manzolo Linux Builder!${NC}"
    echo -e "${DIM}Create your own personalized Linux distribution from scratch${NC}"
    echo

    print_info "📚 What you'll learn:"
    echo -e "   • How to compile the Linux kernel"
    echo -e "   • Create a minimal filesystem with BusyBox"
    echo -e "   • Generate initramfs and bootable images"
    echo -e "   • Test your system with QEMU"
    echo -e "   • Advanced kernel configuration"
    echo

    read -p "$(echo -e "${CYAN}Press ENTER to continue...${NC}")"
}

# Main menu
main_menu() {
    while true; do
        clear
        show_main_menu_header
        show_main_menu_options

        local choice
        read -rp "$(echo -e "\n${CYAN}Select option [1-12]: ${NC}")" choice

        case $choice in
            1) unattended_build ;;                     # Sposta la build automatica in cima
            2) check_prerequisites_interactive ;;      # Sposta il check dei prerequisiti
            3) kernel_menu ;;                          # Sposta gli altri menu
            4) busybox_menu ;;
            5) test_menu ;;
            6) iso_menu ;;
            7) config_menu ;;
            8) utilities_menu ;;
            9) system_info_menu ;;
            10) help_menu ;;
            11) about_menu ;;
            12) exit_program ;;
            *)
                print_error "Invalid option. Please select 1-12."
                read -p "Press ENTER to continue..."
                ;;
        esac
    done
}

show_main_menu_header() {
    # Larghezza fissa della riga interna (tra i caratteri `│` e `│`)
    local width=76
    
    # Variabili da stampare
    local kernel_info="Kernel: $KERNEL_VERSION"
    local busybox_info="BusyBox: $BUSYBOX_VERSION"
    local arch_info="Arch: $KERNEL_ARCH"
    local build_dir_info="Build Dir: $BUILD_DIR"
    
    # Prima riga: distribuisce kernel_info, busybox_info, arch_info con spaziatura equilibrata
    # Calcoliamo lo spazio disponibile per ogni sezione (dividendo in 3 parti uguali)
    local section_width=$((width / 3))
    local remaining=$((width % 3))
    
    # Formatta ogni sezione centrata nel suo spazio
    local kernel_section=$(printf "%-${section_width}s" "$kernel_info")
    local busybox_section=$(printf "%-${section_width}s" "$busybox_info")
    local arch_section=$(printf "%-$((section_width + remaining))s" "$arch_info")
    
    # Combina le sezioni per creare la prima riga
    local first_line="${kernel_section}${busybox_section}${arch_section}"
    
    # Seconda riga: build_dir_info allineato a sinistra
    local second_line=$(printf "%-76s" "$build_dir_info")
    
    cat << EOF
    ╔═════════════════════════════════════════════════════════════════════════════╗
    ║                       🐧 MANZOLO LINUX BUILDER                              ║
    ║                                 Main Menu                                   ║
    ╚═════════════════════════════════════════════════════════════════════════════╝
    📊 Current Status:
    ┌─────────────────────────────────────────────────────────────────────────────┐
    │ $first_line│
    │ $second_line│
    └─────────────────────────────────────────────────────────────────────────────┘
EOF
}

show_main_menu_options() {
    cat << 'EOF'

    🚀 UNATTENDED BUILD:
    ┌─────────────────────────────────────────────────────────────────────────────┐
    │  1. 🚀 Unattended Full Build          │  2. 🔍 Check System Prerequisites   │
    └─────────────────────────────────────────────────────────────────────────────┘

    🔧 MANUAL BUILD:
    ┌─────────────────────────────────────────────────────────────────────────────┐
    │  3. 🐧 Kernel Management              │  4. 📦 BusyBox Management           │
    │  5. 🖥️  System Testing                 │  6. 💿 ISO Creation & Packaging     │
    └─────────────────────────────────────────────────────────────────────────────┘

    🛠️  SYSTEM & UTILITIES:
    ┌─────────────────────────────────────────────────────────────────────────────┐
    │  7. ⚙️  Configuration                  │   8. 🧹 Utilities & Cleanup         │
    │  9. 📊 System Information             │  10. ❓ Help & Documentation        │
    │ 11. ℹ️  About                          │  12. ❌ Exit                        │
    └─────────────────────────────────────────────────────────────────────────────┘
EOF
}

# Kernel menu
kernel_menu() {
    while true; do
        clear
        print_header "Kernel Management"

        # Show kernel status
        if [[ -f "$BUILD_DIR/bzImage" ]]; then
            local kernel_size=$(du -h "$BUILD_DIR/bzImage" | cut -f1)
            print_success "Kernel compiled: $kernel_size"
        else
            print_warning "Kernel not compiled yet"
        fi

        cat << 'EOF'

        1. 🔧 Prepare Kernel Source
        2. ⚙️  Configure Kernel
        3. 🏗️  Compile Kernel
        4. 📊 Kernel Information
        5. 🧹 Clean Kernel Build
        6. ⬅️  Return to Main Menu

EOF

        read -rp "$(echo -e "${CYAN}Select option [1-6]: ${NC}")" choice

        case $choice in
            1) prepare_kernel ;;
            2) configure_kernel ;;
            3) compile_kernel ;;
            4) show_kernel_info ;;
            5) clean_kernel ;;
            6) break ;;
            *)
                print_error "Invalid option"
                read -p "Press ENTER to continue..."
                ;;
        esac
    done
}

# BusyBox menu
busybox_menu() {
    while true; do
        clear
        print_header "BusyBox Management"

        # Show BusyBox status
        if [[ -f "$BUILD_DIR/initramfs.cpio.gz" ]]; then
            local initramfs_size=$(du -h "$BUILD_DIR/initramfs.cpio.gz" | cut -f1)
            print_success "Initramfs created: $initramfs_size"
        else
            print_warning "Initramfs not created yet"
        fi

        cat << 'EOF'
        
        1. 📦 Prepare BusyBox Source
        2. ⚙️  Configure BusyBox
        3. 🏗️  Compile BusyBox, create filesystem, generate initramfs
        4. 📊 BusyBox Information
        5. 🧹 Clean BusyBox Build
        6. ⬅️  Return to Main Menu
        
EOF
        
        read -rp "$(echo -e "${CYAN}Select option [1-8]: ${NC}")" choice
        
        case $choice in
            1) prepare_busybox ;;
            2) configure_busybox ;;
            3) compile_busybox && create_filesystem && generate_initramfs ;;
            4) show_busybox_info ;;
            5) clean_busybox ;;
            6) break ;;
            *) 
                print_error "Invalid option"
                read -p "Press ENTER to continue..."
                ;;
        esac
    done
}

# Configuration menu
config_menu() {
    while true; do
        clear
        print_header "Configuration Management"

        cat << 'EOF'

        1. 🔧 Configuration Wizard
        2. 📊 Show Current Configuration
        3. 📝 Edit Configuration
        4. 💾 Export Configuration
        5. 📥 Import Configuration
        6. 🔄 Reset to Defaults
        7. ⬅️  Return to Main Menu

EOF

        read -rp "$(echo -e "${CYAN}Select option [1-7]: ${NC}")" choice

        case $choice in
            1) config_wizard ;;
            2) show_config ;;
            3) edit_config ;;
            4) export_config ;;
            5) import_config ;;
            6) reset_config ;;
            7) break ;;
            *)
                print_error "Invalid option"
                read -p "Press ENTER to continue..."
                ;;
        esac
    done
}

# Help menu
help_menu() {
    clear
    print_header "Help & Documentation"

    cat << 'EOF'

    📚 MANZOLO LINUX BUILDER - HELP

    🎯 Quick Start Guide:
    ────────────────────────────────────────────────────────────────
    1. Check prerequisites (installs required packages)
    2. Prepare kernel source and configure
    3. Compile kernel
    4. Prepare BusyBox and create filesystem
    5. Test with QEMU or create ISO

    🔧 Key Concepts:
    ────────────────────────────────────────────────────────────────
    • Kernel: The core of your Linux system
    • BusyBox: Provides essential Unix utilities
    • Initramfs: Initial RAM filesystem for booting
    • ISO: Bootable disc image for distribution

    ⚙️  Configuration:
    ────────────────────────────────────────────────────────────────
    • Use presets for common configurations
    • Customize modules for specific use cases
    • Save/load configurations for reproducible builds

    🆘 Troubleshooting:
    ────────────────────────────────────────────────────────────────
    • Check build.log for detailed error messages
    • Ensure all prerequisites are installed
    • Use debug mode for verbose output

    🌐 Resources:
    ────────────────────────────────────────────────────────────────
    • Linux Kernel: https://kernel.org
    • BusyBox: https://busybox.net
    • Project Documentation: Check README.md

EOF

    read -p "Press ENTER to continue..."
}

# About menu
about_menu() {
    clear
    print_header "About Manzolo Linux Builder"

    cat << 'EOF'

    🐧 MANZOLO LINUX BUILDER v2.0
    ══════════════════════════════════════════════════════════════

    Educational tool for creating custom Linux distributions
    from the Linux kernel and BusyBox.

    🎯 Features:
    • Interactive kernel compilation
    • Customizable filesystem creation
    • Multiple kernel presets
    • Modular software selection
    • Advanced packaging options
    • QEMU testing integration

    👨‍💻 Author: Manzolo Team
    📧 Support: manzolo@example.com
    🌐 Website: https://manzolo.example.com
    📄 License: GPL v3

    🙏 Special Thanks:
    • Linux Kernel Community
    • BusyBox Project
    • Educational Resources Community

EOF

    read -p "Press ENTER to continue..."
}

# Utilities menu
utilities_menu() {
    while true; do
        clear
        print_header "Utilities & Cleanup"

        cat << 'EOF'

        1. 🧹 Clean Build Directory
        2. 🗑️  Clean Downloads
        3. 🔄 Clean All
        4. 📊 Show Disk Usage
        5. 📋 Show Build Log
        6. 💾 Backup Build
        7. 📤 Create Archive
        8. ⬅️  Return to Main Menu

EOF

        read -rp "$(echo -e "${CYAN}Select option [1-8]: ${NC}")" choice

        case $choice in
            1) clean_build_directory ;;
            2) clean_downloads ;;
            3) clean_all ;;
            4) show_disk_usage ;;
            5) show_build_log ;;
            6) backup_build ;;
            7) create_archive ;;
            8) break ;;
            *)
                print_error "Invalid option"
                read -p "Press ENTER to continue..."
                ;;
        esac
    done
}

# System info menu
system_info_menu() {
    clear
    print_header "System Information"
    
    print_section "Build Environment"
    echo "Host: $(hostname)"
    echo "User: $(whoami)"
    echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "$(uname -s) $(uname -r)")"
    echo "Architecture: $(uname -m)"
    echo "CPU Cores: $(nproc)"
    echo "Memory: $(free -h | awk '/^Mem:/ {print $2}')"
    
    print_section "Compiler Information"
    echo "GCC Version: $(gcc --version 2>/dev/null | head -1 || echo "Not installed")"
    echo "Make Version: $(make --version 2>/dev/null | head -1 || echo "Not installed")"
    
    print_section "Build Status"
    
    # Check kernel
    if [[ -f "$BUILD_DIR/bzImage" ]]; then
        echo "✅ Kernel: $(du -h "$BUILD_DIR/bzImage" | cut -f1)"
    else
        echo "❌ Kernel: Not compiled"
    fi
    
    # Check initramfs
    if [[ -f "$BUILD_DIR/initramfs.cpio.gz" ]]; then
        echo "✅ Initramfs: $(du -h "$BUILD_DIR/initramfs.cpio.gz" | cut -f1)"
    else
        echo "❌ Initramfs: Not created"
    fi
    
    # Check ISO files - METODO CORRETTO
    local iso_files=("$BUILD_DIR"/*.iso)
    if [[ -f "${iso_files[0]}" ]]; then
        # Se ci sono più file ISO, mostra il primo o tutti
        if [[ ${#iso_files[@]} -eq 1 ]]; then
            echo "✅ ISO: $(du -h "${iso_files[0]}" | cut -f1)"
        else
            echo "✅ ISO files found: ${#iso_files[@]}"
            for iso in "${iso_files[@]}"; do
                echo "   - $(basename "$iso"): $(du -h "$iso" | cut -f1)"
            done
        fi
    else
        echo "❌ ISO: Not created"
    fi
    
    print_section "Directory Information"
    if [[ -d "$BUILD_DIR" ]]; then
        echo "Build Directory: $(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1 || echo "N/A")"
        echo "Build Directory Path: $BUILD_DIR"
        
        # Mostra il contenuto della directory per debug
        echo "Build Directory Contents:"
        ls -la "$BUILD_DIR" | grep -E '\.(iso|img)$' | while read -r line; do
            echo "   $line"
        done
    else
        echo "❌ Build Directory: Not found ($BUILD_DIR)"
    fi
    
    read -p "Press ENTER to continue..."
}

# Test menu
test_menu() {
    while true; do
        clear
        print_header "System Testing"

        cat << 'EOF'

        1. 🖥️  Launch QEMU (Standard)
        2. 🐛 Launch QEMU (Debug Mode)
        3. 🖼️  Launch QEMU (Graphics)
        4. 🌐 Launch QEMU (Network)
        5. 📊 QEMU Performance Test
        6. 🔧 Configure QEMU Options
        7. ⬅️  Return to Main Menu

EOF

        read -rp "$(echo -e "${CYAN}Select option [1-7]: ${NC}")" choice

        case $choice in
            1) launch_qemu_standard ;;
            2) launch_qemu_debug ;;
            3) launch_qemu_graphics ;;
            4) launch_qemu_network ;;
            5) qemu_performance_test ;;
            6) configure_qemu_options ;;
            7) break ;;
            *)
                print_error "Invalid option"
                read -p "Press ENTER to continue..."
                ;;
        esac
    done
}

# ISO menu
iso_menu() {
    while true; do
        clear
        print_header "ISO Creation & Packaging"

        cat << 'EOF'

        1. 💿 Create Standard ISO
        2. 🏷️  Configure ISO Labels
        3. ⬅️  Return to Main Menu

EOF

        read -rp "$(echo -e "${CYAN}Select option [1-3]: ${NC}")" choice

        case $choice in
            1) create_standard_iso ;;
            2) configure_iso_labels ;;
            3) break ;;
            *)
                print_error "Invalid option"
                read -p "Press ENTER to continue..."
                ;;
        esac
    done
}

# Exit program
exit_program() {
    clear
    print_header "Thank You!"

    cat << 'EOF'

    🐧 Thanks for using Manzolo Linux Builder!

    🎯 What you accomplished today:
    • Learned about Linux kernel compilation
    • Explored filesystem creation with BusyBox
    • Experienced the power of custom Linux distributions

    🚀 Keep exploring and building amazing things!

    📚 Resources for continued learning:
    • Linux From Scratch: https://linuxfromscratch.org
    • Kernel Newbies: https://kernelnewbies.org
    • BusyBox Documentation: https://busybox.net

EOF

    if ask_yes_no "Are you sure you want to exit?"; then
        print_success "Goodbye! 👋"
        exit 0
    fi
}

# Helper functions for menu items
edit_config() {
    if command -v nano &> /dev/null; then
        nano "$MAIN_CONFIG_FILE"
        load_config
        print_success "Configuration reloaded"
    else
        print_error "No text editor found. Please edit $MAIN_CONFIG_FILE manually"
    fi
    read -p "Press ENTER to continue..."
}

import_config() {
    print_step "Import configuration..."
    read -rp "Enter path to configuration file: " config_path
    if [[ -f "$config_path" ]]; then
        cp "$config_path" "$MAIN_CONFIG_FILE"
        load_config
        print_success "Configuration imported successfully"
    else
        print_error "File not found: $config_path"
    fi
    read -p "Press ENTER to continue..."
}

reset_config() {
    if ask_yes_no "Reset configuration to defaults?"; then
        rm -f "$MAIN_CONFIG_FILE"
        create_default_config
        load_config
        print_success "Configuration reset to defaults"
    fi
    read -p "Press ENTER to continue..."
}