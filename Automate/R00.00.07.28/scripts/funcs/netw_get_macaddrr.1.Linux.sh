#!/bin/sh

: <<=cut
=script
This function retrieves the mac address. Either from existing ifconfig file
or from the ifconfig.
=ret
The MAC-Address in the form of HWADD=00:00:00... Emtpy it not found.
=version    $Id: netw_get_macaddrr.1.Linux.sh,v 1.2 2015/01/22 13:49:12 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local name="$1"     # (M) The interface name to get the MAC address  for.

check_set "$name" 'interface name not given'

#
# Add Ethernet interface without VLAN-tag
#
local ifcfg=$OS_nwconfig_path/ifcfg-$name
func_return=''
if [[ -f $ifcfg ]]; then
    func_return=$($CMD_grep HWADDR $ifcfg)
fi
if [[ ! "$func_return" ]]; then
    func_return="HWADDR=$($CMD_ifconfig $name | $CMD_gawk '/HWaddr/ {print $5}')"
fi
