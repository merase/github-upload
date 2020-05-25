#!/bin/sh

: <<=cut
=script
This step configure NTP on the current node.
=version    $Id: configure_NTP.1.sh,v 1.11 2018/01/26 08:22:19 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local my_etc="$STP_etc_dir"

: <<=cut
=func_int
Append a ip translation to the host file. If the ip already exists it is appended
otherwise added.
=cut
function append_host() {
    local ip="$1"   # (M) The IP address to append
    local name="$2" # (M) The host name to append

    [ -z help ] && show_short="Add or append the $ip/$name combination to $OS_hosts"
    [ -z help ] && show_trans=0

    local line=$(grep "^$ip" $OS_hosts)
    if [ "$(echo -n "$line" | grep "$name")" != '' ]; then
        log_debug "The combination $ip/$name is already available skipping"
        return
    fi

    if [ "$line" != '' ]; then
        cmd_hybrid "Append hosts '$name' to '$ip'" "$CMD_sed -i -e 's/^\($ip.*\)\$/\1 $name/' $OS_hosts"
    else
        echo -e "$ip\t$name" >> $OS_hosts
    fi
}

if [ "$GEN_ntp_server" == '' ]; then    #= ntp_server not set
    log_info "Skip NTP setup, as [$sect_generic]ntp_server='' is not defined"
else
    if [ $OS_ver_numb -ge 70 ]; then        #= RHEL >= 7.0 
        # Make sure it is disabled (if still isntalled).
        func $IP_OS set_autostart off chronyd
    fi

    func service stop ntpd
    
    # Copy the template file to the real NTP config file. THis is kind
    # of dirty but was used by lnxfg
    if [ -f "$OS_cnf_ntp" ] && [ ! -f "$OS_cnf_ntp.org" ]; then # Safe original only once
        cmd 'Safe original NTP cnf' $CMD_cp "$OS_cnf_ntp" "$OS_cnf_ntp.org"
    fi
    local our_cnf=$(get_best_file "$my_etc/ntp" '' '' '' '' 'conf')
    if [ "$our_cnf" == '' ]; then
        log_warning "Did not find NTP template, NTP might not work properly"
    else
        cmd 'Copy our NTP cnf' $CMD_cp "$our_cnf" "$OS_cnf_ntp"
    fi

    # Now find out if we are an OAM node. The OAM nodes are used as local
    # NTP servers for all the other device nodes
    # This take the lnxcfg approach and defines ip address in the host
    # currently there is no replace in the host files (could be added)
    is_substr $hw_node "$dd_oam_nodes"
    if [ $? != 0 ]; then
        log_info "NTP configuration for a MGR/OAM Node"
        append_host "$GEN_ntp_server" 'ntpserver1'
        # Don't think this is needed
        # timeappend_host "$dd_oam_ip" 'ntpeerA'
    else    # Any other node is seen as Device Node
        log_info "NTP configuration for a Device Node"
        IFS=' '
        local idx=1
        for i in $dd_oam_nodes
        do
            select_oam_ip "$i"
            append_host "$sel_ip" "ntpserver$idx"
            ((idx++))
        done
        IFS=$def_IFS
        append_host "$GEN_ntp_server" "ntpserver$idx"
    fi

    # Create/Add the step ticker file for the initial ntpdate sync
    if [ -f "$OS_ntp_step_tickers" ] && [ ! -f "$OS_ntp_step_tickers.org" ]; then # Safe original only once
        cmd 'Safe original NTP step tickers file' $CMD_cp "$OS_ntp_step_tickers" "$OS_ntp_step_tickers.org"
    fi
    cat > $OS_ntp_step_tickers << EOF
# List of servers used for initial synchronization.
# Initially created by automate.

$GEN_ntp_server
EOF
    check_success 'Created NTP step ticker file' "$?"

    if [ $OS_ver_numb -lt 60 ]; then        #= RHEL < 6.0 
        cmd 'No service yet do manually' ntpdate $GEN_ntp_server
    else
        func service restart ntpdate
    fi

    # Start and start output, with verify_NTP there will be more validation
    func $IP_OS set_autostart on ntpd
    func service start ntpd
    cmd 'Validate NTP' ntpq -p
fi

return $STAT_passed
