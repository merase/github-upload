#!/bin/sh

: <<=cut
=script
This function verifies if the default gateway is reachable. This becuase it
may take a before it is reachable after the intial configuration.
=version    $Id: netw_vfy_def_gw.1.Linux.sh,v 1.5 2015/06/16 08:52:22 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local def_gw="$1"   # (O) The expected default gateway. leave empty if current is to be taken

# The gateway should be set already
eval $($CMD_route -n | $CMD_gawk '/^(0.0.0.0|default)/ {print "ACTIVE_DEF_RT_IP="$2";ACTIVE_DEF_RT_FLAGS="$4";ACTIVE_DEF_RT_INTF="$8}')
if [ "$ACTIVE_DEF_RT_IP" != '' ]; then
    if [ "$def_gw" != '' -a "$def_gw" != "$ACTIVE_DEF_RT_IP" ]; then
        log_exit "Current default gateway ($ACTIVE_DEF_RT_IP) is different then expected ($def_gw), failed."
    else
        def_gw="$ACTIVE_DEF_RT_IP"
    fi
else
    # This is warning and not an exit as some system might not have a default gateway defined
    log_warning "No default gateway defined, skipping verification"
    return
fi

# I takes a while before the gateway is reachable seen 30 seconds. This cause
# the initial trial to fail because it assume the network was available directly
# therefore wait at most 2 minutes (try 60 times). It will stop once it found the host
log_info "Waiting until default gw ($def_gw) is reachable ..."
local tries=30
local reach=''
while [ "$tries" -gt '0' ]; do
    reach=`$CMD_ping -c1 -q $def_gw -W 2 | grep " 0% packet loss"`
    if [ "$reach" != '' ]; then break; fi
    # Next try using arping in case ping is blocked completely
    if [ "$ACTIVE_DEF_RT_INTF" != '' ]; then
        reach=$($CMD_arping -w 2 $def_gw -I $ACTIVE_DEF_RT_INTF | grep 'response(s)' | cut -d' ' -f2)
        if [ "$reach" != '' -a "$reach" != '0' ]; then break; fi
    fi
    if [ $tries == 15 ]; then
        log_screen_info '' "Verifying gateway is taking longer then expected.${nl}Pings to gateway might be blocked.${nl}Please wait some more..."
    fi
    ((tries--))
done

if [ "$reach" == '' ]; then
    # If the route table says up then just accept is and see where it ends
    if [ "$(echo "$ACTIVE_DEF_RT_FLAGS" | grep 'U')" != '' ]; then
        log_info "Accepting default gateway ($def_gw) as it is up ($ACTIVE_DEF_RT_FLAGS)."
        log_warning "Could not verify default gateway ($def_gw) not pingable? Continue as its route is up."
    else
        log_exit "Default gateway ($def_gw) not reachable"
    fi
else
    log_info "Default gateway ($def_gw) is now reachable, continuing"
fi

return 0