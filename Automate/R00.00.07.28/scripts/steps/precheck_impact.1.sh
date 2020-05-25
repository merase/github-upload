#!/bin/sh

: <<=cut
=script
This step does a pre-check on the impact of an installation or upgrade.
=script_note
For the Subscriber Provisioning Platform (SPP) it was decided to recreate
a dedicated plan. Though a previously created plan could be used (filtered).
The problem is that the state of that plan cannot be guaranteed. By doing it
this way it is in principle allowed to run the associated step file without
a previous step file. It would also allow for future OS patches included in
the same step file while it is assumed to be done by the generic upgrade.
=version    $Id: precheck_impact.1.sh,v 1.15 2018/08/02 08:10:05 fkok Exp $
=author     Frank.Kok@newnet.com
=help_todo Complex file, will be done later
=cut

local what="$1"        # (O) Defines what to do, might contains a _ which denotes a subset
local iso_sw_sect="$2" # (O) The optional SW iso section to upgrade to
local iso_os_sect="$3" # (O) The optional OS iso section to upgrade to
local cur_sw_iso="$4"  # (O) An optional current SW ISO which will be loaded as current. iso_sw_sect is needed as well.

# Filter subset, done to prevent interrfcae incompatibility
local subset="$(get_field 2 "$what" '_')"
subset=${subset:-all}
what="$(get_field 1 "$what" '_')"

check_in_set "$what"   "'',show,verify,upgrade,debug"
check_in_set "$subset" "all,SPP"

: <<=cut
=func_int
Simple helper to show some debug data
=cut
function show_impact_debug_data() {
    log_screen_info       # Will interrupt the step
    show_installable_pkg
    show_current_require_data
}

# Need to be sure we have create repo later on. Normally it is installed
# As soon as we retrieve the ISO the repo's became invalid due to changes in
# RHEL7.5. Decide to move the check here.
#
if [ "$what" == 'upgrade' ] && [ "$OS" == "$OS_linux" ] && [ $OS_ver_numb -ge 70 ]; then
    # Safety cleanup in case there is a problem in yums cache
    cmd 'Safety cleanup yum cache'       $CMD_yum clean all
 
    local tool='createrepo'
    if [ "$($CMD_ins_query_all | grep -i $tool)" == "" ]; then
        cmd "Need to install $tool" $CMD_yum_install $tool
    else
        AUT_allow_failure='allow'   # not critical if fails
        cmd "Need to upgrade $tool" $CMD_yum_ins_freshen $tool
        AUT_allow_failure=''
    fi
fi

#
# This part is to retrieve the OS ISO (Only for upgrade).
# Currently upgrade_SPP is not supposed to work with OS (it might though)
#
if [ "$STR_run_type" ==  "$RT_upgrade" -a "$subset" != 'SPP' ]; then
    if [ "$iso_os_sect" != '' ]; then
        execute_step 0 "retrieve_ISO OS $iso_os_sect"
        start_step "Analyze OS impact"
        func $IP_OS analyze_os_differences
        finish_step $STAT_passed
    else
        start_step "Skipping OS impact, no target <os_iso>"     # Show intermediate sub step if others used.
        finish_step $STAT_info
    fi
fi

#
# This part is to retrieve the SW ISO
#
if [ "$cur_sw_iso" != '' ]; then
    check_set "$iso_sw_sect" "To ISO is needed i.c.w. the current ISO!"
    execute_step 0 "retrieve_ISO $cur_sw_iso na na $INS_col_cur_version"
# Todo add when requires a rebuild as well and separate packages are known
#    execute_step 0 "collect_Automate_files"
    # There is one bummer how to identify the OS so this is exception code. I which
    # We look a the required version in TextPass (and or others)
    if [ "$IP_OS" != '' ]; then
        if [ "$IP_TextPass" != '' ]; then
            local cur_ver=$(map_get "$map_cfg_ins/$IP_TextPass" "$INS_col_cur_version")
            local req_ver=$(get_req_version "$IP_TextPass" "$cur_ver")
            local need=$(map_get "$map_cfg_ins/$IP_TextPass/$ins_require/$req_ver/$req_typ_package/$IP_OS" "$req_fld_ver")
            if [ "$need" == '' ]; then
                log_wanrning "Cannot identify required OS version, using current"
            else
                log_info "Identified OS version as '$need'"
                map_put "$map_cfg_ins/$IP_OS" "$INS_col_cur_version" "$need"
            fi
        # Else if others can be used to identify
        fi
    fi
fi 

if [ "$iso_sw_sect" != '' ]; then
    execute_step 0 "retrieve_ISO $iso_sw_sect"
elif [ "$AUT_retrieved_ISO_file" == '' ]; then
    if [ "$STR_retrieved_ISO_file" == '' ]; then
        log_exit "No ISO retrieved and not known which, execute 'retrieve ISO' once."
    fi
    execute_step 0 "retrieve_ISO file $STR_retrieved_ISO_file $STR_retrieved_ISO_md5"
fi
if [ "$AUT_retrieved_ISO_file" == '' ]; then
    log_exit "Something went wrong no ISO at all."
fi
# TODO add when requires a rebuild as well and separate packages are known
# execute_step 0 "collect_Automate_files"

#
# Init for the proper entities within the iso version. Add the products as
# they are not contained within the ISO.
#
local ents="$(map_get $map_cfg_iso "$AUT_retrieved_ISO_file")"
ents="$(echo -n "$STR_products" | tr ',' ' ') $ents"
init_upgrade_plan "$ents"            

# Find out which component to use in this 'sub' section
local components
if [ "$subset" == 'SPP' ]; then
    components="$(get_concat "$IP_MySQL_Cluster" "$(get_intersect "$dd_components" "$dd_prov_plat_comps" ' ')")"
else
    is_substr "$hw_node" "$dd_prov_plat_nodes"
    if [ $? == 0 ]; then
        components="$dd_components"
    else                        # The cluster if it isi one of the nodes. The NDB_MGR is a tricky oen as not assigned to a entity.
        components="$(get_concat "$IP_MySQL_Cluster" "$dd_components")"
    fi
fi

case "$what" in
    show)
        show_impact_debug_data
        ;;
    verify|upgrade|debug) 
        start_step "$what plan for $subset"
        log_info "Components in list: [$components]"
        upgrade_impact_new_ver 1 "$components"
        upgrade_impact_deps
        upgrade_impact_intf
        if [ "$what" == 'debug' ]; then
             show_impact_debug_data
             log_screen 'The created upgrade plan :'
             show_upgrade_plan 'all'
        fi
        create_local_upgrade_plan
        if [ "$?" != 0 ]; then
            log_exit "Plan, contains failures, cannot upgrade automatically:$nl$(cat $plan_file)"
        elif [ "$what" == 'upgrade' ]; then
            # Difference between verify and upgrade is that upgrade actually stores
            # the upgrade plan file
            log_info "Changing current upgrade plan to '$plan_file'"
            STR_upg_plan_file="$plan_file"
            rotate_files "$UPG_stat_file"           # Make sure any left over status file is removed/saved
            store_current_state

            log_wait "Created the following plan$nl$LOG_isep$nl$(cat $plan_file | column -t)$nl$LOG_isep${nl}${COL_warn}Continue the upgrade?$COL_def" 60
        fi
        finish_step $STAT_passed
        ;;
    '') log_info 'Analyze was done before no further processing (e.g. for upgrade done).'; ;;
    *)  log_exit "Unhanded option '$what'"                                    ; ;;
esac

return $STAT_passed
