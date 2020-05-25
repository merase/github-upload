#!/bin/sh

: <<=cut
=script
Collect disk data needed for e.g. upgrade
=version    $Id: collect_disks.1.Linux.sh,v 1.9 2017/12/13 14:14:55 fkok Exp $
=author     Frank.Kok@newnet.com
=set OS_boot_slot
Holds the slot of the array holding the disks
=set OS_boot_logical_drv
Identifies the logical drive.
=cut

add_cmd_require $CMD_da_cli

local root_row
if [ $OS_ver_numb -ge 70 ]; then    # As of 7.0 /dev/mappper for root so use /boot
    root_row=`df -h | sed "$SED_del_spaces" | grep '/boot$'`
else
    root_row=`df -h | sed "$SED_del_spaces" | grep '/$'`
fi
check_set $root_row 'Did not find the root partition.'

local RHEL_OS_version=`echo "$OS_version" | $CMD_ogrep '^RH5'`

local root_disk
if [ "$RHEL_OS_version" == "RH5" ];then
    root_disk=`echo "$root_row" | $CMD_ogrep 'c[0-9]d[0-9]'`
    OS_boot_slot=${root_disk:1:1}
    OS_boot_logical_drv=${root_disk:3:1}
    ((OS_boot_logical_drv++))           # hp util start counting at 1 not 0
    local out=`$CMD_da_cli ctrl slot=$OS_boot_slot show config | sed "$SED_del_spaces"  | sed "$SED_del_preced_sp" | \
            sed 's/.*rray.*//' | sed 's/.*SEP.*//' | sed 's/logical/=\nlogical/' | tr -d '\r'`
else
    root_disk=`echo "$root_row" | $CMD_ogrep 'sd[a-d][0-9]'`
    OS_boot_slot=0 # For RHEL6 the slot is zero for raid configuration.
    raid_array="$(get_upper "${root_disk:2:1}")"
    local out=`$CMD_da_cli ctrl slot=$OS_boot_slot show config | sed "$SED_del_spaces"  | sed "$SED_del_preced_sp" | \
            sed 's/.*SEP.*//' | sed 's/array/=\narray/' | tr -d '\r'`
fi
check_set "$root_disk" "Did not recognized the root device (new_type?): $root_row"

log_debug "Found OS_boot: slot: $OS_boot_slot : logdrv: $OS_boot_logical_drv"

local line
local drive=''
local output=''
local drive_matched=0
IFS="$nl"
for line in $out
do
    IFS=$def_IFS
    if [ "$drive" == '' ]; then
        if [ "$RHEL_OS_version" != "RH5" -a "$array" != "$raid_array" ]; then
            array=`echo "$line" | $CMD_ogrep 'array [A-D]' | $CMD_ogrep '[A-D]'`
            continue
        fi
        drive=`echo "$line" | $CMD_ogrep 'logicaldrive [1-9]' | $CMD_ogrep '[1-9]'`
        drive_matched=1
        if [ "$RHEL_OS_version" == "RH5" ];then
            if [ "$drive" != "$OS_boot_logical_drv" ]; then
                drive=''
                drive_matched=0
            fi
        else
            if [ "$array" != "$raid_array" ]; then
                drive=''
                drive_matched=0
            fi
         fi
         if [ "$drive_matched" == "1" ]; then
             drive=$line
             log_debug "= Collecting disk data:"
             log_debug "=----------------------"
             log_debug "= $drive"
         fi
    else 
        if [ "$line" == '' ]; then
            IFS="$nl"
            continue
        elif [ "${line:0:1}" == '=' ]; then
            break;      # Ends here
        fi
        log_debug "= $line"
        if [ "$output" == '' ]; then
            output="$line"
        else
            output="$output$nl$line"
        fi
    fi
    IFS="$nl"
done
IFS=$def_IFS

check_set $output "Did not find drive info of root device"

COL_boot_info="$drive$nl$nl$output"
COL_boot_physical_drv=`echo "$output" | sed 's/.*bay \([0-9]\).*/\1/' | tr '\n' ' ' | cut -d' ' -f1-`

