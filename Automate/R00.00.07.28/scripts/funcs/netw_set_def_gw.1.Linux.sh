#!/bin/sh

: <<=cut
=script
This function set the default gateway for all network interfaces.
=script_note
Its original source was taken from the lnxcfg, but has been adapted for the automate usage.
=version    $Id: netw_set_def_gw.1.Linux.sh,v 1.5 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local def_gw="$1"   # (M) The default gateway to configure

check_set $def_gw 'The default gateway is a mandatory parameter'

# Just a safety check if it alreayd exist (which it should not)
eval $($CMD_route -n | $CMD_gawk '/^(0.0.0.0|default)/ {print "ACTIVE_DEF_RT_IP="$2";ACTIVE_DEF_RT_INTF="$8}')
if [[ "$ACTIVE_DEF_RT_IP" ]]; then
    log_warning "Default route $ACTIVE_DEF_RT_IP already exists on $ACTIVE_DEF_RT_INTF"
    if [ "$def_gw" != "$ACTIVE_DEF_RT_IP" ]; then
        log_exit "Current default gateway ($ACTIVE_DEF_RT_IP) is different then wanted ($def_gw), failed."
    fi
else
    cmd 'Adding default route' $CMD_route add default gw $GEN_netw_def_gw
    echo "GATEWAY=$GEN_netw_def_gw" >>  $OS_sysconfig/network
fi

#
# Verify the default GW (specified), wait until reachable
#
func netw_vfy_def_gw "$def_gw"

return 0