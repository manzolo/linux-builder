create_network_config() {
    print_step "Creating network configuration..."
    
    # /etc/hosts
    cat > etc/hosts << EOF
127.0.0.1    localhost $HOSTNAME
127.0.1.1    $HOSTNAME
::1          localhost ip6-localhost ip6-loopback
ff02::1      ip6-allnodes
ff02::2      ip6-allrouters
EOF

    # /etc/hostname
    echo "$HOSTNAME" > etc/hostname
    
    # DHCP client script
    create_dhcp_script
}

create_dhcp_script() {
    mkdir -p etc/udhcpc
    cat > etc/udhcpc/default.script << 'EOF'
#!/bin/sh
# DHCP client configuration script

[ -z "$1" ] && echo "Error: should be called from udhcpc" && exit 1

RESOLV_CONF="/etc/resolv.conf"
RESOLV_CONF_BAK="/etc/resolv.conf.bak"

[ -n "$broadcast" ] && BROADCAST="broadcast $broadcast"
[ -n "$subnet" ] && NETMASK="netmask $subnet"

case "$1" in
    deconfig)
        echo "Deconfiguring network interface $interface"
        /sbin/ifconfig $interface 0.0.0.0
        while route del default gw 0.0.0.0 dev $interface 2>/dev/null; do :; done
        ;;
    renew|bound)
        echo "Configuring network interface $interface"
        /sbin/ifconfig $interface $ip $BROADCAST $NETMASK
        
        if [ -n "$router" ]; then
            echo "Setting default gateway to $router"
            while route del default gw 0.0.0.0 dev $interface 2>/dev/null; do :; done
            route add default gw $router dev $interface
        fi
        
        echo "Updating DNS configuration"
        [ -f "$RESOLV_CONF" ] && mv "$RESOLV_CONF" "$RESOLV_CONF_BAK"
        [ -n "$domain" ] && echo "search $domain" > "$RESOLV_CONF"
        for dns_server in $dns; do
            echo "nameserver $dns_server" >> "$RESOLV_CONF"
        done
        
        echo "Network configured: IP=$ip, Gateway=$router, DNS=$dns"
        ;;
esac
exit 0
EOF
    chmod +x etc/udhcpc/default.script
}
