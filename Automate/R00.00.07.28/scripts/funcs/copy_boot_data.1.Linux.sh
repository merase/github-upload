#!/bin/sh

: <<=cut
=script
This function tries to mount a specific boot location and if the proper directory
is found than all data is copied. A file is create to do this only once, 
at the moment this is:
- /dev/sda as given by the ILO-3

A special 'mount' option can be given to only collect the boot 1st device with 
the automate data. Which can be used in case of USB upgrades. This will
require a writable automate-boot-data folder.
 
This function probably need rework for multiple systems.
=opt1
If set to mount then only a writable directory is collected and mounted copied.
If set to unmount then a previously mounted boot directly is unmounted
=set AUT_boot_data_dev
The device holding the current bootable data.
=set AUT_boot_data_mounted
If 1 then this script mounted the boot data and should still be unmounted.
=version    $Id: copy_boot_data.1.Linux.sh,v 1.11 2017/06/08 11:45:10 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local what="$1"         # (O) What to do
local upgr_dst="$2"     # (O) Directory used for copying the upgrad packages to. (mandatory in case $what=='upgrade'

check_in_set "$what" "'',mount,unmount,upgrade"

# Only need to do once otherwise it might start over if the partition is 
# still available after a reboot
if [ "$what" == 'unmount' ]; then
    if [ "$AUT_boot_data_dev" != '' -a "$AUT_boot_data_mounted" == '1' ]; then       # We don't need it anymore
        cmd '' $CMD_umount $AUT_boot_data_dev
    else
        log_info "Device '$AUT_boot_data_dev' not mounted by us ($AUT_boot_data_mounted)"
    fi
    AUT_boot_data_mounted=0
    return 0 # Always return
elif [ "$what" == '' ] && [ -e $boot_copied ]; then   # Skip if the action already occurred once!
    return 0
fi

# Now see if it happens to be 'auto' mounted
local tried=''
local we_mounted=0
local df=`df`
local mnt_dir=''
local data_dir=''
local dev=`echo "$df" | grep "$AUT_tmp_mnt_dir" | cut -d' ' -f1`
if [ "$dev" != '' ]; then
    log_info "$AUT_tmp_mnt_dir already mounted on dev $dev"
    mnt_dir="$(get_mnt_for_filesys "$dev")"
    data_dir="$mnt_dir/$AUT_boot_data_dir"
else
    local devs="$(get_unique_words "$OS_cd_devs $OS_img_devs $OS_nb_devs")"
    cmd '' $CMD_mkdir $AUT_tmp_mnt_dir
    for dev in $devs; do
        if [ ! -e $dev ]; then
            continue
        fi
        local type=''
        if [ "$(echo -n "$dev" | grep -e 'cdrom' -e '/sr')" != '' ]; then
            # mounting CDROM could be slow. During upgrade this is not an expected location so skipp ot.
            if [ "$what" == 'upgrade' ]; then continue; fi
            type='iso9660'
        elif [ -e "$dev${OS_part_pfx}1" ]; then   # use main partition if it is there
            dev="$dev${OS_part_pfx}1"
        elif [ -e "${dev}1" ]; then               # use main partition for regular device as well
            dev="${dev}1"
        fi
        if [ "$type" == '' ]; then  # Still to be determined
            type=$($CMD_blkid -s TYPE -o value "$dev")
            if [ $? != 0 ]; then
                tried="$tried$dev : unable to identify type$nl"
                continue
            fi
        fi
        if [ "$type" != '' ]; then type="-t $type"; fi

        mounted=`echo "$df" | grep "$dev"`      # Check if not already mounted
        if [ "$mounted" == '' ]; then
            log_info "Trying to mount boot device: $dev $type"
            $CMD_mount $type $dev $AUT_tmp_mnt_dir >> $LOG_file 2>&1
            if [ $? != 0 ]; then
                tried="$tried$dev : unable to mount ($type)$nl"
                continue
            fi
            mnt_dir="$AUT_tmp_mnt_dir"
            we_mounted=1
        else
            mnt_dir="$(get_mnt_for_filesys "$dev")"
        fi
        if [ "$mnt_dir" != '' ]; then
            # The mounted dir should contain the AUT_store_script
            data_dir="$mnt_dir/$AUT_boot_data_dir"
            local wrong=0
            if [ ! -d "$data_dir" ]; then
                log_info "Did not find the automation dir '$data_dir'"
                tried="$tried$dev : no automation dir$nl"
                wrong=1
            elif [ "$what" == 'mount' ] && [ ! -w "$data_dir" ]; then
                log_info "Found automation dir but not writable dir '$data_dir'"
                tried="$tried$dev : not writable dir$nl"
                wrong=1
            else
                tried="$tried$dev : found automation dir$nl"
                log_info "Found automation dir on $dev -> $mnt_dir"
                break;
            fi
            if [ $wrong == 1 ]; then    # Unmount it
                if [ $we_mounted == 1 ]; then
                    cmd '' $CMD_umount $dev
                    we_mounted=0
                fi
                mnt_dir=''
                data_dir=''
            fi
        else
            tried="$tried$dev : no mount point$nl"
            log_info "Did not found mount point for $dev"
        fi
    done    
fi

log_info "Tried info for '$what':$nl$tried"

# from here on we have a valid mount
AUT_boot_data_dev="$dev"
AUT_boot_data_mounted=$we_mounted
case "$what" in
    mount)
        if [ "$data_dir" == '' ]; then
            log_info "Did not find any writable boot-data"
            AUT_boot_data_dev=''
        elif [ ! -w "$data_dir" ]; then       # extra check if we come here through already mounted device
            log_info "Did not find writable boot-data on $AUT_boot_data_dev"
            AUT_boot_data_dev=''
        else
            log_info "Found writable boot-data on $AUT_boot_data_dev"
        fi
        ;;

    upgrade)
        check_set "$upgr_dst" 'Upgrade destination directory not given.'

        local upgr_dir="$mnt_dir/$AUT_upgr_data_dir"
        echo "$nl"`date`"===========================================================" >> $update_chk
        echo `date`" - Upgrade check requested, looking in '$upgr_dir'" >> $update_chk
        log_info "Upgrade check requested, looking in '$upgr_dir'"
        # Always clean the upgrade destination
        if [ -d "$upgr_dst" ]; then cmd '' $CMD_rm "$upgr_dst"; fi
        

        if [ "$mnt_dir" != '' ]; then
            if [ -d "$upgr_dir" ]; then
                # Only copy files which are newer than out current versions
                # We only support $CMD_install_ext
                local f
                for f in $(ls "$upgr_dir"); do
                    local full="$upgr_dir/$f"
                    local ext=${f##*.}
                    if [ "$ext" != "$CMD_install_ext" ]; then 
                        echo `date`" - Skipping '$full' as extension '$ext' != '$CMD_install_ext'" >> $update_chk
                        continue
                    fi
                    local pkg=$(get_field 1 "$f" '-')
                    local c_ver=$(get_norm_ver "$(get_field 2 "$($CMD_install_name $pkg)" '-')")
                    local n_ver=$(get_norm_ver "$(get_field 2 "$f" '-')")     # The version is is in between the 1st and 2nd -
                    if [ "$n_ver" -gt "$c_ver" ]; then 
                        if [ ! -d "$upgr_dst" ]; then cmd '' $CMD_mkdir "$upgr_dst"; fi     # Create dst if the 1st copied, indicates any updates
                        cmd '' $CMD_cp "$full" "$upgr_dst/"
                        echo `date`" - Newer $n_ver > $c_ver, copied '$full' to '$upgr_dst/'" >> $update_chk
                        log_info "Found newer, copied '$full' to ;$upgr_dst'."
                    else
                        echo `date`" - Older or equal $n_ver <= $c_ver, skipped '$full'" >> $update_chk
                    fi
                done
            else
                echo `date`" - No upgrade data dir found: '$upgr_dir'" >> $update_chk
            fi
        else
            echo `date`" - Did not find any upgrade data, tried:$nl$tried" >> $update_chk
        fi
        echo `date`" - Upgrade check finished." >> $update_chk
        log_info "Upgrade check finished. More info written to '$update_chk'"
        ;;
            
    *)
        if [ "$data_dir" != '' ] && [ -d "$data_dir" ]; then
            # check for the right directory (double check)
            log_screen $LOG_sep
            # Copy all files/subdirs as is into the $vardir, outside cmd() logging in done file, which prevents second run as well
            echo `date`" - Found boot data, tried devices:$nl$tried. Copying files:" >> $boot_copied
            /bin/cp -rvf  $data_dir/* $vardir >> $boot_copied 2>&1
            check_success "Copy all boot data from $data_dir to $vardir" "$?"
            log_screen "Copied automate boot data from $dev:$data_dir"

            # Make sure any store script is executable it might be forgotten if a disk image is used
            if [ -f $AUT_pref_store_file ] && [ ! -x $AUT_pref_store_file ]; then
                cmd '' $CMD_chmod +x $AUT_pref_store_file
            fi

            # Also Copy download data if. Which is just a possible option of getting the 
            # data here. A preferred solution would be with local files USB 
            local down_dir="$mnt_dir/$AUT_down_data_dir"
            if [ -d "$down_dir" ]; then
                log_screen "Copying download data, this could take a while."
                # Copy all files/subdirs as is into tmp_download
                $CMD_mkdir $tmp_download
                /bin/cp -rv $down_dir/* $tmp_download >> $boot_copied 2>&1
                check_success "Copy all download data from $down_dir to $tmp_download" "$?"
            fi

            log_screen $LOG_sep
            log_screen ''
        else
            echo `date`" - Did not find any boot data, tried:$nl$tried" >> $boot_copied
            log_info "Did not find boot-data, continuing without it"
        fi
        ;;
esac
   
if [ "$what" != 'mount' ]; then
    func copy_boot_data unmount     # Use ourselfs (prevent code multiplicity for same functionality
fi

return 0
