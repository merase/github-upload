#!/bin/sh

: <<=cut
=script
This script contains simple helper functions for ncat (or netcat tool).
The netcat tool can be used for temporarily given remote access to files. Which
could e.g. be the Screen-Log file of the SSH public keys.
On each port only one server can be running
=version    $Id: 15-helper_ncat.sh,v 1.10 2017/02/22 09:05:50 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

NCAT_port_base=9950
NCAT_log_idx=0     
NCAT_ssh_idx=1
NCAT_fxf_idx=2
NCAT_syn_idx=3
NCAT_chk_idx=4
NCAT_num_ports=5       # Currently only a predefined ports

declare -a NCAT_pids

: <<=cut
=func_frm
Translates an index int a port. To be in in stdout context \$( )
=cut
function NCAT_get_port() {
    local idx="$1"  # (M) The index uses from the base port

    [ -z help ] && show_ignore=1    # Not of interest, so ignore

    local port=$((NCAT_port_base + idx))
    echo "$port"
}


: <<=cut
=func_frm
Start a listener on a specific port/idx with a specific file.
=ret
0 if started, 1 if already running
=cut
function NCAT_start_listener() {
    local idx="$1"  # (M) The index to start it for.
    local cmd="$2"  # (M) The command to execute once a connection is received

    [ -z help ] && show_trans=0 && show_short="Communication listener using port:$(NCAT_get_port $idx) was started, make sure it is reachable!"

    check_range "$idx" 0 $NCAT_num_ports
    check_set   "$cmd" 'Command missing'

    if [ "${NCAT_pids[$idx]}" != "0" -a "${NCAT_pids[$idx]}" != '' ]; then
        log_debug "Listener is already running, not restarting"
        return 1
    fi

    local port=$(NCAT_get_port $idx)

    # Try to see if hanging, if so the whole tree before continuing
    find_pids 'ncat' "-p $port"
    if [ "$found_pids" != '' ]; then
        log_info "Killing hanging ncat pids for port $port: $found_pids"
        local pid
        for pid in $found_pids; do
            kill -KILL $pid 2>/dev/null
        done
    fi

    $CMD_ncat -l -k -p $port -c "$cmd" &
    NCAT_pids[$idx]=$!
    log_debug "Created in netcat process with pid: ${NCAT_pids[$idx]}"
    return 0
}

: <<=cut
=func_frm
Stops an earlier started listener.
=cut
function NCAT_stop_listener() {
    local idx="$1"  # (M) The index to stop it for.

    [ -z help ] && show_short="Communication listener using port:$(NCAT_get_port $idx), pid:${NCAT_pids[$idx]} was stopped."
    [ -z help ] && show_trans=0

    check_range "$idx" 0 $NCAT_num_ports

    if [ "${NCAT_pids[$idx]}" != "0" -a "${NCAT_pids[$idx]}" != '' ]; then
        log_debug "Stopping of netcat process ($idx), pid:  ${NCAT_pids[$idx]}"
        killtree "${NCAT_pids[$idx]}" TERM 
        NCAT_pids[$idx]=0
    else
        log_debug "Stop of in netcat process requested but it is not running, continuing"
    fi
}

: <<=cut
=func_frm
Retieves data from a remote site and print it to stdout us \$( ) construction
=stdout
Teh data or empty if none/error occured.
=cut
function NCAT_get_data() {
    local ip="$1"   # (M) The ip address to get it from
    local idx="$2"  # (M) The index of the NCAT configuration (to get the port)

    [ -z help ] && show_ignore=1    # Too much detail, so ignore

    check_set   "$ip"   'No IP address given'
    check_range "$idx"  0 $NCAT_num_ports

    local tmp=$(mktemp)                 # Store optional error
    local port=$(NCAT_get_port $idx)
    # NCAT does not disconnect due to keep_alive option, so quit after 0.5 sec
    $CMD_ncat -i 0.5 $ip $port  2>$tmp
    if [ $? != 0 ]; then
        # It might still be the requested/needed timeout
        if [ "$(grep "Idle timeout expired" $tmp)" == '' ]; then
            log_info "NCAT Retrieval from $ip was not(yet) successful: "`cat $tmp`
        fi
    fi
    remove_temp $tmp
}

: <<=cut
=func_frm
Send data to a remote site
=ret 
0 if success, otherwise error
=cut
function NCAT_send_data() {
    local ip="$1"   # (M) The ip address to send it from
    local idx="$2"  # (M) The index of the NCAT configuration (to get the port)
    local data="$3" # (M) The data to send, what to send is up to the protocol for this port.

    [ -z help ] && show_ignore=1    # Too much detail, so ignore

    check_set   "$ip"   'No IP address given'
    check_range "$idx"  0 $NCAT_num_ports
    check_set   "$data" 'No data given to send'

    local tmp=$(mktemp)                 # Store optional error
    local port=$(NCAT_get_port $idx)
    # NCAT does might hang on connect,, so quit after 1 sec
    echo -n '' >$tmp    # Make sure file exists
    echo "$data" | $CMD_ncat -i 1 $ip $port  2>$tmp
    local ret=$?
    if [ $ret != 0 ]; then
        if [ "$(grep "Idle timeout expired" $tmp)" == '' ]; then
            log_info "NCAT Send to $ip was not(yet) successful($?): "`cat $tmp`
        else    # A tmeout is okay this is a send, the timeout is a way of protecting a none responsive host
            ret=0
        fi
    fi
    remove_temp $tmp
    return $ret
}

: <<=cut
Test a connection by setting up to the host/port combination. This only assumes
a listener to be available. It will not write data it self, only read if data
is automatically send. This only work for tcp/ip listeners.
=func_note
There will be a 1 second delay in case the connection was successful and the 
response is given.
=ret
0 if success, otherwise error
=cut
function NCAT_test_tcp_connection() {
    local ip="$1"   # (M) The ip address to test connection to
    local port="$2" # (M) The port to connect to

    [ -z help ] && show_short="Test a tcp/ip connection to '$ip:$port'"

    check_set   "$ip"   'No IP address given'
    check_set   "$port" 'No Port given'

    local output="$($CMD_ncat -i 1 $ip $port 2>&1 1>/dev/null)"
    if [ "$(echo -n "$output" | grep "Idle timeout expired")" != '' ]; then
        # This is successful so connection succeeded
        return 0
    fi

    log_info "test_tcp_connection($ip:$port) : failed with error '$output'"
    return 1

    [ -z help ] && ret_vals[0]="tcp/ip connection to '$ip:$port' was successful"
    [ -z help ] && ret_vals[1]="failed to do tcp/ip connect to '$ip:$port'"
}

