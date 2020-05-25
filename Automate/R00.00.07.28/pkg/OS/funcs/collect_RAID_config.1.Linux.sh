#!/bin/sh

: <<=cut
=script
Collect the current disk data from the RAID controller. The information is
stored in generic variable to be used by others
=version    $Id: collect_RAID_config.1.Linux.sh,v 1.4 2018/01/25 08:34:32 fkok Exp $
=author     Frank.Kok@newnet.com
=set RAID_slots
A list (space separated) with the available slots
=set RAID_arrays
A list (space separated) with the available arrays (being slot:array)
=set RAID_log_drives
A list (space separated) with the available logical drives (being slot:array:drivenum:size:unit)
=set RAID_log_names
A list (space separated_ witht the current devices names (drivenum:/dev/xxx). 
Matches the number of RAID_log_drives. /dev/null is used if unknown
(not all smart array versions support this).
=set RAID_phy_drives
A list ((space separated) with the available physical drives (being slot:array:port:box:bay:size)
The array may be empty meaning unassigned drive.
=cut

add_cmd_require $CMD_da_cli

RAID_slots=''
RAID_arrays=''
RAID_log_drives=''
RAID_log_names=''
RAID_phy_drives=''

#First get all the information we one (and as fast as possible)
local line
local slot=''
local array=''
local ldrive=''
local pdrive=''
local out=$($CMD_da_cli ctrl all show config | sed "$SED_del_spaces"  | sed "$SED_del_preced_sp")
IFS=$'\n'
for line in $out; do
    if [ "$(echo "$line" | grep -i 'Smart Array')" != '' ]; then
        slot="$(echo -n "$line" | egrep -o -i 'Slot [0-9]' | egrep -o '[0-9]')"
        RAID_slots="$RAID_slots$slot "
    elif [ "$(echo "$line" | grep -i '^array')" != '' ]; then
        array=$(get_field 2 "$line")        
        RAID_arrays="$RAID_arrays$slot:$array "
        ldrive=''
    elif [ "$(echo "$line" | grep -i '^unassigned')" != '' ]; then
        array=''    # Not assigned to any array yet
        ldrive=''
    elif [ "$(echo "$line" | grep -i '^logicaldrive')" != '' ]; then
        local size=$(get_field 3 "$line");  size=${size:1}      # Strip (
        ldrive="$(get_field 2 "$line"):${size:1}:$(get_field 4 "$line" | tr -d ',')"
        RAID_log_drives="$RAID_log_drives$slot:$array:$ldrive "
    elif [ "$(echo "$line" | grep -i '^physicaldrive')" != '' ]; then
        pdrive=$(get_field 2 "$line")
        RAID_phy_drives="$RAID_phy_drives$slot:$array:$ldrive:$pdrive:$(get_field 8 "$line") "
    fi
done
IFS=$def_IFS

for line in $RAID_log_drives; do
    slot="$(  get_field 1 "$line" ':')"
    ldrive="$(get_field 3 "$line" ':')"
    out="$($CMD_da_cli controller slot=$slot logicaldrive $ldrive show | grep -i 'Disk Name' | sed "$SED_del_spaces"  | sed "$SED_del_preced_sp" | cut -d' ' -f3)"
    if [ "$out" != '' ]; then
        RAID_log_names="$RAID_log_names$ldrive:$out "
    else
        RAID_log_names="$RAID_log_names$ldrive:/dev/null "
    fi
done

# Remove trailing spaces, made code above easier
RAID_slots=$(rem_trail_sp "$RAID_slots")
RAID_arrays=$(rem_trail_sp "$RAID_arrays")
RAID_log_drives=$(rem_trail_sp "$RAID_log_drives")
RAID_log_names=$(rem_trail_sp "$RAID_log_names")
RAID_phy_drives=$(rem_trail_sp "$RAID_phy_drives")

log_debug "RAID: slots: $RAID_slots, arrays: $RAID_arrays"
log_debug "RAID: logical drives: $RAID_log_drives"
log_debug "RAID: logical names: $RAID_log_names"
log_debug "RAID: phyicical drivesL $RAID_phy_drives"
