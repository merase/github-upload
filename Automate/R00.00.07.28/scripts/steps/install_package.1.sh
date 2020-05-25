#!/bin/sh

: <<=cut
=script
This step installs any package delivered by NewNet and which is part
of the package list of the automation tool.

The routine allowed for .gz|.tar|.tar.gz  .rpm|.pkg files

This step is without package knowledge, which means that in some
cases a post_install step is required.

B<A package which is already installed (version set in install table) cannot
be installed again!>
=version    $Id: install_package.1.sh,v 1.29 2018/09/25 06:41:11 fkok Exp $
=author     Frank.Kok@newnet.com
=set installed_pkg
Name of the installed package.
=set installed_ver
version of the installed package.
=example
C<install package OpenSource>     # Installs the opensource package
=example
C<install package E<lt>componentsE<gt>>   # Installs any component belonging to this node
=cut

local name="$1"     # (M) Name of package to be installed.
local subname="$2"  # (O) Sub name, in case of multiple components in 1 package (aliasing). 'ver' is specific to identify a version without subname
local version="$3"  # (O) If subname is ver then this version could identify a specific version to install (overrules $install_ins_ver)

installed_ver=''    # Clear output vars
installed_pkg=''

#
# Find the install information
#
find_install "$name"
if [ "$install_ent" == '' ]; then   #= Package '$name' not found
    return $STAT_not_applic
fi

#=skip_control
ver_to_install=$install_ins_ver
if [ "$subname" == 'ver' ]; then
    if [ "$version" != '' ]; then
        ver_to_install="$version"
        log_debug "Forcing version to install to $name:$version"
    fi
    subname=''
fi  

local idir="$install_dir"           # Make sure it is saved locally
local ifiles="$install_files"       # Make sure it is saved locally

# Difficult one if an old SIO is used with a baseline having new packages.
# Normally retrieve_ISO would fdoun the right one, but we could start in the 
# middle so try to fix the info we need.
#=skip_control
if [ "$install_act_vld" == '0' ] && [ "$install_any_old" != '' ]; then  # Version no validate and old packages
    log_info "Updating ptential old package versions for $name as it was not done this run."
    local pkg
    for pkg in $install_pkgs; do
        find_file $pkg "$idir" 'optional'
        [ "$found_file" == '' ]&& continue
        find_file_version $idir/$found_file
        [ "$found_version" == '' ] && continue
        pkg=`echo "$found_file" | sed "s/-$found_version.*//"`
        update_install_pkg_field '' "$pkg" "$INS_col_ins_ver" "$found_real_version"
        update_install_pkg_field '' "$pkg" "$INS_col_ins_name" "$pkg"
    done
    install_ent=''                  # Make sure renewed in this case as we change he parameters
    find_install "$name"            # Should be okay, if need act_pkgs will be changed!
fi
requested_pkgs="$install_act_pkgs"  # Safe in own global can be overruled by pre-install 
unset requested_options             # Unset requested option as it can be set by pre-install
unset requested_ins_dir
unset requested_allow_dir
unset requested_implicit

#
#=* Tool executes some sanity checks
#=- There should not be a current version installed or
#=- The is a current version, meaning uninstalling first
#=execute_step "uninstall_package $name $install_cur_ver"
#=- Some 'helper' packages are only installed if required.
#=skip_until_marker
local uninstalled=0
if [ "$install_cur_ver" == '' ]; then
    :       # should always be installed
elif [ "$ver_to_install" == '' ]; then
    log_info "No package version known for '$name', using any available"
elif [ "$ver_to_install" != "$install_cur_ver" ]; then
    log_info "The package '$name' will be upgraded from '$install_cur_ver' to '$ver_to_install'"
    execute_step 0 "uninstall_package $name $install_cur_ver"
    uninstalled=1                       # To be able to continue nice feedback
fi
if [ "$install_cur_ver" != '' -a $uninstalled == 0 ]; then
    if [ "$subname" == '' ]; then
        log_warning "The package '$name-$install_cur_ver' is already installed."    # Currently unexpected and thus an error
    else
        log_debug "The package '$name' no specific alias install needed."
    fi
    return $STAT_done
fi

#
# Conditionally install see if anybody requires us. 
# Always install in case Or in case forced by an version
#
if [ "$ifiles" == 'y' -a "$version" == '' ]; then
    local who="$(get_who_requires "$name" "$dd_components $dd_supporting")"
    if [ "$who" == '' ]; then
        log_info "Package '$name' is not required by anybody, skipping."
        return $STAT_not_applic
    fi
fi
#=skip_until_here

#=* Call package specific pre-install (if available):
#=- to see if specific packages are required may change requested_pkgs
#=- to see if any requested_options are to be added.
#=- see <pkg>/funcs/pre_install.*.sh for more info
#=skip_until_marker
cmd '' $CMD_cd $idir            # By default idir is the location, however pre_install may change it
func "$name" pre_install "$ver_to_install"

# 
# If the pre install cleared to the requested_pkgs or if there where none
# in the beginning then this install_package is seen as none applicable
#
if [ "$requested_pkgs" == '' ]; then
    log_info "Package '$name' has not requested pkgs (after pre-install)"
    return $STAT_not_applic
fi
if [ "$requested_implicit" == 'yes' ]; then
    # Remember no post-install will be run afterwards!
    log_info "Package '$name' will be installed implicitly"
    return $STAT_implicit
fi
#=skip_until_here

#=* Execute actual install,
#=- Files are located in $CFG_pkg_tmp_dir, depending on the package it can be
#=- [$CFG_dir_drivers, $CFG_dir_opensource, $CFG_dir_mm_software, $tmp_os_pkgs]
#=- ADVICE: Look at the log files to find the exact failing command.
#=- Newer system could support yum
#=inc_indent
#=unpack_file <file> <dir>/
#=cmd 'Use RPM to install package' $CMD_rpm_install $unpacked_file $requested_options
#=cmd 'Use YUM to install package' $CMD_yum_install $unpacked_file
#=dec_indent
#=skip_until_marker
 
# unpack(if needed) and install the package
log_info "Installing($name): $requested_pkgs"
if [ $uninstalled != 0 ]; then
    start_step "installing package $name $ver_to_install"  # To continue nice feedback
fi

# So see if yum is supported if so simply clal yum and let that do the rest 
# otherwise fallback to the old/own principle. (We don't have a version yet)
set_install_comands "$name" 
if [ $? != 0 ]; then    # yum is supported
    cmd '' $CMD_install $requested_pkgs $requested_options
    # Assume it is install so get the install version (only from first)
    local pkg="$(get_field 1 "$requested_pkgs")"
    func get_pkg_version "$name" '/' "$pkg"
    installed_ver=$func_return
    installed_pkg="$pkg"                    # Set name
else                    # To bad for indenting making a sub-function would require proper var passing
    local pkg
    local first_file_ver=''
    for pkg in $requested_pkgs; do
        find_file $pkg "$idir" '' "$requested_allow_dir"
        unpack_file "$found_file" "$idir/"

        local ext=`echo "$unpacked_file" | $CMD_ogrep "\.$OS_install_ext$"`
        if [ "$first_file_ver" == '' ]; then
            if [ "$ext" == ".$OS_install_ext" ]; then   # get using install tool
                find_file_pkg_info "$found_file"
                [ $? == 0 ] && first_file_ver="$found_version"
            fi
            if [ "$first_file_ver" == '' ]; then    # Not found yet Fallback to more simple file base version
                local len=${#pkg}
                first_file_ver="$(echo "${unpacked_file:$len}" | cut -d'-' -f 2)"       # Take version
            fi
            if [ "$version" != '' -a "$version" != "$first_file_ver" ]; then
                log_exit "Found different version than requested $pkg : $version != $first_file_ver, ISO retrieved?"
            fi
        fi

        if [ "$ifiles" == 'Y' -o "$ifiles" == 'y' ]; then # installing could be done by other tools
            local dir="$idir/$unpacked_file"
            log_debug "processing: $dir"
            if [ -d "$dir" ]; then      # Install all files in the extracted is a dir
                cmd '' $CMD_cd $dir
                # This is a dirty but limited way to install some file wihtout deps. Needed due to the fatc that lperl mysql depends on dual client package
                requested_nodeps=''
                set_install_comands "$name" "$first_file_ver"
                func "$name" pre_install_files
                local file
                for file in $requested_nodeps; do
                    cmd '' $CMD_install "$file" $CMD_iopt_nodep $requested_options
                    cmd '' $CMD_rm "$file"      # Prevent reinstall
                done
                cmd '' $CMD_install "*" $requested_options
                cmd '' $CMD_cd '..'
                cmd '' $CMD_rm $dir     # Remove the directory to cleanup
            elif [ "$ext" == ".$OS_install_ext" ]; then
                cmd '' $CMD_install $unpacked_file $requested_options
            else
                log_exit "Found an unsupported package: '$unpacked_file'"
            fi
        fi

        if [ "$installed_ver" == '' ]; then         # Only store first found version of file
            installed_ver=$first_file_ver           # Copy version
            installed_pkg="$pkg"                    # Set name
        fi
    done
fi

if [ "$installed_ver" != '' ]; then
    update_install_ent_field $name "$INS_col_cur_version" "$installed_ver"
    # Some special handling not the nicest but it works
    case "$name" in
        "$IP_Tools"       ) func TextPass identify_mm_release           ; ;;
        "$IP_MySQL_Server") refresh_mysql_version                       ; ;;
    esac
else
    # Not important enough for user, but log it for the records
    log_info "Did not find a new installed version for $name, no update occurred!"
fi

#=skip_until_here

#=* Execute optional post install (up-to the package)
func "$name" post_install "$installed_pkg-$installed_ver" "$installed_ver" "$installed_pkg" #=!

[ $uninstalled != 0 ] && finish_step $STAT_passed                            #=!

return $STAT_passed