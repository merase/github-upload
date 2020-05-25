#!/bin/sh
: <<=cut
=script
This script will analyze the OS difference between the currently installed 
OS/OS-Packages and the packages on the already loaded OS in the $tmp_os_pkgs
directory. The output will be a lit with package that should be updated.
A difference will be made between kernel packages it self and related OS 
packages.

The list will only contain differences it will not check the 
actual version which will be done when the real RPM's are updated.

Some packages will be excluded from the check (e.g. our own).
=remark
For yum update ti still analyzes but does not check adds/removes
for now this is needed to know if the kernel or other os packages
are updated. Tis approach might not be needed in the future!.
=set OS_kernel_updates
Will contain package names of the kernel to be updated. Or empty if none
=set OS_package_updates
Will contain the packages which require updating.
=set OS_pkgs_added
Will contain the packages which need to be added
=set OS_pkgs_removed
Will contain the packages which need to be removed. This is not implemented yet
and will always be empty (future feature).
=version    $Id: analyze_os_differences.1.Linux.sh,v 1.8 2017/12/13 14:14:55 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

OS_kernel_updates=''
OS_package_updates=''
OS_pkgs_added=''
OS_pkgs_removed=''                      # Not implemented yet
OS_upgrade_to_os_rel=''                 # Is set then the OS's differ.


local sup_arch
if [ ! -d $tmp_os_pkgs ]; then
    log_exit "Did not find temporary packages directory '$tmp_os_pkgs'"
fi

local from_rel=$(get_trans_rh_os_release "$OS_NMM_rel_file" "$OS_version")
local to_rel=$(  get_trans_rh_os_release "$tmp_os_pkgs/$OS_NMM_rel_base")

#
# Let's safe some time (as the package compare is somewhat expensive) in case 
# nothing changed. This is only skipped in case the from and to release are
# exactly the same.
#
local from_ver="$(get_norm_ver "$from_rel")"
local to_ver="$(get_norm_ver "$to_rel")"
if [ "$from_ver" == "$to_ver" ]; then
    log_info "OS version is the same ($to_rel), nothing to upgrade." 
    return 0
elif [ "$to_ver" -lt "$from_ver" ]; then
    log_warning "OS version seem to be downgrading, not supported so skipping"
    return 0
fi
OS_upgrade_to_os_rel="$to_rel"


local same=''
local diff=''
local new=''

log_debug "Analyzing files in '$tmp_os_pkgs':"
local file
for file in $tmp_os_pkgs/*.rpm; do
    find_file_pkg_info "$file" 'check_installed'
    local ret=$?
    if [ $ret != 0 ]; then
        log_debug "Skipping '$file' due to error '$ret'"
        continue
    fi

    is_substr "$found_name" "$GEN_our_pkgs_sp"
    if [ $? != 0 ]; then
        log_debug "Skipping '$file' as it is our own."
        continue
    fi

    if [ "$found_installed" != '' ]; then
        if [ "$found_differ" == '0' ]; then
            same+="$found_name:$found_cur_verrel:$found_version-$found_release:$found_arch$nl"
        else
            diff+="$found_name:$found_cur_verrel:$found_version-$found_release:$found_arch$nl"
        fi
    else
        new+="$found_name:NA:$found_version-$found_release:$nl"
    fi
done

#
# Calculate differences currently supported are:
# Remember our stored names are names without versions!
# K: A kernel package update required
# U: A update needed on existing package
# N: A new package to be added.
# (R: A package to be removed, not needed yet)
#
if [ "$diff" != '' ]; then      # We need to check in differences, not changed no use
    local info
    IFS=$nl; for info in $diff; do IFS=$def_IFS
        local pkg="$(get_field 1 "$info" ':')"
        is_substr "$pkg" "$OS_kernel_pkgs"
        if [ $? == 1 ]; then
            OS_kernel_updates+="$info$nl"
        else
            OS_package_updates+="$info$nl"
        fi
    IFS=$nl; done; IFS=$def_IFS
fi

find_install $IP_OS     # There are not multiple version the OS contains all
if [ "$install_aut" == '' ] || [ ! -d "$install_aut/etc" ]; then
    # Lest make it a fatal it should not happen though we could continue.
    log_exit "Cannot determine Automate pkg OS/etc directory, which is unexpected."
fi
local dir="$install_aut/etc"

if [ $OS_ver_numb -gt 70 ]; then
    # Rest not applicable for RHEL7 and up as yum update takes care of it
    return 0
fi

# Now analyze file which can should be added. These are store int the OS/etc
# directory added-system and removed-system packages
local type
for type in 'added' 'removed'; do
    local sorted="$(get_matching_files 'subrange,movein' "$dir/$type-system_pkgs" $OS $OS_prefix "$from_rel" "$to_rel" 'files')"
    local info
    IFS=$nl; for info in $sorted; do IFS=$def_IFS
        local file="$(get_field 3 "$info" ';')"
        local pkg
        IFS=''; while read pkg; do IFS=$def_IFS
            pkg="$(get_field 1 "$pkg" '#' | $CMD_sed "$SED_del_trail_sp")"
            if [ "$pkg" == '' ]; then continue; fi
            if [ "$type" == 'added' ]; then         # To be added check in new
                local found="$(echo -n "$new" | grep "^$pkg:")"
                if [ "$found" != '' ]; then
                    OS_pkgs_added+="$found$nl"
                else
                    found="$(echo -n "$same$diff" | grep "^$pkg:")"
                    if [ "$found" == '' ]; then
                        log_warning "Package $pkg needs to be added but is not found in OS-ISO ignoring."
                    else
                        log_info "Package $pkg to be added is already installed, no action"
                    fi
                fi
            else
                # has to be 'removed', will not be in same or diff (passed on new OS iso), so use installed
                # It can be it is not installed at
                local pkg_info="$($CMD_install_name "$pkg")"
                if [ "$(echo -n "$pkg_info" | grep 'not installed')" == '' ]; then
                    local rem_ver="$(echo -n "$pkg_info" | sed -r "s/$pkg-(.*)-(.*)\..*/\1-\2/")"
                    if [ "$rem_ver" != '' ]; then
                        OS_pkgs_removed+="$pkg:$rem_ver::$nl"
                    else    # Strange should make a warning
                        log_warning "Package $pkg to be removed could not be identified, no action."
                    fi
                else    # This is info as it is already removed, strange but not worth a warning
                    log_info "Package $pkg to be removed is not installed, no action."
                fi
            fi
        IFS=''; done < $file; IFS=$def_IFS        
    IFS=$nl; done; IFS=$def_IFS
done

return 0