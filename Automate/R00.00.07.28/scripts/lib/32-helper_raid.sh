#!/bin/sh

: <<=cut
=script
This script is capable of discoverign raid controller information. It will store
or update information into a map. In the future it might handle multiple
raid controllers on multiple OSes. The output per type/OS should
be the same so that the callers do not notice the difference.
=version    $Id: 32-helper_raid.sh,v 1.3 2018/06/07 07:10:50 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly map_raid="RAID_cfg"

# Each raid configuration can have:
# * Multipile slots (we normally have slot 0 at the moment)
# * Each slot can have multuple arrays, each array has
#   * 0/1 logical drive (size, raid type, status, progress)
#   * 0/1..n physical drives (port, box, bay, drive type, size, status)
# 

readonly RAID_fld_slot='slot'
readonly RAID_fld_array='array'
readonly RAID_fld_log_drive='log_drive'
readonly RAID_fld_phy_drive='phy_drive'
readonly RAID_fld_unused='unused'
readonly RAID_fld_size='size'
readonly RAID_fld_name='name'
readonly RAID_fld_raid_type='raid_type'
readonly RAID_fld_status='status'
readonly RAID_fld_progress='progress'
readonly RAID_fld_port='port'
readonly RAID_fld_box='box'
readonly RAID_fld_bay='bay'
readonly RAID_fld_drive_type='drive_type'
readonly RAID_fld_ctrl_type='controller_type'
readonly RAID_fld_part_of='part_of'

# definign them allows for later change (e.g. when other raid controller comes in place)
readonly RAID_stat_ok='OK'
readonly RAID_stat_int_recov='Interim Recovery Mode'
readonly RAID_stat_recovering='Recovering'
readonly RAID_stat_rdy_for_bld='Ready for Rebuild'

: <<=cut
=func_iny
This function update the available raid fro a hp smart array (p4x e.g p401).
=cut
function update_raid_info_hp_p4x() {
    add_cmd_require $CMD_da_cli

    #First get all the information we one (and as fast as possible)
    local line
    local bline
    local slot=''
    local array=''
    local ldrive=''
    local pdrive=''
    local entry=''
    local out=$($CMD_da_cli ctrl all show config | sed "$SED_del_spaces"  | sed "$SED_del_preced_sp")
    IFS=$'\n'
    for line in $out; do
        IFS=$def_IFS
        bline="$(get_field 2 "$(get_field 1 "$line" ')')" '(' | sed 's/, /,/g')"     # Get the first line between brackets, remove spaces after , 
        if [ "$(echo "$line" | grep -i 'Smart Array')" != '' ]; then
            slot=$(echo -n "$line" | $CMD_ogrep -i 'Slot [0-9]+' | $CMD_ogrep '[0-9+]') 
            entry="$map_raid/$RAID_fld_slot/$slot"
            map_put "$entry" "$RAID_fld_ctrl_type" "$(get_field 1-3 "$line")"
        elif [ "$(echo "$line" | grep -i '^array')" != '' ]; then
            check_set "$slot" "Slot should have been defined"
            array=$(get_field 2 "$line")
            ldrive=''
            entry="$map_raid/$RAID_fld_slot/$slot/$RAID_fld_array/$array"
            map_put "$entry" $RAID_fld_drive_type "$(get_field 1   "$bline" ',')"
            map_put "$entry" $RAID_fld_unused     "$(get_field 2-3 "$bline")"
        elif [ "$(echo "$line" | grep -i '^unassigned')" != '' ]; then
            # TODO store as free ? find out layut (no example
            array=''    # Not assigned to any array yet
            ldrive=''
        elif [ "$(echo "$line" | grep -i '^logicaldrive')" != '' ]; then
            # Each array has one logicaldrive
            check_set "$array" "Array should have been defined"
            ldrive=$(get_field 2 "$line")
            entry="$map_raid/$RAID_fld_slot/$slot/$RAID_fld_log_drive/$ldrive"
            map_put "$entry" $RAID_fld_name      $ldrive
            map_put "$entry" $RAID_fld_size      "$(get_field 1 "$bline" ',')"
            map_put "$entry" $RAID_fld_raid_type "$(get_field 2 "$bline" ',')"
            map_put "$entry" $RAID_fld_status    "$(get_field 3 "$bline" ',')"
            map_put "$entry" $RAID_fld_progress  "$(get_field 4 "$bline" ',')"
            # Link logical drive to array
            map_link "$map_raid/$RAID_fld_slot/$slot/$RAID_fld_array/$array" "$RAID_fld_log_drive" "$map_raid/$RAID_fld_slot/$slot/$RAID_fld_log_drive" "$ldrive"
        elif [ "$(echo "$line" | grep -i '^physicaldrive')" != '' ]; then
            # I have chosen to put it under the array not under the logical drive (same layout as hpacucli)
            check_set "$array" "Array should have been defined"
            pdrive=$(get_field 2 "$line" | tr ':' '-')
            entry="$map_raid/$RAID_fld_slot/$slot/$RAID_fld_phy_drive/$pdrive"
            map_put "$entry" $RAID_fld_name       $pdrive
            map_put "$entry" $RAID_fld_port       "$(get_field 1 "$pdrive" ':')"
            map_put "$entry" $RAID_fld_box        "$(get_field 2 "$pdrive" ':')"
            map_put "$entry" $RAID_fld_bay        "$(get_field 3 "$pdrive" ':')"
            map_put "$entry" $RAID_fld_drive_type "$(get_field 2 "$bline"  ',')"
            map_put "$entry" $RAID_fld_size       "$(get_field 3 "$bline"  ',')"
            map_put "$entry" $RAID_fld_status     "$(get_field 4 "$bline"  ',')"
            # Link physical drive to array
            map_link "$map_raid/$RAID_fld_slot/$slot/$RAID_fld_array/$array/$RAID_fld_phy_drive" "$pdrive" "$map_raid/$RAID_fld_slot/$slot/$RAID_fld_phy_drive"
            # Link phisical drive to logical drive (if any)
            if [ "$ldrive" != '' ]; then
                map_link "$entry" "$RAID_fld_part_of" "$map_raid/$RAID_fld_slot/$slot/$RAID_fld_log_drive" "$ldrive"
            fi
        fi
        IFS=$'\n'
    done
    IFS=$def_IFS
}

: <<=cut
=func_frm
This function will call the appropriate update routine to make sure the latest
data is written. This is reached by first clearing the existing data.

 configuration by rewriting it 
the current data completely (this to handle potential removing of data).
=cut
function update_raid_info() {
    map_init $map_raid      # Start fresh

    case $OS in
        $OS_linux   ) update_raid_info_hp_p4x                                ; ;;      # Currently only one identified
        $OS_solaris ) log_exit "Solaris RAID info not yet supported."        ; ;; # For future
        *) log_exit "Unhandled OS type, unable to proceed gettign RAID info."; ;;
    esac
}