#!/bin/sh

: <<=cut
=script
This step retrieves and moves files from the ISO.
The ISO is downloaded/copied as part of this step.
=version    $Id: retrieve_ISO.1.sh,v 1.13 2018/08/23 09:34:45 fkok Exp $
=author     Frank.Kok@newnet.com
=man1 iso_sect
The ISO section holding then info to download.
=set AUT_retrieved_ISO_file
The last retrieved ISO file name, volatile var to spot if ISO is processed.
=set STR_retrieved_ISO_file
The last retrieved ISO file name
=set STR_retrieved_ISO_md5
The laste retrieved MD5 belonging to the file
=help_todo Complex file, will be done later
=cut

local iso_sect="$1"   # (M) The ISO section referring to the data file. 'file' if direct file/md5 is used
local iso_file="$2"   # (O) The direct file name to use
local iso_md5="$3"    # (O) The md5 belong to the direct file, may be empty
local ver_col="$4"    # (O) The column to use to store version info. By default INS_col_ins_version is used.

ver_col=${ver_col:-$INS_col_ins_version}
#
# Remark although the interface allows for multiple ISO, the implementation
# might need tweaking or separating!
#

if [ "$iso_sect" != '' -a "$iso_sect" != 'file' ]; then
    ISO_file=''
    read_iso_vars "$iso_sect"
    if [ "$ISO_file" == '' ]; then
        log_exit "No file given in [iso/$iso_sect]file=''"
    fi        
elif [ "$iso_file" != '' ]; then
    ISO_file="$iso_file"
    ISO_md5="$iso_md5"
else
    log_exit 'No value given from [iso/?] section, not direct file.'
fi

local i

cmd '' $CMD_mkdir $tmp_iso
download_file $tmp_iso "$ISO_file" "$ISO_md5"
# Mount the ISO
cmd '' $CMD_mkdir $mnt_iso
cmd 'Mounting the ISO' mount -rt udf $tmp_iso/$ISO_file $mnt_iso -o loop

# First dtermine new (>= 17.0) or old ( < 17.0 ISO. Done by looking at SW directory.
local iso_ver
local pkg_dirs
if [ -d "$mnt_iso/SW" ]; then
    # We require a minimal baseline to support this type of iso. As software
    # directories were changed.
    check_min_version "$GEN_our_pkg_baseline" "R17.0.0.1" "This NMM-SW ISO requires target Baseline:$nl"
    iso_ver=2
    pkg_dirs="$CFG_pkg_SW_dir"
else
    check_max_version "$GEN_our_pkg_baseline" "R16.99.99.99" "This NMM-SW ISO is only supported upto target Baseline:$nl"
    iso_ver=1
    pkg_dirs="$CFG_dir_mm_software $CFG_dir_opensource $CFG_dir_drivers $CFG_dir_repodata"
fi

log_info "Layout of the ISO is identified as $iso_ver"
for i in $pkg_dirs; do
    cmd 'Create temporary directory' $CMD_mkdir $i
    cmd 'Empty if still contains files' $CMD_rm $i/*
done

if [ $iso_ver == 1 ]; then # The < 17.0 approach, directories are expected
    cmd 'Copy Product Software' $CMD_cp "$mnt_iso/NewNetPackages/*" $CFG_dir_mm_software
    cmd 'Copy OpenSource Software' $CMD_cp "$mnt_iso/OpenSource/*" $CFG_dir_opensource
    # I've could have made an exception but why not copy always. And decide later 
    if [ "$IP_Adax" != '' ]; then   # Later NMM software has no support 
        cmd 'Copy Adax Software' $CMD_cp "$mnt_iso/Adax/*" $CFG_dir_drivers
    fi
    # repodat was added fro RHEL7.0 chekc existiance before copy
    if [ "$CFG_dir_repodata" != '' ] && [ -d "$mnt_iso/repodata" ]; then
        cmd 'Copy Repo Data' $CMD_cp "$mnt_iso/repodata/*" $CFG_dir_repodata
    fi
else                       # The >= 17.0 approach
    cmd 'Copy Product Software' $CMD_cp "$mnt_iso/SW/*" $CFG_pkg_SW_dir
    cmd 'Create Software Link' $CMD_ln $CFG_dir_mm_software $CFG_pkg_SW_dir
fi

# Unmount the ISO again
umount $mnt_iso

# This si not doen files shul already be there upon installing the NMM-ISO
# That order is kind of strange. It will all be doen using configure_Repository
# create_our_repo_config      # Will do so if needed and found

# Now do some extra work on the versioning. This works on specific versioning of 
# the known iso:
# NMM-SW-10.8.3-108.9.0_RHEL5.iso   (Current)
# 872-2092-109-8.0.4-80.9.0_RHEL5   (older)
# It will take 10.8.3-108.9.0 and 8.0.4-80.9.0 as the version
local ver
ver=`echo "$ISO_file" | cut -d '_' -f1`  # Cut off everything after _
i=`echo "$ver" | cut -d'-' -f5`      # Try the 5th field
if [ "$i" == '' ]; then             # No it is a 4 field version
    ver=`echo "$ver" | cut -d'-' -f3,4`
else
    ver=`echo "$ver" | cut -d'-' -f4,5`
fi
if [ "$ver" != '' ]; then
    update_install_ent_field $IP_TextPass "$ver_col" "$ver"
fi

# Ouch how ugly, but R&D 'cannot' remove faulty ECO Images, see Bug 25571
# This image has wrong MySQL-server names in it and should never be attempted
# to be installed!
if [ "$ver" == "15.7.0-157.1.0" ]; then
    log_exit "Sorry this ISO image '$ver' was marked as invalid and cannot be supported by Automate, use a newer ISO version."
fi
# The NMM-SW-16.0.0-160.1.0 warning was removed. As R&D decide to go back
# to NMM-SW-16.0.0-160.0.0 for their first official version. Meaning it would
# pass the 1 version shortly. And suddenly gave warnings which are invalid.
# Of course it is not wise to go back version wise, nor develop an automated
# procedure on quick sand.
# Left it in for fun for now.
#elif [ "$ver" == "NMM-SW-16.0.0-160.1.0" ] ; then
#    log_wait "This ISO is not fully correct, continue on own risk.
#Known issues:
#- cci does not start up after reboot
#- stv_poll_config_sync fails to start
#- mgr might fail to start, which impact fserver as well
#- several work around applied to fix package issues.
#- others
#Only use for pre-testing purposed "
#fi

# For yum this should not be needed!, so skip it
# Help in case an implementation needs to get files themselves.
if [ $YUM_supported == 0 ]; then 
    local comp
    for comp in $dd_components $dd_supporting; do
        func $comp gather_packages
    done
fi

# YUM: Question do we need this or does it bother doing at the moment. Don't think it bothers for (keep as much same as possible)
# Now retrieve all the version information in the package directory
# All  files in the directory should be packages!
local pkg
local d
local ents_in_iso=''
for d in $pkg_dirs; do
    for i in `ls $d`; do
        find_file_version $d/$i
        if [ "$found_version" != '' ]; then
            pkg=`echo "$i" | sed "s/-$found_version.*//"`
            update_install_pkg_field '' "$pkg" "$ver_col" "$found_real_version"
            update_install_pkg_field '' "$pkg" "$INS_col_ins_name" "$pkg"
            if [ "$updated_ent" == '' ]; then # Lets see if it is wildcarded
                pkg=$(get_field 1 "$pkg")
                update_install_pkg_field '' "*$pkg" "$ver_col" "$found_real_version"
            fi
            if [ "$updated_ent" != '' ]; then
                ents_in_iso="$(get_concat "$ents_in_iso" "$updated_ent:$found_real_version")"
            fi
        fi
    done
done
map_put $map_cfg_iso $ISO_file "$ents_in_iso"

AUT_retrieved_ISO_file="$ISO_file"      # This is a volatile var
STR_retrieved_ISO_file="$ISO_file"      # This will be a permanent var
STR_retrieved_ISO_md5="$ISO_md5"

return $STAT_passed
