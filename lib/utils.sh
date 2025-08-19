#!/bin/bash

# =============================================================================
# 🛠️ UTILITY FUNCTIONS
# =============================================================================

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root!"
        print_info "Please run as a regular user. sudo will be used when needed."
        exit 1
    fi
}

# Check internet connectivity
check_internet() {
    print_step "Checking internet connectivity..."
    if ping -c 1 -W 5 8.8.8.8 &> /dev/null; then
        print_success "Internet connection available"
        return 0
    else
        print_warning "No internet connection detected"
        return 1
    fi
}

# Download file with progress
download_file() {
    local url="$1"
    local output="$2"
    local description="${3:-file}"
    
    print_step "Downloading $description..."
    
    if command -v wget &> /dev/null; then
        if wget --progress=bar:force -O "$output" "$url" 2>&1 | \
           stdbuf -o0 grep -o '[0-9]*%' | \
           while read percentage; do
               echo -ne "\r${CYAN}Progress: $percentage${NC}"
           done; then
            echo
            print_success "$description downloaded successfully"
            return 0
        fi
    elif command -v curl &> /dev/null; then
        if curl -L --progress-bar -o "$output" "$url"; then
            print_success "$description downloaded successfully"
            return 0
        fi
    fi
    
    print_error "Failed to download $description"
    return 1
}

# Extract archive
extract_archive() {
    local archive="$1"
    local destination="${2:-.}"
    local description="${3:-archive}"
    
    print_step "Extracting $description..."
    
    case "$archive" in
        *.tar.gz|*.tgz)
            tar -xzf "$archive" -C "$destination"
            ;;
        *.tar.xz)
            tar -xJf "$archive" -C "$destination"
            ;;
        *.tar.bz2|*.tbz2)
            tar -xjf "$archive" -C "$destination"
            ;;
        *.zip)
            unzip -q "$archive" -d "$destination"
            ;;
        *)
            print_error "Unsupported archive format: $archive"
            return 1
            ;;
    esac
    
    if [[ $? -eq 0 ]]; then
        print_success "$description extracted successfully"
        return 0
    else
        print_error "Failed to extract $description"
        return 1
    fi
}

# Check available disk space
check_disk_space() {
    local required_gb="${1:-5}"
    local path="${2:-$BUILD_DIR}"
    
    print_step "Checking available disk space..."
    
    local available_kb=$(df "$path" | awk 'NR==2 {print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    
    if [[ $available_gb -ge $required_gb ]]; then
        print_success "Sufficient disk space: ${available_gb}GB available"
        return 0
    else
        print_error "Insufficient disk space: ${available_gb}GB available, ${required_gb}GB required"
        return 1
    fi
}

# Verify file checksum
verify_checksum() {
    local file="$1"
    local expected="$2"
    local algorithm="${3:-sha256}"
    
    if [[ ! -f "$file" ]]; then
        print_error "File not found: $file"
        return 1
    fi
    
    print_step "Verifying $algorithm checksum..."
    
    local actual
    case "$algorithm" in
        md5) actual=$(md5sum "$file" | cut -d' ' -f1) ;;
        sha1) actual=$(sha1sum "$file" | cut -d' ' -f1) ;;
        sha256) actual=$(sha256sum "$file" | cut -d' ' -f1) ;;
        *) 
            print_error "Unsupported checksum algorithm: $algorithm"
            return 1
            ;;
    esac
    
    if [[ "$actual" == "$expected" ]]; then
        print_success "Checksum verification passed"
        return 0
    else
        print_error "Checksum verification failed"
        print_error "Expected: $expected"
        print_error "Actual: $actual"
        return 1
    fi
}

# Create backup
create_backup() {
    local source="$1"
    local backup_dir="${2:-$BUILD_DIR/backups}"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_name="backup-$timestamp"
    
    if [[ ! -e "$source" ]]; then
        print_error "Source not found: $source"
        return 1
    fi
    
    print_step "Creating backup..."
    
    mkdir -p "$backup_dir"
    
    if [[ -d "$source" ]]; then
        tar -czf "$backup_dir/$backup_name.tar.gz" -C "$(dirname "$source")" "$(basename "$source")"
    else
        cp "$source" "$backup_dir/$backup_name.$(basename "$source")"
    fi
    
    if [[ $? -eq 0 ]]; then
        print_success "Backup created: $backup_dir/$backup_name"
        return 0
    else
        print_error "Failed to create backup"
        return 1
    fi
}

# Lock file management
acquire_lock() {
    local lock_file="${1:-$BUILD_DIR/.manzolo.lock}"
    local timeout="${2:-300}"
    local start_time=$(date +%s)
    
    while [[ -f "$lock_file" ]]; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [[ $elapsed -ge $timeout ]]; then
            print_error "Failed to acquire lock after ${timeout}s"
            return 1
        fi
        
        print_warning "Waiting for lock... (${elapsed}s)"
        sleep 5
    done
    
    echo $$ > "$lock_file"
    print_success "Lock acquired"
}

release_lock() {
    local lock_file="${1:-$BUILD_DIR/.manzolo.lock}"
    
    if [[ -f "$lock_file" ]]; then
        rm -f "$lock_file"
        print_success "Lock released"
    fi
}

# Process management
run_with_timeout() {
    local timeout="$1"
    local command="$2"
    
    print_step "Running command with ${timeout}s timeout..."
    
    timeout "$timeout" bash -c "$command"
    local exit_code=$?
    
    case $exit_code in
        0) print_success "Command completed successfully" ;;
        124) print_error "Command timed out after ${timeout}s" ;;
        *) print_error "Command failed with exit code $exit_code" ;;
    esac
    
    return $exit_code
}

# Memory management
check_memory() {
    local required_mb="${1:-1024}"
    
    print_step "Checking available memory..."
    
    local available_mb=$(free -m | awk '/^Mem:/ {print $7}')
    
    if [[ $available_mb -ge $required_mb ]]; then
        print_success "Sufficient memory: ${available_mb}MB available"
        return 0
    else
        print_warning "Low memory: ${available_mb}MB available, ${required_mb}MB recommended"
        return 1
    fi
}

# CPU information
get_cpu_info() {
    local cores=$(nproc)
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    local cpu_freq=$(grep "cpu MHz" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    
    echo "CPU: $cpu_model"
    echo "Cores: $cores"
    echo "Frequency: ${cpu_freq}MHz"
}

# Disk usage analysis
analyze_disk_usage() {
    local path="${1:-$BUILD_DIR}"
    
    if [[ ! -d "$path" ]]; then
        print_error "Directory not found: $path"
        return 1
    fi
    
    print_header "Disk Usage Analysis"
    
    echo "Total size: $(du -sh "$path" | cut -f1)"
    echo
    echo "Top 10 largest items:"
    du -sh "$path"/* 2>/dev/null | sort -hr | head -10
    
    echo
    echo "File type distribution:"
    find "$path" -type f -name "*.*" | sed 's/.*\.//' | sort | uniq -c | sort -nr | head -10
}

# Clean temporary files
clean_temp_files() {
    local temp_patterns=("*.tmp" "*.temp" "*~" ".#*" "core.*")
    local cleaned=0
    
    print_step "Cleaning temporary files..."
    
    for pattern in "${temp_patterns[@]}"; do
        while IFS= read -r -d '' file; do
            rm -f "$file"
            ((cleaned++))
        done < <(find "$BUILD_DIR" -name "$pattern" -type f -print0 2>/dev/null)
    done
    
    print_success "Cleaned $cleaned temporary files"
}

# Log rotation
rotate_logs() {
    local log_file="${1:-$LOG_FILE}"
    local max_size="${2:-10M}"
    local max_files="${3:-5}"
    
    if [[ ! -f "$log_file" ]]; then
        return 0
    fi
    
    local file_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)
    local max_bytes
    
    case "$max_size" in
        *K|*k) max_bytes=$((${max_size%[Kk]} * 1024)) ;;
        *M|*m) max_bytes=$((${max_size%[Mm]} * 1024 * 1024)) ;;
        *G|*g) max_bytes=$((${max_size%[Gg]} * 1024 * 1024 * 1024)) ;;
        *) max_bytes=$max_size ;;
    esac
    
    if [[ $file_size -gt $max_bytes ]]; then
        print_step "Rotating log file..."
        
        # Rotate existing logs
        for ((i=max_files-1; i>=1; i--)); do
            if [[ -f "${log_file}.$i" ]]; then
                mv "${log_file}.$i" "${log_file}.$((i+1))"
            fi
        done
        
        # Move current log
        mv "$log_file" "${log_file}.1"
        touch "$log_file"
        
        # Remove old logs
        for ((i=max_files+1; i<=10; i++)); do
            rm -f "${log_file}.$i"
        done
        
        print_success "Log rotated successfully"
    fi
}

# Performance monitoring
monitor_performance() {
    local duration="${1:-60}"
    local interval="${2:-5}"
    local output_file="$BUILD_DIR/performance-$(date +%Y%m%d-%H%M%S).log"
    
    print_step "Monitoring system performance for ${duration}s..."
    
    {
        echo "Performance monitoring started at $(date)"
        echo "Duration: ${duration}s, Interval: ${interval}s"
        echo "========================================="
        echo
        
        for ((i=0; i<duration; i+=interval)); do
            echo "Timestamp: $(date)"
            echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
            echo "Memory Usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
            echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
            echo "---"
            sleep $interval
        done
    } > "$output_file" &
    
    local monitor_pid=$!
    
    # Return the PID so it can be stopped if needed
    echo $monitor_pid > "$BUILD_DIR/.monitor.pid"
    print_info "Performance monitoring started (PID: $monitor_pid)"
    print_info "Output: $output_file"
}

# Stop performance monitoring
stop_performance_monitor() {
    local pid_file="$BUILD_DIR/.monitor.pid"
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$pid_file"
            print_success "Performance monitoring stopped"
        else
            print_warning "Performance monitor was not running"
            rm -f "$pid_file"
        fi
    else
        print_warning "No performance monitor PID file found"
    fi
}


check_dependencies() {
    local args=("$@")
    local missing=()

    for name in "${args[@]}"; do
        if dpkg -s "$name" &>/dev/null; then
            print_success "$name is installed."
        elif command -v "$name" &>/dev/null; then
            print_success "$name command is available."
        else
            print_warning "$name is missing."
            missing+=("$name")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        print_success "All dependencies fulfilled."
    else
        print_warning "Installing missing dependencies: ${missing[*]}"
        sudo apt update
        sudo apt install -y "${missing[@]}" || {
            print_warning "Some dependencies could not be installed."
            return 1
        }
    fi
}

