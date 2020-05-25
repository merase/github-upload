#!/bin/sh

: <<=cut
=script
This step will shutdown the machine (system/server will not restart by itself).
=brief Machine will be shutdown after a short waiting period.
=version    $Id: shutdown_machine.1.sh,v 1.12 2017/12/13 14:14:56 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local extra="$1"    # Any extra task to execute before the shutdown (e.g. store_state)

check_in_set "$extra" "'',store_state,for_kernel_update,support_rollback_with_kernel_change"

#=* It is possible to skip the shutdown for a given extra task.
#=- This is done by setting $STR_skip_shutdown;
#=- Which can be a space separated list of the <extra> values;
#=- Whever <extra> is in the list it will reboot or directly go ro runlvl 1;
#=- Basically removing the option to spilt disks;
#=- The default is to execute the 'normal procedure';
#=- This is for advanced usage only!
#=skip_control
local skip=0
if [ "$extra" != '' ]; then
    is_substr "$extra" "$STR_skip_shutdown"
    if [ $? == 1 ]; then skip=1; fi
fi

if [ $skip == 0 ]; then     #= normal procedure
    log_wait "System shutdown requested" 30
fi


# This is a funny approach as the step should be marked passed before the actual
# execution

STR_shutdown_info="$extra"      # Store potential extra info for recovery after OS install
finish_step $STAT_shutdown    # finish the step

case "$extra" in
    'store_state')
        func store_boot_data
        # We want to prevent o an accidental reboot without recover of the state
        # would continue unwanted step. We prevent this by removing the current
        # storage file. The current storage should be recovered when needed
        # The just stored data should not be recovered because we make sure the
        # .download_data file exists.
        if [ -f "$AUT_store_file" ]; then
            cmd 'Remove current storage file to prevent accidental continue' $CMD_rm $AUT_store_file
        fi
        if [ ! -f $boot_copied ]; then
            echo "Created to prevent accidental continue" > $boot_copied
        fi
        ;;
    'support_rollback_with_kernel_change')
        # Do not remove the data file but flag the kernel version
        # If automate find the same kernel version then it may not continue@
        STR_prev_kernel_version="$(uname -r)"
        func store_boot_data
        ;;
    'for_kernel_update')
        set_runlevel_after_reboot 1
        ;;
esac

if [ $skip == 0 ]; then     #= normal procedure
    if [ "$extra" != 'for_kernel_update' ]; then
        if [ "$OS" != "$OS_linux" ] || [ $OS_ver_numb -lt 70 ]; then  
            # Old <= RHEL6 behavior
            # I still don't understand why and what the shutdown -i0 -g0 -y is meant to
            # do however it does not work in case the runlevel is set one (drop to rl1)
            cmd 'Shutting down the system' shutdown -i0 -g0 -y
        else
            # Fro RHEL7 >= the above does not work anymore, use this instead
            cmd 'Shutting down the system' shutdown -h now
        fi
    else
        # To prevent accidental start of the tool, moving this file secondary storage
        if [ -f "$AUT_store_file" ] && [ $AUT_store_file == $AUT_pref_store_file ]; then
            cmd 'moving the current storage file' $CMD_mv $AUT_store_file $BCK_link_dir/tpbackup
            echo "$BCK_link_dir "
        fi
        cmd 'Shutting down the system' shutdown -h now
    fi
else
    if [ "$extra" != 'for_kernel_update' ]; then
        log_warning "Skipping shutdown upon request, rebooting instead"
        execute_step 0 'reboot_machine always'
    else
        log_screen_info '' "Skipping shutdown upon request (no disk removal), going to run-level 1"
        cmd 'Going to run-level 1' init 1
        exit 0
    fi
fi

# In case we come here bail out, perhaps this should be beautified.
log_screen_info '' "Exiting as shutdown was requested"
exit 0
