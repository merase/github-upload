#!/bin/sh

: <<=cut
=script
This step verifies the settings in the grub configuration.
- For G6/G7 system the intremap parameter should be defined and set to off
- If not a warning will be given to manually fix it.
=brief Verify grub.conf settings and warn if incorrect.
=version    $Id: verify_grub_Config.1.Linux.sh,v 1.3 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local ret=$STAT_passed

local cpumodel="$(cat /proc/cpuinfo | grep -m1 'model name' | tr -s ' ' | cut -d ' ' -f 6)" #= identified model
if [ "$cpumodel" == 'E5540' -o "$cpumodel" == 'X5650' ]; then #= this a G6 or G7 system
    log_info "Identified G6 or G7 ($cpumodel), checking interrupt remapping setting."
    if [ "$OS_grub_conf" != '' ]; then #= grub config defined
        local found=0
        if [ -r "$OS_grub_conf" ]; then
            #=# search for intremap on the kernel line and set found with result
            #=skip_control
            local outp="$(cat "$OS_grub_conf" | grep 'kernel' | grep 'intremap')"
            if  [ "$outp" != '' ]; then     # found check if it off
                if [ "$(echo -n "$outp" | grep 'intremap=off')" != '' ]; then
                    found=1
                else
                    log_info "Found intremap but not 'off', '$outp'"
                fi
            else
                log_info "intremap not found in $OS_grub_conf."
            fi
        else
            log_info "No grub config file ($OS_grub_conf) found. Asusming not set."
        fi
        
        if [ $found == 0 ]; then #= intremap is not off
            # Give a warning and manual step. Basically a manual step should be enough
            log_warning "The grub config does not disable intremap, please fix it manually"
            log_manual "Set 'intremap=off' in '$OS_grub_conf'" "The interrupt remapping should be disabled on G6/G7. This is currently
not the case. And has to be fixed manually, after automate is finished.
Use the following steps as a guideline:"
            log_manual '' "Open '$OS_grub_conf' in an editor;"
            log_manual '' "Go-to the line starting with 'kernel';"
            log_manual '' "Make sure 'intremap=off' is added (e.g. behind 'quiet' separated by space);"
            log_manual '' "If already set to 'on' then make sure it is set to 'off';"
            log_manual '' "Save the file;"
            log_manual '' "Reboot the system to activate the parameter."
            
            ret=$STAT_warning
        fi
    else
        log_info "No grub config defined. Running on too new RHEL version($OS_version)?"
        ret=$STAT_not_applic
    fi
fi


return $ret
