#!/bin/sh

: <<=cut
=script
This script will verify some required settings and change them if needed 
(enforce it). This means that no changes are made unless really needed.
The script uses an configuration file '<OS>/etc/system_service_settings.<ver>.txt' 
to find out which service needs to be set and what to expect. The file can be 
generated/adapted using the output of chkconfig. Any service missing 
will be silently ignore (an info msg will be written though). 

The script itself will not start-up any services.
=script_note
It is currently the assumption it is not needed to run these at run-level 1.
This approach might be changed in the future. A reboot might be needed though.
=fail
If this step fails then you'll have to compare all the settings yourself.
The may be skipped, however failures might occur after rebooting.
Systems migh have exceptions, this is however the default case which is
enforce during a fresh instalation only.
=version    $Id: enforce_settings.1.sh,v 1.4 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

#
# Pre-checks
#
check_upgrade_plan_readable 
if [ ! -d $tmp_os_pkgs ]; then
    log_exit "Did not find temporary packages directory '$tmp_os_pkgs'"
fi
local to_rel=$(get_trans_rh_os_release "$tmp_os_pkgs/$OS_NMM_rel_base")

#
# Find the matching files
#
find_install $IP_OS     # There are not multiple version the OS contains all
if [ "$install_aut" == '' ] || [ ! -d "$install_aut/etc" ]; then #= OS pkg not found ] or [ <OS>/etc not a directory 
    # Lets make it a fatal it should not happen though we could continue.
    log_exit "Cannot determine Automate pkg OS/etc directory, which is unexpected."
fi
local dir="$install_aut/etc"
local sorted="$(get_matching_files 'match' "$dir/system_service_settings" $OS $OS_prefix "$to_rel" '' 'txt')"

#=* Enforcing settings ...
#=- Using: $(get_field 3 "$sorted" ';')
#=- Which contains:
#=inc_indent
#=inc_indent
#=cat $(get_field 3 "$sorted" ';')
#=dec_indent
#=cmd 'Compare the settings' $CMD_chkcfg --list
#=dec_indent
#=- Sevice tp_ftransfer will be skipped
#=- For each service, each run level is checled if properly set
#=inc_indent
#=cmd 'If differs then setting change' $CMD_chkcfg --level <run lvl>  <service name.> <new set value>
#=dec_indent
#=skip_until_marker

#
# Process, the file by going through every entry. Skip # and empty lines
#
local file_info
local cnt=0
IFS=$nl; for file_info in $sorted; do IFS=$def_IFS
    ((cnt++))
    if [ "$cnt" == '2' ]; then # Make a small reminder in the log
        log_info "Assumed none overlapping (could be package problem):${nl}$sorted"
    fi

    local info
    local file="$(get_field 3 "$file_info" ';')"
    IFS=''; while read info; do IFS=$def_IFS
        info="$(get_field 1 "$info" '#' | tr '\t' ' ' | tr -s ' ')"
        [ "$info" == '' -o "$info" == ' ' ] && continue

        # Check if service exists
        local svc="$(get_field 1 "$info" )"

        # skip the tp_ftransfer process as we will process it later after resetting the tp_fclient in host config file
        if [ "$svc" == 'tp_ftransfer' ]; then
            log_info "'$svc' will be changed later. This will be done, once the setting of tp_fclient was updated in host config file."
            continue
        fi

        local cur="$($CMD_chkcfg --list $svc 2>/dev/null | tr '\t' ' ' | tr -s ' ')"
        if [ "$cur" == '' ]; then
            log_info "Service '$svc' does not seem to be installed, cannot change it."
            continue
        fi

        # Quick compare if there is difference
        if [ "$info" != "$cur" ]; then
            # Yes there is a difference lets fix them, stop when there are no more items
            local fld=2             # Start at field 2 which should be runlevel 0
            local new="$(get_field $fld "$info")"
            local old
            while [ "$new" != '' ]; do
                old="$(get_field $fld "$cur")"
                if [ "$old" != '' ]; then
                    local new_rl="$(get_field 1 "$new" ':')"
                    local old_rl="$(get_field 1 "$old" ':')"
                    if [ "$old_rl" == "$new_rl" ]; then
                        local new_rl_set="$(get_field 2 "$new" ':')"
                        local old_rl_set="$(get_field 2 "$old" ':')"
                        if [ "$new_rl_set" != "$old_rl_set" ]; then
                            if [ "$new_rl_set" != 'on' -a "$new_rl_set" != 'off' ] ||
                            [ "$old_rl_set" != 'on' -a "$old_rl_set" != 'off' ] ; then
                                log_warning "found strange run-level value ('$new_rl_set' or '$old_rl_set'), ignoring"
                            else
                                # take the approach of one level at a time whihc is easier to program. the amount of changes are expected to be limited.
                                cmd "change service $svc rl:$new_rl to:$new_rl_set" $CMD_chkcfg --level $new_rl $svc $new_rl_set
                            fi
                        else
                            log_debug "ServiceCheck: No change needed for $svc run-level $new_rl ($new_rl_set)"
                        fi
                    else
                        log_warning "Order of run-level entries for '$svc:$old_rl:$new_rl' does not match, ignoring"
                    fi
                else
                    log_warning "Amount of run-level definition for '$svc' does not match, ignoring"
                fi
                ((fld++))
                new="$(get_field $fld "$info")"
            done
        fi
    IFS=''; done < $file;  IFS=$def_IFS
IFS=$nl; done; IFS=$def_IFS
#=skip_until_here

return $STAT_passed
