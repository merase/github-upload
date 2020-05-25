#!/bin/sh

: <<=cut
=script
This function verifies if a interface (which can be a bond) is correctly
configured.
=script_note 
Its original source was taken from the lnxcfg, but has been adapted for the automate usage.
=ret func_return
A status value:
A - should be added
D - exists could be deleted
X - unknown error
=version    $Id: netw_vfy_intf.1.Linux.sh,v 1.2 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local intf="$1"     # (M) The inteerface name to verify e.g. bond0 or bond0.1129
local outcome="$2"  # (O) If set to expectd outomce  then error checking is enforced, 
                
log_info "Testing $intf ..."

func_return=X
local b_ifcfg=$OS_nwconfig_path/ifcfg-$intf
local ifstatus=$($CMD_ip -o -4 addr show $intf 2>/dev/null)
if [[ $? -eq 0 ]]; then
    [[ $ifstatus ]] && func_return=D || func_return=A
else
   func_return=X
fi

# Not all thing check for all types
case $intf in
    bond[0-9])
        [[ $($CMD_grep bond $b_ifcfg 2>/dev/null) ]] && func_return=D
        [[ $($CMD_grep dhcp $b_ifcfg 2>/dev/null) ]] && func_return=D
        ;;
    *)
        [[ $($CMD_grep dhcp $b_ifcfg 2>/dev/null) ]] && func_return=D
        ;;
esac

if [ "$outcome" != '' ]; then
    if [ "$func_return" == "$outcome" ]; then
        log_info "Success ..."
    else
        log_exit "Unexpected outcome ($func_return != $outcome) verifying interface ($intf)"
    fi
else
    log_info "Outcome for $intf -> $func_return"
fi
if [ "$func_return" == 'D' ]; then
    cmd 'Info' $CMD_ip addr show $intf
fi
