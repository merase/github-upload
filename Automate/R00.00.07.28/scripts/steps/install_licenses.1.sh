#!/bin/sh

: <<=cut
=script
This step installs the licenses. This script is used for both the installation
and upgrade/recover.
=version    $Id: install_licenses.1.sh,v 1.10 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local type="$1"     # (O) The type of prepare currently instance/zone/<empty>
local extra="$2"    # (O) Extra information (e.g. instance number or zone name)

check_in_set "$type" "$C_TYPE_SET"

init_lic "$type" "$extra"

#
#=* Whenever [ No license-able components ] and [ this is not an OAM node]
#=inc_indent
#=return $STAT_not_applic
#=dec_indent
#=skip_control
#
local cnt=$(map_cnt $map_lic_data)
if [ "$cnt" == '0' -a $dd_is_oam == 0 ]; then   #= Components do not need licenses
    log_info "None of the components '$dd_components' for '$type/$extra' need licenses."
    return $STAT_not_applic     # None found so not applicable
fi

[ ! -d "$tmp_lic" ] && cmd 'Create tmp_lic dir' $CMD_mkdir "$tmp_lic"        #=!

#
#=* Whenever [ all license already available ]
#=inc_indent
#=return $STAT_done
#=dec_indent
#=skip_control
local ok=0
for comp in $(map_keys $map_lic_data); do
    if [ "$(map_get $map_lic_data "$comp/$LIC_typ_prd")" == $LIC_sta_active ]; then
        ((ok++))
    fi
done
if [ "$ok" == "$cnt" -a $dd_is_oam == 0 ]; then #=  All lics ok ] and [ this is not an OAM node 
    if [ "$type" != '' ]; then
        log_info "All components '$dd_components' for '$type/$extra' have stored files, assume they are ok."
    else
        log_info "All components '$dd_components' have stored files, assume they are ok."
    fi
    log_debug "Extra info: ok:$ok, stored:$cnt"
    return $STAT_done
fi


#
# Continue after function declarations (if read for 1st time)
#

: <<=cut
=func_int
Checks if licenses are available. This should only be called if there are 
components to check which do require checking (so not all are stored == pre-check)
=cut
function verify_lics_available() {

    [ -z help ] && show_desc[0]='Checks if all licenses are available.'
    [ -z help ] && show_desc[1]="If not make sure copied to '$tmp_lic'"
    [ -z help ] && show_trans=0

    read_new_license_files

    #
    # Create potential msg and verify the need in one go.
    #
    local str="Not all license are found/correct, license status:$nl"
    local fail=0
    local t
    str="${str}Needed products     : $LIC_need_comps$nl"
    for t in 'A' '*' 'E' 'R'; do
        local act=''
        local prd=''
        local type
        local comp
        for comp in $(map_keys $map_lic_data); do
            for type in $(map_keys "$map_lic_data/$comp"); do
                local data="$(map_get $map_lic_data "$comp/$type")"
                [ "$t" != '*' ] && [ "$t" != "$data"    ] && continue
                [ "$t" == '*' ] && [ "${#data}" -le '1' ] && continue
                case $type in
                    $LIC_typ_prd) prd="$(get_concat "$prd" "$comp" ", ")"           ; ;;
                    $LIC_typ_act) act="$(get_concat "$act" "$comp" ", ")"           ; ;;
                    *) log_info "Warning strange lic type found: '$type' for '$comp'"; ;;
                esac
            done
        done
        case "$t" in
            'A') if [ "$act" != '' ]; then str="${str}Already activated   : ${COL_ok}${act}${COL_def}$nl"              ; fi
                 if [ "$prd" != '' ]; then str="${str}Already installed   : ${COL_ok}${prd}${COL_def}$nl"              ; fi; ;;
            '*') if [ "$act" != '' ]; then str="${str}Found activation    : ${COL_ok}${act}${COL_def}$nl"              ; fi
                 if [ "$prd" != '' ]; then str="${str}Found products      : ${COL_ok}${prd}${COL_def}$nl"              ; fi; ;;
            'E') if [ "$act" != '' ]; then str="${str}Expired activation  : ${COL_warn}${act}${COL_def}$nl"; ((fail++)); fi
                 if [ "$prd" != '' ]; then str="${str}Expired products    : ${COL_warn}${prd}${COL_def}$nl"; ((fail++)); fi; ;;
            'R') if [ "$act" != '' ]; then str="${str}Not found activation: ${COL_info}${act}${COL_def}$nl"; ((fail++)); fi
                 if [ "$prd" != '' ]; then str="${str}Not found products  : ${COL_info}${prd}${COL_def}$nl"; ((fail++)); fi; ;;
            *) log_exit "Unexpected type '$t'"
        esac
    done
        
    if [ "$fail" != '0' ]; then
        str="${str}Our node info: hwId:$LIC_sn_host, ss7:$LIC_sn_ss7, sysSerNum:$LIC_sn_ext instSerNum:$LIC_sn_ins$nl"
        WAIT_pass_request="${str}Please copy proper license to '$tmp_lic'"
    else
        WAIT_pass_request=''
    fi
}

wait_until_passed "$STR_lic_retry_time" "$STR_lic_max_retries" verify_lics_available
if [ $? == 0 ]; then
    log_exit "Not all licenses available, not wise to continue."
fi

#
#=* Copy all the discovered license files to the '$MM_etc'
#=- The tool identifies two types:
#=inc_indent
#=- ours     : being this nodes and always copied
#=- not_ours : Some other node, only copied if this is an OAM node
#=cmd "Copy a license file" $CMD_cp $tmp_lic/<file> $MM_etc
#=dec_indent
#=skip_control
local name
for name in $(map_keys $map_lic_file); do
    local file="$(map_get "$map_lic_file/$name" "$LIC_fld_file")"
    [ "$file" == '' ] && log_exit "Did not find license file '$name'"   # Should not have happened so not continue.
    case "$(map_get "$map_lic_file/$name" "$LIC_fld_state")" in 
        "$LIC_fil_ours")
            cmd "Copy license file '$name'" $CMD_cp "$file" $MM_etc
            ;;
        "$LIC_fil_not_ours")
            if [ $dd_is_oam != 0 ]; then # If OAM then it need all valid files
                cmd "Copy license file '$name' for OAM" $CMD_cp "$file" $MM_etc
            fi
            ;;
        *) : ;;
    esac
done

# Just do for all available lic files:
cmd '' $CMD_chown $MM_usr "$MM_etc/*.lic"
cmd '' $CMD_chgrp $MM_grp "$MM_etc/*.lic"
cmd '' $CMD_chmod "a+r" "$MM_etc/*.lic"

log_info "Installed following files:$nl$(ls -asl $MM_etc/*lic)"              #=!

return $STAT_passed
