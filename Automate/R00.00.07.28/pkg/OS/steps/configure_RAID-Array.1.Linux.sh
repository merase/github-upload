#!/bin/sh

: <<=cut
=script
Configure a physical disk into a logical disk using the RAID controller.
Currently only RAID0,  RAID1 and RAID5 is supported
=fail
Manually configure the RAID configuration to the systems type disk layout.
Use the RAID array tool or lnxcfg to do this.
Only skip the step when all done otherwise wrong disk layout will be used.
=version    $Id: configure_RAID-Array.1.Linux.sh,v 1.3 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local raid_type="$1"     # (M) The type of , currently only RAID1 supported
local phy_disks="$2"     # (M) The amount of needed physical disks

check_in_set "$raid_type" 'RAID0,RAID1,RAID5'

case $raid_type in
    RAID0)  if [ "$phy_disks" -ne 1 ]; then     #= $phy_disk not 1
                log_exit "$raid_type only allows for 1 disk."
            fi; ;;
    RAID1)  if [ $((phy_disks%2)) -ne 0 ]; then #= $phy_disk is not an even amount
                log_exit "Need an even amount of disks for $raid_type"
            fi; ;;
    RAID5)  if [ "$phy_disks" -lt 3 -o "$phy_disks" -gt 8 ]; then #= $phy_disk not in range [4..8]
                log_exit "Support 4-8 disk for $raid_type (6 is normal)"
            fi; ;;
    *) log_exit "Unsupported raid-type ($raid_type) requested."; ;;
esac
local raid=${raid_type:4:1}

#
# First find all the available disks
#
func OS collect_RAID_config

# 
#=# Now collect the physical data order per slot/size
#=- Already used disk are skipped
#=skip_until_marker
#
local map_avail_phy='RAID_avail_phy' # Map with available per size
map_init $map_avail_phy

local size
local phy
local sep=''
for phy in $RAID_phy_drives; do
    if [ "$(get_field 2 "$phy" ':')" != '' ]; then
        continue        # Already in use skip
    fi
    size="$(get_field  7 "$phy" ':'):$(get_field 1 "$phy" ':')"     # need to know the slot as well
    map_put $map_avail_phy "$size" "$(get_concat "$(map_get $map_avail_phy "$size")" "$(get_field 4-6 "$phy" ':')" ' ')"
done
#=skip_until_here

#
#=* Select the physical drives for the RAID set
#=- The calling code is written in such way that the smaller disk are assigned first
#=- The disk are ordered in port/box/bay order
#=- It will also be calculated if the disk set is optimal (as many disk as requested)
#=skip_control
#
local drives=''
local drives_slot=''
local bnum=0
local optimal='No'
IFS=$'\n'
for size in $(echo "$(map_keys $map_avail_phy)" | tr ' ' '\n' | sort) ; do
    local phy=$(echo -n "$(map_get $map_avail_phy "$size")" | tr ' ' '\n' | sort)    # Sort it to be sure/same behavior
    local num=$(echo "$phy" | wc -l)
    if [ "$num" -ge "$phy_disks" ]; then      # It could fit
        drives_slot=$(get_field 2 "$size" ':')
        drives=$(get_field "1-$phy_disks" "$(echo -n "$phy" | tr '\n' ',')" ',')
        optimal='Yes'
        break
    elif [ "$num" -gt "$bnum" ]; then
        drives_slot=$(get_field 2 "$size" ':')
        drives=$(echo -n "$phy" | tr '\n' ',')
        bnum=$num
        optimal='No'
    fi
done
IFS=$def_IFS

#=set_var_cur drives '<port:box:bay>,<port:box:bay>'
#=set_var_cur bnum 1
if [ "$drives" != '' ]; then                            #= found drives
    if [ "$optimal" != 'Yes' ]; then                    #= not optimal configuration
        # Define the fallback scenarios
        if [ "$raid" == 5 -a "$bnum" -lt 3 ]; then      #= RAID5 ] and [ less than 3 drives
            if [ "$bnum" == 1 ]; then                   #= only one drive
                #=# fallback to RAID0
                raid=0                                  
            else
                #=# fallback to RAID1
                raid=1                                  
            fi
        elif [ "$raid" == 1 -a "$bnum" -lt 2 ]; then    #= RAID1 ] and [ less than 2 drives
            #=# fallback to RAID0
            raid=0                                      
        fi
        log_warning "Creating a disk-set but not as requested: $raid_type ${phy_disks}* will be RAID$raid ${bnum}*"
    fi
    cmd 'Create Logical Drive' $CMD_da_cli ctrl slot=$drives_slot create type=ld drives=$drives raid=$raid
else
    log_warning "Could not create requested logical drive ($raid_type ${phy_disks}*) no more disks available"
fi

return $STAT_passed
