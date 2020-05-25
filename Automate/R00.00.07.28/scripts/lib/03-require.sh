#!/bin/sh

: <<=cut
=script
This script contains simple but very important helper functions related
the require functionality.
=version    $Id: 03-require.sh,v 1.33 2019/01/24 09:40:41 skrish10 Exp $
=author     Frank.Kok@newnet.com
=cut

readonly       map_pkg='REQ_pkg'
readonly      map_intf='REQ_intf'
readonly      map_node='REQ_node'

readonly   req_typ_package='package'
readonly req_typ_interface='interface'
readonly      req_typ_node='on_nodes'
readonly       req_typ_all="$req_typ_package,$req_typ_interface,$req_typ_node"

# Fields used by require information which is also stored in $map_cfg_ins
readonly  req_fld_type='type'      # The required type. (min, exact, any). Default any if not given.
readonly   req_fld_ver='ver'       # A version to check for, see also type
readonly   req_fld_cur='cur'       # The current (interface) version.
readonly   req_fld_ent='ent'       # And package/entity requiring a package
readonly  req_fld_node='node'      # A node requiring this package.
readonly  req_fld_with='with'      # Interfaces with a specific comp/ent
readonly   req_fld_sel='selective' # indicates the this requirement depend on one or more (or'ed) variables. 
readonly req_fld_flags='flags'     # Optional flags to define the dependency see REQ_flag_* (comma sep)

# Requirement Internal and External types, as use internally (perhaps it can change in external names, 
# but single chars are easier/understandable in the output
readonly   REQ_etype_any='any'
readonly   REQ_etype_min='min'
readonly REQ_etype_exact='exact'
readonly      REQ_etypes="$REQ_etype_any,$REQ_etype_min,$REQ_etype_exact"

readonly   REQ_itype_any='*'        # Maps from REQ_etype_any
readonly   REQ_itype_min='<'        # Maps from REQ_etype_min
readonly   REQ_itype_max='>'        # Not yet externally supported (yet)
readonly REQ_itype_exact='='        # Maps from REQ_etype_exact

readonly REQ_flag_runtime='run-time'       # Means the the direct parent needs to be stop/started if this is to be installed (default)
readonly REQ_flag_install='install-only'   # Re-Installation is allowed without stopping parent
readonly REQ_flag_upg_bck='upgrade-backup' # The parent should be backup-up if this being upgraded
readonly REQ_flags="$REQ_flag_runtime,$REQ_flag_install,$REQ_flag_upg_bck"

# Readable value used for compare_ver function
readonly   REQ_cmp_equal=0          # ver1 == ver2
readonly    REQ_cmp_less=1          # ver1 <  ver2
readonly REQ_cmp_greater=2          # ver1 >  ver2

: <<=cut
=func_int
Get the map to a specific entity and type of require
=need map_cfg_ins
=stdout
The map directory
=cut
function get_require_map() {
    local who="$1"      # (M) The entity:<version? requiring this install
    local what="$2"     # (M) What to add: P for package or I for interface
    local name="$3"     # (M) The name of entity or interface

    local ent="$(get_field 1 "$who" ':')"
    local ver="$(get_field 2 "$who" ':')"
    ver=${ver:-any}
    echo -n "$map_cfg_ins/$ent/$INS_col_require/$ver/$what/$name"
}

: <<=cut
=func_int
Add any requirement. It will only be added into the internal structures.
It will need combining/dependent search when all collected.
if the package is installed and has the right version
if not then it will be printed to be installed
=cut
function add_require() {
    local who="$1"      # (M) The entity:<version> requiring this install
    local what="$2"     # (M) What to add: req_typ_* (e.g. package or interface)
    local name="$3"     # (M) The name of entity or interface
    local type="$4"     # (O) The required type. (min, exact, any). Default any if not given.
    local ver="$5"      # (O) A version to check for, see also type
    local cur="$6"      # (O) The current version (only useful for interface). Will be overruled/checked by exact
    local with="$7"     # (O) Optionally identifies with which component is been interfaced (FFU) (comma separated). Only useful for interface
    local flags="$8"    # (O) Define additional flags comma sep (see REQ_flags), default to REQ_flag_runtime

    log_debug "add_require: w:$who, wh:$what, i:$name, t:$type, v:$ver, w:$with, f:$flags."
    check_set "$who" 'Entity is missing'
    check_in_set "$what" "$req_typ_all"
    check_set "$name" 'Required dependency is missing'

    # Check flags one by one to allow multiple for the future
    flags=${flags:-$REQ_flag_runtime}
    local flag
    for flag in $(echo -n "$flags" | tr ',' ' '); do
        check_in_set "$flag" "$REQ_flags"
    done

    cur=${cur:-$ver}
    case $type in
        $REQ_etype_min   )
            type=$REQ_itype_min
            compare_ver "$cur" "$ver"
            if [ $? == $REQ_cmp_less ]; then
                log_exit "Minimal version not reached by current ($cur < $ver), definition error!"
            fi
            ;;
            
        $REQ_etype_exact )  
            type=$REQ_itype_exact
            if [ "$cur" != "$ver" ]; then 
                log_exit "Exact version requested but current differ ($cur != $ver), definition error!"
            fi
            ;;
            
        $REQ_etype_any|'')
            type=$REQ_itype_any
            ver='*'
            ;;
            
        *) log_exit "Wrong type given for add_require: '$type', use '$REQ_etypes'."; ;;
    esac
    
    local map="$(get_require_map $who $what $name)"
    if [ "$(map_get "$map" "$name")" != '' ]; then
        log_warning "The require for $who, $what, $name already exists!"
    else
        # The map path by itself defines the who and what and name
        map_put "$map" $req_fld_type  "$type"
        map_put "$map" $req_fld_ver   "$ver"
        map_put "$map" $req_fld_cur   "$cur"
        map_put "$map" $req_fld_flags "$flags"
    fi

    return 0
}    

: <<=cut
=func_int
Adds an selective dependency for an existing install requirement. This is basically
telling the processing engine that this requirement depends on a specific variable
with a specific value.
=func_note
The var 'hw_node' get special treatments as it means specific nodes are eligible
for the who entity. The values should be , separates like all selectives. And
'<none.' should be used to indicate no nodes. Remember calling it with none
has different effect then not calling it. As none is treated as no nodes can 
match.
=cut
function add_selective_info() {
    local who="$1"      # (M) The entity:<version? requiring this install
    local what="$2"     # (M) What to add: req_typ_* (e.g. package or interface or node)
    local name="$3"     # (M) The name of entity or interface
    local var="$4"      # (M) A variable to make the selective dependency on, require value as well
    local val="$5"      # (M) A value to match in case var is set. Use command to specify multiple exact values

    check_set "$who" 'Entity is missing'
    check_in_set "$what" "$req_typ_all"
    check_set "$name" 'Required dependency is missing'
    check_set "$var"  'Variable is missing'
    check_set "$val"  "Value is missing"

    local map="$(get_require_map $who $what $name)"
    local cur_val="$(map_get "$map/$req_fld_sel" "$var")"
    if [ "$cur_val" != '' -a  "$cur_val" != "$val" ]; then
        log_info "Updating selective info for $who, $what, $name, $var from $cur_val to $val"
    fi
    map_put "$map/$req_fld_sel" "$var" "$val"

    # Special case for hw_node
    if [ "$var" == 'hw_node' -a "$val" != '' ]; then
        if  [ "$val" == '<none>' ]; then    # Make dir which cause it to known it is needed
            map_put "$map/$req_fld_node" "none" ''  # Empty will be removed but create dir
        else
            local node
            for node in $(echo -n "$val" | tr ',' ' '); do
                map_put "$map/$req_fld_node" "$node" '1'    # One just a value but lets say it means on.
            done
        fi
    fi

    return 0 
}

: <<=cut
=func_int
Checks if a requirement is selected or not. This is done by looking the req_fld_sel
map and if it exists it check if one the optional values is true.
If the variable to be checked does not exists then it try to run the proper
define_vars first based on the prefix.
=return
1 it is selected, either always or matches. 0 is not select (need optional 
which do not match.
=cut
function is_req_selected() {
    local map="$1"  # The full map or the requirement which could include the optional parameters
    
    map_exists "$map/$req_fld_sel"
    if [ $? == 0 ]; then return 1; fi   # No optional so always selected
    
    #
    # All the variables in the optional directory are current or-ed so if one 
    # matches then the requirement is selected
    #
    local var
    for var in $(map_keys "$map/$req_fld_sel"); do
        if [ "${!var}" == '' ]; then  # the var does not exist try to call define_vars
            local comp=$(get_field 1 "$var" '_')
            log_debug "Trying to call define_vars for '$comp' to hopefully define '$var'"
            func "*$comp" define_vars
        fi
        if [ "${!var}" == '' ]; then    # The var does not exist log_info and not selected
            log_info "'$var' is not defined which was needed for '$map' assume disabled"
            return 0
        fi
        local val="$(map_get "$map/$req_fld_sel" "$var")"
        if [ "$val" == '' ]; then
            log_exit "Could not retrieve value for '$map/$var' which is strange."
        fi
        is_substr "${!var}" "$val" ','
        if [ $? != 0 ]; then return 1; fi
    done
    return 0
}

: <<=cut
=func_int
Combines a single require into a (potential) existing require. This function
was separate to lower the indents and readability of combine_requires, it should
not be called directly (as other initialization/checking is needed).
=cut
function combine_into_require() {
    local map="$1"       # (M) The base map to used e.g. package or interface incl the sub_entity
    local req_ent="$2"   # (M) The requesting entity
    local req_ver="$3"   # (M) The requesting entity version
    local ins_ent="$4"   # (M) The needed/required entity
    local ins_typ="$5"   # (M) The needed/required type (see REQ_itype_*)
    local ins_ver="$6"   # (O) The needed/required version (*/empty in case of any)
    local ins_flags="$7" # (O) The needed/required flags (see REQ_flag_*)

    check_set "$ins_typ" "No type set"
    ins_ver=${ins_ver:-"$REQ_itype_any"}
    
    local chk_ver="$(map_get "$map" "$req_fld_ver")"
    if [ "$chk_ver" == '' ]; then   # does not yet exist
        map_put "$map"              "$req_fld_type" "$ins_typ"
        map_put "$map"              "$req_fld_ver"  "$ins_ver"
        map_link "$map/$req_fld_ent" "$req_ent" "$map_cfg_ins"
        local flag
        for flag in $(echo -n "$ins_flags" | tr ',' ' '); do
            map_link "$map/$req_fld_ent-$flag" "$req_ent" "$map_cfg_ins"
        done
        return      # Safes indent level
    fi

    local chk_typ="$(map_get "$map" "$req_fld_type")"
    local new_ver=''
    local new_typ=$ins_typ

    compare_ver "$ins_ver" "$chk_ver"       # put here makes code simpler
    local cmp=$?

    case "$ins_typ" in
        "$REQ_itype_any")    # Anything is allowed however not * gives a warning
            new_ver=$chk_ver
            ;;                       
        "$REQ_itype_min")
            case "$chk_typ" in
                "$REQ_itype_any")    # Always take the other minimum version
                    new_ver=$ins_ver
                    ;;
                "$REQ_itype_min")    # Change version to the higest minimum
                    if [ $cmp == '2' ]; then
                        new_ver=$ins_ver
                    else
                        new_ver=$chk_ver
                        new_typ="$REQ_itype_min"
                    fi
                    ;;
                "$REQ_itype_exact")    # Only allowed if minimum is less equal exact
                    if [ $cmp == 0 -o $cmp == 1 ]; then
                        new_ver=$chk_ver
                        new_typ="$REQ_itype_exact"
                    fi
                    ;;
            esac
            ;;
        "$REQ_itype_exact")    # Only allowed if exactly the same or if the other has a lower minimal or if any
            if [ $cmp == 0 ] || 
               [ "$chk_typ" == "$REQ_itype_any" ] ||
               [ "$chk_typ" == "$REQ_itype_min" -a $cmp == 2 ]; then
                new_ver=$ins_ver
            fi
            ;;
        *) log_exit "Wrong stored version type '$ins_typ' ($req_ent:$req_ver => $ins_ent:$ins_ver)"; ;;
    esac
    if [ "$new_ver" == '' ]; then
        # THis might need to change into less strict. E.g. store the incompatibility
        # As it is not said the user will actually hit the incompatibility
        log_exit "Incompatibility problem for $ins_ent: $(map_keys "$map/$req_fld_ent") requires $chk_typ$chk_ver, $req_ent needs $ins_typ$ins_ver"
    elif [ "$new_typ$new_ver" != "$chk_typ$chk_ver" ]; then
        log_debug "Updating $ins_ent: from $chk_typ$chk_ver to $new_type$new_ver"
        map_put "$map" "$req_fld_type" "$new_typ"
        map_put "$map" "$req_fld_ver"  "$new_ver"
    fi

    map_exists "$map/$req_fld_ent/$req_ent"
    if [ $? == 0 ]; then
        log_debug "Linking $req_ent to $ins_ent (1st time)"
        map_link "$map/$req_fld_ent" "$req_ent" "$map_cfg_ins"
    fi
    local flag
    for flag in $(echo -n "$ins_flags" | tr ',' ' '); do
        map_link "$map/$req_fld_ent-$flag" "$req_ent" "$map_cfg_ins"
    done
}    

: <<=cut
=func_int
Retrieves which entities requires a specific product or interface.
The function can go recursively through the entities as some dependencies might
be more then one  level deep.
=stdout
All the components in need of the given product. The components are
separated by a space.
=cut
function get_which_ents_requires() {
    local map="$1"      # (M) The map towards the package or interface requirements
    local prod="$2"     # (M) The product to retrieve the information for 
    local flag="$3"     # (O) The flag to search for use <empty> for all
    local allow="$4"    # (O) A list (space separated) with components/package which are allowed for the retrieval. Empty all in the data resource
    local visited="$5"  # (O) A list (space separated) with visited entities, to prevent loops
    local one_lvl="$6"  # (O) If set then only current level is searched (not recursive)


    check_in_set "$flag" "'',$REQ_flags"

    is_substr "$prod" "$visited"
    if [ $? != 0 ]; then return; fi     # already visited 
    visited="$(get_concat "$visited" "$prod")"

    local ents="$(map_keys "$map/$prod/$req_fld_ent")"
    if [ "$allow" == '' ]; then
        echo -n "$ents"         # just return all keys 
    else
        local ent
        for ent in $ents; do
            is_substr "$ent" "$allow"
            if [ $? != 0 ]; then
                if [ "$flag" != '' ]; then              # Check if flag matches
                    map_exists "$map/$prod/$req_fld_ent-$flag/$ent"
                    [ $? != 0 ] && echo -n "$ent "
                else                                    # all allowed
                    echo -n "$ent "
                fi
            elif [ "$prod" != "$ent" -a "$one_lvl" == '' ]; then
                # Look for sub level, by calling recursively. After that put on 
                # visited list to prevent loops
                get_which_ents_requires "$map" "$ent" "$flag" "$allow" "$visited"
                visited="$(get_concat "$visited" "$ent")"
            fi
        done
    fi
}


: <<=cut
=func_ext
Compare two versions. The subversion should separate by '.' Any preceding
alpha character will be ignored. The maximum digits depends on get_norm_ver.
=ret
See REQ_cmp_* values. Basically: 0 is equal, 1 if ver1 < ver2, or 2 if ver1 > ver2
=cut
function compare_ver() {
    local ver1="$1"  # (M) the src version to be compared
    local ver2="$2"  # (M) the dst version to be compared

    local idx=1
    ver1=`echo -n "$ver1" | $CMD_ogrep '[0-9].*'`
    ver2=`echo -n "$ver2" | $CMD_ogrep '[0-9].*'`
    cmp1=$(get_norm_ver $ver1)
    cmp2=$(get_norm_ver $ver2)

    if [ "$cmp1" == "$cmp2" ]; then
        return $REQ_cmp_equal
    elif [ "$cmp1" -lt "$cmp2" ]; then
        return $REQ_cmp_less
    fi
    return $REQ_cmp_greater
}

: <<=cut
=func_frm
Add a requirements for a command to be able to proceed. 
For now simple checks to be improved,
=cut
function add_cmd_require() {
    local req_cmd="$1"  # (M) The required command
    local user="$2"     # (O) The user to run the check under
    local no_check="$3" # (O) If set then check for success is skipped, use return value

    [ -z help ] && show_trans=0 && show_short="script requires '$req_cmd' to continue, install if missing"

    if [ "$user" == '' ]; then
        `which $req_cmd >>$LOG_file 2>1`
    else
        `su - $user -c "which $req_cmd" >> $LOG_cmds 2>&1`
    fi
    local ret=$?

    [ "$no_check" == '' ] && check_success "require cmd: $req_cmd" "$ret"

    return $ret

    [ -z help ] && ret_vals[0]="Successfully found '$req_cmd'"
    [ -z help ] && ret_vals[1]="Failed to locate '$req_cmd', please install manually."
}

: <<=cut
=func_frm
Compares a given version with the version of the installed package.
=return
0 given is higher or pkg not found, 1 given is same or lower
=cut
function compare_pkg_version() {
    local pkg="$1"  # (M) The package name to check e.g. ${GEN_our_pkg_pfx}Automate
    local cmp="$2"  # (M) The version to compare with.
    
    local ver="$($CMD_install_query $pkg | grep 'Version' | sed "$SED_del_spaces" | cut -d' ' -f3)"
    local cmp_ver="$(get_norm_ver "$cmp")"
    local cur_ver="$(get_norm_ver "$ver")"
    if [ "$ver" == '' ] || [ "$cmp_ver" -gt "$cur_ver" ]; then
        return 0
    fi
    return 1
}

: <<=cut
=func_frm
Checks the minimal required version of a specific package (>=)
=cut
function check_min_version() {
    local pkg="$1"  # (M) The package name to check e.g. ${GEN_our_pkg_pfx}Automate
    local min="$2"  # (O) The minimum version required. Version are normalized. If empty only package installation checked.
    local info="$3" # (O) Optional extra info for the reason behind this require, please add $nl 

    local ver="$($CMD_install_query $pkg | grep 'Version' | sed "$SED_del_spaces" | cut -d' ' -f3)"

    if [ "$min" == '' ]; then
        check_set "$ver" "${info}Did not find required packaged '$pkg' at all."
    else
        local min_ver="$(get_norm_ver "$min")"
        local cur_ver="$(get_norm_ver "$ver")"
        if [ "$cur_ver" -ge "$min_ver" ]; then
            log_info "${info}Found minimal required version [$min] for '$pkg-$ver'"
        else
            log_exit "${info}Requires a minimal version [$min] for '$pkg-$ver',${nl}wrong combination, please update manually."
        fi
    fi
}

: <<=cut
=func_frm
Checks the maximum valid version of a specific package (<=)
=cut
function check_max_version() {
    local pkg="$1"  # (M) The package name to check e.g. ${GEN_our_pkg_pfx}Automate
    local max="$2"  # (O) The maximum version allowed (including). Version are normalized. If empty only package installation checked.
    local info="$3" # (O) Optional extra info for the reason behind this require, please add $nl 

    local ver="$($CMD_install_query $pkg | grep 'Version' | sed "$SED_del_spaces" | cut -d' ' -f3)"

    if [ "$max" == '' ]; then
        check_set "$ver" "${info}Did not find required packaged '$pkg' at all."
    else
        local max_ver="$(get_norm_ver "$max")"
        local cur_ver="$(get_norm_ver "$ver")"
        if [ "$cur_ver" -ge "$max_ver" ]; then
            log_exit "${info}Newer than maximal supported version [$max] for '$pkg-$ver',${nl}wrong combination, please update manually."
        else
            log_info "${info}Found version less than maximal required version [$max] for '$pkg-$ver'"
        fi
    fi
}

: <<=cut
=func_frm
Initializes the internal variable for a new inquire run.
=cut
function init_require() {
    #
    # Now walk through the known packages and run require on them
    #
    log_screen_bs init 'Require Info    : '
    log_screen_bs bs   'starting'
    local pkg
    for pkg in $(map_keys $map_cfg_ins); do
        is_pkg_alias $pkg
        if [ $? != 0 ]; then continue; fi
        log_screen_bs bs "$pkg"
        func "*$pkg" require
        log_screen_bs add "$([  $? != 0 ] && echo -n " (done)" || echo -n " (skipped)")"
#        sleep 0.05   # Slightly slow down the output (disabled).
    done
    log_screen_bs bs  'combining'
    combine_requires
    log_screen_bs bs  'calculate'
    late_deduce_data
    log_screen_bs end 'done'
}

#
# The followinf (4) function shield of external from internal implmentation. 
# They make sure the external really looks differnt while the internal are
# at the moment pretty much shared. The return 0 is a safeguard to the way they 
# are being called.
#

: <<=cut
=func_frm
Add a package requirement. It will onlt be added into the internal structures.
It will need combinging/dependent search when all collected.
if the package is installed and has the right version
if not then it will be printed to be installed
=cut
function add_install_require() {
    local who="$1"      # (M) The entity:<version? requiring this install
    local ins_ent="$2"  # (M) The entity install name (see install-able packages) which is required e.g. MGR
    local type="$3"     # (O) The required type. (min, exact, any). Default any if not given.
    local ver="$4"      # (O) A version to check for, see also type
    local flags="$5"    # (O) Define additional flags comma sep (see REQ_flags), <empty> leave decision to add_require

    # Allays add the install require, the combined require will filter later on.
    log_debug "add_install_require: w:$who, i:$ins_ent, t:$type, v:$ver, f:$flags."
    add_require "$who" $req_typ_package "$ins_ent" "$type" "$ver" '' '' "$flags"
    
    return 0
}    

: <<=cut
=func_frm
Add a interface requirement. It will only be added into the internal structures.
It will need combinging/dependent search when all collected.
if the package is installed and has the right version
if not then it will be printed to be installed
=cut
function add_interface_require() {
    local who="$1"      # (M) The entity:<version? requiring this install
    local intf="$2"     # (M) The interface name see IF_*
    local type="$3"     # (O) The required type. (min, exact, any). Default any if not given.
    local ver="$4"      # (O) A version to check for, see also type
    local cur="$5"      # (O) The current interface version
    local with="$6"     # (O) Optionally identifies with which component is been interfaced (FFU) (comma separated)

    log_debug "add_interface_require: w:$who, i:$intf, t:$type, v:$ver."
    add_require "$who" $req_typ_interface "$intf" "$type" "$ver" "$cur" "$with"
    
    return 0 
}

: <<=cut
=func_frm
Adds an selective dependency for an existing install requirement. This is basically
telling the processing engine that this requirement depends on a specific variable
with a specific value.
=func_note
If the var is 'hw_node' then the dependency is also added for the node.
=cut
function add_selective_install_info() {
    local who="$1"      # (M) The entity:<version? requiring this install
    local ins_ent="$2"  # (M) The entity install name (see install-able packages) which is required e.g. MGR
    local var="$3"      # (M) A variable to make the selective dependence on, require value as well
    local val="$4"      # (M) A value to match in case var is set. Use command to specify multiple exact values

    log_debug "add_selective_install_info: w:$who, i:$ins_ent $var=='$val'"
    add_selective_info "$who" $req_typ_package "$ins_ent" "$var" "$val"    

    return 0 
}

: <<=cut
=func_frm
Adds an selective dependency for an existing interface requirement. This is basically
telling the processing engine that this requirement depends on a specific variable
with a specific value.
=cut
function add_selective_interface_info() {
    local who="$1"      # (M) The entity:<version? requiring this install
    local intf="$2"     # (M) The interface name see IF_*
    local var="$3"      # (M) A variable to make the selective dependence on, require value as well
    local val="$4"      # (M) A value to match in case var is set. Use command to specify multiple exact values

    log_debug "add_selective_install_info: w:$who, i:$intf $var=='$val'"
    add_selective_info "$who" $req_typ_interface "$intf" "$var" "$val"    

    return 0 
}

: <<=cut
=func_frm
Select a require version out of a given list. If none is found and the 'any'
version is available then that one will be returned.
=cut
function get_req_version() {
    local ent="$1"  # (M) The entity to search in
    local vers="$2" # (O) A list with versions to search for (ordered, comma separated), '' or '*' is best match

    local ver
    if [ "$vers" == '' -o "$vers" == '*' ]; then         # First see if a wildcard has to be found
        local cur_ver=0
        for ver in $(map_keys "$map_cfg_ins/$ent/$ins_require"); do
            if [ "$ver" == 'any' ]; then ver=0; fi
            compare_ver "$ver" "$cur_ver"
            if [ $? == 2 ]; then cur_ver=$ver; fi
        done
        if [ "$cur_ver" == '0' ]; then vers=''; else vers=$cur_ver; fi
    fi

    local found=''
    for ver in $vers any; do
        map_exists "$map_cfg_ins/$ent/$ins_require/$ver"
        if [ $? != 0 ]; then
            found=$ver
            break
        fi
    done

    echo -n "$found"
}

: <<=cut
=func_frm
Combines the collected require data into requirements per required package
=func_note
This assume the version info is correct as store by add_install_require, which
saves additional checks.
=cut
function combine_requires() {
    local ents="$1" # (O) A list with a entities with optional version <ent>:<version>. If empty then all found in map_cfg_install are processed
    local main="$2" # (O) If set then this means this a sub list, which will not init the maps again.

    local check_aliases=0
    if [ "$ents" == '' ]; then 
        ents="$(map_keys $map_cfg_ins)";    # Already includes aliases!
    else
        check_aliases=1
    fi

    if [ "$main" == '' ]; then
        map_init $map_pkg
        map_init $map_intf
        map_init $map_node
    fi

    local req_ent
    local req_ver
    local ins_wht
    local ins_ent
    for req_ent in $ents; do
        req_ver="$(get_field 2 "$req_ent" ':')"
        req_ent="$(get_field 1 "$req_ent" ':')"
        req_ver="$(get_req_version "$req_ent" "$req_ver")"
        local map_ver="$map_cfg_ins/$req_ent/$INS_col_require/$req_ver"
        for ins_wht in $(map_keys "$map_ver"); do

            local map               # Future prove way of extending
            case $ins_wht in
                $req_typ_package)   map=$map_pkg ; ;;
                $req_typ_interface) map=$map_intf; ;;
                $req_typ_node)      map=$map_node; ;;
                *)  log_exit "Unrecognized what '$ins_wht' ($req_ent,$ins_ent,$ins_ver,$ins_typ) , incomplete coding?"; ;;
            esac

            local map_wht="$map_ver/$ins_wht"
            for ins_ent in $(map_keys "$map_wht"); do
                local map_ins="$map_wht/$ins_ent"
                is_req_selected "$map_ins"
                if [ $? != 0 ]; then
                    local ins_typ="$(  map_get "$map_ins" "$req_fld_type")"
                    local ins_ver="$(  map_get "$map_ins" "$req_fld_ver" )"
                    local ins_flags="$(map_get "$map_ins" "$req_fld_flags" )"

                    combine_into_require "$map/$ins_ent" "$req_ent" "$req_ver" "$ins_ent" "$ins_typ" "$ins_ver" "$ins_flags"

                    if [ "$(map_get "$map_ins/$req_fld_node" "$hw_node")" != '' ]; then
                        map_link "$map_node/$ins_ent" "$hw_node" "$map_data"
                    fi
                else
                    log_debug "Skipping '$map_$ins' as it is not selected."
                fi
            done
        done
        
        if [ $check_aliases != 0 ]; then
            # Check for aliases theoretical this could lead to some double calls.
            # Which won't hurt. But in practice either the alias is used or the main
            # package. Do it one by one as version needs to be added.
            local alias
            for alias in $(map_keys "$map_cfg_ins/$req_ent/$ins_aliases"); do
                combine_requires "$alias:$req_ver" "$req_ent"
            done
        fi
    done
}    

: <<=cut
=func_frm
Check if a specific product is required by any of the to be installed components.
=stdout
All the components in need of the given product. The components are
separated by a space.
=cut
function get_who_requires() {
    local prod="$1"     # (M) The product to get the requires for. Use e.g. $IP_
    local allow="$2"    # (O) A list (space separated) with components/package which are allowed for the retrieval. Empty all in the data resource
    local flag="$3"     # (O) The flag to search for use <empty> for all
    local one_lvl="$4"  # (O) If set then only current level is searched (not recursive)

    check_set "$prod" 'Product not defined, programming error?'
    get_which_ents_requires "$map_pkg" "$prod" "$flag" "$allow" '' "$one_lvl"
}

: <<=cut
=func_frm
Check if who uses a specific interface any of the to be installed components.
=stdout
All the components in need of the given interface. The components are
separated by a space.
=cut
function get_who_uses_interface() {
    local intf="$1"     # (M) the interface to get the users for. Use e.g. $IF_ 
    local allow="$2"    # (O) A list (space separated) with components/package which are allowed for the retrieval. Empty all in the data resource

    get_which_ents_requires "$map_intf" "$intf" '' "$allow"
}

: <<=cut
=func_int
Retrieves which nodes who have registered in need of specific product.
=stdout
All the nodes/sections in need of the given product. The components are
separated by a space. If empty then it can also mean the product did not 
register specific nodes (which is a valid case).
=cut
function get_which_node_need_product() {
    local prod="$1"     # (M) The product to get the requires for. Use e.g. $IP_
    local allow="$2"    # (O) A list (space separated) with nodes which are allowed for the retrieval. Empty all in the data resource

    local nodes="$(map_keys "$map_node/$prod")"
    if [ "$allow" == '' ]; then
        echo -n "$nodes"         # just return all keys 
    else
        local node
        for node in $nodes; do
            is_substr "$node" "$allow"
            [ $? != 0 ] && echo -n "$node "
        done
    fi
}

: <<=cut
=func_frm
Defines from which version of the same package this installation is compatible with.
This gives an easy way to identify what is needed to upgrade the software to
the current version.
=func_note
A type of exact will result in an error because this should not be used as by
default a version should allow future upgrade Use min with the same version to
tell the system all should be upgrade at the same time (for this release which does
not mean for next releases). 
=cut
function compatible_with() {
    local who="$1"      # (M) The entity + version requiring this install
    local ent="$2"   # (M) The entity it is compatible with
    local type="$3"  # (O) The version type. (min, exact, any). Default any if not given.
    local ver="$4"   # (M) The version it is compatible with. 

    find_install $ent
    find_pkg_version $install_dir $install_pkg 'optional'

    log_debug "Checking compatibility of $who with $install_pkg $type version '$ver'"
    
    case $type in
        any|'') 
            log_debug "$install_pkg is compatible with any version"
            return 
            ;;   # No need for further checking
        exact) 
            log_exit "Compatible with exact version is not advisable, please change"
            ;;
        min) : ;;
        *) 
            log_exit "Wrong type given for compatible with: '$type', use 'any' or 'min'."
            ;;
    esac

    # TODO continue with functionality for now print
    log_debug "$who: $install_pkg $found_version compatible with $ver ??"
}

: <<=cut
=func_frm
This will show the current require information which is for development only.
The data itself is collected from the created map (install, req).
=cut
function show_current_require_data() {
    local map
    for map in $map_pkg $map_intf $map_node; do
        local ents=$(echo -n "$(map_keys $map)" | tr ' ' '\n' | sort)
        local ent
        local req=$(basename $map)
        local hdr='%-13s %c %-14s %s'
        log_screen_info '' "$(printf "$hdr" "$req" 'T' 'version' 'used by')"
        log_screen_info '' "$LOG_isep"
        for ent in $ents; do
            local type="$(map_get "$map/$ent" $req_fld_type)"
            local ver="$(map_get "$map/$ent" $req_fld_ver)"
            local users="$(map_keys "$map/$ent/$req_fld_ent")"
            log_screen_info '' "$(printf "$hdr" "$ent" "$type" "$ver" "$users")"
        done
        log_screen_info
    done    
}
