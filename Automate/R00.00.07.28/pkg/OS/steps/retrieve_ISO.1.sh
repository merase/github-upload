#!/bin/sh

: <<=cut
=script
This step retrieves and moves needed packages files from the the OS ISO (not SW).
The ISO is downloaded/copied as part of this step.
=version    $Id: retrieve_ISO.1.sh,v 1.6 2018/08/02 08:10:05 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local iso_sect="$1"   # (M) The ISO section referring to the data file. Or a /dev/<cdrom> reference.

read_iso_vars "$iso_sect"
if [ "$ISO_file" == '' ]; then
    if [ ! -e "/dev/$iso_sect" ]; then
        log_exit "No file given in [iso/$iso_sect]file='' nor does it refer to device in '/dev/$iso_sect'"
    else
        ISO_device="/dev/$iso_sect"
        log_info "Assuming original ISO on: $ISO_device"
    fi
fi

cmd 'Create temporary directory' $CMD_mkdir $tmp_os_pkgs
cmd 'Clean temproary directory'  $CMD_rm   "$tmp_os_pkgs/*" 
cmd 'Create mountpoint'          $CMD_mkdir $mnt_iso
if [ "$ISO_device" != '' ]; then    #= original I SO device selected
    cmd 'Mount original ISO' $CMD_mount $ISO_device $mnt_iso 
elif [ "$ISO_file" != '' ]; then    #= ISO file selected
    cmd '' $CMD_mkdir $tmp_iso
    download_file $tmp_iso "$ISO_file" "$ISO_md5"
    cmd 'Mounting the ISO' $CMD_mount -rt iso9660 $tmp_iso/$ISO_file $mnt_iso -o loop
fi

cmd 'Copy OS Packages'  $CMD_cp "$mnt_iso/Packages/*.rpm" $tmp_os_pkgs
[ -d $mnt_iso/TKLC ] && cmd 'Copy Our Packages' $CMD_cp "$mnt_iso/TKLC/*.rpm" $tmp_os_pkgs
rel_file="$mnt_iso/$OS_NMM_rel_base"
local rel
if [ -e "$rel_file" ]; then     # Copy existing
    cmd 'Copy NMM-OS release file' $CMD_cp $rel_file $tmp_os_pkgs
    rel="$(cat "$rel_file")"
else                            # Does not exist yet, lets create it with out n
    rel="${ISO_file%.*}"
    echo "$rel" > "$tmp_os_pkgs/$OS_NMM_rel_base"
    check_success "Create NMM-OS release file for '$rel'" "$?"
fi
os_rel="$(get_our_OS_release "$rel")"  # From 7.5 the repositories changed

# Install packaged for according to yum support.
if [ "$OS" == "$OS_linux" ] && [ $OS_ver_numb -ge 70 ]; then
    if [ $os_rel -ge 75 ]; then
        if [ -d "$CFG_pkg_OS_upg_dir" ]; then
            cmd 'Clean legacy os_upgrade directory'        $CMD_rm   "$CFG_pkg_OS_upg_dir" 
        fi
        if [ -d "$CFG_pkg_OS_sup_dir" ]; then
            cmd 'Clean legacy support-packages directory'  $CMD_rm   "$CFG_pkg_OS_sup_dir" 
        fi

        cmd 'Create OS directory' $CMD_mkdir "$CFG_pkg_OS_dir"
        cmd 'Clean OS directory'  $CMD_rm   "$CFG_pkg_OS_dir/*" 
        cmd 'Copy OS Packages'  $CMD_cp "$mnt_iso/Packages/*" "$CFG_pkg_OS_dir"
    else
        cmd 'Create os_upgrade directory' $CMD_mkdir "$CFG_pkg_OS_upg_dir"
        cmd 'Clean os_upgrade directory'  $CMD_rm   "$CFG_pkg_OS_upg_dir/*" 
        cmd 'Copy os_upgrade Packages'  $CMD_cp "$mnt_iso/Packages/*" "$CFG_pkg_OS_upg_dir"

        cmd 'Create OS directory' $CMD_mkdir "$CFG_pkg_OS_dir"
        cmd 'Clean OS directory'  $CMD_rm   "$CFG_pkg_OS_dir/*" 
        cmd 'Copy RHSupport Packages to OS'  $CMD_cp "$mnt_iso/RHSupport-packages/*" "$CFG_pkg_OS_dir"    # No this is not a mistake, reason it is not looped!

        cmd 'Create support-packages directory' $CMD_mkdir "$CFG_pkg_OS_sup_dir"
        cmd 'Clean support-packages directory'  $CMD_rm   "$CFG_pkg_OS_sup_dir/*" 
        cmd 'Copy support-packages Packages'  $CMD_cp "$mnt_iso/support-packages/*" "$CFG_pkg_OS_sup_dir"
    fi
fi

cmd 'Unmount the ISO again' umount $mnt_iso

return $STAT_passed
