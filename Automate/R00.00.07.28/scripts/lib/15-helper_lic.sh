#!/bin/sh

: <<=cut
=script
This script contains simple helper functions which are related to the license
files.
=version    $Id: 15-helper_lic.sh,v 1.13 2018/09/21 11:54:26 fkok Exp $
=author     Frank.Kok@newnet.com

=feat checks for correct licenses
The process requires proper license. It is therefore checked if license are
correct. Meaning for this node, activation available (and not expired), product enabled and 
license available (not expired). 

=feat ability to install valid license and go on
If the license are not valid then the tool can wait for a configurable time and
continues if a proper license is supplied after all.
=cut

#
# These are actually for easy access. They are related to the license table
# from gen_lic.c (a link would be preferred (ideas available). 
# For now one place only (within automate)
#
readonly    LIC_str_hw_id='Hardware ID'
readonly       LIC_str_sn='Serial Number'
readonly   LIC_str_ss7_sn="SS7 Card $LIC_str_sn"
readonly   LIC_str_ext_sn="External $LIC_str_sn"
readonly   LIC_str_ins_sn="Instance $LIC_str_sn"
readonly  LIC_str_zone_sn="Zone $LIC_str_sn"
readonly  LIC_str_lic_key='License Key'
readonly  LIC_str_lic_enc='License Enc'
readonly  LIC_str_enabled='Enabled'
readonly LIC_str_end_date='End date'
readonly   LIC_str_lic_no='License Number'
readonly LIC_str_issue_no='Issue No'    # Also use-able for general issue no 

readonly  LIC_str_true='TRUE'
readonly LIC_Str_false='FALSE'

readonly LIC_sct_gen='GEN'
readonly LIC_typ_act='ACT'
readonly LIC_typ_prd='PRD'

readonly LIC_sta_active='A'
readonly LIC_sta_request='R'
readonly LIC_sta_expired='E'

readonly LIC_fil_ours='O'
readonly LIC_fil_not_ours='N'
readonly LIC_fil_invalid='I'

readonly LIC_fld_name='name'    # Name of file exlucing path
readonly LIC_fld_path='path'    # Full given path
readonly LIC_fld_state='state'  # See LCI_fil_*
readonly LIC_fld_file='file'    # Full path/name

#
# Map to temporary store info:
# LIC_file: List with all files 
#   [full_file]={[(O)urs|(N)ot ours|(I)invalid]}
# LIC_data: Data with the most matching one or short status
#   [COMP/type]={full lic data}   For ACT and PRD
#   [COMP/type]="A"               Means already active, a .store exist
#   [COMP/type]="R"               Still need to identify license
#   [COMP/type]="E"               Only found expired
readonly map_lic_file='LIC_file'
readonly map_lic_data='LIC_data'

: <<=cut
=func_int
Retrieve the value a just a section with license paremeters
=stdout
Empty means not found 
=cut
function get_any_item() {
    local info="$1"     # (M) The info to search in
    local par="$2"      # (M) the parameter to search for use of LIC_str_* is preferred (define if needed)

    echo -n "$info" | grep "$par" | cut -d'=' -f2
}

: <<=cut
=func_int
Check if the given license is a better license than the stored one.
Currently it is not rechecked if the license matches (it should never be 
generated like that and lets assume the other procedures are correct.
This could be improved if needed.
=ret
0 if not better (= not enabled, epxired) otherwise 1
=cut
function better_license() {
    local sect="$1" # (M) The component/section
    local type="$2" # (M) The type of license ACT or PRD
    local info="$3" # (The textual license key info (up until the key)

    # Check if section is enable in GEN (which should have been read before this
    local val
    if [ "$sect" != "$LIC_sct_gen" ]; then
        val=$(get_lic_item "$LIC_sct_gen" "$type" "$sect $LIC_str_enabled")
        if [ "$val" != "$LIC_str_true" ]; then
            log_debug "Comp $sect does not seem to be enabled, not better"
            return 0
        fi

        # See if this license still valid (not yet expired)
        val=$(get_any_item "$info" "$LIC_str_end_date")
        if [ "$val" == 'unlimited' ]; then  # always pass unlimited
            log_debug "Found unlimited end_date for comp $sect, passing"
        elif [ "$val" != '' ]; then
            # Date format is in DD-MM-YYYY
            local ed=($(get_fields "$val" '-'))
            local c_date=$(date '+%s')
            local e_date=$(date -d "${ed[2]}-${ed[1]}-${ed[0]}" '+%s')
            if ((c_date > e_date)); then
                log_debug "Comp $sect seem to be expired on '$val'"
                return 0
            fi                
        else
            log_debug "Comp $sect did not find end_date."
            return 0
        fi
    fi

    # See if there is a current license and if this is newer
    local data="$(map_get $map_lic_data "$sect/$type")"
    if [ "${#data}" -le '1' ]; then
        log_debug "Storing 1st valid for '$sect/$type'"
        map_put $map_lic_data "$sect/$type" "$info"
        return 1        # It is the first valid one
    fi

    # Check the license number better should be higher
    if [ "$sect" != "$LIC_sct_gen" ]; then
        local cur_licno=$(get_lic_item "$sect/$type" "$LIC_str_lic_no")
        local our_licno=$(get_any_item "$info"      "$LIC_str_lic_no")
        cur_licno=$(get_field 2 "$cur_licno" '-')
        our_licno=$(get_field 2 "$our_licno" '-')
        if [ "$cur_licno" == '' -o "$our_licno" == '' ]; then
            log_debug "Problem with license_no for $sect ('$our_licno' '$cur_licno')"
            return 0
        elif ((our_licno < cur_licno)); then
            log_debug "Comp $sect has lower license number ($our_licno < $cur_licno)"
            return 0
        fi
    fi

    
    # Check the issue number better should be higher
    local cur_issue=$(get_lic_item "$sect/$type" "$LIC_str_issue_no")
    local our_issue=$(get_any_item "$info"      "$LIC_str_issue_no")
    if [ "$cur_issue" == '' -o "$our_issue" == '' ]; then
        log_debug "Problem with issue_no for $sect ('$our_issue' '$cur_issue')"
        return 0
    elif ((our_issue < cur_issue)); then
        log_debug "Comp $sect has lower issue number ($our_issue < $cur_issue)"
        return 0
    fi
        
    # If we come here then this is better, store it
    log_debug "Comp $sect found a better license '$our_licno-$our_issue_no'"
    map_put $map_lic_data "$sect/$type" "$info"
    return 1
}

: <<=cut
=func_int
Read a license file if it matches out the the better license matches are
updated.
=cut
# Some local functions first
function read_license_file() {
    local file="$1"     # (M) The file to read in.

    local seqno=0       # 0 also means activation (that is at least how it internally works)
    local licno=$(echo "$file" | cut -d'-' -f2)
    local type="$LIC_typ_prd"
    if [ "$(echo "$file" | grep '.*_activation.lic$')" != '' ]; then
        type="$LIC_typ_act"
    else
        seqno=$(echo "$file" | cut -d'-' -f3 | cut -d'.' -f1)
    fi                  # Not interest in others type at the moment!

    # Write or update some data (always)
    local name="$(basename "$file")"
    map_put "$map_lic_file/$name" "$LIC_fld_name" "$name"
    map_put "$map_lic_file/$name" "$LIC_fld_path" "$(dirname "$file")"
    map_put "$map_lic_file/$name" "$LIC_fld_file" "$file"

    #
    # First get the generic information to check if this license (only check GEN)
    # belong s to this node
    #
    local info=$(grep $file  -e "$LIC_str_hw_id" -e "$LIC_str_sn" -e "($LIC_sct_gen)")
    local line
    local enc=''
    local map_tmp_data='LIC_tmp_data'
    map_init $map_tmp_data
    while read line; do
        local par=$(echo "$line" | cut -d'=' -f1 | sed "$SED_del_trail_sp")
        local val=$(echo "$line" | cut -d'=' -f2 | sed "$SED_del_preced_sp")
        map_put $map_tmp_data "$par" "$val"
        if [ "$(echo "$par" | grep "$LIC_str_lic_key")" != '' ]; then
            local digit=$(echo "$val" | cut -d'-' -f2 )
            enc=$(echo "ibase=16; ${digit:3}" | bc)
        fi
    done <<< "$info"

    #
    # Now check if this file belongs to this node
    #
    local pass=0
    if [ "$enc" != '' ]; then
        local sn_ins=''
        if (((enc & 8) == 8)); then    # Get the it form zone ir instance field (mutual exclusive)
            sn_ins="$(map_get $map_tmp_data "$LIC_str_ins_sn")"
            [ "$sn_ins" == '' ] && sn_ins="$(map_get $map_tmp_data "$LIC_str_zone_sn")"
        fi

        if (((enc & 1) == 1)) && [ "$(map_get $map_tmp_data "$LIC_str_hw_id")" != "$LIC_sn_host" ]; then
            log_debug "Ignoring $licno with hostid '$(map_get $map_tmp_data "$LIC_str_hw_id")' does not belong to us '$LIC_sn_host'"
        elif (((enc & 2) == 2)) && [ "$(map_get $map_tmp_data "$LIC_str_ss7_sn")" != "$LIC_sn_ss7" ]; then
            log_debug "Ignoring $licno with ss7 '$(map_get $map_tmp_data "$LIC_str_ss7_sn")' does not belong to us '$LIC_sn_ss7'"
         # Bug 26939, lics can be limited to 40, 39 (space removed)
        elif (((enc & 4) == 4)) && [ "$(map_get $map_tmp_data "$LIC_str_ext_sn")" != "$LIC_sn_ext" ] &&
                                   [ "$(map_get $map_tmp_data "$LIC_str_ext_sn")" != "${LIC_sn_ext:0:40}" ] &&
                                   [ "$(map_get $map_tmp_data "$LIC_str_ext_sn")" != "${LIC_sn_ext:0:39}" ] &&
                                   [ "$(map_get $map_tmp_data "$LIC_str_ext_sn")" != "reliable"    ]; then          # allow for special reliable encodings
            log_debug "Ignoring $licno with ext snr. '$(map_get $map_tmp_data "$LIC_str_ext_sn")' does not belong to us '$LIC_sn_ext'"
        elif (((enc & 8) == 8)) && [ "$sn_ins" != "$LIC_sn_ins" ]; then
            log_debug "Ignoring $licno with ins/zone snr. '$sn_ins' does not belong to us '$LIC_sn_ins'"
        else
            pass=1
        fi
    else    # No encoding which is strange mark as invalid
        map_put "$map_lic_file/$name" "$LIC_fld_state" $LIC_fil_invalid
    fi
    if [ $pass == 0 ]; then     # Mark as not ours
        map_put "$map_lic_file/$name" "$LIC_fld_state" $LIC_fil_not_ours
    else
        map_put "$map_lic_file/$name" "$LIC_fld_state" $LIC_fil_ours
    fi

    local mark=$(map_get "$map_lic_file/$name" "$LIC_fld_state")
    log_debug "License file '$file' marked as '$mark'"
    if [ "$mark" != $LIC_fil_ours ]; then
        return      # No need to continue if not active
    fi

    # 
    # Read the file section by section, check if needed along the way
    #
    local line 
    local sect=''
    local info=''
    while read line; do
        if [ "$sect" == '' ]; then
            sect=$(echo "$line" | $CMD_ogrep '^-{3,} [A-Z]{2,3} -{3,}$' | $CMD_ogrep '[A-Z]{2,3}')
        else
            line=$(echo -n "$line" | sed 's/ *= */=/g')
            info=$(get_concat "$info" "$line" "$nl")
            if [ "$(echo "$line" | grep "^$LIC_str_lic_key")" != '' ]; then
                better_license "$sect" "$type" "$info"
                if [ $? != 0 ]; then
                    map_put $map_lic_data "$sect/$type" "$info"
                elif [ "$(map_get $map_lic_data "$sect/$type")" == "$LIC_sta_request" ]; then
                    map_put $map_lic_data "$sect/$type" $LIC_sta_expired
                fi
                info=''
                sect=''
            fi
        fi
    done < $file
}

: <<=cut
=func_frm
Initializes the license reading.
=set LIC_need_comps
A comma separated list with the needed components.
=cut
function init_lic() {
    local type="$1"     # (O) The type of prepare currently instance/zone/<empty>
    local extra="$2"    # (O) Extra information (e.g. instance number or zone name)

    [ -z help ] && show_ignore=1        # Too in-depth for now

    map_init $map_lic_file
    map_init $map_lic_data

    #
    # Initialize first with needed components
    #
    local components=''
    case "$type" in
        instance) components="$(get_all_components $hw_node instance "$extra")" ; ;;
        zone)     components="$dd_components"; ;;           # Should be this never verified
        *)        components="$dd_components"; ;;
    esac
    
    LIC_need_comps=''
    local comp
    for comp in $components; do
        find_component $comp
        if [ "$comp_idx" != '0' -a "$comp_lic" != '' ]; then
            LIC_need_comps=$(get_concat "$LIC_need_comps" "$comp_lic" ', ')
            map_put $map_lic_data "$comp_lic/$LIC_typ_prd" $LIC_sta_request
            map_put $map_lic_data "$comp_lic/$LIC_typ_act" $LIC_sta_request
        fi
    done

    #
    # See if we can find .store file : .nvr.<comp> file
    #
    if [ -d "$MM_store" ]; then
        for comp in $(map_keys $map_lic_data); do
            if [ -e "$MM_store/.nvr.$comp" ]; then
                map_put $map_lic_data "$comp/$LIC_typ_prd" $LIC_sta_active
                map_put $map_lic_data "$comp/$LIC_typ_act" $LIC_sta_active
            fi
        done
    fi

    #
    # Collect the serial number information
    #
    LIC_sn_host=$(hostid | sed 's/^0*//g')
    LIC_sn_ext="$hw_serial_number"
    LIC_sn_ss7=''   # Not fully supported yet
    LIC_sn_ins=''
    case "$type" in
        instance) LIC_sn_ins=$((extra+200))      ; ;;
        zone)     LIC_sn_ins=${extra:-global}    ; ;;
        *)        LIC_sn_ins='n.a.'              ; ;;
    esac

}


: <<=cut
=func_frm
Read all new/invalid license files. All others are ignored. It is not supported
to fix a mistake in earlier supplied license (this to speed up the process).
=cut
function read_new_license_files() {
    local file
    for file in $tmp_lic/*.lic; do
        [ ! -e "$file" ] && continue   # Skip none matching
        local state="$(map_get "$map_lic_file/$(basename "$file")" "$LIC_fld_state")"
        case "$state" in
            ''|$LIC_fil_invalid) read_license_file "$file"; ;;
            *) log_debug "Skipping file, state='$state'"
        esac
    done
}


: <<=cut
=func_frm
Retrieve the value a specific license parameter.
=stdout
Empty means not found 
=cut
function get_lic_item() {
    local comp="$1"     # (M) The component section to search for see $comp_lic for options. With GEN added. Add /ACT if activation data is needed
    local type="$2"     # (M) The type of license ACT or PRD
    local par="$3"      # (M) the parameter to search for use of LIC_str_* is preferred (define if needed)

    echo -n "$(map_get $map_lic_data "$comp/$type")" | grep "$par" | cut -d'=' -f2
}

: <<=cut
=func_frm
This function will translated a component into a license section or
return empty if not licensed. It basically is subtracted from gen.h and needs
adaptation if products added (or generated). This made in the license helper
to make it centralized.
=stdout
Will hold the license section or empty if not licesned.
=cut
function LIC_get_lic_sect() {
    local comp="$1" # The textpass component to translate

    local sect="$comp"      # Default same a comp !
    # first some quick wins.
    if   [ "${comp:0:2}" == 'XS'  ]; then sect='XS'
    elif [ "${comp:0:2}" == 'EC'  ]; then sect='EC'
    elif [ "${comp:0:3}" == 'SPF' -a "$comp" != 'SPFSOAP' ]; then sect='SPF'
    else
        case $comp in
            RTR) sect='TPR'; ;; # Old naming
            HUB) sect='TPH'; ;; # Old naming
            AMS|BAT|CRA|EMG|FAF|IIW|LGP|NAF|PBC|SCR) sect="$comp"; ;; # same as comp
            *)   sect=''   ; ;; # No license section
        esac
    fi

    echo -n $sect
}

