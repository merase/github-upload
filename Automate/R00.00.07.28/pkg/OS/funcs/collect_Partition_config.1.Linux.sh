#!/bin/sh

: <<=cut
=script
Collects the current partition data from the OS. The information is
stored in generic variable to be used by others
=fail
See if the calling step can be manually fixed and then skipped. 
Otherwise call for support.
=version    $Id: collect_Partition_config.1.Linux.sh,v 1.11 2018/01/25 08:43:54 fkok Exp $
=author     Frank.Kok@newnet.com
=set PART_devices
A list (space separated) with the available disk name (being <dev>:size)
=set PART_mounts
A list (space separated) with the available partitions (<dev><nr>:size)
=set PART_unalloc
A list (space separated) with the disk name which do not have any partitions yet.
=set PART_skip
A list (space separated) with disk to be skipp (too small). This filters out any
strange ILO mounted devices.
=set PART_reuse
A list (space separated) with the disk which are allocated and still have partition
paratition data on it (<dev><nr>:<label>)
=set PART_inuse
A list (space separated) with the disk which are currently in use and mounted.
(<dev><nr>:<label>)
=set PART_free
A list (space separated) with the disk which are allocated but free to be 
mounted.
=cut

#=# Complex logic to collect the Partition Configuration
#=skip_until_marker

local min_size=$((4 * 1000000)) # in blocks of 1024 bytes
local info=$(cat /proc/partitions | tr -s ' ' | sed 's/^ *//g' | sort)
PART_devices=$(echo -n "$info" | grep "$OS_nb_hd_dev\$"  | gawk '{ printf "%s:%s ",$4,$3 }')
PART_mounts=$( echo -n "$info" | grep "$OS_nb_hd_part\$" | gawk '{ printf "%s:%s ",$4,$3 }')
PART_skip=''
PART_unalloc=''
local device
for device in $PART_devices; do
    local dev=$(get_field 1 "$device" ':')
    is_substr "$dev" "$PART_mounts"
    if [ $? == 0 ]; then
        PART_unalloc=$(get_concat "$PART_unalloc" "$dev")
    fi
    local size=$(get_field 2 "$device" ':')
    if [ "$size" -le "$min_size" ]; then
        PART_skip=$(get_concat "$PART_skip" "$dev")
    fi
done

# Add strange partition to the skip list.
# Build for gen10 USB hub so start with a very dumb filtering
local all_devs=$(echo -n "$info" | grep "$OS_all_hd_dev\$"  | gawk '{ printf "%s ",$4 }')
local disk
for disk in `ls $OS_hd_dev/$OS_all_hd_dev`; do
    local dev="$(basename "$disk")"
    is_substr "$dev" "$all_devs"
    if [ $? == 0 ] && [ "$(smartctl -i $disk | grep 'USB')" != '' ]; then
        PART_skip=$(get_concat "$PART_skip" "$dev")
    fi
done

#=skip_until_here
func OS collect_Partition_config_reuse
#=skip_until_end

PART_free=''
local tmp_lst=$(mktemp)
local tmp=$(mktemp)
$CMD_mount > $tmp_lst
check_success 'Get initial mount list' "$?"
log_info "Current mount list:$nl$(cat $tmp)"

cat $tmp_lst | grep "$OS_hd_dev/$OS_all_hd_dev" > $tmp
if [ $? == 0 ]; then
    # skip the swap partition
    local swap_UUID=$(cat /etc/fstab | grep swap | cut -f1 -d' ' | cut -f2 -d'=')
    local swap_disk=$($CMD_blkid | grep "$swap_UUID" | cut -f1 -d':')
    echo $swap_disk >> $tmp
    # skip the extended partition(s)
    local i
    echo "$OS_hd_dev/$OS_boot_hd_dev${OS_part_pfx}4" >> $tmp
    for i in $(ls $OS_hd_dev/$OS_all_hd_dev${OS_part_pfx}5 2>/dev/null); do
        echo $i | sed "s/${OS_part_pfx}5/${OS_part_pfx}4/" >> $tmp
    done
            
    for i in $(ls $OS_hd_dev/$OS_all_hd_dev${OS_part_pfx}[1-9]); do
        grep $i $tmp >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            local dev=$([ "$OS_hd_type" != '' ] && echo -n "$OS_hd_type/$(basename $i)" || echo -n "$(basename $i)")
            # Skip some special types ...
            local type=$($CMD_blkid -s TYPE -o value "/dev/$dev")
            if [ $? == 0 ]; then
                case "$type" in
                    vfat ) log_debug "Skipping $type device $dev"; continue ;;
                    LVM* ) log_debug "Skipping $type device $dev"; continue ;;
                    *    ) : ;;
                esac
            fi
            PART_free=$(get_concat "$PART_free" $dev)
        fi
    done
else
    log_info "No regular mount point found (vitual server?)"
fi

log_debug "PART: devices: $PART_devices"
log_debug "PART: mounts : $PART_mounts"
log_debug "PART: unalloc: $PART_unalloc"
log_debug "PART: resuse : $PART_reuse"
log_debug "PART: skip   : $PART_skip"
log_debug "PART: free   : $PART_free"

remove_temp $tmp_lst
remove_temp $tmp 
