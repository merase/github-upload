#!/bin/sh

: <<=cut
=script
This step configure the IP routing settings. 
=version    $Id: configure_IP-Routing.1.sh,v 1.6 2017/11/21 13:10:51 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

function save_original_iptable() {
    local table="$1"    # (M) an iptable to save

    if [ -e "$table" ]; then
        if [ ! -e "$table.org" ]; then
            cmd 'Saving a copy once' $CMD_mv "$table" "$table.org"
        else
            log_info "Copy available in $table.org, removing $table, contents:$nl$(cat "$table")"
        fi
        echo "# Empty file, configure as needed, see $table.org" > "$table"
    else
        echo "# Empty file, configure as needed" > "$table"
    fi
}

# Turning off iptables/ip6tables.
func service disable iptables
func service disable ip6tables

log_info "Enabling IPv6 networking."
cmd '' $CMD_sed '/NETWORKING_IPV6/d' -i $OS_cnf_network
text_add_line $OS_cnf_network 'NETWORKING_IPV6=yes' 'NETWORKING_IPV6=.*'

STR_rebooted=0      # New reboot advised

# RHEL 7 comes with a default iptables file. But this block some of our
# required communication. So backup the file. If backup does not exist.
# Create an empty file. I also made it possible to disable the ip[6]tables
# by a variable in [generic] section. However if not defined then the default
# is enable them.
if [ "$GEN_disable_iptables" == '' ]; then
    save_original_iptable "$OS_sysconfig/iptables"
    func service enable iptables
    func service start  iptables
fi
if [ "$GEN_disable_ip6tables" == '' ]; then
    save_original_iptable "$OS_sysconfig/ip6tables"
    func service enable ip6tables
    func service start  ip6tables
fi

return $STAT_passed
