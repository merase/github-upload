#!/bin/sh

: <<=cut
=script
This step verifies the installed versions.
=fail
This is a verification step and can be skipped upon failure. One should make
sure the device layout is as expected. And in this case expected is as it
was configured during an install. During an upgrade it will only show
the current configuration (as there is no naming convention).
=version    $Id: verify_versions.1.sh,v 1.6 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

MGR_is_master
# Only do this if this is the master manager node
if [ $? == 0 ]; then
    return $STAT_passed
fi

set_cmd_user $MM_usr 'output'
local out=$(cmd 'Get MGR software versions' 'tp_install_mgr --check')
log_info "tp_install_mgr --check output:$nl$out"
default_cmd_user


#=# Output is processed and stored into internal data-structures
#=skip_control

local ent_lst=''

local output="${nl}MGR Device versions:$nl"
local reserved=7
local dev=''
local in_mgr=0
local in_dev=0
local entry
local e_ip
local e_ver
local e_name
local line
IFS=''
while read line; do
    IFS=$def_IFS
    if [ $in_dev == 0 ] && [[ "$line" =~ 'Current devices' ]]; then
        in_dev=1
    elif [ $in_dev != 0 ]; then
        local new_dev=$(echo -n "$line" | $CMD_ogrep ' *[a-zA-Z]+ :' | $CMD_ogrep '[a-zA-Z]+')
        if [ "$new_dev" != '' ]; then
            dev=$new_dev
            in_dev=1
        else    # Not a device it should be a device entry
            entry="$(echo -n "$line" | $CMD_sed -e 's/\t//g' -e 's/^ *//g' -e 's/ : /:/g')"
            e_ip=$(  get_field 1 "$entry" ':')
            e_ver=$( get_field 2 "$entry" ':')
            e_name=$(get_field 3 "$entry" ':')
            if [ "$e_name" == '' ]; then
                in_dev=0      # name empty not a full line, so finished
                continue
            fi
            ((in_dev++))
        fi
        if [ "$dev" != '' -a $in_dev -ge 2 ]; then
            if [ $in_dev == 2 ]; then
                output+="$(printf "%${reserved}s : " "$dev")"
            else
                output+="$(printf "%${reserved}s : " '')"
            fi
            output+="$e_ip : $e_ver : $e_name$nl"
            # Our names happen to be very usefull as it is: ent-sect-inst
            ent_lst+="$(get_field 1 "$e_name" '-')@$(get_field 2 "$e_name" '-'):$(get_field 3 "$e_name" '-')$nl"
        fi
    elif [ $in_mgr == 0 ] && [[ "$line" =~ 'Current MGR version' ]]; then
        in_mgr=1
    elif [ $in_mgr != 0 ]; then
        e_ver=$(echo -n "$line" | $CMD_sed -e 's/\t//g' -e 's/ *//g')
        output+="$(printf "%${reserved}s : $e_ver" "$C_MGR")$nl"
        in_mgr=0
    fi
    IFS=''
done <<< "$out"
IFS=$def_IFS

#=# The actual output is written to screen and log-file
log_screen_info '' "$output"                                                 #=!

#=* Verify in case of installation
#= It is hard to verify version as the version given is not the version
#= installed. There is also no standard instance information available in the
#= given output (other could use port translation). But if this is an install
#= then we can use our naming convention: ent-sect-inst
#=skip_control
if [ "$STR_run_type" == "$RT_install" ]; then
    local extra=$(echo -n "$ent_lst" | grep -v "$dd_full_system")
    if [ "$extra" != '' ]; then
        log_warning "Found unexpected device:$nl$extra"
        ret=$STAT_warning
    fi
    local missing=$(echo -n $ent_lst | grep -v "$dd_full_system" | grep -v "$extra")
    if [ "$missing" != '' ]; then
        # This is slightly more difficult as the full list could contain
        # components which are not managed by the MGR
        local fcomp
        local check=$(echo -n "$missing" | tr '\n' ' ')
        missing=''
        for fcomp in $check; do
            local comp=$(get_field 1 "$fcomp" '@')
            find_component $comp
            if [ $comp_idx != 0 ] && [ "$comp_device" == 'N' -o "$comp_snmp_port" == '0' ]; then
                continue
            fi
            missing+="$fcomp$nl"
        done
    fi
    if [ "$missing" != '' ]; then
        log_exit "Did not find following devices:$nl$missing"
    fi
fi

return $STAT_passed
