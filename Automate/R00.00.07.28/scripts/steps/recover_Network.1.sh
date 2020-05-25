#!/bin/sh

: <<=cut
=script
This step recovers the Network setup from previous system after an OS installation.
=brief Recovers the Network setup after from an overwritten OS.
=fail
All command are need. Only at the very last the host-name is set.
Only skip this step if you are sure the default gateway is reachable.
=version    $Id: recover_Network.1.sh,v 1.12 2017/10/27 12:22:50 fkok Exp $
=author     Frank.Kok@newnet.com

=feat configure easy network
During the process the easy network will be configured. Which will setup the 
configured interface and will allow for network access to the system.
Depending on the customer layout additional configuration might be needed.

=cut

#
# See if fixes has to be applied, see called function for more info.
#
func OS analyze_and_fix_network_changes

#
# Mandatory parameter checking
#
local added=0
local prefix='NTW'
process_section_vars "$hw_node" "${prefix}_"
check_set "$NTW_host" "Host-name not defined for [$hw_node]"

#
# Recover the main files
#
recover_files $IP_OS 'backup' 'etc/sysconfig/network'                 /
recover_files $IP_OS 'backup' 'etc/sysconfig/network-scripts/ifcfg-*' /
recover_files $IP_OS 'backup' 'etc/sysconfig/network-scripts/route-*' / '' 'optional'

#
# Check for bonded devices, this is not needed for REHL7+ recognised by the 
# fact bondig config fiel is not avialable
#
if [ "$OS_cnf_modp_bonding" == '' ]; then
    log_info "Bonding config file recovery is not needed on this OS version, skipping."
else
    local aliases=''
    recover_files $IP_OS 'backup' "${OS_cnf_modp_bonding:1}"              /tmp '' 'optional'
    if [ $? != 0 ]; then
        log_info "No '$OS_cnf_modp_bonding' found, recovering from network scripts"
        #=* Find all $OS_nwconfig_path/ifcfg-bond* without vlan tag .<tag> in it
        #=- 
        local file
        for file in $OS_nwconfig_path/ifcfg-bond*; do
            file=$(basename $file)
            if [ "$(echo -n "$file" | cut -d '.' -f2)" == '' ]; then #= file is base bond not vlan tagged (having .<id>
                file=$(echo -n "$file" | cut -d '-' -f2)
                #=# Add to $aliases list as: alias $file bonding
                aliases+="alias $file bonding$nl"
            fi
        done
    else
        log_info "Getting bonded aliases from '$OS_cnf_modp_bonding'"
        local cnf="/tmp/$(basename $OS_cnf_modp_bonding)"
        if [ -f "$cnf" ]; then
            #=# Set $aliases to: grep 'alias' "$cnf"
            local aliases="$(grep 'alias' "$cnf")"
        fi
    fi
    
    if [ "$aliases" != '' ]; then #= Boding aliases found
    # No backup in same directory, gives a warning
    #    if [ -f "$OS_cnf_modp_bonding" ]; then
    #        cmd 'Backup existing bonding cnf' $CMD_mv "$OS_cnf_modp_bonding" "$OS_cnf_modp_bonding.bck"
    #    fi
        echo "$aliases" > $OS_cnf_modp_bonding
        check_success 'Wrote new info modprobe bonding file' "$?"
    fi
fi

#
#=* Sanity check for 'incorrect' network configurations
#=inc_indent
#= We have seen that to many system has incorrect/incomplete configurations
#= which do not cause problems at RH5.7(x) but are restricted in RH6.5(x) and
#= causing the $? of service network restart to give a none 0 value. To prevent
#= problem w'll allow failures and continue if any (with warning).
#=dec_indent
set_cmd_user '' '' 'allow_failure'
cmd '' service network restart
if [ "$AUT_cmd_outcome" != '0' ]; then  #= network restart not fully successful
    log_screen_info '' "Network start not fully successful.${nl}This might be due to stricter checking, extra info:$nl$(cat $LOG_cmds)"
    log_warning "Continuing, problems might occur, check network-config afterwards!" 30  
fi
default_cmd_user

#
# Verification, into log file
#
cmd 'Saving output for reference' $CMD_ifconfig -a

#
# All device should be set with ONBOOT="yes" otherwise they will not start after
# a reboot. This is currently assumed.
#

#
# Set the hostname
#
set_hostname $NTW_host

#
# Verify the default GW (any), wait until reachable
#
func netw_vfy_def_gw


return $STAT_passed

