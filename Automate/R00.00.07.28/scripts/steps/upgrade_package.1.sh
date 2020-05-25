#!/bin/sh

: <<=cut
=script
This is the generic upgrade script will can call one or more of the following 
pre/post upgrade scripts/steps if needed. The follow types are allowed:
=le pre-os  : Range identifies an OS. May not be overlapping and is executed before an OS upgrade
=le post-os : Range identifies an OS. May not be overlapping and is executed after an OS upgrade
=le <empty> : Range identifies package version. May be overlapping and is execute when requested
=
The routine searches for two types of files. First the .steps which is a list with
steps to execute. Or .sh which is a single step. Only a single file version is 
allowed (so .1.). e.g.:
=le pre-os-upgrade.1.<os>.<range>.steps steps file
=le post-os-upgrade.1.<os>.<range>.steps steps file
=le upgrade.1.<os>.<range>.steps steps file
=le pre-os-upgrade.1.<os>.<range>.sh script file
=le post-os-upgrade.1.<os>.<range>.sh script file
=le upgrade.1.<os>.<range>.sh script file
=
=script_note
A link may been used to identify a file. Which helps in creating a nicer named
output. However this link has to be located in the same directory (which is
hard to verify automatically). If it not located in the same directory then then
the tool will continue but most likely give an NOT_APPLIC status which.
It is therefore expected that the programmer using this approach knows what he 
does.
=version    $Id: upgrade_package.1.sh,v 1.13 2018/09/05 11:19:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local pkg="$1"      # (M) The short-name of a package to upgrade.
local type="$2"     # (M) The type of upgrade currently pre-os/post-os/upgrade/install

check_in_set "$type" "'',pre-os,post-os,$upg_act_install,$upg_act_upgrade"
type=${type:-$upg_act_upgrade}

#
# Check the current recorded state
#
local state="$(get_state $pkg)"
case "$state" in
    $exe_state_done)
        log_debug "upgrade $pkg: Already done due to dependencies"
        return $STAT_done
        ;;
    $exe_state_upgr)
        log_debug "upgrade $pkg: Already upgraded due to procedure"
        return $STAT_done
        ;;
    $exe_stat_todo)
        # Though it is worth an exit (programming erro, lets keep it a warning
        log_warning "The package '$pkg' should have been stopped, stopping it again"
        func $pkg service stop
        update_state "$pkg" $exe_state_stop
        ;;
    $exe_state_stop)
        :       # This is the expected state
        ;;
    '')
        log_info "upgrade $pkg: Is currently not registered to be upgraded, ignoring"
        return $STAT_not_applic
        ;;
    *)  # Want to show it, it will most likely fail later on.
        log_warning "Unexpected state '$state' for '$pkg', skipping for now."
        return $STAT_warning
        ;;
esac

# 
# Verify package existence
#
find_install "$pkg"
if [ "$install_idx" == '0' ]; then
    log_info "upgrade $pkg: Not defined so no upgrade (not applicable)"
    update_state "$pkg" $exe_state_fail
    return $STAT_not_applic
fi
local dir="$install_aut/steps"
local act_pkgs="$install_act_pkgs"
    
#
# Check if the component is actually requires, this safe checking in the called
# function and allows for proper status reported (nice not applicable)
# This is only need for none components (so the generic packages)
#
find_component "$pkg"           # See if it is an internal component
if [ "$comp_idx" == '0' ]; then # No so need to check if required
    # The upgrade plan should be right so check requires with anyone
    local who=$(get_who_requires "$pkg")
    if [ "$who" == '' ]; then   #= $pkg is not required
        log_info "upgrade $pkg: The package is not required by anyone."
        update_state "$pkg" $exe_state_fail
        return $STAT_not_applic
    fi
fi

retrieve_versions "$pkg"
if [ "$?" != $STAT_passed ]; then   #= version not retrieved
    local ret=$?
    log_info "upgrade $pkg: Versions do not pass, returning $ret."
    update_state "$pkg" $exe_state_upgr             # Register as upgrade so it will be started
    return $ret
fi

#
# We have to stop our dependent packages (E.g. MySQL->PBC
# Where the later is responsible for stopping its dependencies. In this case
# we only look to requires with the flag run-time. Use anyone it does not
# mater if package not installed or active. Only do this if not yet stopped.
#
#=* Stop dependent package if not done.
#=- E.g. if MySQL-Server is upgraded then all dependent should be stopped.
#=- Like PBC, LGP, BAT MGR, etc
#=- MySQL-Server relation is currently the only concerned entity.
#=- The stopped entities get also state '$exe_state_stop'
#=skip_until_marker
local pkgs="$(get_who_requires "$pkg" "$dd_components $dd_supporting" "$REQ_flag_runtime")"
for stop_pkg in $pkgs; do
    if [ "$(get_state $stop_pkg)" == $exe_state_todo ]; then
        func $stop_pkg service stop
        update_state "$stop_pkg" $exe_state_stop
    fi
done
#=skip_until_here

func "$pkg" pre_upgrade     #=# Run optional pre_upgrade script

#
# First install the new version in case of upgrades
#
if [ "$type" == "$upg_act_upgrade" -a "$pkg_from_version" != "$pkg_to_version" ]; then  #= $type is upgrade ] and [ different version
    set_install_comands "$pkg" 
    if [ $? != 0 ]; then    #= yum supported?
        queue_step "yum_update $pkg"
    else
        #=# The install package is responsible from removing obsolete packages (if needed)!
        queue_step "install_package $pkg ver $pkg_full_to_ver"
    fi
fi

#=skip_until_marker Internal stuff sets name to search for
local os_type='Any'
local pfx="$(echo -n "$pkg_full_to_ver" | $CMD_sed -r 's/[0-9_.]+//')"
local name='upgrade'
if [ "$pkg" == "$IP_OS" ]; then   # Always an OS version
    os_type=$OS
    pfx=$OS_prefix
    name=$(get_concat "$type" "$name" '-')
else
    case "$type" in
        'pre-os'|'post-os')     # Currently implies OS version
            name=$(get_concat "$type" "$name" '-')
            os_type=$OS
            pfx=$OS_prefix
            ;;
        ''|"$upg_act_upgrade")
            : ;;       # Leave name as it is
        "$upg_act_install")
            name=''     # Don't do upgrade scripting it is a new install
            ;;
        *) log_exit "Unhandled type '$type' given for upgrade script"; ;;
    esac
fi
#=skip_until_here

#
#=* See if we can find intermediate upgrade steps to do for this package.
#=- This is done by looking at <type><upgrade>.1.<from>-<till>.(steps|sh)
#=- Each file which is within the range of the actual upgrade versions will
#=- be added to the queue. That script can be single file (.sh) or a set of steps 
#=- What is selected depending on the from and to version
#
# In this case take the moveover, movein and always versions, but after each other to
# keep order (always first)
#
# If no matches are found then none are added.
#
#=skip_until_marker
local found=0
if [ "$name" != '' ]; then      # #only search files if name given
    local sorted="$(get_matching_files 'moveover,movein,always' "$dir/$name.1" $OS "$pfx" "$pkg_from_version" "$pkg_to_version" '(steps|sh)')"
    local info
    IFS=$nl; for info in $sorted; do IFS=$def_IFS
        local file="$(get_field 3 "$info" ';')"
        local link="$(readlink -f "$file")"
        queue_step "$link"
    IFS=$nl; done; IFS=$def_IFS
fi
#=skip_until_here
   
execute_queued_steps 'optional'   # This will start the stored list.
if [ $? == 0 -a $found == 0 ]; then #= nothing needed
    log_debug "Did not find any files associated with '$pkg_from_version'"
    update_state "$pkg" $exe_state_upgr
    return $STAT_not_applic
fi

func "$pkg" post_upgrade    #=# Run optional post_upgrade script

update_state "$pkg" $exe_state_upgr            # Package is now upgraded, not started yet

return $STAT_passed
