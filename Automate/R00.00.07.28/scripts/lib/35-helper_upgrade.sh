#!/bin/sh

: <<=cut
=script
This library containt helper functions to create analyze and create an upgrade
plan.

=version    $Id: 35-helper_upgrade.sh,v 1.17 2018/10/30 12:11:08 skrish10 Exp $
=author     Frank.Kok@newnet.com
=cut

readonly UPG_stat_file="$upgdir/Current-Upgrade-Status.txt"


readonly map_plan='UPG_plan'

readonly     upg_fld_type='type'
readonly      upg_fld_pkg='pkg'
readonly  upg_fld_cur_ver='ver_cur'
readonly  upg_fld_new_ver='ver_new'
readonly upg_fld_need_ver='ver_need'
readonly     upg_fld_deps='deps'
readonly   upg_fld_action='action'
readonly    upg_fld_depth='depth'
readonly   upg_fld_reason='reason'
readonly     upg_fld_intf='intf'

# The actions are reference to different sub part. Which can be used to
# identify what and how to do it.
readonly upg_ref_kernel='kernel'    # kernel requires run level 1
readonly upg_ref_os_pkg='os_pkg'    # OS package (upgrade requires run level 1 (for now is this really needed)
readonly upg_ref_os_vfy='os-vfy'    # Special to be defined to verify OS setting which is currently done at run level 1 (why ?)
readonly upg_ref_sw_pkg='sw_pkg'    # One of our own product packages

readonly upg_typ_upgrade='upgrade' # Need to be upgraded`
readonly  upg_typ_verify='verify'  # Need to be verified for dependencies
readonly upg_typ_current='current' # Current version is installed
readonly upg_typ_install='install' # Require a fresh install (no old version)
readonly  upg_typ_remove='keep'    # No new version package should be remove but for now ext state keep

readonly        upg_act_none='none'
readonly     upg_act_upgrade="$upg_typ_upgrade"
readonly     upg_act_install="$upg_typ_install"
readonly      upg_act_remove='remove'
readonly  upg_act_preinstall='preinstall'   # Pre installed by a full OS install (changed later)
readonly    upg_act_incompat='incompat'
readonly     upg_act_rolling='rolling'      # upgrade possible but same type should be rolling
readonly  upg_act_no_rolling='noroling'     # Upgrade possible but all users of same type has to go down
readonly    upg_act_separate='separate'     # Upgrade possible use separate steps

# The exe_type has to be single charatcers!
readonly  exe_type_main='M'       # A main package in need of upgrading
readonly   exe_type_sub='S'       # A sub package which needed tracking
readonly exe_type_regex="[$exe_type_main$exe_type_sub]"

# The number is used to track state advances (only up allowed)
# Make sure the numbers are unique and in order. Please use : to separate
readonly exe_state_todo='1:todo'         # Still to be upgraded
readonly exe_state_inst='2:install'      # An install no stop, require start though before done
readonly exe_state_stop='3:stopped'      # Currently stopped upgrade needed
readonly exe_state_upgr='4:upgraded'     # Upgraded not started
readonly exe_state_done='5:done'         # Upgrade and started
readonly exe_state_fail='6:fail'         # Unplanned failure assuming the plan was good.

: <<=cut
=func_frm
Initializes the upgrade plan so that a new upgrade plan can be created.
This has to be called before any new plan can be created
=func_note
Be aware that this function will recalculate the require settings by calling 
combine_requires.
=cut
function init_upgrade_plan() {
    local ents="$1" # (O) A list with <ent>:<ver>. Which are analyzed during this run, if empty then all current are used

    combine_requires "$ents"            
    map_init $map_plan
    upg_depth=0
}

: <<=cut
=func_frm
This will analyze the upgrade impact and create an upgrade plan based on the
wanted new versions. The plan could be empty meaning nothing has to be done. 
The plan does not look at interface version or minimal package version this is 
done in a later stage. It will however ignore selective packages which are 
not enabled.
=cut
function upgrade_impact_new_ver() {
    local depth="$1"    # (M) The search depth, will be increased upon recursive call
    local ents="$2"     # (M) The entities (comp or packages) to include in this run (space separated)

    if [ "$upg_depth" -lt "$depth" ]; then upg_depth=$depth; fi

    local ent
    local pkg
    for ent in $ents; do        
        local action=$upg_act_none
        local main_cur=''
        local main_new=''
        map_exists "$map_cfg_ins/$ent"
        if [ $? == 0 ]; then continue; fi                               # Skip does not exist

        local map="$map_plan/$ent"
        local cdepth=$(map_get "$map" $upg_fld_depth)
        if [ "$cdepth" != '' ] && [ "$cdepth" -gt "$depth" ]; then      # Skip already lower depth
            continue
        fi

        # The OS should be lower then all on the same level
        if [ "$IP_OS" != '' -a "$ent" == "$IP_OS" ]; then
            if [ "$ents" == "$ent" ]; then        # It is the only so safe to increase depth here
                ((depth++))
            else
                upgrade_impact_new_ver $((depth + 1)) "$ent"
                continue    # This is now done
            fi
        fi

        map_put "$map" $upg_fld_depth $depth

        # The main entity contauisn the package info so it has to be retrieved
        local main=$(get_main_pkg $ent)
# I don't want to call the main entity, as it should be in the main list anyhow
#        if [ "$main" != "$ent" ];then
#            upgrade_impact_new_ver $depth "$main"
#            map_link "$map_plan/$ent/$upg_fld_deps" "$main" "$map_plan"
#        fi

        # The loop contents uses the main entity
        local imap="$map_cfg_ins/$main/$ins_pkg"
        for pkg in $(map_keys "$imap"); do
            local pmap="$map_plan/$main/$upg_fld_pkg/$pkg"
            local type=''
            local cur_ver=''
            local new_ver=''
            local cfg_type=$(map_get "$map_cfg_ins/$main" "$INS_col_type")
            case "$cfg_type" in
             $CFG_type_component | $CFG_type_helper | $CFG_type_alias)
                local imap_pkg="$imap/$pkg"
                cur_ver="$(map_get "$imap_pkg" $ins_cur_ver)"
                if [ "$cur_ver" == '' ]; then
                    log_info "No current version known for '$main($ent)->$pkg' going to install"
                    cur_ver='NA'
                    type=$upg_typ_install
                fi
                
                # this is code hack to over come the STV problem
                # now while checking the version, tool will getthe older version according to older name
                local new_imap=$imap_pkg
                if [ "$pkg" == 'TextPassSTV' ]; then
                    new_imap="$imap/TextPassSTVstvnode"
                fi
                local new_ver="$(map_get "$new_imap" $ins_ins_ver)"
                if [ "$new_ver" == '' ]; then
                    if [ "$main" != "TextPassTomcat" ] && [ "$main" != "Tomcat" ] && [ "$main" != "OpenSource" ] ; then
                        log_warning "No new version known for '$main($ent)->$pkg'"
                    fi
                    # Could introduce a remove, but lets keep it like this, with warning
                    new_ver='NA'
                    type=$upg_typ_remove
                fi

                if [ "$type" == '' ]; then
                    if [ "$cur_ver" == "$new_ver" ]; then
                        log_info "$main($ent)->$pkg' is up to date both have version $cur_ver."
                        type=$upg_typ_current
                    else
                        type=$upg_typ_upgrade
                    fi
                fi
                ;;

             $CFG_type_product | $CFG_type_system )
                cur_ver=$(map_get "$map_cfg_ins/$main" $INS_col_cur_version)
                new_ver=$(map_get "$map_cfg_ins/$main" $INS_col_ins_version)
                if [ "$new_ver" == '' ]; then        # No new version can we get it from a package requirement
                    new_ver=$(map_get "$map_pkg/$main" $req_fld_ver)
                fi
                type=$upg_typ_verify
                ;;

             $CFG_type_none ) 
                log_warning "Found a package ($pkg) to be upgraded which has type set to '$cfg_type'"
                continue
                ;;

             *) log_exit "Unhandled cfg_type '$cfg_type', programming error!"
                ;;
            esac

            check_set "$type" 'Programming error no type set.'   # Safe check for future changes

            cur_ver=${cur_ver:-NA}
            new_ver=${new_ver:-NA}
            map_put "$pmap" $upg_fld_type    $type
            map_put "$pmap" $upg_fld_cur_ver $cur_ver
            map_put "$pmap" $upg_fld_new_ver $new_ver

            # Set main versions to first package found
            [ "$main_cur" == '' -a "$cur_ver" != "NA" ] && main_cur=$cur_ver
            [ "$main_new" == '' -a "$new_ver" != "NA" ] && main_new=$new_ver

            if [ "$type" == $upg_typ_upgrade ] ||
               [ "$type" == $upg_typ_install -a "$action" == $upg_act_none ]; then
                action=$type
            fi
            if [ "$type" == $upg_typ_current -a "$action" == $upg_act_install ]; then
                action=$upg_act_none        # Another package is current so do not install
            fi

            #
            # Now do all the sub entities (look at new version or any)
            #
            local req_ver=$(get_req_version $main "$new_ver $cur_ver")
            if [ "$req_ver" != '' ]; then
                local dep
                for dep in $(map_keys "$map_cfg_ins/$main/$ins_require/$req_ver/$req_typ_package"); do
                    [ "$dep" == "$ent" ] && continue    # Skip dependencies to ourself (e.g. cluster).
                    is_req_selected "$map_cfg_ins/$main/$ins_require/$req_ver/$req_typ_package/$dep"
                    if [ $? != 0 ]; then
                        upgrade_impact_new_ver $((depth + 1)) "$dep"            # One at a time
                        map_link "$map_plan/$main/$upg_fld_deps" "$dep" "$map_plan"
                    fi
                done
            fi            
        done

        main_cur=${main_cur:-NA}    # Fix default if none found.
        main_new=${main_new:-NA}    # Fix default if none found.

        # Store it under the entity which could be an alias as well.
        map_put "$map_plan/$ent" $upg_fld_action  $action
        map_put "$map_plan/$ent" $upg_fld_cur_ver $main_cur
        map_put "$map_plan/$ent" $upg_fld_new_ver $main_new

        # Special case for a cluster at the moment we advice cluster to be 
        # upgrade separetly. Evne though rolling might supported later on. There
        # is currently no instrument to put the knowledge in (might be in the future.
        # This 'big' bang aproach was reuested as a first step.
        if [ "$ent" == "$IP_MySQL_Cluster" -a "$action" == "$upg_typ_upgrade" ]; then
            map_put "$map_plan/$ent" $upg_fld_action "$upg_act_separate"
            map_put "$map_plan/$ent" $upg_fld_reason "SubProvPlat"
        fi
    done
}

: <<=cut
=func_frm
This will continue to analyze the upgrade plan (dependencies). By looking into 
analyze the min/exact requirements. This for all known upgraded and dependent 
entities.
=cut
function upgrade_impact_deps() {
    local ent
    local ver
    local line
    for ent in $(map_keys "$map_plan"); do
        local map="$map_plan/$ent"
        local action=$(map_get "$map" $upg_fld_action)
        if [ "$action" != $upg_act_none ]; then continue; fi    # Already action required

        local rmap="$map_pkg/$ent"
        map_exists "$rmap"
        if [ $? == 0 ]; then continue; fi                       # No package requirements

        local pver="$( map_get "$map" $upg_fld_new_ver)"
        local type="$(map_get "$rmap" $req_fld_type)"
        local ver="$( map_get "$rmap" $req_fld_ver)"
        case "$type" in
            "$REQ_itype_any")   # don't care about the version, always good
                :
                ;;
            "$REQ_itype_min")   # The new version should be >= then required
                compare_ver $pver $ver
                if [ $? == $REQ_cmp_less ]; then
                    map_put "$map" $upg_fld_need_ver "$ver"
                    map_put "$map" $upg_fld_action   $upg_act_incompat
                    map_put "$map" $upg_fld_reason   'min not reached'
                fi
                ;;
                
            "$REQ_itype_max")   # The new version may not be more then required <=
                compare_ver $pver $ver
                if [ $? == $REQ_cmp_greater ]; then
                    map_put "$map" $upg_fld_need_ver "$ver"
                    map_put "$map" $upg_fld_action   $upg_act_incompat
                    map_put "$map" $upg_fld_reason   'max exceeded'
                fi
                ;;

            "$REQ_itype_exact") # The versions should match
                if [ "$pver" != "$ver" ]; then  # Current is not the same
                    map_put "$map" $upg_fld_need_ver  "$ver"
                    map_put "$map" $upg_fld_action    $upg_act_incompat
                    map_put "$map" $upg_fld_reason    'need exact'
                fi
                ;;

            *)
                map_put "$map" $upg_fld_reason  "unsup. type '$type'"
                log_exit "None or unsupported require type found '$type'"
                ;;                    
        esac
    done
}

: <<=cut
=func_frm
This will continue to analyze the upgrade plan (interfaces). By looking into 
analyze the min/exact interface requirements. This for all known upgraded and dependent 
entities.
=cut
function upgrade_impact_intf() {
    local ent
    for ent in $(map_keys "$map_plan"); do
        local map="$map_plan/$ent"
        local cur_ver=$(get_req_version $ent "$(map_get "$map" $upg_fld_cur_ver)")
        local new_ver=$(get_req_version $ent "$(map_get "$map" $upg_fld_new_ver)")

        local set_act
        for set_act in "$upg_act_incompat" "$upg_act_no_rolling"; do
            if [ "$set_act" == "$upg_act_incompat" ]; then
                local tst_ver="$new_ver"
                local upd_fld="$upg_fld_new_ver"
            else
                local tst_ver="$cur_ver"
                local upd_fld="$upg_fld_cur_ver"
            fi
            
            local intf
            local rmap="$map_cfg_ins/$ent/$INS_col_require/$tst_ver/$req_typ_interface"
            for intf in $(map_keys "$rmap"); do
                local cur="$(map_get "$rmap/$intf" $req_fld_cur)"

                map="$map_plan/$ent/$upg_fld_intf/$intf"                

                # Check get the interface requirements
                local imap="$map_intf/$intf"
                map_exists "$imap"
                if [ $? == 0 ]; then continue; fi                       # No interface requirements
                local type="$(map_get "$imap" $req_fld_type)"
                local ver="$( map_get "$imap" $req_fld_ver)"

                compare_ver $cur $ver
                local cmp=$?

                local reason=''
                case "$type" in
                    "$REQ_itype_any") : ;;  # don't care about the version, always good
                    "$REQ_itype_min")       # The new version should be >= then required
                        if [ $cmp == $REQ_cmp_less ]; then
                            reason='min not reached'
                        fi
                        ;;
                
                    "$REQ_itype_max")   # The new version may not be more then required <=
                        if [ $cmp == $REQ_cmp_greater ]; then
                            reason='max exceeded'
                        fi
                        ;;

                    "$REQ_itype_exact") # The versions should match
                        if [ $cmp != $REQ_cmp_equal ]; then 
                            reason='need exact'
                        fi
                        ;;
                        
                    *)
                        map_put "$map" $upg_fld_reason  "unsup. type '$type'"
                        log_exit "None or unsupported require type found '$type'"
                        ;;                    
                esac

                map_put "$map" $upd_fld "$cur"
                if [ "$reason" == '' ]; then
                    map_put "$map" $upg_fld_action $upg_act_none
                else
                    map_put "$map" $upg_fld_need_ver "$ver"
                    map_put "$map" $upg_fld_action   "$set_act"
                    map_put "$map" $upg_fld_reason   "$reason"
                fi
            
                if [ "$reason" == "$upg_act_incompat" ]; then
                    break;      # No need to continue with next check
                elif [ "$reason" == "$upg_act_no_rolling" ]; then
                    # Still need to check if it could be rolling. It could a rolling
                    # upgrade if all involved entities have the rolling upgrade option
                    # This can also differ per version, so both (old and new need 
                    # the rolling upgrade feature.
                    # TODO TODO; THe above is not implemented yet, however in
                    # case of a SPF_service interface we could fallback
                    # to as special script.
                    if [ "$intf" == "$IF_SPF_Service" ]; then
                        map_put "$map" $upg_fld_action   "$upg_act_separate"
                        map_put "$map" $upg_fld_reason   "SubProvPlat"
                    fi
                fi
            done
        done
    done
}

: <<=cut
=func_frm
Help function to show the current upgrade plan. Mainly used for debugging.
=cut
function show_upgrade_plan() {
    local all="$1"  # (O) Is set then all info is shown, otherwise only with action!='none'

    local output="Ent${tb}Action${tb}D${tb}CurV${tb}NewV${tb}Deps${tb}Info$nl"
         output+="---${tb}------${tb}-${tb}----${tb}----${tb}----${tb}----$nl"
    local ent
    for ent in $(map_keys "$map_plan"); do
        local map="$map_plan/$ent"
        local action=$(map_get "$map" $upg_fld_action)
        if [ "$all" == '' -a "$action" == $upg_act_none ]; then continue; fi    # Skipp all none actions if requested
        local depth=$(map_get "$map" $upg_fld_depth)
        local ver=$(  map_get "$map" $upg_fld_new_ver)
        local deps=$(map_keys "$map/$upg_fld_deps")
        local info="$(get_concat "$(map_get "$map" $upg_fld_need_ver)" "$(map_get "$map" $upg_fld_reason)")"
        output+="$ent$tb$action$tb$depth$tb $tb${ver:- }$tb${deps:- }$tb$info$nl"
        
        local pkg
        for pkg in $(map_keys "$map/$upg_fld_pkg"); do
            local pmap="$map/$upg_fld_pkg/$pkg"
            local type=$(map_get "$pmap" $upg_fld_type)
            local cur_ver=$(map_get "$pmap" $upg_fld_cur_ver)
            local new_ver=$(map_get "$pmap" $upg_fld_new_ver)
            output+=" p $pkg$tb$type$tb $tb$cur_ver$tb$new_ver$nl"
        done
        
        local intf
        for intf in $(map_keys "$map/$upg_fld_intf"); do
            local imap="$map/$upg_fld_intf/$intf"
            local act=$(map_get "$imap" $upg_fld_action)
            local cur_ver=$(map_get "$imap" $upg_fld_cur_ver)
            local new_ver=$(map_get "$imap" $upg_fld_new_ver)
            output+=" i $intf$tb$act$tb $tb$cur_ver$tb$new_ver$nl"
        done
    done
    log_screen "$(echo "$output" | column -s "$tb" -t)"
}

: <<=cut
=func_frm
Creates an upgrade plan out of the current available data ($map_plan). So this 
function assumes the proper plan data has been processed. The OS data can be
available in the OS variables.
=need OS_kernel_updates
=need OS_package_updates
=need OS_pkgs_added
=need OS_pkgs_removed
=set plan_file
The file with the create upgrade plan. The file will contain node and time-stamp
data in it. The file is created in the $upgdir
=return
The amount of failures, 0 if no failures.
=cut
function create_local_upgrade_plan() {
    local added=0
    local fail=0
    local warn=0

    if [ ! -d $upgdir ]; then       # Make sure the directory exists, silently create
        cmd '' $CMD_mkdir $upgdir
    fi

    # First make the upgrade plan name
    # Currently use the TextPass version in the files, this might need changing
    local from
    local to
    if [ "$IP_TextPass" != '' ]; then
        from=$(map_get "$map_cfg_ins/$IP_TextPass" $INS_col_cur_version)
        to=$(map_get "$map_cfg_ins/$IP_TextPass" $INS_col_ins_version)
    fi
    from=${from:-NA}
    to=${to:-NA}
    plan_file="$upgdir/upgrade_$hw_node_${from}-${to}_$(date +%F_%H%M%S).plan"
    if [ -e "$plan_file" ]; then
        cmd 'Plan exists should not be possible, removing' $CMD_rm "$plan_file"
    fi

    #
    # The plan will only hold the ent which need to be upgraded. Each
    # line is a piece of the puzzle. The lines are ordered, 1st line should be
    # upgraded first.
    # <action> <reference> <ent> <from_ver> <to_ver>
    #
    local info
    for info in $OS_kernel_updates; do
        ((added++))
        echo "$upg_act_upgrade $upg_ref_kernel $(echo -n "$info" | tr ':' ' ')" >> $plan_file
    done
    for info in $OS_package_updates; do
        ((added++))
        echo "$upg_act_upgrade $upg_ref_os_pkg $(echo -n "$info" | tr ':' ' ')" >> $plan_file
    done
    for info in $OS_pkgs_added; do
        ((added++))
        echo "$upg_act_install $upg_ref_os_pkg $(echo -n "$info" | tr ':' ' ')" >> $plan_file
    done
    for info in $OS_pkgs_removed; do
        ((added++))
        echo "$upg_act_remove $upg_ref_os_pkg $(echo -n "$info" | tr ':' ' ')" >> $plan_file
    done
    if [ "$OS_upgrade_to_os_rel" ]; then
        ((added++))
        echo "$upg_act_upgrade $upg_ref_os_vfy Any $OS_upgrade_to_os_rel" >> $plan_file
    fi
    while [ "$upg_depth" != '0' ]; do
        # Not the smartest loop but it works
        for ent in $(map_keys "$map_plan"); do
            local map="$map_plan/$ent"
            local depth=$(map_get "$map" $upg_fld_depth)
            if [ "$depth" != "$upg_depth" ]; then continue; fi      # Skip not this depth
            local action=$(map_get "$map" $upg_fld_action)
            local new_ver=$(  map_get "$map" $upg_fld_new_ver)
            local cur_ver=$(  map_get "$map" $upg_fld_cur_ver)
            local reason=$(   map_get "$map" $upg_fld_reason)

            case $action in
                $upg_act_none)      continue; ;;     # Nothing to add
                $upg_act_upgrade) : ;;
                $upg_act_install) : ;;
                $upg_act_separate): ;;
                $upg_act_incompat)
                    local need_ver=$(map_get "$map" $upg_fld_need_ver)
                    log_warning "$ent not compatible ($reason) with needed version '$need_ver'"
                    ((fail++))
                    ;;
                $upg_act_rolling)
                    log_warning "$ent requires a rolling upgrade."
                    ((warn++))
                    ;;
                $upgact_no_rolling)
                    log_warning "$ent can be upgraded but needs shutdown of all entities of same type"
                    ((warn++))
                    ;;
                *) log_exit "Unsupported action ($action) requested for '$ent'"; ;;                    
            esac

            ((added++))
            echo "$action $upg_ref_sw_pkg $ent $cur_ver $new_ver $reason" >> $plan_file
        done
        ((upg_depth--))
    done

    # This is a temporary check because the calling code will not be able to handle
    # the warnings. It should be able to handle the failures.
    if [ $warn != 0 ]; then
        log_exit "Check warnings, they are not implemented automatically, shutting down${nl}Plan:$nl$(cat $plan_file)"
    fi
    if [ $added == 0 ]; then
        echo "$upg_act_none needed" >> $plan_file
    fi
    STR_num_to_upgrade=$added
    store_current_state

    return $fail
}

: <<=cut
=func_frm
Check if the upgrade plan if defined and is readable. The function can check
the existence/no-existence of the stat file as well. Will exit on failure.
=cut
function check_upgrade_plan_readable() {
    local check_stat="$1"   # (O) Can be used to check the stat file 'restart_stat_file' or 'need_stat_file'

    [ -z help ] && show_short="Checks readable upgrade plan ($STR_upg_plan_file) or fail"
    [ -z help ] && [ "$check_stat" != '' ] && show_short+=", extra: '$check_stat'"
    [ -z help ] && show_trans=0 

    check_set "$STR_upg_plan_file" 'Upgrade plan file not defined (step precheck_impact upgrade).'
    if [ ! -r "$STR_upg_plan_file" ]; then
        log_exit "Unable to open upgrade plan file '$STR_upg_plan_file'"
    fi
    case "$check_stat" in
        'restart_stat_file')
            if [ -e "$UPG_stat_file" ]; then
                log_warning "It looks like a previous upgrade did not finished, restarting."
                rotate_files "$UPG_stat_file"   # Rotate it to clean current
            fi
            ;;
        'need_stat_file')
            if [ ! -e "$UPG_stat_file" ]; then
                log_exit "No status file, looks like upgrade is not yet started."
            fi
            ;;
        '') : ;;
        *) log_warning "Check_upgrade-plan_readable called with unknown request '$check_stat'"; ;;
    esac
}

: <<=cut
=func_frm
Simple helper to get a state of a specific package
=stdout
The state or empty in case package not found.
=cut
function get_state() {
    local pkg="$1"  # (M) The package to retrieve the state
    
    if [ -r $UPG_stat_file ]; then
        get_field 3-4 "$(grep "^$pkg:" "$UPG_stat_file")" ':'
    fi
}

: <<=cut
=func_frm
Helper to update the state. It assumes every package is already
defined in the status file (this to make it simple). The stop and done
states will also be registered under the 1st level children.
The Main package are the one to be updated, the Sub packages are registered
for tracking purposes (to know if they need to be restarted).
=cut
function update_state() {
    local pkg="$1"       # (M) The package to update
    local new_state="$2" # (M) The state to update
    local new_type="$3"  # (O) The type the (if newly created), default to sub

    [ -z help ] && show_short="Update upgrade state, set '$pkg'->'$new_state'"
    [ -z help ] && show_trans=0

    new_type=${new_type:-$exe_type_sub}
    # get current state
    local cur_state="$(get_state $pkg)"
    if [ "$cur_state" == '' ]; then           # Does not exists yet add it
        echo "$pkg:$new_type:$new_state" >> "$UPG_stat_file"
    else
        new_ord=$(get_field 1 "$new_state" ':')
        cur_ord=$(get_field 1 "$cur_state" ':')
        if [ "$new_ord" -lt "$cur_ord" ]; then  # now going back, equal allowed
            log_exit "Upgrade state is being lowered for '$pkg', '$cur_state' -> '$new_state'"
        elif [ "$new_ord" -gt "$cur_ord" ]; then  # it is newer, update
            $CMD_sed -i "s/^$pkg:\($exe_type_regex\):.*/$pkg:\1:$new_state/" "$UPG_stat_file"

            case $new_state in
                $exe_state_stop | $exe_state_done)
                    local child
                    for child in $(map_keys "$map_cfg_ins/$pkg/$INS_col_childs"); do
                        update_state $child $new_state
                    done
                    ;;
            esac
        fi
    fi
}
