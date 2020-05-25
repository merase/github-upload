#!/bin/sh

: <<=cut
=script
This step configure the system Configuration.
=le SCTP configuration
=le Core parameters for high traffic elements
=brief Configure System Parameters: SCTP and high traffic elements.
=version    $Id: configure_Sys-Params.1.sh,v 1.11 2017/09/13 09:33:35 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

#
# The SCTP changes are always done
#
modify_sectioned_config $OS_cnf_sysctl '' 'net.sctp.hb_interval' 1000 "# Set SCTP heartbeat to 1 second"

is_component_selected "$hw_node" "$C_MGR"
if [ $? != 0 ]; then
    modify_sectioned_config $OS_cnf_sysctl '' 'net.ipv4.tcp_keepalive_time' 1800
    modify_sectioned_config $OS_cnf_sysctl '' 'net.ipv4.tcp_keepalive_intvl' 30
    modify_sectioned_config $OS_cnf_sysctl '' 'net.ipv4.tcp_keepalive_probes' 9
fi 

#
# The High traffic throughput changes only if the entity wants it
#
local high_tp_comp="$(map_find_maps_with_key $map_cfg_ins $INS_col_high_tp | tr ',' '\n')"
local high_tp="$(echo "$dd_components" | $CMD_ogrep "$high_tp_comp")"
if [ "$high_tp" != '' ]; then   #= Any component requiring high throughput [AMS, HUB, IIW, RTR, SSI]
    log_info 'Element contains high throughput components making net.core adjustments'

    modify_sectioned_config $OS_cnf_sysctl '' 'net.core.rmem_max' 8388608 "# Settings high throughput element"
    modify_sectioned_config $OS_cnf_sysctl '' 'net.core.wmem_max' 8388608
    modify_sectioned_config $OS_cnf_sysctl '' 'net.core.rmem_default' 1310710
    modify_sectioned_config $OS_cnf_sysctl '' 'net.core.wmem_default' 1310710
fi

# Enable suid_dumpable as workaround for 15.4 till 16.0 (excl), 
# Do it based on RH release as NMM verison might still be unknonw!
if [ "$OS" == "$OS_linux" ] && [ $OS_ver_numb -ge 60 ] && [ $OS_ver_numb -lt 70 ]; then  
    modify_sectioned_config $OS_cnf_sysctl '' 'fs.suid_dumpable' 1  "# Core-dump workaround, needed until 16.0"
fi

# Seem to be added in 15.0 and spotted from 16.0 manual, added in automate
modify_sectioned_config $OS_cnf_sysctl '' 'vm.dirty_expire_centisecs'    200 '# Virtual Memory Tuning'
modify_sectioned_config $OS_cnf_sysctl '' 'vm.dirty_writeback_centisecs' 100

# Make sure sysctl parameter are always read. 
text_add_line $OS_rc_startup, 'sysctl -p '

#
# Use the -e option as standard option net.bridge.bridge-nf* give errors.
# this has change in RHEL6 as they are used later on.
cmd 'Make new system pars effective' $CMD_sysctl -e -p $OS_cnf_sysctl

return $STAT_passed
