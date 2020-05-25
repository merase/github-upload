#!/bin/sh

: <<=cut
=script
This step describes breaking the mirrored OS Disks.
=brief Info: What/which disk to break to split the mirrored OS Disks.
=fail
The step could be skipped, but be aware not splitting the disk will not
allow for the preferred rolback scenario.
=version    $Id: manualy_break_os_disk.1.Linux.sh,v 1.6 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local wait_time="$1"    # (O) The time to wait

if [ "$STR_skip_split_disk" != '' ]; then #= skip splitting requested
    log_warning "Skipping request to split OS disks, upon request.${nl}See Data-file [automate]skip_split_disk='$STR_skip_split_disk'."
    return $STAT_skipped
fi

func OS collect_disks

local ref_man="Be sure to follow the procedure of breaking the mirrored OS disk 
after the shutdown as described in in the upgrade manual."

# We normally take out the 2nd disk
local removed=0
local col=$COL_ok
local disk
local msg
local phy_drv=$(get_field 2 "$COL_boot_physical_drv")
if [ "$phy_drv" == '' ]; then  #= only one physcial drive found
    local msg="$COL_boot_info
    
${COL_fail}Expected at least 2 drives.
cannot determine which drive to take from mirror set.
If you removed the drive already then you could continue at own risk.${COL_def}

$ref_man"
    log_wait "$msg" $wait_time
else
    # Lest do it stupid we should only have 8 physical disks
    #=skip_until_marker
    case $phy_drv in
        1) disk='first'  ; ;;
        2) disk='second' ; ;;
        3) disk='third'  ; ;;
        4) disk='fourth' ; ;;
        5) disk='fifth'  ; ;;
        6) disk='sixth'  ; ;;
        7) disk='seventh'; ;;
        8) disk='eight'  ; ;;
        *) disk='unkown' ; col=$COL_warn; ;;
    esac
    #=skip_until_here
    local msg="The system will be shutdown after this step.
$ref_man
The first steps are shortly described here.
1. If Server type is Gen8/Gen9, then execute following sections 
   of RHEL Upgrade Manual to break mirrored disk remotely:

   . Creating a HTTP Server
   . Creating a split mirror backup

2. If Server type is Gen6/Gen7, execute below steps to break mirror disk:
   . Ensure that the system is fully powered off (orange power led indication)

   . Remove the $col$disk$COL_def disk from the left indicated by the 
     slot number $col$phy_drv$COL_def and store the disk in a safe place following 
     ESD precautions. This Drive will be used as a RollBack option if required."

    log_wait "$msg" $wait_time
fi


return $STAT_passed
