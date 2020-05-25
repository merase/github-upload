#!/bin/sh

: <<=cut
=script
This script contains helper for wait routines.
=version    $Id: 01-waiting.sh,v 1.11 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com

=feat wait for actions to pass
Framework functions are available to wait on a manual action or wait on e.g.
othe nodes states to change before a step is passed. By given proper exit 
criteria it will continue once these are met.
=cut

#
# globalvariables
#
WAIT_pass_request=''  # Used to transfer a wait request with info. If empty then finsished.
WAIT_sleep_time=''    # Will hold the next sleep time, can be adapted once, reset before call to given defualt

: <<=cut
=func_frm
Waits for a certain period before continuing
=cut
function wait_time() {
    local slp="$1"  # (O) The time to wait, defualt is 30
    local str="$2"  # (O) The string to give after 'Waiting .. more seconds ', defaults to '...'
    
    slp=${slp:-30}
    str=${str:-'...'}

    [ -z help ] && show_trans=0 && show_short="Wait for $slp seconds."
    
    while [ "$slp" -gt '0' ]; do
        log_screen "Waiting $slp more seconds $str \r" 'n'
        sleep 1
        ((slp--))
    done
}

: <<=cut
=func_int
Catches the ctrl+c signal durng read call and nicely exits. In stead of closing 
the main shell as well.
=cut
function catch_read_ctrlc() {
    log_screen "Waiting has been interrupted by pressing Ctrl+C"
    exit
}

: <<=cut
=func_frm
Waits for a certain period before continuing. the waiting is
however interrupt-able with <ENTER>. It will only wait in case console is enable
this because the console cannot use stdin.
a message what it means.
=ret
0 means not interrupted, 1 means the wait time was interrupted with enter.
=cut
function wait_time_interuptable() {
    local slp="$1"  # (O) The time to wait, if not given then no message is shown, nor waited
    local msg="$2"  # (M) The extra message to show, will not be shown in case of console

    local int=0
    
    slp=${slp:-0}     
    if [ "$slp" == '0' ]; then
        return $int
    fi

    [ -z help ] && [ $slp == 0 ] && show_ignore=1
    [ -z help ] && [ $slp != 0 ] && show_trans=0 && show_short="Wait for $slp seconds, wait can be interupted."

    WAIT_interrupted=0
    log_screen "Waiting $slp seconds before continuing."
    if [ $FLG_cons_enabled == 0 ]; then     # only stdin when not console
        log_screen "$msg"
        fflush_stdin    # empty stdin before wait for key
    fi
    while [ "$slp" -gt '0' ]; do
        log_screen "Seconds to wait: $slp \r" 'n'
        if [ $FLG_cons_enabled == 0 ]; then     # only stdin when not console
            local key
            [ $FLG_interactive != 0 ] && trap catch_read_ctrlc INT
            read -t1 -rs key
            local ret=$?
            [ $FLG_interactive != 0 ] && trap catch_iact_ctrlc INT
            if [ "$ret" == '0' ]; then
                # Some special key handlings
                case $key in
                    e) STR_wait_overlay=1; ;; 
                    d) STR_wait_overlay=0; ;;
                    *) : ;;
                esac
                WAIT_interrupted=1
                int=1
                break;
            fi
        else
            sleep 1
        fi
        ((slp--))
    done
    
    return $int
}

: <<=cut
=func_frm
Waits until a specific outcome is passed. The outcome is determined by a 
freely given bash function (so not the framework func). If the outcome
did not pass (checking WAIT_pass_request) then a time is waiting before trying
again. Also we first test is done before trying (allowed simplicity for 
the caller). If WAIT_continue_allowed is set to none zero then the user
might continue at own risk!
=optx
Parameters to be given to the function
=set WAIT_pass_request
Will be reset before every call to given function
=set WAIT_continue_allowed
Will be set to 0 (false) before every call to given function
=need WAIT_pass_request
=need WAIT_continue_allowed
=ret
0 = failed all attempts, > 0 successful after x attempts; 
=cut
function wait_until_passed() {
    local slp="$1"         # (O) The time to wait, default is 30
    local max="$2"         # (O) The maximum times to wait., 0 or empty = unlimited
    local fnc="$3"         # (M) The function name to call)
    
    log_debug "wait_until passed: called with: '$*'"

    shift 3         # Get potential optional parameters for sub function call

    slp=${slp:-30}
    max=${max:-0}   # Default is unlimited

    [ -z help ] && show_trans=0 && show_short="Calls function '$fnc' and waits (max $((slp * max)) sec) until it is passed."

    local ret=0
    local attempts=0
    local written=''
    local max_text=''

    # Maximize settings if console run is going on. this to prevent too long uninteruptable checks
    if [ $FLG_cons_enabled != 0 ]; then
        [ $max > $STR_cons_max_retries ] && max=$STR_cons_max_retries
        [ $slp > $STR_cons_retry_time  ] && slp=$STR_cons_retry_time
        max_text=", max: $max (console limited)"
    else
        max_text=", max: $max"
    fi
    [ "$max" == '0' ] && max_text=''      # Disable max if no max given
    
    while [ "$attempts" -lt "$max" -o "$max" == '0' ]; do
        WAIT_pass_request=''
        WAIT_continue_allowed=0
        WAIT_sleep_time=$slp
        log_debug "Trying to see if '$fnc' passes, attempts so far $attempts."
        $fnc $*
        ((attempts++))
        if [ "$WAIT_pass_request" == '' ]; then
            ret=$attempts
            break;  # Nothing requested so it passed
        fi
        if [ "$WAIT_sleep_time" == '' -o "$WAIT_sleep_time" -lt '1' ]; then # Some safety, not full!
            WAIT_sleep_time=$slp
        fi
        log_wait "${WAIT_pass_request}(attempts: $attempts$max_text)." $WAIT_sleep_time "$written"
        written=$?
        if [ "$WAIT_continue_allowed" != '0' -a $WAIT_interrupted == 1 ]; then
            log_wait "This step will be skipped with partial pass. Be certain you want to continue !" 60
            log_info "Continuing step upon user request, info:$nl$WAIT_pass_request"
            ret=$attempts
            break;  # User choose to skip
        fi
    done
    
    log_debug "Returning wait_until_passes with $ret, attemtps: $attempts"
    return $ret

    [ -z help ] && ret_vals[0]="All attempts failed (stopped trying)"
    [ -z help ] && ret_vals[1]="An attempt passed"
}
 