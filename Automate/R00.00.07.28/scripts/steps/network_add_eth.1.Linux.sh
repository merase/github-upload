#!/bin/sh

: <<=cut
=script
This function adds a regular Ethernet interface to the system. Its original source
was taken from the lnxcfg, but has been adapted for the automate usage.
The VLAN tagging is optional.
=fail
In case of failure, check the configuration and try to understand the error.
This script shows the commands to add eth device, which should be similar to 
the old lnxcfg, one could also try other wrapper tools like that to add the 
device as given by the parameters. If this is the OAM/main interface to use then
it is not advised to skipp this step until it is fixed.
=version    $Id: network_add_eth.1.Linux.sh,v 1.3 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local eth="$1"      # (M) The eth name to ad, e.g. eth0 or eth0.1129 including VLAN tag
local ipaddr="$2"   # (M) The IP address to assign to this bond. currently IPv4 only
local netmask="$3"  # (M) The Network mask use

# Some simple sanity checks
check_set "$eth"           'ethernet name not given'
vlan_id=$(get_field 2 "$eth" '_')  # Get vlan if any
eth=$(get_field     1 "$eth" '_')      # Always make sure single ethernet name
check_set "$ipaddr"        'ipaddr not given'
check_set "$netmask"        'netmask not given'


if [ "$vlan_id" != '' ]; then   #= Eth is vlan tagged
    func netw_mod_vlan del $eth $vlan_id
    func netw_mod_vlan add $eth $vlan_id "$ipaddr" "$netmask"

    return $STAT_passed
fi

#
# Add Ethernet interface without VLAN-tag
#
local ifcfg=$OS_nwconfig_path/ifcfg-$eth
if [ -f $ifcfg ]; then
    # An eth normally exists, so do not give a warning, but make it a log_info
    log_info "Ethernet interface '$eth' already exists, will be removed first"
    cmd '' $CMD_ifdown $eth
    log_info "Old contents of '$ifcfg':$nl$(cat $ifcfg)"
    cmd '' $CMD_rm $ifcfg
fi

func netw_get_macaddrr $eth
local macaddr="$func_return"

log_info "Configuring $eth"
echo "DEVICE=$eth
$macaddr
ONBOOT=yes
BOOTPROTO=static
IPADDR=$ipaddr
NETMASK=$netmask" > $ifcfg

cmd "Configured $eth ..." $CMD_ifup $eth

func netw_vfy_intf $eth 'D'        # Should now exist

return $STAT_passed
