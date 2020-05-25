#!/bin/sh

: <<=cut
=script
This script contains simple but very impotant helper funcitons related
the check routines. The routine make life a lot easy and readble
When ever a check fails the processing will stop with a proper error message
=version    $Id: 02-check.sh,v 1.11 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly IP4_dig='0*([0-9]|[0-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])'
readonly IP4_ip="$IP4_dig.$IP4_dig.$IP4_dig.$IP4_dig"

: <<=cut
=func_frm
Checks the outcome a command I<$?> against 0 being success
or otherwise failure. Upon failure a message is logged and execution is stopped.
=cut
function check_success() {
    local str="$1"      # (M) The string to log using log_info/log_exit
    local outcome="$2"  # (M) The outcome of the previous command (I<$?>)
    local no_info="$3"  # (O) If set then no extra log is written if successful.Only the regular command output (with status)

    [ -z help ] && [ "$fnd_hlp_comment" == '' ] && show_short="Continue if $outcome == 0, otherwise fail with '$str'"
    [ -z help ] && [ "$fnd_hlp_comment" != '' ] && show_short="Continue if [ $fnd_hlp_comment ], otherwise fail with '$str'" && fnd_hlp_comment=''
    [ -z help ] && show_trans=0

    local result="$([ $outcome == '0' ] && echo -n "Successful" || echo -n "Failed{\$?=$outcome}")"
    local extra=`cat $LOG_cmds`
    if [ "$extra" != '' ]; then
        log_info "cmd: $result: $extra" >> $LOG_file
    fi
    if [ "$outcome" != '0' ]; then
        log_exit "${extra}${nl}$result: $str"
    elif [ "$no_info" == '' ]; then
        log_info "$result: $str"
    fi
    
    if [ -e $LOG_cmds ]; then
        /bin/mv $LOG_cmds $LOG_prv_cmds # keep this in case needed, CMD_mv not set yet!
    fi
    echo -n '' > $LOG_cmds              # Empty the last cmds
}

: <<=cut
=func_frm
Check if the given value is set. If not then a message is logged and execution
is stopped.
=cut
function check_set() {
    local str_val="$1"      # (O) The string which should be set to any value. Empty is error
    local err_str="$2"      # (O) String used in case value is not set.

    [ -z help ] && show_trans=0 && show_short="Continue if '$str_val' is set, otherwise fail with '$err_str'"

    if [ "$str_val" == '' ]; then
        log_exit "Failed: Value not set. $err_str"
    fi
}    

: <<=cut
=func_frm
Check if the given value is equal to the expected value. 
If not then a message is logged and executionis stopped.
=cut
function check_same() {
    local str_val="$1"      # (O) The 1st string to compare
    local str_exp="$2"      # (O) The 2nd string to compare with
    local err_str="$3"      # (O) String used in case value is not the same
    if [ "$str_val" != "$str_exp" ]; then
        log_exit "Failed: Value not same ($str_val!=$str_exp). $err_str"
    fi
}    

: <<=cut
=func_frm
Checks if a fields has a specific value if not stop. Fields are 
expected to separated by a tab.
=cut
function check_field() {
    local input="$1"        # (M) The input var/text to filter from
    local match_field="$2"  # (M) The field name to match which is at the start of a line
    local column="$3"       # (M) The column number (name is column 1)
    local exp_val="$4"      # (M) The expected value
    
    [ -z help ] && show_short="Check line starting '$match_field', column $column should be '$exp_val', or fail"
    [ -z help ] && show_trans=0

    field=`echo "$input" | grep "^$match_field" | cut -f $column`
    if [ "$field" != "$exp_val" ]; then
        log_exit "The '$match_field=$field' does not match expected '$exp_val'"
    else
        check_success "Check Field '$match_field' set to '$exp_val'" '0'
    fi
}

: <<=cut
=func_frm
Checks if a generic var is set. Exit if not, otherwise continues.
=cut
function check_mandatory_genvar() {
    local name="$1"     # (M) The name of the var (with GEN_), not the value
    
    [ -z help ] && show_trans=0 && show_short="Checks if $name is set, fails if not (check log)"
    local var="${!name}"
    name=`echo "$name" | cut -d'_' -f2- | tr ' ' '_'`
    if [ "$var" == '' ]; then
        log_exit "Mandatory variable '$name' is not defined under the [$sect_generic] section."
    fi
}

: <<=cut
=func_frm
Check if a process is running. with a minim amount of processes.
=cut
function check_running() {
    local info="$1"     # (M) The info to print in the standard text
    local min_exp="$2"  # (M) The minimum expect amount of processes
    local match="$3"    # (M) the string to match (not case sensitive)
    local match2="$4"   # (O) A secondary string to match (not case sensitive)

    [ -z help ] && show_short="Check if '$info' is running. Need $min_exp process(es), matching '$match'"
    [ -z help ] && [ "$match2" != '' ] && show_short+=" or '$match2'"
    [ -z help ] && show_trans=0

    check_set "$match" 'Need a search criteria for ps'

    found=`ps -ef | grep -v grep | grep -i "$match" | grep -i "$match2" | wc -l`
    if [ "$found" -lt "$min_exp" ]; then
        log_exit "The $info does not seem to be running!"
    else
        log_info "$info is running with $? processes"
    fi
}

: <<=cut
=func_frm
Check if the give value is a number. Which means it has to contain at least
1 digit and only digits. 
=cut
function check_is_pos_number() {
    local check="$1"    # (M) The number to check

    local ver=`echo -n "$check" | $CMD_ogrep '[0-9]+'`
    if [ "$check" == '' -o "$check" != "$ver" ]; then
        log_exit "Failed: '$check' is not a positive number."
    fi
}

: <<=cut
=func_frm
Checks if the give value is a number and falls within a range.
=cut
function check_range() {
    local check="$1"    # (M) The number to check
    local min="$2"      # (O) The minimum range to check, skipped if not given.
    local max="$3"      # (O) The maximum range to check, skipped if not given.

    local ver=$(echo -n "$check" | $CMD_ogrep '[+-]{0,1}[0-9]+')
    if [ "$check" == '' -o "$check" != "$ver" ]; then
        log_exit "Failed: '$check' is not a (full) number."
    fi
    if [ "$min" != '' -a "$check" -lt "$min" ]; then
        log_exit "Failed: $check is less than $min."
    fi
    if [ "$max" != '' -a "$check" -gt "$max" ]; then
        log_exit "Failed: $check is greater than $max."
    fi    
}

: <<=cut
Checks if the value is in a specific set of values
=cut
function check_in_set() {
    local str="$1"    # (M) The string to check may be empty
    local set="$2"    # (M) The set to check separate with ,. Empty should be quoted ''
    local extra="$3"  # (O) Extra info to show if not in set
    
    [ -z help ] && show_short="String '${show_pars[1]}' has to be part of set [$set] or fail."
    [ -z help ] && show_trans=0     # ignore pars the are in the short

    if [ "$str" == '' ]; then   # kind of a hack but it deals with the empty one
        str="''"
    fi
    local i
    for i in `echo -n "$set" | tr ',' ' '`; do
        if [ "$i" == "$str" ]; then
            return 0
        fi
    done
    log_exit "Did not find '$str' in set ($set)$extra"
}

: <<=cut
=func_frm
Check is a listener is active on a specific port
=cut
function check_listener() {
    local info="$1"     # (M) The additional info to print.
    local port="$2"     # (M) The listener port to check

    [ -z help ] && show_short="Check if a '$info' listener active on port:$port."
    [ -z help ] && show_trans=0

    local list=$(netstat -an | grep LISTEN | grep ":$port ")
    if [ "$list" == '' ]; then
        log_exit "Failed: ($info): No listener active on $port"
    fi
    check_success "$info" '0'
}

: <<=cut
=func_frm
Check if all the strings exist exactly in the other string.
=cut
function check_all_elements() {
    local info="$1"         # (M) the additional info to print
    local empty_err="$2"    # (O) 1 will cause failure if list1 is empty)
    local list1="$3"        # (O) the list to find
    local list2="$4"        # (O) the list to find in
    local sep1="$5"         # (O) The separator of list 1, empty means space
    local sep2="$6"         # (O) The separator of list 2, empty means space
    
    if [ "$list1" == '' ]; then     # always ok
        check_success "$info" "${empty_err:-0}"
    elif [ "$list2" == '' ]; then   # Always failure
        check_success "$info" '1'
    else 
        sep1=${sep1:- }
        sep2=${sep2:- }
        local elems1=$(echo -n "$list1" | tr "$sep1" '\n')
        local elems2=$(echo -n "$list2" | tr "$sep2" '\n')
        if [ "$(echo -n "$elems1" | grep "$elems2")" != "$elems1" ]; then
            check_success "$info ('$list1' not in '$list2')" '1'
        else
            check_success "$info ('$list1')" '0'
        fi
    fi
}

: <<=cut
=func_frm
Checks if the given string is an ip address. Currently it ony checks for
ipv4, but that might change in the future.
=ret
0 menas it is an ip addres, otherwise 1 (if opt parameter used)
=cut
function check_ip() {
    local info="$1" # (O) the additional info (type) to print
    local str="$2"  # (O) The string to check, empty would be a failure.
    local opt="$3"  # (O) If set then failure does not cause exit

    check_set "$str" "IP address ($info) not set."
    
    # IPv4 check, currently only ip address, no ports, no dns
    if [ "$(echo -n "$str" | $CMD_egrep "^$IP4_ip\$")" != '' ]; then 
        return 0
    fi  # additional check could go in the else

    if [ "$opt" == '' ]; then
        log_exit "IP '$str' is not an IP address ($info)"
    fi
    return 1
}
