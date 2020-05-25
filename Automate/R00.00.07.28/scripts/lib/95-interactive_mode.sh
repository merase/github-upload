#!/bin/sh

: <<=cut
=script
This script handles the interactive mode functionality of automate. This to
offload the code in the tool and allow for easy extensions. It is also build
this way to allow subs scripting (if needed)
=version    $Id: 95-interactive_mode.sh,v 1.14 2017/12/13 14:14:55 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly iact_lvl_user='user'
readonly iact_lvl_expert='expert'

: <<=cut
=func_int
Catches the ctrl+c signal and nicely stop. In stead of closing the main shell
as well.
=cut
function catch_iact_ctrlc() {
    local ret=$STAT_partial

    stop_inprogress_ind
    print_status "$ret"
    log_screen "Command has been interrupted by pressing Ctrl+C"
}

: <<=cut
=func_int
Handle a given command. This function does not read the command itself, which
allows it to be both called interactively as well as by automate main stream
if needed. Which direct safes double code in some cases. The option of the 
interactive mode and command line are not fully in line (yet). The interactive
mode will always have more complex features.
=stdout
The output to print on the log_screen
=cut
function handle_iact_cmd() {
    local line="$1"     # (O) The command to execute, empty is allowed and will not doe anything
    local exit="$2"     # (O) if set then the code use in some erro cases log_exit iso log_screen

    local spec_log=log_screen           # 
    [ "$exit" != '' ] && spec_log=log_exit

    [ $FLG_interactive != 0 ] && trap catch_iact_ctrlc INT

    # Handle expert commands (if allowed)
    local handled=1
    if [ "$STR_iact_mode" == "$iact_lvl_expert" ]; then
        case "$line" in
            help|'?')
                log_screen "Interactive expert mode commands. ${COL_bold}Use with great care:$COL_def
    * [no]debug                 : Enables or disables debugging
    * env [pfx]                 : Give a list of all global environment variables. Use prefix to filter.
    * set var='<val>'           : Set a specific global var, does not work for read only values.
    * flist [pfx]               : Give a list of all functions. Allows first characters as prefix filter.
    * ifunc [ent] <name> [pars] : Will execute the given internal function with parameters (within subshell, means vars will not be passed).
    * lfunc [ent] <name> [pars] : Same as ifunc but called in local shell, means vars can be passed, but log_exit is exit.
    * func  <name> [pars]       : Will execute the given script function (so a script 
                                  located in the funcs directory) with parameters."
                handled=0
                ;;

            debug  ) FLG_dbg_enabled=1; FLG_dbg_par=''; ;; # All
            nodebug) FLG_dbg_enabled=0                ; ;;

            env*)
                if [ ${#line} == 3 ] || [ ${#line} == 4 -a "${line:3:1}" == ' ' ]; then
                    log_screen "$(declare -p | cut -d ' ' -f 2-)"
                else
                    log_screen "$(declare -p | cut -d ' ' -f 2- | grep "^[^ ]* ${line:4}")"
                fi
                ;;

            'set '*)
                local var=$(get_field 1 "${line:4}" '=')
                local val="$(get_field 2- "${line:4}" '=' | sed -e 's/^"//' -e 's/" *$//' -e "s/^'//" -e "s/' *\$//")"
                if [ "${!var}" != '' ]; then
                    log_screen "Current value: $(declare -p $var | cut -d ' ' -f 2-)"
                else
                    log_screen "No current value for '$var'"
                fi
                if [ "$var" == '' -o "$val" == '' ]; then
                    log_screen "Wrong set, use set var='<val>'"
                else
                    export $var="$val"
                    log_screen "New value: $(declare -p $var | cut -d ' ' -f 2-)"
                fi
                ;;

            flist*)
                if [ ${#line} == 5 ] || [ ${#line} == 6 -a "${line:5:1}" == ' ' ]; then
                    log_screen "$(declare -F | cut -d ' ' -f 3-)"
                else
                    log_screen "$(declare -F | cut -d ' ' -f 3- | grep "^${line:6}")"
                fi
                ;;

            'ifunc '*|'lfunc '*)            # Difference in shell handled by caller
                ${line:6}                   # Execute as internal function (strip cmd)
                log_screen "[\$?=$?] " 'n'  # Show actual return code
                ;;   

            'func '*) 
                func ${line:5}              # Execute as func script could have stated line, this is clearer
                log_screen "[#=$?] " 'n'    # The return code is the amount of processed scripts
                ;;
            *)  handled=0; ;;
        esac
    else
        handled=0       # Still need to handle user mode
    fi

    # Handle the user commands (if not handked yet)
    if [ $handled == 0 ]; then
        case $line in
            help|'?')
                log_screen "Interactive user mode commands. The following inputs are accepted:
 -- Step related commands
    * <number>     : A step number, referring to a current step, use 'list' to show active steps.
    * <full step>  : A full step name (mind use of _) including parameters (separated by space)
    * exec <steps> : Set steps to execute comma separated. Use * for all. Or a single range using #..#
    * next | n     : Execute the following step in the current sequence.
    * skip         : Skip the next step but do not execute.
    * cont         : Continue execution until something fails.
    * list         : Will show all current steps, including numbers.
    * brief        : Will show all current steps, including numbers and brief info (if available).
    * doc <step>   : Will document a step             
 -- Commands similar to automate --<cmd> see automate --help for more help)
    * analyze      : Will execute the pre-check impact step but only showing stuff
    * finish       : Finishes automate run nicely and make sure it is dormant.
    * fxfer        : Will execute the verify File-Transfer step.
    * if_usr       : Checks/creates interface user.
    * ssh          : Will execute the check SSH step.
 -- Other useful commands
    * help | ?     : Will show this help
    * pkgs         : Will show the current package information. 
    * rstep <file> : Reads a new given steps filed (experimental)
    * rdata <file> : Reads a new given data file. This will re-read the current steps file as well.
    * exit | quit  : Exit interactive mode"
                ;;
            next|n) execute_all_steps 1             ; ;;  # only one.
            cont  ) execute_all_steps               ; ;;
            skip  )
                if [ "$STR_exec_steps" != '' ]; then
                    local step_skipped="$(echo -n "$STR_exec_steps" | cut -d',' -f 1)"
                    STR_exec_steps="$(echo -n "$STR_exec_steps" | cut -d',' -f 2-)"
                    log_screen "Skipped current step ($step_skipped)"
                fi
                ;;
            list  ) show_steps_to_execute           ; ;;
            brief ) show_steps_to_execute '' 'brief'; ;;
            pkgs  ) show_installable_pkg            ; ;;
            'doc '*) help_on_step "${line:4}"       ; ;;
            'exec '*)
                local err=0
                local par="${line:5}"
                if [ "$par" == '*' ]; then
                    log_screen "== Steps are reset to start from beginning"
                    func store_boot_data clean      # clean all store file to be sure.
                    clear_special_logs              # this is seen as a new start of a run
                    reset_store_vars
                    local until=${#AUT_step[@]}
                    ((until--))
                    [ $until -ge 1 ] && STR_exec_steps="$(seq -s',' 1 $until)" || STR_exec_steps='*'
                    [ $FLG_interactive != 0 -a "$STR_exec_steps" == '*' ] && STR_exec_steps=''
                elif [ "$(echo -n "$par" | grep '\.\.')" != '' ]; then  # Given range
                    local from="$( get_field 1 "$par" '.' | $CMD_ogrep '[0-9]+')"
                    local until="$(get_field 3 "$par" '.' | $CMD_ogrep '[0-9]+')"
                    if [ "$from" == '' -o "$until" == '' ]; then
                        $spec_log "Wrong range given (#..#) for exec parameter ($par)"
                    else
                        STR_exec_steps="$(seq -s',' $from $until)"
                    fi
                elif [ "$(echo -n "${line:5}" |  egrep -o '^((u|)[0-9]{1,3})(,(u|)[0-9]{1,3})*$')" == '' ]; then
                    $spec_log "Wrong exec parameter ($par). Use only x (u)[0-999] separated by comma."
                else
                    STR_exec_steps="$par"
                    log_screen "== Steps has been manually set to: '$(get_compact_seq "$par")'"
                fi
                reset_state_data    # Always reset even in input failure!
                ;;

            analyze) execute_step 0  'precheck_impact show'               ; ;;
            ssh    ) execute_step 0  'check_SSH-Peers'                    ; ;;
            fxfer  ) execute_step 0  'verify_File-Transfer TextPass start'; ;;

            if_usr)
                MGR_init_shell
                if [ "$hw_node" == "$dd_oam_master" ]; then
                    log_screen "== Successfully checked (created if needed) interface manager user."
                else
                    log_screen "== Successfully checked interface manager user."
                fi
                ;;
            finish)                # format finish step nicely.
                log_screen '== Forcibly finishing pending steps upon request.'
                log_screen "$LOG_isep"
                execute_step 0 "$STEP_finish_automate"
                log_screen "$LOG_isep"
                log_screen "== $AUT_exec_name will stay dormant upon next start/reboot."
                log_screen "$LOG_sep"
                ;;
                
            'rdata '*)
                STR_data_file="${line:6}"
                read_data_file $STR_data_file
                read_step_file $STR_step_file
                ;;

            'rstep '*)
                STR_step_file="${line:6}"
                read_step_file $STR_step_file
                ;;
            'mode '*)                 # change interactive mode, not in help on purpose !
                case "${line:5}" in
                    $iact_lvl_user|$iact_lvl_expert)
                        STR_iact_mode="${line:5}"
                        log_screen "Changing Interactive Mode into '$STR_iact_mode'."
                        ;;
                    *)  log_screen "Unknown mode given, please use proper mode."
                        ;;
                esac
                # Auto switch on keep_tmp in expert mode, never switch off
                [ "$STR_iact_mode" == "$iact_lvl_export" ] && FLG_keep_tmp=1 
                ;;
            exit|quit) : ;;  # handled by higher caller due to subshell needs.
            '' )  : ;;  # Read again.
            *) 
                translate_into_single_step "$line" 'info'
                if [ "$translated_step" != '' ]; then
                    execute_step "$step_num" "$translated_step" '' 'opt'
                fi
                ;;
        esac
    fi

    [ $FLG_interactive != 0 ] && trap - INT

    # In case of interactive mode always write just as easy (because of subshell passing data)
    [ $FLG_interactive != 0 ] && store_current_state 
}

: <<=cut
=func_int
Common funciton to print the used prompt.
=cut
function print_iact_prompt() {
    [ "$STR_exec_steps" != '' ] && log_screen "exec:$(get_compact_seq "$STR_exec_steps") " 'n'
    log_screen 'cmd> ' 'n'
}

: <<=cut
=func_ext
Little wrapper around handle_iact_cmd to call it and exit with an code 0
This is called in local context so log_exit calle will exit as well.
=cut
function handle_cmd_and_exit() {
    local line="$1" # (M) The full command (line) to handle
    local exit_code="$2"    # (O) The optional exit code to use, defualts to 0

    exit_code=${exit_code:-0}
    handle_iact_cmd "$line" exit_on_error
    exit $exit_code
}
: <<=cut
=func_ext
Handles interactive mode
=cut
function handle_interactive_mode() {
    local mode="$1"     # (O) The interactive mode, if empty then it will be user mode

    STR_iact_mode=${mode:-$iact_lvl_user}
    # Auto switch on keep_tmp in expert mode, never switch off
    [ "$STR_iact_mode" == "$iact_lvl_expert" ] && FLG_keep_tmp=1     

    # Disable special exec steps.
    [ "$STR_exec_steps" == '?' ] && STR_exec_steps=''
    [ "$STR_exec_steps" == '*' ] && handle_iact_cmd 'exec *'

    store_current_state

    log_screen "Please enter a full step name or number (or use 'help')"
    log_screen $LOG_isep
    print_iact_prompt
    IFS=''; while read line; do IFS=$def_IFS
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


        # Handle some statement her due there specific needs
        case "$line" in
            exit|quit) break                   ; ;; # Exit here and now
            'rstep '*|'rdata '*|'func '*|'lfunc '*|'set '*|debug|nodebug) 
                handle_iact_cmd "$line" 1>&2        # Set 'local' variables
                ;;
            *)
                if [ "$STR_iact_mode" == "$iact_lvl_expert" ]; then # In expert mode protect, which give some definition problems, but easier testing
                    trap '' INT                     # Ignore standard Ctrl+C in interactive mode
                    `handle_iact_cmd "$line" 1>&2`  # Execute in sb shel to simply cath in current way.
                    trap - INT                      # Reset ctrl to react on it
                else
                    handle_iact_cmd "$line" 1>&2        # Set 'local' variables
                fi
                ;;
        esac
        read_current_state              # Make sure sub process changes are reflected.
        print_iact_prompt
    IFS=''; done < /dev/stdin; IFS=$def_IFS
}