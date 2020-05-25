#!/bin/sh

: <<=cut
=script
This is the generic upgrade script which will call the other scripts related
to the upgrade. It read the upgrade plan and splits of the main tasks
=script_note
This is a highly complex step creating all needed sub-steps. The logic will
be shown however. It is the end result that counts. Up until the executed
steps it will be visible. Perhaps the future will contains a actual list
but only if automate is still within this upgrade step. So it can not be 
pre-created. Why is the logic here, well adding the potential steps allows
the auto document system to process related steps. Otherwise it would
miss important steps.
=version    $Id: upgrade.1.sh,v 1.32 2019/05/15 14:20:41 skrish10 Exp $
=author     Frank.Kok@newnet.com
=cut

local what="$1"     # (M) What to do, like 'planned', 'finalize', 'continue', 'stop' are special names, see below for others
local extra="$2"    # (O) Extra parameter if needed.
local text="$3"     # (O) Extra for text if required, As of now it is required for multi-instance
local instance="$4" # (O) Extra for instance info if required, As of now it is required for multi-instance


#=#
#=* This will execute the generic upgrade, based on the earlier created plan
#=- The column of the upgrade plan represent the following
#=    <type> <ref> <pkg> <from_ver> <to_ver?
#=- The <plan> being followed is:
#=inc_indent
#=inc_indent
#=cat $STR_upg_plan_file
#=dec_indent
#=dec_indent

STR_reboot_aft_upgrade=${STR_reboot_aft_upgrade:-0}   # Set if not yet

# text and instance are not required when component is STVPol
# STVPol is having only one instance, even system is configured with multiple instances
if [ "$extra" == "STVPol" ]; then
unset $text
unset $instance
fi

#
# Check what should be done
#
case "$what" in
'continue') 
    #=# Dummy state to prevent starting over after planned init 1 reboot
    :
    ;;

'continue_planned'|'planned')  
    #=# Make sub taks for the given plan and then execute them
    local skip_row=0
    if [ "$what" == 'planned' ]; then
        check_upgrade_plan_readable 'restart_stat_file'
    else
        check_set "$extra" 'The upgrade continue planned needs an extra parameter!'
        check_upgrade_plan_readable
        skip_row=1
    fi

    
    #
    # It is easier to track progress by storing information into a map. Which
    # also always the state tracking of dependent entities later on.
    # Although the manual states differently I only assume runlevel 1 is needed
    # in case of kernel package (until proven otherwise)
    #
    local kern=0
    local os_pkg=0
    local os_vfy=0
    local res_runl=0
    local sw_pkg=0
    local ign_ph2=0            # To ignore rest after a separate request
    local line
    local q_ph1=''
    local q_ph2=''
    IFS=''; while read line; do IFS=$def_IFS;   #= is line to read from <plan>
        # The file is ordered, sw_pkg come at the end.
        local ref=$( get_field 2 "$line")       #= <ref column>
        if [ "$skip_row" != 0 ]; then                  # ALways skip row, disable on specific item
            if [ "$ref" == "$upg_ref_sw_pkg" ]; then
                local act=$( get_field 1 "$line")
                local rsn=$( get_field 6 "$line")
                if [ "$act" == "$upg_act_separate" -a "$rsn" == "$extra" ]; then
                    skip_row=0      # Next rows are to be upgraded.
                fi
            fi
            continue 
        fi
        
        case $ref in
            $upg_ref_kernel)
                if [ $kern == 0 ]; then         #= 1st found kernel pkg
                    queue_step "backup OS" '' ign_double
                    queue_step "update_config_file runtpfclientprocess false"
                    queue_step "update_chkconfig tp_ftransfer off" #set it off so we can do the rollback smoothly.
                    queue_step "update_config_file runmgrdprocess false"
                    queue_step "manualy_break_os_disk OS 60"
                    if [ $YUM_supported == 0 ]; then
                        queue_step "shutdown_machine for_kernel_update"
                        queue_step "upgrade_kernel OS"
                    else
                        ((STR_reboot_aft_upgrade++))
                        queue_step "shutdown_machine support_rollback_with_kernel_change"
                    fi
                fi
                ((kern++))
                ;;
            $upg_ref_os_pkg)
                if [ $os_pkg == 0 ]; then       #= 1st found os pkg
                    queue_step "backup OS" '' ign_double
                    [ $YUM_supported == 0 ] && queue_step "upgrade_packages OS"
                    queue_step "reasure_local-time_setting OS"
                fi
                ((os_pkg++))
                ;;
            $upg_ref_os_vfy)
                if [ $os_vfy == 0 ]; then       #= 1st found os verify
                    queue_step "backup OS" '' ign_double
                    queue_step "enforce_settings OS"
                    queue_step "update_release_file OS"
                fi
                ((os_vfy++))
                ;;
            $upg_ref_sw_pkg)
                if [ $sw_pkg == 0 ]; then       #= 1st found sw pkg
                    if [ $kern != 0 ] && [ $res_runl == 0 ] && [ $YUM_supported == 0 ]; then   #= kernel upgrade needed ] and [ 1st found run-lvl 1 request
                        queue_step "reboot_machine restore_runlevel"
                        res_runl=1
                    fi

                    # Add general product and instances backup (no stop done)
                    local prod; local ins; local info
                    #=set_var_cur prod TextPass
                    for prod in $(echo -n "$STR_products" | tr ',' ' '); do #= TextPass
                        info="backup $prod"
                        if [ $dd_instanciated == 0 ]; then
                            queue_step "backup $prod" prune ign_double
                        else
                            for ins in $dd_instances; do
                                queue_step "backup $prod $KW_instance $ins" prune ign_double
                            done
                        fi
                    done
                fi
                ((sw_pkg++))
                # Add the main product tasks
                local act=$( get_field 1 "$line")   #= <act column>
                local ent=$( get_field 3 "$line")   #= <pkg column>
                local rsn=$( get_field 6 "$line")   #= <rsn column>
                #=skip_control   $his is sanity check lets not bother in this case
                if [ "$act" != " $upg_act_none" ]; then
                    find_install "$ent"
                    if [ "$install_ent" == '' ]; then
                        log_warning "Did not find component '$ent', ignoring."
                        continue;
                    fi
                fi

                #=# Determine what should be done with found sw package
                case $act in
                    $upg_act_none)
                        if [ "$(get_queued_steps)" == '0' ]; then   #= no steps queued
                            log_warning "No upgrades are needed, please verify expectations."
                            echo '' >> $UPG_stat_file       # Just make empty file.
                            return $STAT_skipped
                        fi
                        ;;
                    $upg_act_upgrade)
                        #=# See if parent backup has to be added, only for supporting tools 
                        #=# and if the package requested it.
                        #=# If done manually please decide yourself what is wanted.

                        # Requesting is done with flag REQ_flag_upg_bck is requested.
                        # The ign_doubles later on will prevent double backups.
                        local pkg
                        for pkg in $dd_supporting; do
                            if [ "$(get_who_requires "$pkg" "$ent" "$REQ_flag_upg_bck" 'one_lvl')" != '' ]; then #= supporting pkg require backup
                                queue_step "backup $pkg" prune ign_double                            
                            fi
                        done

                        # Stop and Backup is in reverse order, made 2 liner for readability,
                        # The entity still defines what is done first. So get the info from the flags
                        # Stop/Backup all the instances one by one (also make things more clear)
                        # Remember there are multiple instance but only one package installation.

                        #=* Creating backup task, however the order differs.
                        #=- Most will use stop before backup
                        #=- But MySQL uses stop after backup
                        #=- Example steps used:
                        #=queue_step upgrade stop $ent
                        #=queue_step backup $ent
                        #=skip_until_marker
                        is_substr "$CFG_opt_run_for_backup" "$install_options" ','
                        local rfb=$?
                        [ $dd_instanciated == 0 ] && ins_extra='' || ins_extra=" instance $ins"
                        [ $rfb != 0 ] && q_ph1="$(add_step_to_list "$q_ph1" insert "upgrade stop $ent" "$ent")" # Stop after backup (so insert first)
                                         q_ph1="$(add_step_to_list "$q_ph1" insert "backup $ent" "$ent")"
                        [ $rfb == 0 ] && q_ph1="$(add_step_to_list "$q_ph1" insert "upgrade stop $ent" "$ent")" # Stop before backup (so insert last)
                        [ $ign_ph2 == 0 ] && q_ph2="$(add_step_to_list "$q_ph2" add "upgrade_package $ent")"                         # Other in normal order (not instanced)
                        #=skip_until_here
                       
                        if [ "$what" == 'planned' ]; then
                            update_state "$ent" $exe_state_todo $exe_type_main
                        fi
                        ;;
                    $upg_act_install)
                        local to=$(  get_field 5 "$line")   #= <to_ver column>
                        [ $ign_ph2 == 0 ] && q_ph2="$(get_concat "$q_ph2" "install_package $ent ver $to" "$nl")"    #=!
                        #=queue_step install_package $ent ver $to
                        # Configure is not supported, a warning will be given in finalize step
                        # [ $ign_ph2 == 0 ] && q_ph2="$(get_concat "$q_ph2" "configure $ent" "$nl")"
                        update_state "$ent" $exe_state_inst $exe_type_main
                        ;;
                    $upg_act_separate)
                        if [ "$STR_skip_sep_upgrades" != '' ]; then
                            log_warning "Separate upgrade scripts are skipped upon request, continuing."
                        elif [ "$rsn" != "$extra" ]; then
                            queue_step "explain_upgrade_procedure $rsn halt"
                        else
                            ((ign_ph2++))
                            update_state "$ent" $exe_state_todo $exe_type_main
                        fi
                        ;;
                    *)  log_warning "The action '$act' for '$ent' is not yet supported, ignoring."
                        ;;
                esac
                ;;
            *)
                local act=$( get_field 1 "$line")
                if [ "$act" != "$upg_act_none" ]; then  #= $act is not $upg_act_none
                    log_exit "Unhandled action reference '$ref' for line '$line'"
                fi
                ;;
        esac
    IFS=''; done < $STR_upg_plan_file; IFS=$def_IFS
    
    #=queue_step "setup_Backup-Dir mount"
    #=skip_until_marker
    [ "$what" == 'continue_planned' ] && q_ph1='' 
    
    [ "$q_ph1" != '' ] && queue_step "$q_ph1" prune  ign_double         # Prune stop/backups, show only if available
    [ "$q_ph2" != '' ] && queue_step "setup_Backup-Dir mount$nl$q_ph2"  # Add mount bck (in case recover is needed) and add other tasks
    #=skip_until_here

    if [ $kern != 0 ]; then             #= kernel update
        if [ $res_runl == 0 ]; then     #= run-lvl needs to be restored
            if [ $YUM_supported == 0 ]; then    # only is not via yum
                queue_step "reboot_machine restore_runlevel"
                queue_step "upgrade continue"       # Need this otherwise upgrade would start over due to empty queue.      
            fi
            res_runl=1
        fi
        log_wait "Be informed that this upgrade includes a kernel package update.${nl}Extra steps and reboots required.${nl}Please interrupt (Ctrl+C) if unexpected!" 30
    fi

    execute_queued_steps 'optional'    # This will start or continue at the stored list.
    if [ $? == 0 ]; then
        echo -n "" > $UPG_stat_file     # Creat empty file to indicate nothing is needed.
        return $STAT_not_applic
    fi
    ;;

'stop')   # Task to stop all given process before we can start
    check_upgrade_plan_readable 'need_stat_file'

    check_set "$extra" 'The entity parameter is mandatory for stop_process.'
    local ent="$extra"
    local state="$(get_state "$ent")"
    if [ "$state" == '' ]; then    #= state for $ent not found
        log_warning "The given entity '$ent' is not subject to current upgrade, ignoring."
        break;
    fi


    if [ "$state" == "$exe_state_todo" ]; then
        func $ent service stop

        if [ "$instance" != '' -a $dd_instanciated != 0 ]; then
            # update the state if we are processing the last instance of multi-instanced setup
            check_set "$instance" 'The Component Instance number is mandatory.'
            local last_ins="$(echo ${dd_instances: -1})"
            if [ "$instance" == "$last_ins" ]; then
                update_state "$ent" $exe_state_stop
            fi
        else
            # update the state if the setup is not multi-instanced
            update_state "$ent" $exe_state_stop
        fi
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
    local pkgs="$(get_who_requires "$ent" "$dd_components $dd_supporting" "$REQ_flag_runtime")"
    local stop_pkg
    local state
    for stop_pkg in $pkgs; do
        state=$(get_state $stop_pkg)
        if [ "$state" == '' -o "$state" == $exe_state_todo ]; then
            func $stop_pkg service stop
            update_state "$stop_pkg" $exe_state_stop
        fi
    done
    #=skip_until_here
    ;;

'others')     # Update other package none done, e.g. OS.
    #=# If yum is supported then always update all other packages
    set_install_comands "$pkg" 
    if [ $? != 0 ]; then    #= yum supported?
        # always do updtae do no use --exelcude="TextPassMysql' for none MySQL
        # This was discussed and agreed with Zhijiang and Divya. Safes complexity.
        cmd 'Execute yum update' $CMD_ins_freshen
        return $STAT_passed
    fi
    return $STAT_not_applic
    ;;

'verify')     # Verifies if all expectd is done
    if [ ! -r $UPG_stat_file ]; then
        log_exit "Cannot read the upgrade status file: '$UPG_stat_file'"
    fi
    if [ "$(cat $UPG_stat_file)" == '' ]; then      # An empty file nothing upgraded.
        log_info "The upgrade plan is empty nothing todo."
        return $STAT_not_applic
    fi

    local main_pkgs="$(grep ":$exe_type_main:" $UPG_stat_file)"
    local  sub_pkgs="$(grep ":$exe_type_sub:"  $UPG_stat_file)"

    # Check for real failures.
    local  fail_lis="$(grep $exe_state_fail $UPG_stat_file | cut -d':' -f1 | tr '\n' ' ')"  #= <failure list, see log>
    if [ "$fail_lis" != '' ]; then  #= any package with state '$exe_state_fail'
        log_exit "Some packages failed upgrading: $fail_lis"
    fi

    # Check if all our out of todo state or main in stopped state, which is wrong
    local  todo_lis="$(grep $exe_state_todo $UPG_stat_file | cut -d':' -f1 | tr '\n' ' ')"          #= <todo list, see log>
    local main_stop="$(echo -n "$main_pkgs" | grep $exe_state_stop | cut -d':' -f1 | tr '\n' ' ')"  #= <main comp to stop, see log>
    if [ "$todo_lis$main_stop" != '' ]; then    #= any packages with state '$exe_state_todo' or '$exe_state_stop'
        log_exit "Not all packages are upgraded: main_stop: $main_stop, todo: $todo_lis"
    fi

    # Check is sub packages are in unexpected state (should always be in stop or done)
    local sub_oth="$(echo -n "$sub_pkgs" | grep -v $exe_state_stop)"
    sub_oth="$(echo -n "$sub_oth" | grep -v $exe_state_done)"           #= <sub packages, see log>
    if [ "$sub_oth" != '' ]; then   #= failed sub-packages
        log_exit "Somehow sub packages are in wrong state:$nl$sub_oth"
    fi

    #
    # Now check fro installed packages and give a warning that there is no config not start
    # This might be a temporary check if we have somehow added configuration as well
    # Remember package cannot be started until it is configured (so it needs to be in other places)
    #
    local main_inst="$(echo -n "$main_pkgs" | grep $exe_state_inst | cut -d':' -f1 | tr '\n' ' ')"
    local inst
    for inst in $main_inst; do  #= packages in state '$exe_state_inst'
        log_warning "Installed '$inst' however that is not configured nor started!"
    done
    ;;

'reboot')
    # In the none yum approach reboot was pretty selective now it seems
    # always requested in the manual. So much for efficiency. I still made it
    # dependent on requested. Let be vigilant. Flag only set in new approach.
    if [ $STR_reboot_aft_upgrade != 0 ]; then
        # Reboot needs to be done via queued_step otherwise it will redo the same
        log_info "Reboot requested during upgrade."
        queue_step 'reboot_machine always'
        queue_step 'upgrade continue'       # Need this otherwise upgrade would start over due to empty queue.      
        execute_queued_steps
    else
        return $STAT_not_applic
    fi
    ;;

'finalize')     # Finalize the upgrade (after a potential reboot
    if [ ! -r $UPG_stat_file ]; then
        log_exit "Cannot read the upgrade status file: '$UPG_stat_file'"
    fi
    if [ "$(cat $UPG_stat_file)" == '' ]; then      # An empty file nothing upgraded.
        log_info "The upgrade plan is empty nothing todo."
        return $STAT_not_applic
    fi

    local main_pkgs="$(grep ":$exe_type_main:" $UPG_stat_file)"
    local  sub_pkgs="$(grep ":$exe_type_sub:"  $UPG_stat_file)"

    # Check which processed are need to be restarted again upgraded then all sub stopped
    local main_upgr="$(echo -n "$main_pkgs" | grep $exe_state_upgr | cut -d':' -f1 | tr '\n' ' ')"
    local  sub_stop="$(echo -n "$sub_pkgs"  | grep $exe_state_stop | cut -d':' -f1 | tr '\n' ' ')"

    if [ $STR_reboot_aft_upgrade == 0 ]; then
        # Check if a manager was stopped, then it has to be started before updating devices
        local ins
        if [ "$C_MGR"  != '' ] && [ "$(get_substr "$C_MGR" "$main_upgr $sub_stop")" != '' ]; then #= MGR was stopped
            for ins in $(get_all_components "$hw_node" ins_comp "$C_MGR"); do
                set_MM_instance $ins
                start_step "starting MGR$MM_ins_extra process"
                func $C_MGR service restart     # Some upgrade like STV starts it so to be safe use restart.
                finish_step $STAT_passed '' 'info'
            done
            update_state "$C_MGR" $exe_state_done
        fi
    fi

    # Next update the device before starting the entities. Just always do it
    execute_step 0 'update_devices on_this_node'

    # start the tpfclient and tpmgrd processes
    # I actually think this might cause problem if tpfclient was disabled anyhow.
    execute_step 0 'update_config_file runmgrdprocess true'
    execute_step 0 'update_chkconfig tp_ftransfer on'       #set tp_ftransfer to on in chkconfig
    execute_step 0 'update_config_file runtpfclientprocess true'


    if [ $STR_reboot_aft_upgrade == 0 ]; then
        #=# Now start all process upgraded or stopped
        if [ "$(echo -n "$main_upgr $sub_stop" | tr -s ' ')" != ' ' ]; then #= any others stopped
            start_step "starting other processes"
            local start_pkg; local ins
            for start_pkg in $main_upgr $sub_stop; do #= all upgraded, all sub-ent stopped, except MGR
                [ "$start_pkg" == "$C_MGR" ] && continue    #=! Skip manager, was already done
                for ins in $(get_all_components "$hw_node" ins_comp "$start_pkg"); do   #= all instances of $start_pkg on $hw_node
                    MM_ins_extra=''; 
                    if [ "$ins" != '-' ]; then  #= Whenever a component
                        set_MM_instance "$ins"
                    fi
                    start_step "starting $start_pkg$MM_ins_extra process"
                    func $start_pkg service start
                    finish_step $STAT_passed '' 'info'
                done
                update_state "$start_pkg" $exe_state_done
            done
            finish_step $STAT_passed '' 'info'
        fi
    fi

    STR_reboot_aft_upgrade=0
    store_current_state

    set_MM_instance                         # Reset to be sure.

    rotate_files "$UPG_stat_file"           # Now rotate the file away as we are finished
    ;;

esac

return $STAT_passed
