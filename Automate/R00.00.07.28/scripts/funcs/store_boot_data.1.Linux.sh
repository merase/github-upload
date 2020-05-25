#!/bin/sh

: <<=cut
=script
This function will store or clean the boot data on the first available none 
boot disk. In store mode this should only be called right before a new OS is 
installed which will wipe out the current automate data (in /var).

Before storing the data all disk are checked for the automate boot directory
and if one exits it will be removed. This to prevent that the wrong boot data
will be used. 
=script_note
The auto recover will of-course only work if the given disk is still mountable
after a reboot (with its data intact).

This function probably need rework for multiple systems (but it might work).
=version    $Id: store_boot_data.1.Linux.sh,v 1.9 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local what="$1" # (O) set to clean if only cleanup is requested

local mnt_dir=''

if [ "$what" != 'clean' ]; then # see if an existing and writable disk can be found
    func copy_boot_data mount
else
    AUT_boot_data_dev=''        # Clean all
fi

# First make sure all automation dirs are gone on all disk (safety precaution)
# This also find the directory to install it on (first match)
local dev
local store_dir=''
for dev in $AUT_boot_data_dev $OS_nb_devs; do
    if [ $dev != "$AUT_boot_data_dev" ]; then
        dev="$dev${OS_part_pfx}1"       # Only use 1st main partition
    fi
    if [ -e $dev ]; then
        mnt_dir="$(get_mnt_for_filesys "$dev")"
        if [ "$mnt_dir" == '' ]; then  continue; fi # Not mounted, skip
        local tdir="$mnt_dir/$AUT_boot_data_dir"
        if [ $dev != "$AUT_boot_data_dev" ] && [ -d "$tdir" ]; then
            # Use rotat_file (will work for directories as well) to keep a backup and remove current (keep only 5)
            # This just in case somebody left an USB mounted unwanted.
            rotate_files "$tdir"                        5
            rotate_files "$mnt_dir/$AUT_down_data_dir"  5
            rotate_files "$mnt_dir/$AUT_upgr_data_dir"  5
        fi
        if [ "$what" != 'clean' -a "$store_dir" == '' ]; then   # Now try to (re)create
            $CMD_mkdir "$tdir"
            if [ -d "$tdir" ]; then store_dir="$tdir"; fi
        fi
    fi
done

if [ "$what" == 'clean' ]; then # finished in case of clean
    return 0
fi

# Execute some checks before we can guarantee a proper automation information
check_set "$store_dir"      "Did not find any safe disk to store automate data files."
check_set "$AUT_store_file" "No current store file defined."
check_set "$STR_data_file"  "No current data file loaded."
check_set "$STR_step_file"  "No current step file loaded."

log_info "Storing automate data in: '$store_dir'"

local etc="$store_dir/etc"
cmd '' $CMD_mkdir "$etc"
cmd '' $CMD_cp -H "$AUT_store_file" "$etc/$AUT_store_script"
cmd '' $CMD_cp -H "$STR_data_file"  "$etc/$(basename $STR_data_file)"
cmd '' $CMD_cp -H "$STR_step_file"  "$etc/$(basename $STR_step_file)"

# See if we can save some log files (only current ones)
local log="$store_dir/log"
cmd '' $CMD_mkdir "$log"
cmd '' $CMD_cp "$LOG_screen_cpy"    "$log/$(basename $LOG_screen_cpy)"
cmd '' $CMD_cp "$LOG_file"          "$log/$(basename $LOG_file)"
if [ -e "$LOG_warn_cpy" ]; then     # Keep warning file if existing
    cmd '' $CMD_cp "$LOG_warn_cpy"  "$log/$(basename $LOG_warn_cpy)"
fi

if [ "$what" != 'clean' ]; then 
    func copy_boot_data unmount  # unmount if needed.
fi

return 0
