#!/bin/sh

: <<=cut
=script
Check the disk to see if they are in a proper state to continue. If the disk
are rebuilding then the step will wait. If there are failures on the disk
(or disks missing then) it will warn.
=brief Validation: Check and only continue if disks has proper state
=fail
It is not wise to continue if 'failures' are reported. This will either give 
a risk in recovery or perhaps removing the wrong disk. You should only
skip the step if you are sure it is safe to. The decision and risk is yours.
=version    $Id: check_Disks.1.sh,v 1.4 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local pass_par="$1"   # (O) Set to AllOk to check for all physical disk available as well.

check_in_set "$pass_par"   "'',LogicalOk,AllOk"

pass_par=${pass_par:-LogicalOk}

: <<=cut
=func_int
Get the collor for a specific state. The color also indicates what todo.
=cut
function get_disk_status_col() {
    local status="$1"   # The status of the disk/logical disk, see RAID_stat_*

    local col
    case "$status" in
        $RAID_stat_ok         ) col=$COL_ok   ; ;;  # Seen as successfull
        $RAID_stat_int_recov  ) col=$COL_warn ; ;;  # Could be a planned outage
        $RAID_stat_recovering ) col=$COL_fail ; ;;  # Is still building cannot continue
        $RAID_stat_rdy_for_bld) col=$COL_fail ; ;;  # Waits for building cannot continue
        *) log_info "Unknown/New state '$status'"; col=$COL_fail; ;;
    esac

    echo -n "$col"
}

: <<=cut
=func_int
Checks if the disk status is correct
=set WAIT_pass_request
Will hold information in case the disk are not ok. <empty> if finished.
=cut
function verify_disk_status() {
    [ -z help ] && show_short="The disk status is not waiting|rebuilding"
    [ -z help ] && show_trans=0

    update_raid_info

    local slot
    local log_fail=0
    local phy_fail=0
    for slot in $(map_keys "$map_raid/$RAID_fld_slot"); do
        local s_entry="$map_raid/$RAID_fld_slot/$slot"
        local array
        for array in $(map_keys "$s_entry/$RAID_fld_array"); do
            local a_entry="$s_entry/$RAID_fld_array/$array"
            # 1st walk over the logical drives
            local l_entry="$a_entry/$RAID_fld_log_drive"
            local ldrive="$(map_get "$l_entry" $RAID_fld_name)"
            local status="$(map_get "$l_entry" $RAID_fld_status)"
            local progress="$(map_get "$l_entry" $RAID_fld_progress)"
            if [ "$progress" != '' ]; then progress=", $progress"; fi
            local col="$(get_disk_status_col "$status")"
            if [ "$col" == "$COL_fail" ]; then ((log_fail++)); fi
            WAIT_pass_request+="Slot $slot, Array $array, Drive $col$ldrive ($status$progress)$COL_def ["

            # get all the physical drives for this array/logical drive
            local pdrive
            local sep=''
            for pdrive in $(map_keys "$a_entry/$RAID_fld_phy_drive"); do
                local p_entry="$s_entry/$RAID_fld_phy_drive/$pdrive"
                status="$(map_get "$p_entry" $RAID_fld_status)"
                col="$(get_disk_status_col "$status")"
                if [ "$col" == "$COL_fail" ]; then ((phy_fail++)); fi
                # A failed sub disk only seen as error if AllOk is requested.
                if [ "$pass_par" == 'AllOk' -a "$col" == "$COL_fail" ]; then ((fail++)); fi
                WAIT_pass_request+="$sep$col$pdrive ($status)$COL_def"
                sep=', '
            done
            if [ "$sep" == '' ]; then 
                WAIT_pass_request+="${COL_fail}none$COL_def"
                ((phy_fail++))
            fi
            WAIT_pass_request+="]$nl"
        done

        if [ $log_fail == 0 ]; then
            if [ "$pass_par" != 'AllOk' -o $phy_fail == 0 ]; then
                # Log it anyhow for later knowlede dont show on the screen
                log_info "Disks passed requested level '$pass_par':$nl$WAIT_pass_request" '-e'
                WAIT_pass_request=''
            else
                WAIT_pass_request="Not all physical disks are in the proper state:$nl$WAIT_pass_request"
                WAIT_pass_request+="Disks will be re-checked in a short while "
                WAIT_continue_allowed=1
            fi
        else
            WAIT_pass_request="Not all logical disk are in the proper state:$nl$WAIT_pass_request"
            WAIT_pass_request+="Disks will be re-checked in a short while "
        fi
    done
}

wait_until_passed "$STR_dsk_retry_time" "$STR_dsk_max_retries" verify_disk_status
if [ $? == 0 ]; then
    log_exit "Exceeded max attempts, disk status is not valid, please check problem manually."
fi
        
return $STAT_passed
