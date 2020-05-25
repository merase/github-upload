#!/bin/sh

: <<=cut
=script
Collects the partition data of partitions which can/should be reused.
=set PART_reuse
A list (space separated) with the disk which are not in use and still have
partition data on it (<dev><nr>:<label>)
=set PART_inuse
A list (space separated) with the disk which are currently in use and mounted.
(<dev><nr>:<label>)
=cut

PART_reuse=''
PART_inuse=''
local row
IFS=$nl
for row in $($CMD_lsblk -fs | grep "^$OS_nb_hd_dev" | tr -s ' '); do
    local type=$(get_field 2 "$row")
    if [ "$type" == '' -o "$type" == 'swap' -o "$type" == 'vfat' ]; then
        continue    # Skip undefined, swap and ilo mounted vfats
    fi
    local lab=$(get_field 3 "$row")
    if [ "$lab" == '' ]; then
        continue    # Skip not formatted at all
    fi
    local dev=$(get_field 1 "$row")
    local mnt=$(get_field 5 "$row")
    if [ "$mnt" == '' ]; then   # Yes is could be reused
        PART_reuse=$(get_concat "$PART_reuse" "$dev:$lab")
    else                        # Is is already being used
        PART_inuse=$(get_concat "$PART_inuse" "$dev:$lab")
    fi
done
IFS=$def_IFS

