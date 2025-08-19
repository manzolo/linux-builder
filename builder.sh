#!/bin/bash

# =============================================================================
# 🐧 MANZOLO LINUX BUILDER - Main Script
# =============================================================================

set -euo pipefail

# 📂 Script directory and includes
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/colors.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/menu.sh"

# 🛡️ Trap for cleanup on exit
trap cleanup_on_exit EXIT

cleanup_on_exit() {
    if [[ ${CLEANUP_NEEDED:-false} == true ]]; then
        print_info "Performing cleanup..."
    fi
}

# 🎯 Main function
main() {
    # Initialize
    init_environment
    check_dependencies flex bison build-essential libelf-dev libssl-dev xorriso grub-pc-bin mtools

    
    # Check system compatibility
    if ! command -v apt &> /dev/null; then
        print_error "This script is designed for Debian/Ubuntu systems!"
        exit 1
    fi
    
    # Show welcome screen
    show_welcome
    
    # Main menu loop
    main_menu
}

# 🚀 Start the application
main "$@"