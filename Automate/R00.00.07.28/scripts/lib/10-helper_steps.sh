#!/bin/sh

: <<=cut
=script
This script contains simple helper functions which are related to steps handling
=version    $Id: 10-helper_steps.sh,v 1.37 2018/03/05 14:47:35 fkok Exp $
=author     Frank.Kok@newnet.com

=feat easy independent step definition
Using the steps configuration file and s bash script oen create a steps. No
impact on the framework whatsoever.

=feat auto sub steps (8) through file-name
The file name are <name>.[1-9].<extra>.sh. Single steps have 1, but sub steps
start are 2. No gaps allowed.

=feat define undo steps
A file name with <name>.u.<extra>.sh is an undo step (no sub-steps allowed). This
can be called as u<stepnr>.

=feat possibility to be OS or even OS version independent
The extra can be [Linux|Solaris] the tool search for the best match.
The OS version can be defined with [Linux.RH#_#|Solaris.Sol#]
=cut

# This is the current user executing commands. Use set_user to temporary
AUT_cmd_usr=''      # Empty means the default user being root
AUT_num_steps=0
AUT_cur_step=1      # The current step index
AUT_cur_script=''   # The current script file
AUT_tb_exec=''      # Textual Steps to be executed
AUT_step_info=''    # Textual step info
AUT_step_line[0]=''
AUT_inprogress_pid=0
AUT_step_interrupted=0

# Used fore step continuation
declare -a AUT_cont_step_queue
declare -a AUT_cont_step_arr
declare -a AUT_cont_step_cmd
           AUT_cont_step_depth=''

STEP_finish_automate='finish_automation'

# These are also use to print to the screen
readonly step_type_def='Step'
readonly step_type_undo='Undo'
STEP_type=$step_type_def                 # Type currently: defualt or undo

readonly step_order='1 2 3 4 5 6 7 8 9'  # Used to define the potential step sequences
 
: <<=cut
=func_int
Recalculates step info and set the global variables accordingly.
=set AUT_step_info
The textual step info
=cut
function recalc_step_info() {
    local idx=0
    local num=$STR_step_depth
    
    # first build previous step
    AUT_step_info=''
    while [ "$idx" -lt "$num" ]
    do
        if [ "$AUT_step_info" == '' ]; then
            AUT_step_info="${STR_step_arr[$idx]}"
        else
            AUT_step_info="$AUT_step_info-${STR_step_arr[$idx]}"
        fi  
        ((idx++))
    done
}

: <<=cut
=func_int
S*tops the inprogress indicator. Which is currently implemented as a child script
showing the indication.
=set AUT_inprogress_pid
Will be set to 0
=cut
function stop_inprogress_ind() {
    if [ "$AUT_inprogress_pid" != "0" ]; then
        log_debug "Stopping in progress process, pid:  $AUT_inprogress_pid"
        kill -TERM "$AUT_inprogress_pid" 2>/dev/null
        AUT_inprogress_pid=0
    else
        log_debug "Stop of in progress process requested but it is not running, continuing"
    fi
}

: <<=cut
=func_int
Start the inprogress indicator. Which is currently implemented by creating
a child script, which shows the indication.
=set AUT_inprogress_pid
Will hold the pid of the child process
=cut
function start_inprogress_ind() {
    if [ "$AUT_inprogress_pid" != "0" ]; then
        log_debug "In progress still running, it should not, continuing"
        stop_inprogress_ind
    fi        
    # start the inprogress indicator
    $libdir/show_inprogress.sh &
    AUT_inprogress_pid=$!
    log_debug "Created in progress process with pid: $AUT_inprogress_pid"
}

: <<=cut
=func_int
Print a status text, which also means the inprogress indicator will be
stopped. The numeric status is translate into a text + color. Which is
then printed on the screen.
=cut
function print_status() {
	local status="$1"		# (M) The status to print which should be a $STAT_* value.

    local color
    case "$status" in
        $STAT_todo | $STAT_partial | $STAT_usr_skipped)              color=$COL_todo    ;;
        $STAT_passed | $STAT_wait | $STAT_done | $STAT_substeps)     color=$COL_ok      ;;
        $STAT_implicit)                                              color=$COL_ok      ;;
        $STAT_shutdown | $STAT_reboot | $STAT_s_reboot)              color="$COL_ok$COL_blink" ;;
        $STAT_failed )                                               color=$COL_fail    ;;
        $STAT_warning | $STAT_sum_warn | $STAT_manual | $STAT_later) color=$COL_warn    ;;
        $STAT_not_found)                                             color=$COL_warn    ;;
        $STAT_not_applic | $STAT_skipped |  $STAT_info )             color=$COL_info    ;;
        *) log_exit "Programming error: Unknown status '$status' given" ;;
    esac

    # The fact that a status is printed mean the progress has to stop
    stop_inprogress_ind

    local pstat="${STAT_stats[$status]}"
    if [ $status == $STAT_warning -a "$LOG_warnings" != '' ]; then
        pstat="$pstat#$LOG_warnings"
    elif [ $status == $STAT_sum_warn -a "$LOG_warnings" != '' ]; then
        pstat="$LOG_warnings ${pstat}"
        if [ "$LOG_warnings" -gt '1' ]; then
            pstat="${pstat}S"
        fi
    fi

    log_screen "${color}[$pstat]${COL_def}${space}"
}

: <<=cut
=func_int
This functions shields variables clashes from the local function and the called
step (as it cannot be controlled what user steps are doing.
=set SCR_whoami
This will hold the entity + optional version (separated by a :) of the
being called step. This can be used by a step to store info about
himself. This is accessible for its children. May be empty if unknown.
=set SCR_alias
This will hold the original alias name or entity (if no alias, without a version).
This is accessible for its children. May be empty if unknown.
=set SCR_instance
This hold the instance number can be useful if entity needs to know. One could
use MM_instance but that would require overruling in e.g. func. This is more
localized in the SCRIPT function. Do not add to whoami, which would cause
unwanted side effect. Now the pkg can decide what it wants.
=ret status
A STAT_* value
=cut
function call_step_in_func() {
    local whoami="$1"          # (O) Identifies who this step belong to may be empty
    local alias="$2"           # (O) Identifies the original alias, may be empty
    local step_script="$3"     # (M) the step script to call
    local parameters="$4"      # (O) The additional parameter to pass
    
    # First check if this step should be skipped (implemented in a general
    # way so that theoretically all steps can be skip. This is done
    # by define skip_step_<name> in the automate section which will turn it
    # into STR_skip_step_<name> if set to '1' then the step will be skipped
    # with STAT_usr_skipped and a warning.
    local name="$(basename "$step_script")"
    name="${name%%.*}"
    local var="STR_skip_step_$name"
    if [ "${!var}" == '1' ]; then
        local text="${COL_warn}This step will be skipped upon user request.${COL_def} 
Please make sure you know what you are doing and that you manually execute
what is done in this step. 
 
Automate is used outside its intended and verified scope. Therefore the 
responsibility of potential (indirect) failures is entirely up-to the user.
 
This step is skipped because the customer data file holds the following 
configuration:
[automate]
skip_step_$name = '${!var}'
 
To disable please replace above with:
skip_step_$name = '0'
"
        log_wait "$text" 60
        log_manual "User skipped upon own decision" "$text"
        return $STAT_usr_skipped
    fi

    # Store the whoami as local but with a 'global' prefix as it can be used by 
    # this functions children. Not using a global allows correct handling of
    # nested calls.
    local SCR_whoami="$whoami"; readonly SCR_whoami
    local  SCR_alias="$alias" ; readonly SCR_alias
     
    #
    # To make all step calls uniform and prevent (forgetting double code,
    # w'll make sure that the proper instance(/zone future ) is set).
    # Also make sure that the define_vars is called if available. The
    # define_var could be split up in two sections. Dynamic (e.g. depending
    # on the instance) and static (never changes).It is up to the define_vars
    # to either implement this. What should be kept in mind is that repetitively
    # expensive define vars should be prevented
    #
    # The instance is enforce by the steps generator as instance<sp>#
    # If this is not available then the main instance is being set.
    # set_MM_instance is optimizes for similar calls so always call it 
    #
    local instance=$(echo -n "$parameters" | $CMD_ogrep 'instance [0-9]' | $CMD_ogrep '[0-9]')
    local SCR_instance="${instance:-0}"; readonly SCR_instance
    set_MM_instance "$instance"
    if [ "$SCR_whoami" != '' ]; then
        func "$SCR_whoami" define_vars
    fi
    
    AUT_cur_script="$step_script"
    log_screen_info "$step_script" $parameters
    . $step_script $parameters ""
    local status="$?"
    # $? of 0 is also seen as passed, just means the routine did not gave a
    # a specific return code.
    if [ "$status" == '0' ]; then
        status=$STAT_passed
    fi

    return $status
}

: <<=cut
=func_int
Removes the current step from the list and returns the next in. The new step
information is also permanently stored to the state file. This is called
after the step_depth is lowered so a step_depth of zero is the main depth.
=set AUT_next_step
The next step to handle
=cut
function remove_cur_step() {
    # find out if the is the main depth or a sub depth
    if [ "$STR_step_depth" == '' ]; then
        prg_exit "Trying to remove a step but none available."
    elif [ $STR_step_depth == 0 ]; then     # This is the main level remove the step
        STR_exec_steps=$(get_field 2- "$STR_exec_steps" ',')
        AUT_next_step=$(get_field 1 "$STR_exec_steps" ',')
    fi
    STR_step_queue_busy=''      # Clear buys step.
    store_current_state
}

: <<=cut
=func_ext
Adds a step to a list (separated by $nl), while adding it can add the
instance tag if enabled and needed. This will only add the 'instance #' tag
if needed.
=stdout
The new list, with new steps inserted or added.
=cut
function add_step_to_list() {
    local lst="$1"      # (M) The list to insert/add it to
    local where="$2"    # (O) insert or add (anything else). Default is add.
    local step="$3"     # (M) Full step including entity (location might differ)
    local ent="$4"      # (O) The entity to check for instance.

    where=${where:-add};
    [ "$where" != 'insert' ] && echo "$lst"

    if [ "$ent" != '' ]; then
        local ins_extra
        local comps="$(get_all_components "$hw_node" ins_comp_full "$ent")"
        IFS=$nl; for ins_extra in $comps; do IFS=$def_IFS
            [ "$ins_extra" == "$ent" ] && echo "$step" || echo "$step $(get_field 2- "$ins_extra")"
        IFS=$nl; done; IFS=$def_IFS
    else
        echo "$step"
    fi

    [ "$where" == 'insert' ] && echo "$lst"
}

: <<=cut
=func_int
Simple helper to add a single step into the queue at end of the queue.
Multiple steps may be added at the same depth using newlines in t step.
=cut
function add_to_step_queue() {
    local depth="$1"      # (M) The depth of the given step
    local info="$2"       # (O) The step information associated (can be separate by nl). Empty nothing added
    local prune="$3"      # (O) If set then the none existent steps are pruned (not added).
    local ign_double="$4" # (O) If set then doubles (at and depth) are ingnored and not added again.

    local num=${#STR_step_queue[@]}
    local step
    IFS="$nl"
    for step in $info; do   # Will also work for the empty case
        if [ "$prune" != '' ]; then           # Check if step should be pruned
            could_step_file_be_found "$step"
            if [ $? == 0 ]; then
                log_info "add_to_step_queue: No default nor specific found, pruning '$info'"
                continue
            fi
        fi
        if [ "$ign_double" != '' ]; then    # check if same step already exists
            local idx=0
            while [ "$idx" -lt "$num" ]; do
                if [ "$(echo -n "${STR_step_queue[$idx]}" | grep ":$step\$")" != '' ]; then
                    log_debug "Step '$step' already queued at index $idx, not queuing again."
                    continue 2      # Don't add this continue at for.
                fi
                ((idx++))
            done
        fi

        STR_step_queue[$num]="$depth:$step"
        log_debug "queue_step: ($num|$prune) : $depth : $step"
        ((num++))
    done
    IFS=$def_IFS    
}

: <<=cut
=func_ext
Will set the correct steps depending on the parameters given or read from
the standard step file. This standard step file can e.g. be used during
reboot.
=set  AUT_*
The globals related to step processing are initialized.
=cut
function set_step_status() {
	local start_step="$1"	# (O) The start step, use 0 to show all steps.
	local end_step="$2"		# (O) The end step.
	
    # Check the steps parameters
    AUT_step_info=''
    AUT_cur_step=1
    if [ "$start_step" != '' ]; then
        if [ "$start_step" -lt '1' ]; then
            log_exit "Start step is wrongly defined $start_step != [1..]"
        fi
        AUT_cur_step=$start_step
    fi
    
    STR_step_depth=0
    STR_step_arr[0]=$((AUT_cur_step-1))

    AUT_num_steps=${#AUT_step[@]}
    ((AUT_num_steps--))     # There is always 1 dummy step
    AUT_tb_exec="total steps: $AUT_num_steps"
    if [ $AUT_cur_step != "1" ]; then
        AUT_tb_exec="$AUT_tb_exec, starting at:$AUT_cur_step"
    fi
    
}

: <<=cut
=func_ext
Registers that a step is started. It will calculate and print the step
information. The progress indicator is started.
=set  AUT_*
Some step variable are adapted to keep track of step stack.
=cut
function start_step() {
    local step_cmd="$1"	# (M) The cmd belonging to this step. Which is stored for later use.

    [ -z help ] && show_trans=0 && show_short="Show informational step: $step_cmd"

    # Now increase the current depth and add the new value
    STR_step_cmd[$STR_step_depth]="$step_cmd"
    local last=${STR_step_arr[$STR_step_depth]}
    if [ $STR_step_depth != 0 ]; then   # Auto increment sub-steps
        ((last++))
        STR_step_arr[$STR_step_depth]=$last
    fi
    local cur_depth=$STR_step_depth
    ((STR_step_depth++))
    STR_step_arr[$STR_step_depth]=0 # Set next to null
    store_current_state             # Step now started safe the state!
    recalc_step_info
        
    # Now do some logging for the log file
    log_info ""
    log_info "#################################################################"
    log_info "# $AUT_step_info | Processing: $step_cmd"
    
    # And logging for to the screen
    local main=`echo "$AUT_step_info" | cut -d'-' -f 1`
    local sub=`echo "$AUT_step_info" | cut -d'-' -f 2-`
    local info=''
    if [  $STR_step_depth == 1 ]; then
        info=`printf "$STEP_type %2d/%2d : $step_cmd" $main $AUT_num_steps`
    else
        if [ "$last" == "1" ]; then     # start of substeps
            print_status $STAT_substeps
        fi
        local idx=2
        while [ "$idx" -lt "$STR_step_depth" ]; do 
            info="$info "
            ((idx++))
        done
        info="$info*"
        info="$info Sub $sub"
        info=`printf "%-11s: $step_cmd" "$info"`
    fi
    local size=$((LOG_screen_width - STAT_min_space))
    info=`printf "%-$size.${size}s" "$info" | sed "$SED_rep_us_w_sp"`
    AUT_step_line[$cur_depth]="$info"   # Store in case needed again
    log_screen "$info" 'n'

    start_inprogress_ind
}

: <<=cut
=func_ext
Registers that the current running (sub)step is fished. The proper status 
message will be shown on the screen.
=cut
function finish_step() {
    local status="$1"       # (M) The final status of the current step.
    local log_type="$2"     # (O) The type of login used log_<info> log_<exit> defualt is exit
    local was_info="$3"     # (O) Special parameter to tell help it was an informational step.

    
    [ -z help ] && [ "$was_info" != '' ] && show_short="Informational step resulted in '$status'"
    [ -z help ] && [ "$was_info" == '' ] && show_short="Finishes this step with '$status'"
    [ -z help ] && show_trans=0

    log_type=${log_type:-exit}
    
    default_cmd_user    # End step go back to root, needed by store state as well
                        # This is case forgotten or error during other user.

    if [ "$AUT_step_interrupted" -gt '0' ]; then
        log_debug "Auto resuming an interrupted task!"
        continue_step
    fi
    if [ "$STR_step_depth" == "0" ]; then
        log_$log_type "Programming error, step depth is already 0"
    fi
    local cur=${STR_step_arr[$STR_step_depth]}
    ((STR_step_depth--))
    
    log_info "# $AUT_step_info | Finished: ${STR_step_cmd[$STR_step_depth]} | Status: $status|${STAT_stats[$status]}"
    
    if [ "$cur" == '0' ]; then
        print_status "$status"
    fi
    
    # If this was a main step then the queue should be empty
    if [ "$STR_step_depth" == '0' -a "${#STR_step_queue[@]}" != '0' ]; then
        IFS=', '
        log_$log_type "Still queued steps at end of ${STR_step_cmd[0]}: ${STR_step_queue[*]}"
    fi
    
    # Some status have special end handling
    STR_rebooted=${STR_rebooted:-0}   # Just make sure default is always set.
    case $status in 
        $STAT_shutdown | $STAT_reboot) ((STR_rebooted++)); remove_cur_step    ; ;;
        $STAT_s_reboot               ) ((STR_rebooted++)); store_current_state; ;;
        *)                                                 store_current_state; ;;
    esac
    recalc_step_info    
}

: <<=cut
=func_ext
Interrupt a step, stop the progress indicator and prints a additional status.
This is allowed to call even if no step is active.
=ret
1 If a step was interrupted, 0 if none interrupted.
=cut
function interrupt_step() {
    local status="$1"   # (M) The status to show

    if [ "$STR_step_depth" == "0" ]; then
        return 0
    fi

    ((AUT_step_interrupted++))
    print_status $status
    return 1
}

: <<=cut
=func_ext
Continues a step after interuption, which means the step is printed and the
progress indicator is started.
=cut
function continue_step() {
    if [ "$STR_step_depth" == "0" ]; then
        return
    fi
    if [ "$AUT_step_interrupted" == '0' ]; then
        log_exit "To much continue steps called"
    fi
    ((AUT_step_interrupted--))

    local depth=$STR_step_depth
    ((depth--))
    log_screen "${AUT_step_line[$depth]}" 'n'
    start_inprogress_ind
}

: <<=cut
=func_ext
Find step file belonging to the given steps. This does not support the versions
but allows for the order and the OS specific selection. Once the step order is
broke so it will stop. The order is 1,2,3,4,..9. So 1,2,4 will show only 1 and 2
=func_note
It is currently not yet used by execute_step (risk of breaking stuff) but it
might be possible/useful to adapt it and use it.
=stdout 
The file (full paths which are related to this step. They are ordered in sequence.
The files are separated by spaces (so no spaces in files names!).
=cut
function find_step_files() {
    local step_info="$1"     # (M) The step info to search for. The 1st par could identify an entity
    
    local command=$(get_field 1 "$step_info")
    local par1=$(   get_field 2 "$step_info")

    log_debug "find_step_files: Finding: $step_info"
    if [ "$command" == '' ]; then
        log_debug "Incorrect step, no command given."
        return  # Ignore in this case as it is not fatal
    fi

    local s_dir=''
    if [ "$par1" != '' ]; then 
        # The step could either be part of a component package or be part of the
        # the installer steps directory. 
        find_install $par1 'optional'
        if [ "$install_idx" != '0' -a "$install_aut" != '' ]; then
            if [ -d "$install_aut/$stepfld" ]; then
                s_dir="${install_aut}/$stepfld/$command"
            fi
        fi
    fi

    local i
    local d
    local file
    local sep=''
    IFS=$def_IFS
    for i in $step_order; do
        file=''
        for d in $s_dir $stepdir/$command; do
            file=$(get_best_file "$d.$i")
            if [ "$file" != ''  ]; then
                echo -n "$sep$file"
                sep=' '
                break 1     # This sequence has been done
            fi
        done
        [ "$file" == '' ] && break  # Stop if none found in this sequence
    done
}

: <<=cut
=func_ext
Executes a full step. Find the related step file and call it with the proper
parameters (take from the I<step_info> all given steps. Make sure the proper
status is shown on the screen.

=man1
The information from this step (so the actual input read from the steps file).
=set STP_etc_dir
Hold the etc dir (if any) belonging to a package dir.
=ret    status of step. Remember failures (2x) will stop execution
=cut
function execute_step() {
    local step_idx="$1"      # (M) The step index to execute. Use 0 for direct step.
    local step_info="$2"     # (O) Only useful if step_idx=0, meaning a free step info.
    local step_file="$3"     # (O) An exact file (including version) to be executed (step_idx=0)
    local opt_step="$4"      # (O) If set then the direct step is also optional

    local alias=''

    if [ "$step_idx" != '0' ]; then
        step_info="${AUT_step[$step_idx]}"
    elif [ "$step_file" != '' ] && [ -r "$step_file" ] ; then
        step_info=$(basename "$step_file")
        [ "$SCR_alias" != '' ] && alias="$SCR_alias" || alias="$(get_field 1 "$SCR_whoami" ':')"
        step_info="${step_info%%.*} $alias"
        step_idx=999

    fi
    check_set "$step_info" "No step information given/retrieved to execute ($step_idx)."
	
    local command=$(get_field 1 "$step_info")
    local par1=$(get_field 2 "$step_info")
    local pars
    local file=''
    local step_out=''
    local whoami=''

    check_set "$command" "Incorrect step, no command given: '$step_info'"

    log_debug "execute_step: Finding: $command $par1 $pars"

    if [ $STR_step_depth == 0 ]; then
        AUT_cur_step=$step_idx
        STR_step_arr[0]=$AUT_cur_step
        if [ "$STR_queued_for_step" != $AUT_cur_step ]; then
            # new step, clear queued to be sure
            STR_queued_for_step=''
            unset STR_step_queue 
            unset STR_step_queue_done
            unset STR_step_queue_proc
        fi
    fi

    STR_step_queue_proc[${#STR_step_queue_proc[*]}]="$STR_step_depth:$step_info";

    local s_dir=''
    local e_dir=''
    if [ "$par1" != '' ]; then 
        # The step could either be part of a component package or be part of the
        # the installer steps directory. 
        find_install $par1 'optional'
        if [ "$install_idx" != '0' -a "$install_aut" != '' ]; then
            if [ -d "$install_aut/$stepfld" ]; then
                s_dir="${install_aut}/$stepfld/$command"
            fi
            if [ -d "$install_aut/etc" ]; then
                e_dir="${install_aut}/etc"
            fi
            whoami=$(get_concat "$install_ent" "$install_cur_ver" ':')
            alias="${install_alias:-$install_ent}"
        fi
    fi

    LOG_manuals=''      # Empty manual steps
    LOG_warnings=''     # Empty warnings
    local cnt=0
    local status=$STAT_not_applic
    [ "$FLG_interactive" != '0' ] && status=$STAT_not_found     # Special for interactive mode. 
    local order="$step_order"
    start_step "$step_info"
    if [ "$step_file" != '' ] && [ -r "$step_file" ]; then
        call_step_in_func "$SCR_whoami" "$alias" "$step_file"    # whoami same as caller
        status=$?
        ((cnt++))
        order=''    # Will disable the automatic search loop below (without another indent)
    elif [ "$STEP_type" == $step_type_undo ]; then
        order='u'       # Only the undo versions
    fi
    
    local i
    local c
    local d
    local f
    local cur
    IFS=$def_IFS
    for i in $order; do
        cur=$cnt
        for d in $s_dir $stepdir/$command; do
            f=$(get_best_file "$d.$i")
            if [ "$f" != ''  ]; then
                if [ ! -x $f ]; then
                    log_exit "Step file '$f' cannot be executed."
                fi
                if [ "$i" != '1' -a "$i" != 'u' ]; then
                    finish_step $status
                    start_step "$step_info (part $i)"
                fi

                # Decide pars base on package included or not (use of s_dir)
                if [ "$s_dir" == '' -o "$d" != "$s_dir" ]; then
                    pars=$(get_field 2- "$step_info")
                    call_step_in_func "$whoami" "$alias" "$f" "$pars"
                else
                    pars=$(get_field 3- "$step_info")
                    STP_etc_dir="$e_dir"
                    call_step_in_func "$whoami" "$alias" "$f" "$pars"
                fi
                status="$?"
                ((cnt++))
                break 1     # This sequence has been done
            fi
        done
        if [ "$cnt" == "$cur" -o "$status" == "$STAT_not_applic" ]; then
            break;      # Stop if none found in this sequence
        fi
    done

    if [ "$opt_step" == '' -a "$step_idx" == '0' -a "$cnt" == '0' ]; then    # A direct step should be found
        log_exit "Did not find direct requested step: $step_info"
    fi
    if [ $status -le $STAT_grp_ok -a "$LOG_warnings" != '' ]; then
        status=$STAT_sum_warn
    fi

    finish_step $status
    return $status
}

: <<=cut
=func_ext
Executes all given steps. Which can be called by the main program.
The input is taken from the steps array. The amount of steps can be limited
=func_note
For easiness the amount of all means 1000000, which should be enough.
=cut
function execute_all_steps() {
    local amount="$1"   # (O) Empty means all, other wise a positive number where 1 means execute 1 step

    log_screen "all_steps: $STR_exec_steps"

    [ "$STR_exec_steps" == '' ] && return;          # Nothing todo anymore

    local first=1
    amount=${amount:-1000000}       # Make the code easy
    # Do the given ones
    local idx=`echo -n "$STR_exec_steps" | cut -d',' -f1`
    while [ "$idx" != '' ] && [ $amount -gt 0 ]; do
        STEP_type=$step_type_def
        if [ "${idx:0:1}" == 'u' -o "${idx:0:1}" == 'U' ]; then
            STEP_type=$step_type_undo
            idx="${idx:1}"
        fi
        # No extra check for now

        # Process any new declare requests. This is not the nicest but still
        # located per package. This approach has to be taken to be sure
        # the associative array are available at the correct level
        local decl
        for decl in $AUT_new_declares; do
            if [ -x "$decl" ]; then
                log_screen_info "$decl"
                . $decl
            fi
        done
        AUT_new_declares=''         
        

        if [ "$first" == '1' ]; then
            first=0
            continue_potential_queued_steps "$idx"
            if [ $? == 0 ]; then        # None execute still do current
                execute_step "$idx"
            fi
        else
            execute_step "$idx"
        fi

        remove_cur_step
        idx=$AUT_next_step

        ((amount--))
   done
}

: <<=cut
=func_frm
Executes the queued steps (if any). The result is that the queue will be empty.
=ret
The number which has been executed. Could be 0 if none queued.
=cut
function execute_queued_steps() {
    local opt="$1"          # (O) If set then the referred step are optional and will not cause an error if not found.
    local all_depths="$2"   # (O) If set then all depths are done. Otherwise only current.

    local exec=0
        
    log_debug "execute_queued_steps : '${STR_step_queue[*]}'"
    store_current_state                     # Store state before staring as step might fail before storing.
    while [ "${STR_step_queue[0]}" != '' ]; do
        local full_step="${STR_step_queue[0]}"
        local depth=$(get_field 1 "$full_step" ':')
        if [ $depth != $STR_step_depth -a "$all_depths" == '' ]; then break; fi        # Finished this depth

        local step="$(get_field 2- "$full_step" ':')"           # readability
        STR_step_queue_busy="$full_step"                        # Store the one being busy
        STR_step_queue=("${STR_step_queue[@]:1}")               # Remove in advance
        store_current_state                                     # Store in case failure
        if [ -r "$step" ]; then
            execute_step 0 '' "$step" "$opt"
        else
            execute_step 0 "$step" '' "$opt"
        fi
        ((exec++))
        STR_step_queue_busy=''                                  # Clear busy step in case crashed
        store_current_state
    done

    return $exec
}

: <<=cut
=func_ext
Shows all process steps (except the last). This will show SUBSTESP and DONE
status for all alreayd executed once. It will rebuild STR_step_queue_proc.
the information will be taken fro AUT_steP-queue_proc. But more important
it will replay the stack so that exceute_steps can be continued.
=cut
function handle_processed_steps() {
    local cur_step="$1"     # (M) The current step executing

    # handle all the process steps and build the stack along the ways
    local idx=0 
    local num="${#AUT_cont_step_queue_proc[@]}"
    log_debug "Handling processed steps from AUT_step_queue_proc ($num)"
    if [ "$num" -le '0' ]; then return; fi
    # See and show if step is skipped
    if [ "$AUT_step_queue_skipped" != '' ]; then
        local last=$num; ((last--))
        if [ "${AUT_cont_step_queue_proc[$last]}" == "$AUT_step_queue_skipped" ]; then
            ((last++))
            AUT_cont_step_queue_proc[$last]="$(get_field 1 "$AUT_step_queue_skipped" ':'):~"      # Indicates last is skipped.
            ((num++))
        fi
    fi
    while [ "$idx" -lt "$num" ]; do
        local info="${AUT_cont_step_queue_proc[$idx]}"
        local STR_step_depth="$(get_field 1 "$info" ':')"
        if [ $STR_step_depth == 0 ]; then
            AUT_cur_step=$cur_step
            STR_step_arr[0]=$AUT_cur_step
        fi
        local step="$(get_field 2- "$info" ':')"
        if [ -r "$step" ]; then     # Try to recover script file and entity (kind of hacky)
            local ent="$(basename "$(dirname "$(dirname "$step")")")"
            if [ "$ent" == 'scripts' ]; then
                start_step "$(basename "$step")"       # Base dir, no ent name
            else
                start_step "$(basename "$step") $ent"
            fi
        else
            start_step "$step"                              # A step show as is.
        fi
        STR_step_queue_proc[${#STR_step_queue_proc[*]}]="$info" 

        # To find the stat w'll need to know the depth of the next
        ((idx++))
        # Substep msg will be created by start_step (increases step_depth as well)
        if [ "$idx" -ge "$num" ] || [ "$(get_field 1 "${AUT_cont_step_queue_proc[$idx]}" ':')" -lt "$STR_step_depth" ]; then
            if [ "$(get_field 2- "${AUT_cont_step_queue_proc[$idx]}" ':')" != '~' ]; then
                finish_step $STAT_done
            else
                finish_step $STAT_skipped   # This will show as not need. The user decided it was not needed!
            fi
        fi
    done

}

: <<=cut
=func_ext
Continue queued steps if any. This will only works if the current step is
the same as before. So only call on mainlevel. (STR_step_depth is ignored).
=ret
1 if continued otherwise 0
=cut
function continue_potential_queued_steps() {
    local cur_step="$1"     # (M) The current step executing

    local ret=0
    local curd=0            # Always from depth 0
    local full_step="${STR_step_queue[$curd]}"
    local step_depth=$(get_field 1 "$full_step" ':')
    log_debug "continue_potential_queued_steps : depth $curd, step_queue: '${STR_step_queue[*]}'"
    
    # Do some pre check, with addiontionl debugging, assume no continue
    if [ "$AUT_cont_step_depth" == '' ] || [ "$AUT_cont_step_depth" -lt '1' ]; then
        log_debug "Step depth at main, nothing to continue."
    elif [ "${AUT_cont_step_queue[0]}" == '' -a "${STR_step_queue[0]}" == '' ]; then
        log_debug "No steps queued to continue"
    elif [ "$cur_step" != "${AUT_cont_step_arr[0]}" ]; then
        log_debug "Cannot continue queued, different step $cur_step != ${AUT_cont_step_arr[0]}"
    elif [ "${AUT_cont_step_arr[$curd]}" == '' -o "${AUT_cont_step_arr[$curd]}" == '0' ]; then
        log_debug "(Sub)level step at depth $curd is not defined"
    elif [ "${STR_step_queue[0]}" == '' -a "${AUT_cont_step_queue[0]}" != '' ]; then     # none stored copy from AUT_ queue
        log_debug "Copying from continue step queue: '${AUT_cont_step_queue[*]}'"
        STR_step_queue=("${AUT_cont_step_queue[@]}")            # First copy before storing state
        unset AUT_cont_step_queue
        handle_processed_steps "$cur_step"
        STR_step_depth="$(get_field 1 "${STR_step_queue[0]}" ':')"
        execute_queued_steps '' 'all_depths'
        ret=$?
        STR_step_depth=0            # Now back at main
    else
        log_debug "No steps to continue with."
    fi

    return $ret
}


: <<=cut
=func_frm
Get the amount of queued for a specific step.
=stdout
The amount of queued steps. 0 if none or if the current step is not the same
as the current setting (which is not an error).
=cut
function get_queued_steps() {
    if [ "$STR_queued_for_step" == "$AUT_cur_step" ]; then
        echo -n "${#STR_step_queue[@]}"
    else
        echo -n '0'
    fi
}

: <<=cut
=func_frm
Check if a step could exits by globally looking at the default steps dir and
trying to look at the entity specific steps dir. This ignores the other
steps setting like os and version. It is just to do a general shift in not-applicable
steps./ If the step would still not be found then at a later stage a not-applicable
will be returned by the framework. This function should not filter to strictly!
=return
1 if ithe file could be found, otherwise a 0
=cut
function could_step_file_be_found() {
    local info="$1" # (M) The full step info, may not be a file.
    local comp="$2" # (O) Optional comp used in case special filter on comp is requested

    local step=$(get_field 1 "$info")
    local found=1   

    # Filter special cases (could be extended, currently requires yum support
    if [ "$YUM_supported" != 0  -a "$comp" != '' -a "$step" == 'install_package' ]; then
        find_install $comp 'opt'
        if [ "$install_ent" != '' -a "$install_options" != '' ] ; then
            is_substr "$CFG_opt_skip_yum_install" "$install_options" ','
            if [ $? == 1 ]; then
                return 0        # No need to check further
            fi
        fi
    fi

    if [ "$(ls $stepdir/$step.*sh 2>/dev/null)" == '' ]; then 
        local pkg=$( get_field 2 "$info")
        if [ "$pkg" != '' ]; then
            find_install $pkg opt                           # No dir is allowed, some other parameter
            if [ "$install_aut" == '' ] ||
                [ "$(ls $install_aut/$stepfld/$step.*sh 2>/dev/null)" == '' ]; then
                found=0     # Has aut dir but no file
            fi
        else
            found=0     # No default and no package given.
        fi
    fi

    return $found
}

: <<=cut
=func_frm
Queues a step request for later processing
=need QUEUE_at_depth
If set then the step is queued a a specific depth. If not or empty then then
current depth is used. Which is the default. If the variable is used then
it is upto the caller to clear it again. If not then dramatic things would
go wrong.
=func_note
The use of QUEUE_at_depth was introduced to allw a higher depth step have control
over lower function, without them to know anything about it.
=cut
function queue_step() {
    local info="$1"         # (M) The full step info to add, multiple allowed with newline as sep. Or reference to a file (.steps|.sh)
    local prune="$2"        # (O) If set then the none existent steps are pruned (not added).
    local ign_double="$3"   # (O) If set then doubles (at and depth) are ingnored and not added again.
 
    local at_depth=${QUEUE_at_depth:-$STR_step_depth}

    if [ -f "$info" ]; then     # if file check type
        local ext="${info##*.}"
        case $ext in
            'steps') read_steps "$file" 'queue'; return; ;;
            'sh'   ) : ;;   # do noting execute_step will translate
            *      ) log_exit "Unrecognized file type ($info -> $ext) for adding a step."
        esac
        # It is a .sh script which is found (so no prune check needed
        prune=''
    fi

    local num=${#STR_step_queue[@]}
    if [ "$num" == 0 ]; then
        STR_queued_for_step=$AUT_cur_step
    elif [ "$STR_queued_for_step" != "$AUT_cur_step" ]; then
        log_exit "Trying to queue step for new step while other levels pending."
    fi

    #
    # Steps could be insert if the new depth is less the stored
    # The 1st is either the one calling or always the same as current depth
    #
    local queue_org=("${STR_step_queue[@]}")
    local idx=0
    IFS="$nl"
    unset STR_step_queue    # Empty current will be rebuild.
    while [ "$idx" -lt "$num" ]; do
        local depth=$(get_field 1 "${queue_org[$idx]}" ':')
        if [ "$info" != '' -a "$depth" -lt "$at_depth" ]; then
            add_to_step_queue "$at_depth" "$info" "$prune" "$ign_double"
            info=''
        fi
        add_to_step_queue "$depth" "$(get_field 2- "${queue_org[$idx]}" ':')" '' "$ign_double" # Do not prune existing ones.
        ((idx++))
    done
    add_to_step_queue "$at_depth" "$info" "$prune" "$ign_double"   # Potentially add if not done yet
}

: <<=cut
=func_frm
Executes a manual step. This can be done in 2 ways:
=le A direct manual step (default). This is done by showing the message which 
    should contain enough information to execute the manual step. It then wait on 
    a <ENTER> key before continue. The uses should not close this window!
=le A later manual step (later). The message will be stored to be shown later on.
=func_note
This function is reused for backwards compatibility. The only risk would be
that if a new code with later is called into an older automate version
(not having later) then it will show it as a direct manual steps which is a 
explainable problem. On could use log_manual directly in case its availability
is known.
=cut
function manual_step() {
    local message="$1"      # (M) The message to show.
    local later_head="$2"   # (O) The message is stored to be shown later, this is the short header

    if [ "$later_head" != '' ]; then
        log_manual "$later_head" "$message"
        return
    fi
    interrupt_step $STAT_wait
    log_screen "========== Manual step requested ============"
    log_screen "$message"
    log_screen "============================================="
    log_screen "Please execute manual step above."
    log_screen "When done press 'Enter' to continue."
    recalc_step_info
    if [ "$FLG_cons_enabled" != '0' ]; then
        # A console cannot enter something so wait 30 sec before exit
        log_info "$AUT_step_info - Running in console mode, interrupting execution"
        log_exit "$AUT_step_info - Stopping executing, continue when ready"
    else
        log_info "$AUT_step_info - Waiting for manual step to be finished."
        fflush_stdin
        read -s
        log_info "$AUT_step_info - Continuing after manual step was executed."
    fi
    continue_step
}


