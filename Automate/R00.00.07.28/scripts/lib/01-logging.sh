#!/bin/sh

: <<=cut
=script
This script contains the logging/debugging functionality
=version    $Id: 01-logging.sh,v 1.33 2017/06/08 11:45:10 fkok Exp $
=author     Frank.Kok@newnet.com
=script_note
Use: >> $LOG_file 2>&1 to redirect output if needed!
=feat screen-copy to file
Screen information is also written in the file '<logdir>Screen-Copy.log' This
can be used to show the progress remotely. The file has a 9 previous copies to 
allow historical searches.

=feat monitor progress of several machines in parallel
A separate monitor (part of distribution) allows to monitor the most recent
Screen-Log from multiple host in parallel (split screen).

=feat script calling mode
The user can enable a so called log caller mode, which will show the scripts
being called for each framework step and function. This are not internal 
function call. Only calls the separate steps/func scripts. It will give more
information what it is doing and where things might need to be adapted.

=feat extra information logs
Beside the use output, extra information will we written to the <lodir>AUT_*.log'
file. Which will show all the commands being executed and its output. This log
file should only be used in case something went wrong and more information is 
required.

=feat extensive developer output
A more extensive developer debug is available when run in debug mode. This puts
all output to the screen and should only used by development.
=cut

#
# globalvariables
#
readonly LOG_screen_cpy="$logdir/Screen-Copy.log"
readonly LOG_manual_cpy="$logdir/Manual-Things-Todo.log"
readonly LOG_warn_cpy="$logdir/Warnings.log"
readonly LOG_log_cpy="$logdir/Current-Logfile.log"      # Will be a link to current one
readonly LOG_help_cpy="$logdir/Document-Failed-Step.log"
readonly LOG_dump_env="$logdir/.Dumped-Environment.log" # For developer use 'hidden'

          LOG_file="$(mktemp)"   # Temp log file until official name is set
          LOG_cmds="$(mktemp)"   # Temp cmd file until officla name is set
      LOG_prv_cmds="$(mktemp)"   # Temp previous cmd file until officla name is set
         LOG_saved=''            # Will be the saved log information.
LOG_last_manu_step=''
LOG_last_warn_step=''
  LOG_help_on_fail=0             # To prevent double calls.
readonly LOG_space='                                                                                '
readonly   LOG_sep='================================================================================'
readonly  LOG_isep='--------------------------------------------------------------------------------'
readonly  LOG_wsep='== WARNING ==== WARNING ==== WARNING ==== WARNING ==== WARNING ==== WARNING ===='
readonly LOG_screen_width=80        # Simple assumption for now

[ $FLG_interactive == 0 ] && readonly LOG_wait_int='the installation process' ||
                             readonly LOG_wait_int='this step'
readonly LOG_wait_msg="* Use <ENTER> to continue directly or;
* Wait until time elapsed, the process then continues or;
* Press ctrl+c to interrupt $LOG_wait_int."
readonly LOG_warn_msg="* Use <ENTER> to interrupt the process or;
* Wait and accept the warning."

# Usede for generating nice output
readonly LOG_bss='\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b'
readonly LOG_sps="                              "

: <<=cut
=func_int
Rotate the number extension of a specific file (keep max 9 + 1 new). 
The rotate is only executed if the given file exists.
<file>.9 is lost
<file>.8 -> <file>.9
<file>.7 -> <file>.8
etc
<file> -> <file>1
=cut
function rotate_files() {
    local file="$1"    # (M) The local/full fill to rotate (no number extension)
    local num="$2"     # (M) the amount of copies, default to 9
    
    num=${num:-9}
    
    [ -z help ] && show_trans=0 && show_short="Rotating '$file', keep $num versions"

    # Rotate screen copy files max 10
    if [ "$file" != '' ] && [ -e "$file" ]; then
        local i=$num
        while [ "$i" -gt '1' ]; do
            local dst="$file.$i"
            ((i--))
            local src="$file.$i"
            if [ -e $src ]; then
                /bin/mv $src $dst
            fi
        done
        /bin/mv $file $file.1
    fi
}

rotate_files "$LOG_screen_cpy" 100 # Rotate screen copy files then make new
echo -e "$LOG_sep\nScreen-Copy started on: "`date`"\n$LOG_sep" > $LOG_screen_cpy
if [ -r "$LOG_dump_env" ]; then  rm "$LOG_dump_env"  > /dev/null; fi    

: <<=cut
=func_int
Retrieves a data which is used for internal debug logging. 
It includes the micro seconds.
=set log_date
The date format in [YYYY-MM-DD hh:mm:ss.uuuuuu]
=cut
function set_log_date() {
    if [ $FLG_dbg_enabled == 0 ]; then
        log_date=`date "+%F %T.%N" | sed 's/........$//'`
    else
        log_date=`date "+%T.%N" | sed 's/......$//'`
    fi
    log_date="[$log_date]"
}

: <<=cut
=func_int
This function logs the current call-frame using the B<log_info> unction.
This is normally called when an unexpected exit is requested.
=cut
function log_callers() {
    local frame=0
    local info

    log_info "=========================== Current Call Flow =================================="
    ninfo=`printf "line %-20s location" "function"`
    log_info "$ninfo"
    log_info $LOG_isep
    info=`caller $frame`
    while [ "$?" == "0" ]; do
        ninfo=`printf "%4d %-20s %s" $info`
        log_info "$ninfo"
        ((frame++))
        info=`caller $frame`
    done
    log_info $LOG_sep
}

: <<=cut
=func_int
Finds the linenr in the stack frame of a specific file.
=stdour
The found line nr
=cut
function find_linenr_from_stack() {
    local file="$1" # (M) The file to searhc for
    
    [ "$file" == '' ] && return
    
    local frame=0
    local info
    info=`caller $frame`
    while [ "$?" == "0" ]; do
        if [ "$(get_field 3 "$info")" == "$file" ]; then
            get_field 1 "$info"
            return
        fi
        ((frame++))
        info=`caller $frame`
    done
}

: <<=cut
=func_ext
Clear the special log files (manual/warning). If there is a current file then it 
rotates the current one away. If there not file then is stays as it was.
=cut
function clear_special_logs() {
    rotate_files "$LOG_manual_cpy"  # will rotate when needed
    rotate_files "$LOG_warn_cpy"    # will rotate when needed
    LOG_last_manu_step=''
    LOG_last_warn_step=''
}

: <<=cut
=func_ext
A tricky way to flush the stdin before reading it. Which is needed
in case of wait on a key press.
=cut
function fflush_stdin() {
    local dummy=''
    local originalSettings=`stty -g`

    stty -icanon min 0 time 0
    while read dummy ; do : ; done
    stty "$originalSettings"
}

: <<=cut
=func_ext
Set a new log file. It will move the old logfile to the new name.
Normally this should be done once. This is done to be able to log before 
the additional info (e.g.section) is known.
Returns 0 in case of succes. Other 
=cut
function set_log_file() {
    local add_info="$1"     # (M) The additional info in the name, eg. the section name

    # Do not use %T which has ':' in it this gives problems with USB/FAT32 copies.
    local old="$LOG_file"
    LOG_file="$logdir/AUT_${add_info}_"`date +%F_%H%M%S`".log"
    # In this case I cannot use the standard cmd handling as log file is moving
    $CMD_mv "$old" "$LOG_file"
    check_success "Move temp log ($old) to new ($LOG_file)" "$?"  
    $CMD_ln -f "$LOG_file" "$LOG_log_cpy"       # ignore if failed

    LOG_cmds="$logdir/Last-Command.log"
    LOG_prv_cmds="$logdir/Previous-Command.log"
    echo -n '' > $LOG_cmds
    echo -n '' > $LOG_prv_cmds
}

: <<=cut
=func_frm
Saves all available log into a tgz file. This can be called upon failure
exit (by log_exit) or in case of normal request. The save should be used
in case of investigating a problem in the automate run.
The default of logging info upon failure can be disabled in the data-customer
file (savelog_on_fail)
=cut
function save_available_logs() {
    local requester="$1"    # (M) The requester e.g. [user|internal].

    requester=${requester:-unknown}

    # Decide on the name
    LOG_saved="$logdir/LOG_${requester}_"`date +%F_%H%M%S`".tgz"

    # Do not use the backup module but a more straight forward approach
    # yes it will get all. it is mainly ascii and zip pretty good.
    # Use a local command and not cmd() not to disturb current state.
     files="${LOG_screen_cpy}*"   # All screen copy logs
    files+=" ${LOG_manual_cpy}*"  # All Manual step logs
    files+=" ${LOG_warn_cpy}*"    # All warning logs"
    files+=" ${logdir}/AUT_*"     # All more in-depth logs
    files+=" $LOG_cmds"           # Current cmd
    files+=" $LOG_prv_cmds"       # Previous cmd
    files+=" $LOG_dump_env"       # A potential environment dump
    files+=" $STR_data_file"      # The currently used data file
    files+=" $STR_step_file"      # The currently used step file
    files+=" $AUT_store_file"     # The storage file with internal states.
    files+=" $MAP_dir/*"          # All automate MAP data
    files+=" $SHM_cur_sect/*"     # Current section info.
    log_info "Saving available log into '$LOG_saved"
    $CMD_mktgz $LOG_saved --ignore-failed-read $files > /dev/null 2>&1
    outcome=$?
    # Remark the below won;t be in the saved tar file ;-)
    log_info "Outcome (\$? = $outcome): save_avialable_logs"

    return $outcome
}

: <<=cut
=func_frm
This function should only by used when calling an external step of func script.
Or very particular info is to be shown (not a warning)
It is specifically uses to show the user which scripts are being called. So that
they can easily be found. it requires a command line option to enable the 
logging.
=optx
Any other parameter to be logged.
=cut
function log_screen_info() {
    local script="$1"   # (O) If given then then this is an assumed a script call. 'no_newline' is a special directive. Otherwise plain info

    local calling=''
    local no_newline=''
    
    if [ "$script" == 'no_newline' ]; then
        no_newline='n';
        script=''
    elif [ "$script" != '' ]; then
        calling="Calling: $script "
    fi

    shift 1
    if [ $FLG_dbg_enabled != 0 ]; then
        log_debug "$calling$*"          # If debug debug output
    elif [ $FLG_call_enabled != 0 -o "$script" == '' ]; then
        if [ "$AUT_step_interrupted" == '0' ]; then
            interrupt_step $STAT_info   # The step will auto continue done in case more info follow
        fi
        log_screen "$calling$*" "$no_newline"
    fi
}

: <<=cut
=func_frm
Function to log additional debugging info. The info does not go to the log file
but is given on the screen (stderr). Normally this should only be used to allow 
debugging the scripts.
=func_note
The 'get_substr' is implemented locally, for speed and to prevent dependency problems.
=man1 msg
The additional message for debugging
=cut
readonly sed_rep='\\\/'
readonly sed_sdir=`echo "$scriptdir/" | sed "s/\//$sed_rep/g"`     # A make sed safe dir
function log_debug() {
    # Remark this function does not use local msg="$1" # (M) The additional message for debugging
    # this t prevent processing which is not needed in  a normal no debug run!

    [ $FLG_dbg_enabled == 0 ] && return   # fast bailout

    local cur_mod='entry'           # Currently modules are not supported so always set as entry

    local debug=0       
    if [ "$FLG_dbg_step" != '' -a "$AUT_cur_step" != '' ]; then                                  # Step was requested
       [ "$(echo -n "$FLG_dbg_step" | grep -E "(^|,)$AUT_cur_step(,|\$)")" != '' ] && debug=1    # In requested steps so enable
    else
       [ "$AUT_cur_step" != '' ] && debug=1                                                                               # No step so enable
    fi
    [ "$FLG_dbg_mod"  != '' -a "$(echo -n "$FLG_dbg_mod" | grep -E "(^|,)$cur_mod(,|\$)")" == '' ] && debug=0 # However mod requested and not set, so disable

    # Filter if the message should be displayed.
    if [ $debug != 0  ]; then
        # Do some filter to get lines smaller and more readble
        # Filters script dir and main install dir
        local msg="$(echo "$1" | sed -e "s|$scriptdir|<scripts>|g" -e "s|$installdir|<install>|g" -e "s|$pkgdir|<pkg>|g")"

        local info=`caller 0`
        local call=''
        if [ "$info" != '' ]; then
            local line=`echo "$info" | cut -d' ' -f 1`
            local func=`echo "$info" | cut -d' ' -f 2`
            local file=`echo "$info" | cut -d' ' -f 3 | sed "s/$sed_sdir//"`
            call=`printf "<- %-15s (%s:%s)" $func $file $line`
        fi
        local debug=`printf "%-130s" "$msg"`
        set_log_date
        echo "$log_date $debug$call" 1>&2   # To stderr not to conflict with stoudout bash operations
    fi
}

: <<=cut
=func_frm
Print a string to the screen. If logging is enabled it will also be send
to the B<log_info> function. This function normally interprets the '\' from
the strings.
=man1 str
The string log to the screen.
=opt2 echo_par
Optional echo parameter without the - e.g. 'n' would disable newline
=cut
function log_screen() {
    if [ $FLG_log_to_stderr != 0 ]; then
        echo "-e$2" "$1" 1>&2
    fi
    if [ $FLG_cons_enabled == 0 -a $FLG_log_to_stderr == 0 ]; then
        echo "-e$2" "$1"
    else
        # Since RH 60 the console and virtual console are the same during boot so only send to one
        if [ "$OS" != "$OS_linux" ] || [ $OS_ver_numb -lt 60 ]; then  
            echo "-e$2" "$1" > /dev/tty0        # The virtual console
        fi
        if [ $FLG_kern_enabled == 0 -o "$2" == 'n' ]; then
            echo "-e$2" "$1" > /dev/console     # The real console
        else
            # An attempt to warokaround the layout in case of runlevel 1. By adding an extra cr
            # It is not ideal and other service are suffering from the same
            echo "-e$2" "$1\r" > /dev/console     # The real console
        fi
    fi
    echo "-e$2" "$1" >> $LOG_screen_cpy                 # Always write in the screen copy file
}

: <<=cut
=func_frm
Print string to screen but it will first backspace a couple of
characters. While doing that it makes sure the given length is also cleared.
The text should not be to long (related to LOG_bss and LOG_sps but it not 
checked
=cut
declare LOG_bs_len=0
function log_screen_bs() {
    local type="$1" # (O) The type, init, bs, add, end
    local text="$2" # (O) The text to print
    
    local len=$LOG_bs_len   # get previous len
    LOG_bs_len=0            # assume zero
    case $type in
        init)   # Intializes the counter, still able to print header text
            log_screen "$text" 'n'  # allowed for empty text as well
            ;;
        bs|end)     # Start or end a new bs text, the previous is whiped out and backspaced
            local newl=''
            if [ $type == 'bs' ]; then
                newl='n'
                LOG_bs_len=${#text}
            fi
            log_screen "${LOG_bss:0:$((len*2))}${LOG_sps:0:$len}${LOG_bss:0:$((len*2))}$text" "$newl"
            ;;
        add)    # Add a text to the line to be backspaced
            log_screen "$text" 'n'
            LOG_bs_len=$((len + ${#text}))
            ;;
        *)  log_exit "Incorrect bs type given '$type'"; ;;
    esac
}

: <<=cut
=func_frm
Use this log function if info should be logged in the log file of the
installation. If debugging is enabled then it is logged to the screen
otherwise it will be stored the F<$LOG_file> file
=cut
function log_info() {
    local inf="$1"      # (M) The info message to log
    local eopt="$2"     # (O) Echo option. e.g. -e

    if [ $FLG_dbg_enabled != 0 ]; then
        log_debug "$1"          # If debug debug output
    elif [ $FLG_log_enabled != 0 ]; then
        set_log_date
        echo $eopt "$log_date $1" >> $LOG_file
    fi
}

: <<=cut
=func_frm
Use this function to log a manual action which is to be shown and executed later.
The header will be show directly to give it some more attention.
If you want something to be done directly then use the function manual_step
=cut
function log_manual() {
    local header="$1"   # (O) The header t show, leave empty if nothing besides status to be shown
    local message="$2"  # (M) The (formatted) message to store for later showing. Do not use '##|' at front of line

    [ "$LOG_manuals" == '' ] && LOG_manuals=0
    ((LOG_manuals++))

    log_info "Manual: $header$nl$message"       # Regular log file

    # To manual file, add header if first of this (sub)step.
    if [ "$LOG_manuals" == '1' ]; then
        if [ "$LOG_last_manu_step" != "${AUT_step_line[0]}" ]; then # Print the main step for additional info
            [ "$LOG_last_manu_step" == '' ] && echo "$LOG_isep" >> $LOG_manual_cpy
            LOG_last_manu_step="${AUT_step_line[0]}"
            if [ $STR_step_depth != 1 ]; then  # The main step could be the warning step, do not print then
                echo "$LOG_last_manu_step" >> $LOG_manual_cpy
            fi
        fi
        # Skip higher sub steps
        echo "$COL_warn${AUT_step_line[$((STR_step_depth - 1))]}$COL_def" >> $LOG_manual_cpy
    fi

    if [ "$header" != '' ]; then
        echo "$LOG_manuals) $header" >> $LOG_manual_cpy
        echo "$message" >> $LOG_manual_cpy

        # Add a later step message (not the info it self) as a notification
        interrupt_step $STAT_later
        log_screen "Please ${COL_warn}notice$COL_def new manual task added: $header"
        continue_step
    else
        echo "$LOG_manuals) $message" >> $LOG_manual_cpy
    fi
}

: <<=cut
=func_frm
Use this function to log a warning. Depending on the flags the logs
can be ignored or results in errors (tbd).
=set LOG_warnings
Will be increased if a warning was given. Which can be used later to decide
something went wrong. This does mean it has to be cleared ('') before starting
a step for example.
=cut
function log_warning() {
    local inf="$1"    # (M) The info message to log
    local slp="$2"    # (O) Optional time to wait before continuing
    
    [ "$LOG_warnings" == '' ] && LOG_warnings=0
    ((LOG_warnings++))

    log_info "$inf"    # Regular log file

    # To warnings file, add header if first of this (sub)step.
    if [ "$LOG_warnings" == '1' ]; then
        if [ "$LOG_last_warn_step" != "${AUT_step_line[0]}" ]; then # Print the main step for additional info
            LOG_last_warn_step="${AUT_step_line[0]}"
            if [ $STR_step_depth != 1 ]; then  # The main step could be the warning step, do not print then
                echo "$LOG_last_warn_step" >> $LOG_warn_cpy
            fi
        fi
        # Skip higher sub steps
        echo "$COL_warn${AUT_step_line[$((STR_step_depth - 1))]}$COL_def" >> $LOG_warn_cpy
    fi
    echo "$LOG_warnings| $inf" >> $LOG_warn_cpy

    # for now use log_screen and log_info no action yet, step need to be interrupted
    interrupt_step $STAT_warning
    log_screen "$COL_warn$LOG_wsep$COL_def"
    log_screen "$inf"
    wait_time_interuptable "$slp" "$LOG_warn_msg"
    if [ $? != 0 ]; then
        continue_step
        log_exit "<ENTER> is pressed, step is canceled by user!"
    fi 
    log_screen "$LOG_sep"
    continue_step
}

: <<=cut
=func_frm
Logs a message to the screen and waits for a specific period before 
continuing. This is slightly different than log_warning as this is intended
behavior. Could be used for example before rebooting and/or shutdown.
=ret
The amount of (potential lines) written
=cut
function log_wait() {
    local inf="$1"     # (M) The info message to log
    local slp="$2"     # (O) Optional time to wait before continuing. If not set default is 10 sec.
    local overlay="$3" # (O) If given then it will overlay this x amount of lines
    
    slp=${slp:-10}

    # for now use log_screen and log_info no action yet, steep need to be interupted
    log_info "$inf"
    interrupt_step $STAT_wait

    local n=$([ $STR_wait_overlay == 1 ] && echo "$overlay")
    n=$([ "$(tput cols)" -ge 80 ] && echo "$n")     # Disable if less then 80, which was our assumption
    if [ "$n" != '' ]; then
        log_screen "\033[${overlay}A" n
        while [ $n != 0 ]; do
            log_screen "$LOG_space"
            ((n--))
        done
        log_screen "\033[${overlay}A" n
    fi
    n=$([ $FLG_cons_enabled == 0 ] && echo 8 || echo  5)  # No console 3 extra lines of LOG_wait_msg
    log_screen "$LOG_sep"
    IFS=$nl
    local line
    for line in $inf; do
        log_screen "$line"
        ((n++))
    done
    IFS=$def_IFS
    log_screen "$LOG_isep"
    wait_time_interuptable "$slp" "$LOG_wait_msg"
    log_screen "$LOG_sep"
    continue_step

    return $n
}

: <<=cut
=func_frm
To be called whenever a permanent failure occurred. It will clear the step
information, log the message to screen and log file. Explain where the process
should continue.
=cut
function log_exit() {
    local msg="$1"  # (M) The failure message to show

    if [ "$STR_step_depth" != '' ] && [ "$STR_step_depth" -gt '0' ]; then
        finish_step $STAT_failed info       # Use info as we want to show the first error to the screen
    fi

    FLG_log_to_stderr=1         # Enable stderr in case we were in a shell command capturing stdout!
    if [ $FLG_log_enabled != 0 ]; then
        log_info "$msg"
        log_callers
        log_info "Failed in step $AUT_cur_step"
        set > $LOG_dump_env     # Always dump current environment in 'hidden' for for development
    fi
    
    
    log_screen ""
    log_screen $LOG_sep
    log_screen "$msg"
    log_screen ""
    if [ $FLG_interactive == 0 ]; then
        log_screen "The installation process stopped, investigate problems."
        log_screen "Please continue at step $AUT_cur_step"
    else
        log_screen "This installation step stopped, investigate problems."
        log_screen "Please continue when fixed."
    fi
    log_screen $LOG_sep

    if [ $FLG_help_on_fail != 0 -a $LOG_help_on_fail == 0 ]; then
        LOG_help_on_fail=1          # Prevent accidental recursive. On help per invocation!
        local step_info="$(get_field 1 "${STR_step_cmd[$STR_step_depth]}")"
        if [ "$step_info" != '' ]; then
            rotate_files "$LOG_help_cpy" 25
            echo "A failure occurred, showing documented version of failed step." > $LOG_help_cpy
            cat $LOG_screen_cpy >> $LOG_help_cpy
            help_on_step "$step_info" 'sup' "$(find_linenr_from_stack "$AUT_cur_script")" >> $LOG_help_cpy

            log_screen "Failed step documented in: $LOG_help_cpy"
            log_screen "You can use: aut_log_help -c fail"
            log_screen $LOG_sep
        fi  # else do not show anything, it was not helpful
    fi
    
    if [ "$STR_savelogs_onfail" == '0' ]; then
        log_info "Skipping to save any log info upon request."
    else
        log_screen "Saving logs for later analysis ..."
        save_available_logs 'internal'
        if [ $? != 0 ]; then
            log_screen "Failed to save log info into ' $LOG_saved'"
        else
            log_screen "Logs saved in '$LOG_saved'"
        fi
    fi
    log_screen $LOG_sep

    if [ $FLG_cons_enabled == 1 ]; then    # Wait some time if console enabled this because output could be cleared directly
        wait_time 30 "before exiting the automation tool."
        log_screen "Exiting the automation tool.                                        "
    fi

    if [ $FLG_interactive == 0 ]; then
        FLG_keep_tmp=1      # Keep MAP data for analyzing if needed.
        kill -15 $$         # Make sure we are also kill in case running in a $( ) command
        exit $AUT_cur_step
    fi

    # The interactive has an exception it does not kill the parent and returns
    exit $STAT_failed
}

: <<=cut
=func_frm
Almost same behavior as log_exit, though it indirectly states this is
an unexpected state or something like that. Thus most likely to be a 
programming error.
=func_note
This function was introduced later, so it is not always in use. It should never
be used for error which can be caused by users, configuration and/or unexpected
system state. Only for programming error.

The function is introduced to show the future coder the difference between error
and to stream line coding error. In the future advanced debugging can be added.

A coding error should never be ignore as it mean som pre-condition for the rest
of the program are not met and might/will/should cause problems if continued.
=cut
function prg_err() {
    local msg="$1"  # (M) The failure message to show

    # For now call log_exit with some extra text, this might change in the future
    log_exit "Error in program state, contact Development$nl$LOG_isep$nl$msg"
}
