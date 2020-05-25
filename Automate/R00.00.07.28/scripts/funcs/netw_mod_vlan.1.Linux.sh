#!/bin/sh

: <<=cut
=script
This function is capable of deleting or adding a vlan tagged interface.
=version    $Id: netw_mod_vlan.1.Linux.sh,v 1.2 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local what="$1"     # (M) What todo etiehr 'add' or 'del'
local name="$2"     # (M) The bond/eth name to ad, e.g. bond0 or eth0 excluding VLAN tag
local vlan_id="$3"  # (M) The VLAN tag
local ipaddr="$4"   # (O) The IP address to assign to this bond. currently IPv4 only
local netmask="$5"  # (O) The Network mask use

# Some simple sanity checks
check_in_set "$what"    'add,del'
check_set    "$name"    'name not given'
check_set    "$vlan_id" 'VLAN tag not given'

local vintfc=${name}.${vlan_id}
local v_ifcfg=$OS_nwconfig_path/ifcfg-$vintfc

if [ "$what" == 'del' ]; then
    #
    # Delete if needed
    #
    if [ -f $v_ifcfg ]; then
        log_warning "VLAN tagged network '$vintfc' already exists, will be removed first"
        cmd '' $CMD_ifdown $vintfc
        log_info "Old contents of '$v_ifcfg':$nl$(cat $v_ifcfg)"
        cmd '' $CMD_rm $v_ifcfg
    fi
    return 0
fi

#
# This is the add part
#
check_set "$ipaddr"  'ipaddr not given'
check_set "$netmask" 'netmask not given'

func netw_vfy_intf $vintfc 'A'      # non-existent (to be added)

# Currenly we onyl support ipv4 addresses no extensive checks yet
if [ "$ipaddr" == 'dhcp' ]; then
    log_exit "DHCP not supported"
fi

# Bonded vlan does not have a mac address
local macaddr
if [[ "$name" =~ ^eth ]]; then
    func netw_get_macaddrr $eth
    macaddr="$func_return"
fi

log_info "Configuring $vintfc ..."
echo "DEVICE=$vintfc
$macaddr
BOOTPROTO=static
IPADDR=$ipaddr
NETMASK=$netmask
ONBOOT=yes
VLAN=yes" > $v_ifcfg

cmd "Configured $vintfc ..." $CMD_ifup $vintfc

func netw_vfy_intf $vintfc 'D'        # Should now exist

return 0