#!/bin/sh

: <<=cut
=script
This step will reboot the the machine (system/server will restart again)
=version    $Id: reboot_machine.1.sh,v 1.8 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local what="$1"     # (O) Default to normal, or use if_none_yet, always which cannot be skipped

what=${what:-normal}
check_in_set "$what" 'normal,if_none_yet,always,restore_runlevel'

if [ "$what" == 'restore_runlevel' ]; then
    set_runlevel_after_reboot restore
elif [ "$what" != 'always' ]; then    
    if [ "$STR_skip_reboot" == '1' ]; then
        log_info "Skipping reboot upon configured request."
        return $STAT_skipped
    fi
    if [ "$what" == 'if_none_yet' -a "$STR_rebooted" != '' -a "$STR_rebooted" != '0' ]; then #= <what> == 'if_none_yet' ] and [ none pending 
        log_info "No reboot required as it has been rebooted already ($STR_rebooted)."
        return $STAT_skipped
    fi
fi

#=skip_control
local wait=30
if [ $FLG_cons_enabled == 1 ]; then    # If console wait shortly not time to interrupt anyhow
    wait=5
fi
log_wait "System reboot requested ($what)" $wait

# This is a funny approach as the step should be marked passed before the actual
# execution. 
finish_step $STAT_reboot          # finish the step
cmd "Rebooting the system ($what)" shutdown -r now

# In case we come here bail out, perhaps this should be beautified.
log_screen_info '' "Exiting as reboot was requested"
exit 0