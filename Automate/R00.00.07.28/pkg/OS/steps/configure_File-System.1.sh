#!/bin/sh

: <<=cut
=script
Configure the additional File-Systems. 
=script_note
Information on the columns within an FSTAB entry, more information can be
found using google (fstab):

The space- or tab-separated fields within each row (typically aligned in columns, as above, but this is not a requirement) must appear in a specific  order, as follows:
=le device-spec : The device name, label, UUID, or other means of specifying the partition or data source this entry refers to.
=le mount-point : Where the contents of the device may be accessed after mounting; for swap partitions or files, this is set to none.
=le fs-type     : The type of file system to be mounted.
=le options     : Options describing various other aspects of the file system, such as whether it is automatically mounted at boot, which users may mount or access it, whether it may be written to or only read from, its size, and so forth; the special option defaults refers to a predetermined set of options depending on the file system type.
=le dump        : A number indicating whether and how often the file system should be backed up by the dump program; a zero indicates the file system will never be automatically backed up.
=le pass        : A number indicating the order in which the fsck program will check the devices for errors at boot time; this is 1 for the root file system and either 2 (meaning check after root) or 0 (do not check) for all other devices.
=version    $Id: configure_File-System.1.sh,v 1.9 2017/09/13 08:31:03 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local what="$1"         # (M) What to do clean or new
local disk_dev="$2"     # (M) The Disk device which need to be mounted
local mnt_point="$3"    # (M) The mount point where the disk needs to be mounted

check_in_set "$what" 'clean,new,reuse,fix'

local label=''
#
# Do some sanity checks first for a new disk
#
if [ "$what" == 'new' -o "$what" == 'reuse' -o "$what" == 'fix' ]; then #= we're not cleaning [$what]
    #=* Do some sanity checks
    #=- A $mnt_point is mandatory, fail if missing
    #=- Fail if the $mnt_point is already mounted on $device 
    #=- Fail if the $mnt_point contains files, warning no mount
    #=- A file with $mnt_point is in the way, remove it
    #=skip_until_marker
    check_set "$mnt_point" "Mount point mandatory for $what"
    local dev=$(get_filesys_for_mnt "$mnt_point")
    if [ "$dev" != '' ]; then
        log_warning "Mount point '$mnt_point already mounted on '$dev', unexpected."
        return $STAT_warning
    fi
    if [ -d "$mnt_point" ]; then
        if [[ $(ls -A "$mnt_point") ]]; then
            log_warning "Mount point '$mnt_point' contains files, continue without mount."
            return $STAT_warning
        fi
    elif [ -e "$mnt_point" ]; then
        log_exit "Mount point '$mnt_point' as file is in the way, stopping."
    fi
    #=skip_until_here
    cmd '' $CMD_mkdir "$mnt_point" 
    label=${mnt_point:0:16}

    local extension='ext3'
    #=#
    case $what in
        new  )
            #=* Whenever [ the disk is an SSD ] use $CMD_mkfs4 and ext4
            #=* Otherwise use $CMD_mkfs and ext3
            #=skip_control
            main_drive="${disk_dev:0:3}"
            ssd_present="$($CMD_lsblk -d -o name,rota | $CMD_grep $main_drive | tr -s ' ')"
            local rotation=$( get_field 2  "$ssd_present" ' ')
            local mkfs="$CMD_mkfs"
            if [ "$rotation" == "0" ]; then
                mkfs="$CMD_mkfs4"
                extension="ext4"
            fi
            cmd "Creating file-system '$disk_dev'" $mkfs -L "$label" "/dev/$disk_dev"
            ;;
        reuse)
            #=# set $STR_allow_fsck_fix to '1' to allow an attempt to fix it 
            if [ "$STR_allow_fsck_fix" == '1' ]; then   #= fix attempt allowed
                set_cmd_user root '' 'allow_failure'
            fi
            cmd "Check file system '$disk_dev'" $CMD_fsck -n "/dev/$disk_dev"
            #=# This will not be reached if no fix allowed and error occurred!
            default_cmd_user
            if [ "$AUT_cmd_outcome" == '4' ]; then #= File-system errors left uncorrected
                # try to do a fix run
                log_warning "File system check failed, executing step to attempt to fix it"
                execute_step 0 "configure_File-System OS fix $disk_dev $mnt_point"
                return $STAT_warning
            fi
            ;;
        fix  )
            cmd "Check and fix file system '$disk_dev'" $CMD_fsck -a "/dev/$disk_dev"
            ;;
        *)  log_exit "Unhandled option ($what), programming error"; ;;
    esac

    # Make the fstab entry
    if [ "$(grep "LABEL=$label" $OS_fstab)" != '' ]; then #= label $label exists in $OS_fstab
        log_warning "Mount tab entry for $label already exists, skipping."
    else
        echo -e "LABEL=$label\t$mnt_point\t$extension\t$OS_fstab_options\t$OS_fstab_dump\t$OS_fstab_pass" >> $OS_fstab
    fi
else
    #=* Use the current file system type for 'clean' action
    #=- There is actually a bug in this see bug 25503
    #=skip_control
    local extension_type="$($CMD_lsblk -fs | grep "$disk_dev" | tr -s ' ')"
    local extension=$( get_field 2  "$ssd_present" ' ')
    local mkfs="$CMD_mkfs"
    if [ "extension" == "ext4" ]; then
        mkfs="$CMD_mkfs4"
    fi
    cmd "Cleaning file-system '$disk_dev'" $mkfs -L \"\" "/dev/$disk_dev"
    mnt_point=''    # Make sure it is empty
fi


if [ "$mnt_point" != '' ]; then #= new mount point found
    cmd "Mount files-system '$disk_dev -> $mnt_point'" $CMD_mount -v "/dev/$disk_dev"
fi

return $STAT_passed

