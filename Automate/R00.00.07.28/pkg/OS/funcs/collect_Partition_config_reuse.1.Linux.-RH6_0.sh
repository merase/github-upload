#!/bin/sh

: <<=cut
=script
Collects the partition data of partitions which can/should be reused.
=set PART_reuse
A list (space separated) with the disk which are allocated and still have partition
partition data on it (<dev><nr>:<label>)
=set PART_inuse
A list (space separated) with the disk which are currently in use and mounted.
(<dev><nr>:<label>)
=cut

PART_reuse=''
PART_inuse=''
local row
local prow
IFS=$nl
for row in $(cat /proc/partitions | tr -s ' '); do
    local name=$(get_field 5 "$row")
    if [ "$(echo -n "$name" | grep "^$OS_hd_type/$OS_all_hd_dev\$")" != '' ] && [ $name != "$OS_hd_type/$OS_boot_hd_dev" ]; then
        for prow in $($CMD_parted "/dev/$name" print | tr -s ' '); do
            local num=$(get_field 2 "$prow")
            local type=$(get_field 7 "$prow")
            if [ "$type" == '' -o "$type" == 'swap' -o "$type" == 'vfat' ]; then
                continue    # Skip undefined, swap and ilo mounted vfats
            fi
            local dev="$name$OS_part_pfx$num"
            local lab=$($CMD_blkid "/dev/$dev" | tr ' ' '\n' | grep "^LABEL=" | cut -d'"' -f 2)
            if [ "$lab" == '' ]; then
                continue    # Skip not formatted at all
            fi
            local mnt=$(grep "/dev/$dev" /proc/mounts)
            if [ "$mnt" == '' ]; then   # Yes is could be reused
                PART_reuse=$(get_concat "$PART_reuse" "$dev:$lab")
            else                        # Is is already being used
                PART_inuse=$(get_concat "$PART_inuse" "$dev:$lab")
            fi
        done
    fi
done
IFS=$def_IFS

