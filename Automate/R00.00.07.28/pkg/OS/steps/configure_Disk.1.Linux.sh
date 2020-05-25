#!/bin/sh

: <<=cut
=script
Configure the Disk partitioning. Current all unallocated disk are partitioned 
as full.
=fail
Manually configure all disk partitions to its full size. lnxcfg could be used
as well. Skip the step when all done.
=version    $Id: configure_Disk.1.Linux.sh,v 1.4 2017/06/08 11:45:10 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local disk_dev="$1"     # (M) The disk device to partition
local part_type="$2"    # (M) The type of partitioning, currently only full supported

if [ ! -b $disk_dev ]; then
    log_exit "The disk device '$disk_dev' is not a block device"
fi
check_in_set "$part_type" 'full'

#=* Create a single partition on the device [$disk_dev]
#=- How? This is Unix system administration
#=- The methods are taken from lnxcfg and that tool could be used as well
#=- One need to calculate the amount of cylinders
#=- For disks < 2.2TB the following command is used, an example:
#=inc_indent
#=cmd_input '' ',<num_cyl>,83' "$CMD_sfdisk $disk_dev"
#=dec_indent
#=- For disks >= 2.2TB the following command is used, an example:
#=inc_indent
#=cmd '' $CMD_parted $disk_dev mkpart p 1 <num_cyl>
#=dec_indent
#=skip_until_end

#
# Some of the technique used are taken from lnxcfg/partCfg
#

#
# Get some need info from fdisk/sfdisk to be used later on, keep all local
# In this case I decide to to make a separate RHEL based function, due to 
# the use of locals. As long as this is the only section in this file this
# is imho acceptable
#
local info="$($CMD_fdisk -l $disk_dev)"
# A simple protection on still mounted folders.
if [ "$(echo -n "$info" | grep -i "No medium found")" != '' ]; then
    log_warning "Did not find a medium in $disk_dev, was this a USB/folder mount?"
    return $STAT_skipped
fi
local bytes="$($CMD_fdisk -l $disk_dev | grep '^Disk /dev' | cut -d' ' -f5)"
local cyl
if [ $OS_ver_numb -lt 70 ]; then  
    cyl="$(echo -n "$info" | grep 'cylinders$' | cut -d' ' -f5)"
else
    cyl="$($CMD_sfdisk -l $disk_dev | grep '^Disk' | cut -d' ' -f3)"
fi
local max_sz=$((bytes / $MB))
local bpc=$((bytes / cyl ))

#
# Now this is tricky how to translate a device into a logical drive.
# Nowadays smart array allows tot store the current disk name. Which is a good
# Coupling. If not available then the old assumption of sequential order
# is used. (starting from sda) this might not be correct if e.g. an folder
# is mounted in between.
# It should work for slot 0. The other are to be seen.
#
local ld=''; 
local name; local f_dev
for name in $RAID_log_names; do
    f_dev="$(get_field 2 "$name" ':')"
    if [ "$f_dev" == "$disk_dev" ]; then
        ld=$(get_field 1 "$name" ':')
        log_info "Translated $disk_dev into logdrive $ld (using Disk Names)"
        break
    fi
done
if [ "$ld" == '' ]; then # fallabck to old riksy mechanims
    local ld_seq=$(echo "$disk_dev" | sed "s/\/dev\/sd//")
    ld=$(( $(printf '%d' "'$ld_seq") - 96 ))
    log_info "Translated $disk_dev into logdrive $ld (using ordered assumption)"
fi
local ld_info=$(echo -n "$RAID_log_drives" | tr ' ' '\n' | egrep "^.+:.+:$ld:.*\$")
if [ "$ld_info" == '' ]; then
    log_exit "Did not find logical drive belonging to $disk_dev($ld)"
fi
local slot=$(get_field 1 "$ld_info" ':')
local part_sz=$(get_field 4 "$ld_info" ':')
local byte_unti=$(get_field 5 "$ld_info" ':')


#
# We currently  supporting only one partition so allocate full size
#
local partn_sz=$max_sz      # Alloc all
local partn_cyl
if [ "$byte_unit" == 'TB' ] && [ $(echo "$partn_sz >= 2.2" | bc) -ne 0 ]; then #= $partn_sz >= 2.2TB
    local no_of_cyl=$[$partn_sz * $MB / $bpc ]
    ((partn_cyl=$[$no_of_cyle * $bpc ] / $MB))

    start=1
    end=$partn_cyl

    cmd "Adding $part_type partition on $disk_dev" $CMD_parted $disk_dev mkpart p 1 $partn_cyl
else
    partn_cyl=$[$partn_sz * $MB / $bpc ]
 
    # Sfdisk does like the cmd_input function so do it locally, for doc it is okay
    $CMD_sfdisk $disk_dev << EOF >> $LOG_file 2>&1
,$partn_cyl,83
EOF
    check_success "Adding $part_type partition on $disk_dev" "$?"
fi

return $STAT_passed
