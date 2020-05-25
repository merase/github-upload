#!/bin/sh

: <<=cut
=script
Does pre-checking on OS system expectancy.
=brief Validation: Checks if the disk are located as expected, if not give a warning.
=version    $Id: precheck.1.Linux.sh,v 1.6 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# Collect disk requires the hpacucli
add_cmd_require $CMD_da_cli '' 'no_check'
if [ $? != 0 ]; then    # Not found, give warning and then exit
    log_warning "Did not find the tool '$CMD_da_cli' which is need to check the disk state.
If you wait then the tool will continue without checking." 30
    # If we come here then it was not interrupted so give an additional warning for loggin pruposes
    log_warning "The OS disk state check was skipped upon request (missing tool)."
    return $STAT_warning
fi


func OS collect_disks

#=* Whenever [ collected data does not match expected ], meaning: 
#=- $OS_boot_slot         != <[$hw_node]exp_dsk_slot='$OS_exp_dsk_slot'>       or
#=- $OS_boot_logical_drv  != <[$hw_node]exp_dsk_log_drv='$OS_exp_dsk_log_drv'> or
#=- $OS_boot_physical_drv != <[$hw_node]exp_dsk_phy_drv='$OS_exp_dsk_phy_drv'>
#=skip_until_marker
#=- $OS_boot_slot != [$hw_node]exp_dsk_slot='$OS_exp_dsk_slot'
if [ "$OS_boot_slot"          != "$OS_exp_dsk_slot"    ] || 
   [ "$OS_boot_logical_drv"   != "$OS_exp_dsk_log_drv" ] ||
   [ "$COL_boot_physical_drv" != "$OS_exp_dsk_phy_drv" ]; then
#=skip_until_here
    local out="$COL_boot_info

Expected: slot:$OS_exp_dsk_slot, log_drv:$OS_exp_dsk_log_drv, phy_drvs:$OS_exp_dsk_phy_drv
Boot drive at ${COL_warn}unexpected${COL_def} location, to prevent this warning
fix the Automate Data Configuration file.  Under the node section adjust:
[$hw_node]
exp_dsk_slot    = '$OS_boot_slot'
exp_dsk_log_drv = '$OS_boot_logical_drv'
exp_dsk_phy_drv = '$COL_boot_physical_drv'


${COL_blink}${COL_warn}Please remember to take out the proper disks!${COL_def}"
    log_warning "$out" 10
fi                                                                           #=!

return $STAT_passed
