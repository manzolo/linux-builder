# Compile BusyBox
compile_busybox() {
    print_header "Compiling BusyBox"

    if [[ ! -f "$BUSYBOX_BUILD_DIR/.config" ]]; then
        print_error "BusyBox non è stato configurato. Si prega di configurarlo prima."
        read -p "Premi INVIO per continuare..."
        return 1
    fi

    cd "$BUSYBOX_SOURCE_DIR" || return 1

    # Controlla lo spazio su disco
    if ! check_disk_space 1; then
        return 1
    fi

    local cores=$(nproc)
    local start_time=$(date +%s)

    print_step "Avvio della compilazione di BusyBox..."
    print_info "Utilizzo di $cores job paralleli"
    print_info "Questa operazione dovrebbe richiedere solo pochi minuti"
    echo

    # Log della compilazione
    {
        echo "Compilazione di BusyBox iniziata il $(date)"
        echo "Versione: $BUSYBOX_VERSION"
        echo "Job paralleli: $cores"
        echo "========================================"
    } >> "$LOG_FILE"

    # Nuova pipeline con visualizzazione su una sola riga
    if make -j"$cores" O="$BUSYBOX_BUILD_DIR" 2>&1 | tee -a "$LOG_FILE" | \
        stdbuf -o0 grep -E ' (CC|AR|LD|GEN|SYMLINK).*' | \
        while read -r line; do
            # Pulisce la riga precedente e stampa la nuova
            echo -ne "\r${CYAN}Building BusyBox: ${line:0:70}...${NC}\033[K"
        done; then

        echo -ne "\r\033[K" # Pulisce la riga dopo la barra di avanzamento
        print_success "BusyBox compilato con successo!"

        # Verifica il linking statico
        if file "$BUSYBOX_BUILD_DIR/busybox" | grep -qi static; then
            print_success "BusyBox è collegato in modo statico (ottimo!)"
        else
            print_warning "BusyBox non è collegato in modo statico"
            print_info "Questo potrebbe causare problemi in ambienti minimali"
        fi
        # Conta gli applet disponibili subito dopo la compilazione
        if [[ -x "$BUSYBOX_BUILD_DIR/busybox" ]]; then
            applet_count=$("$BUSYBOX_BUILD_DIR/busybox" --list 2>/dev/null | wc -l || echo 0)
            print_info "📦 BusyBox applets disponibili: $applet_count"
        else
            print_warning "Impossibile contare gli applet: binario non trovato"
        fi        

    else
        echo -ne "\r\033[K" # Pulisce la riga anche in caso di errore
        print_error "La compilazione di BusyBox è fallita!"
        print_info "Controlla il file $LOG_FILE per informazioni dettagliate sull'errore"
        cd "$CUR_DIR" || return 1
        return 1
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    print_success "Compilazione completata in ${minutes}m ${seconds}s"

    cd "$CUR_DIR" || return 1
    read -p "Premi INVIO per continuare..."
}