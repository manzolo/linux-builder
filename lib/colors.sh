#!/bin/bash

# =============================================================================
# 🎨 COLORS AND OUTPUT FUNCTIONS
# =============================================================================

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'
DIM='\033[2m'

# Background colors
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'
BG_PURPLE='\033[45m'
BG_CYAN='\033[46m'

# 🎯 Output functions
print_header() {
    echo -e "\n${BOLD}${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║${NC} ${WHITE}$1${NC} ${CYAN}║${NC}"
    echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}" >&2
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

print_progress() {
    echo -e "${CYAN}⏳ $1${NC}"
}

print_highlight() {
    echo -e "${BOLD}${YELLOW}🌟 $1${NC}"
}

# 📋 Box drawing functions
print_box() {
    local content="$1"
    local width=${2:-60}
    local color=${3:-$CYAN}
    
    echo -e "${color}┌$(printf '─%.0s' $(seq 1 $width))┐${NC}"
    echo -e "${color}│${NC} $content ${color}│${NC}"
    echo -e "${color}└$(printf '─%.0s' $(seq 1 $width))┘${NC}"
}

print_section() {
    local title="$1"
    echo -e "\n${BOLD}${BLUE}📌 $title${NC}"
    echo -e "${DIM}$(printf '─%.0s' $(seq 1 50))${NC}"
}

# 🎪 Animation functions
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# 📊 Progress bar
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    
    printf "\r${CYAN}["
    printf "%*s" $filled | tr ' ' '█'
    printf "%*s" $((width - filled)) | tr ' ' '░'
    printf "] %d%% (%d/%d)${NC}" $percentage $current $total
}

# 🎯 Interactive prompts
ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    
    while true; do
        if [[ $default == "y" ]]; then
            read -rp "$(echo -e "${CYAN}$prompt [Y/n]: ${NC}")" answer
            answer=${answer:-y}
        else
            read -rp "$(echo -e "${CYAN}$prompt [y/N]: ${NC}")" answer
            answer=${answer:-n}
        fi
        
        case $answer in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) print_error "Please answer yes or no." ;;
        esac
    done
}

ask_choice() {
    local prompt="$1"
    local options=("${@:2}")
    local i
    
    echo -e "${CYAN}$prompt${NC}"
    for i in "${!options[@]}"; do
        echo -e "  ${YELLOW}$((i+1)).${NC} ${options[i]}"
    done
    
    while true; do
        read -rp "$(echo -e "${CYAN}Select option [1-${#options[@]}]: ${NC}")" choice
        if [[ $choice =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#options[@]})); then
            return $((choice - 1))
        fi
        print_error "Invalid choice. Please select a number between 1 and ${#options[@]}."
    done
}

# 🚨 Error handling
handle_error() {
    local exit_code=$1
    local line_number=$2
    print_error "An error occurred on line $line_number with exit code $exit_code"
    exit $exit_code
}

# Set error trap
trap 'handle_error $? $LINENO' ERR