#!/bin/sh

: <<=cut
=script
This script contains simple helper functions for configuring some MGR items.
=script_note
It would be nice if this could move into the MGR code. That could be done by 
making it separates funcs, however that is not that nice and fast. It could
also be done by introducing some kind of lib directory per entity which is
loaded upon init_lib (not lower level).
=version    $Id: 15-helper_MGR.sh,v 1.34 2018/01/22 10:35:41 fkok Exp $
=author     Frank.Kok@newnet.com

=feat easy interface to MGR
Tp_shell is not the most nice interface, nice interface around it, which also 
handle errors in a generic way.
=cut

MGR_domain=1        # Currently 1 global domain, this might change in the future
MGR_inited=0        # Record if MGR module is initialized before.
MGR_shell_usr=''    # The internal shell user might be taken from MGR_if_usr
MGR_shell_pwd=''    # The internal shell pwd  might be taken from MGR_if_pwd

# The cmds below were added later so not all comp MGR files are using it.
# The command as supports to be located under $MM_bin but start under root (!logical).
readonly    MGR_auth_cmd='tp_auth'
readonly MGR_install_cmd='tp_install_mgr' 
readonly   MGR_start_cmd='tp_start_mgr'
readonly   MGR_shell_cmd='tp_shell'

readonly MGR_db_mgr='mgr_domain_mgr'
readonly MGR_db_main='mgr_domain_main'
readonly TP_table='Table'

# ME = MGR Entity
readonly ME_device='device'
readonly ME_poller='poller'

# MT = MGR Table (ME + Table define)
readonly MT_device="$ME_device$TP_table"
readonly MT_poller="$ME_poller$TP_table"

readonly MGR_shell_admin_grp='Administrators'
readonly MGR_shell_aut_usr='aut_admin'
readonly MGR_shell_aut_pwd='aut1234!'
readonly MGR_shell_desc='automate tool actions'
readonly MGR_shell_sts_active='active'
readonly MGR_shell_sts_inactive='inactivate'

MGR_http_port=${MGR_http_port:-80}   # Set default here in case of (backwards compatible problem)


: <<=cut
=func_int
Select the master MGR. This will need the manager to be running at the moment.
Running is defined by checking if there is a listener on port 80.
Unless there will be a different way to identify. It is either us being the
master or with are not.
=set MGR_is_master
0 if not master, 1 is master, <empty> if not collected yet.
=cut
function collect_mgr_master() {
    local i
    MGR_is_master=0
    for i in $dd_oam_nodes; do
        if [ "$i" == "$hw_node" ]; then
            [ "$(netstat -an | grep LISTEN | grep ":${MGR_http_port}[ ]")" != '' ] && MGR_is_master=1
            return
        fi
    done
}

: <<=cut
=func_int
Retrieve a specific MGR user.
=func_note
It would be nice if the tp_auth would allow to query a specific user. It does
not so ned to read the output. To prevent clashes in names I'll have to identify
the user section from the sessions section.
=set mgr_sel_usr
The found user or empty if not found.
=set mgr_sel_state
The current user state 'active'/'deactive' or empty if not found.
=set mgr_sel_grp
The group of the user empty if not found
=cut
function collect_mgr_user() {
    local search_usr="$1"  # (M) The user to search for.

    mgr_sel_usr=''
    mgr_sel_grp=''
    mgr_sel_state=''

    set_cmd_user "$MM_usr" 'output'
    local output="$(cmd 'Retrieve MGR users' $MGR_auth_cmd show)"
    default_cmd_user

    local line
    local state=0
    IFS=''; while read line; do IFS=$def_IFS
        case $state in
            0)  # Finding user section, then skip  3 lines
                [ "$(echo -n "$line" | grep '^Users:')" != '' ] && ((state++))
                ;;
            1|2|3)  # Just skip lines
                ((state++))
                ;;
            4)  # Now we should be in the user secton
                if [ "$line" == '' -o "${line:0:1}" == ' ' ]; then
                    ((state++))
                else
                    line="$(echo -n "$line" | tr -s ' ')"
                    local user="$(get_field 2 "$line")"
                    if [ "$user" == "$search_usr" ]; then
                        mgr_sel_usr="$user"
                        mgr_sel_grp="$(get_field 3 "$line")"
                        mgr_sel_state="$(get_field 1 "$line")"
                        return
                    fi
                fi
                ;;
            5)  # Find sessions section (just for completeness
                [ "$(echo -n "$line" | grep '^Active Sessions:')" != '' ] && ((state++))
                ;;
            *)  : ;;        # Do nothing read input
        esac
    IFS=''; done <<< "$output"; IFS=$def_IFS
}

: <<=cut
=func_frm
Initializes the MGR_shell, can be called to speed up subsequent calls from
subshells. This can then be called at the higher level.
=cut
function MGR_init_shell() {
    local usr="$1"  # (O) User to use if not yet defined. Fallback to MGR defaults or AUT defaults
    local pwd="$2"  # (O) Password to use if not yet defined. Fallback to MGR defaults or AUT defaults
    local tst="$3"  # (O) If set the none master node will test connection as well.

    [ -z help ] && show_desc[0]="Verifies if tp_shell exists and can be used to reach MGR"
    [ -z help ] && show_desc[1]="Access with usr/pwd=[$usr/$pwd] or defaults to[$MGR_shell_aut_usr/$MGR_shell_aut_pwd]"
    [ -z help ] && show_desc[2]="User is create if not existing."
    [ -z help ] && show_desc[3]="The above allow configuring existing user but also work with default (no config needed)"
    [ -z help ] && show_desc[4]="Our created used will be disable in the finish_Automation step."
    [ -z help ] && show_trans=0

    if [ "$usr" != '' -a "$pwd" != '' ] && 
       [ "$MGR_shell_usr" != "$usr" -o "$MGR_shell_pwd" != "$pwd" ]; then
        MGR_inited=0
    fi

    if [ $MGR_inited == 0 ] || [ "$tst" != '' ] ||
       [ "$usr" != '' -a "$pwd" != '' ]; then
        if [ "$IP_MGR" != '' ] && [ "$MGR_if_usr" == '' -o "$MGR_if_pwd" == '' ]; then
            func $IP_MGR define_vars        # Check if the can be read
        fi
        MGR_shell_usr=${usr:-$MGR_if_usr}   # prefer given parameters over config
        MGR_shell_pwd=${pwd:-$MGR_if_pwd}

        MGR_shell_usr=${MGR_shell_usr:-$MGR_shell_aut_usr}  # Use default if none given
        MGR_shell_pwd=${MGR_shell_pwd:-$MGR_shell_aut_pwd}

        add_cmd_require $MGR_shell_cmd "$MM_usr"         # Requires it to be able to continue. 

        MGR_inited=1                            # Prevent loops caused by MGR_shell

        local fail=0
        collect_mgr_master
        if [ $MGR_is_master == 0 -a "$tst" != '' ]; then
            MGR_shell 'Test accessibility (0)' '--show deviceTable' 'Operation is not allowed'
            [ $? != 0 ] && fail=1
        elif [ $MGR_is_master != 0 ]; then
            # Next check if the user exist
            collect_mgr_user "$MGR_shell_usr"
            if [ "$mgr_sel_usr" == '' ]; then                                       # Does not exist, check if given one
                if [ "$MGR_shell_usr" != "$MGR_shell_aut_usr" ]; then               # Another user create ours but give warning
                    log_warning "The requested MGR user '$MGR_shell_usr' was not found, using '$MGR_shell_aut_usr' in stead."
                    MGR_shell_usr="$MGR_shell_aut_usr"
                    MGR_shell_pwd="$MGR_shell_aut_pwd"
                else                                                                # Try to add our user
                    cmd_tp "Adding $MGR_shell_usr" $MGR_auth_cmd add -n=\'$MGR_shell_usr\' -g=\'$MGR_shell_admin_grp\' -p=\'$MGR_shell_pwd\' -d=\'$MGR_shell_desc\'
                fi
            else                                                                    # It exists check if active
                if [ "$mgr_sel_state" != "$MGR_shell_sts_active" ]; then            # Not active try to activate
                    cmd_tp "Activating $MGR_shell_usr" $MGR_auth_cmd activate -n=\'$MGR_shell_usr\'
                fi
                # We cannot just set the password again (to often used, or it is expired so test first
                # Now test it. our user should be ok, however a given user can fail
                MGR_shell 'Test accessibility (1)' '--show deviceTable' 'Operation is not allowed'
                if [ $? != 0 ]; then                                                # Hmm it gave operation not allowed
                    fail=1
                    if [ "$MGR_shell_usr" == "$MGR_shell_aut_usr" ]; then           # Ours try delete add instead and retest
                        cmd_tp "Delete $MGR_shell_usr" $MGR_auth_cmd delete -n=\'$MGR_shell_usr\'
                        cmd_tp "Adding $MGR_shell_usr" $MGR_auth_cmd add -n=\'$MGR_shell_usr\' -g=\'$MGR_shell_admin_grp\' -p=\'$MGR_shell_pwd\' -d=\'$MGR_shell_desc\'
                        MGR_shell 'Test accessibility (2)' '--show deviceTable' 'Operation is not allowed'
                        [ $? == 0 ] && fail=0
                    fi
                fi

            fi
        fi

        if [ $fail != 0 ]; then                                                # Hmm it gave operation not allowed
            local extra=''
            if [ "$MGR_shell_usr" != "$MGR_shell_aut_usr" ]; then               # Not internal one, give extra info
                extra="
* The user is defined in the data file (section [cfg/MGR]) so :
  * Please verify if the following user can connect to the mgr from this node;
  * if_usr='$MGR_shell_usr' and if_pwd='$MGR_shell_pwd', then;
  * Fix the configuration to a correct user/password or
  * Remove the if_usr= and if_pwd= in [cfg/MGR] section to fallback to internal 
    automate user."
            fi

            log_exit "The MGR user '$MGR_shell_usr' could not retrieve information which is mandatory
please check if the user is already created on the Manager, options to fix:
* Make sure the MGR is up an running;
* Make sure the MGR is reachable from this node (firewall) tcp/ip port $MGR_http_port is used;$extra
* If no user is configured in the data file then :
  * Either aut_gen_data should have been used before or;
  * Use --if_usr option of automate on the MGR  node to check/create internal user. 
  * The --if_usr option can also be used on a remote node to check connection
    independently of current automate run.

Note: The fallback user is only created on the manager (due to security reasons)"
        fi
    fi
}

: <<=cut
=func_frm
Disables the shell user if it was ours.
=func_note
The fuciton deactivate our own user. Though that looks nice. I did see (in 10.8)
that tp_shell itself would still be able to retrieve info. I therefore do
not know what the real value is. However still do it to make it nice.
For now it is there but does not do anything.
=cut
function MGR_disable_shell() {
    [ "$MGR_shell_usr" != "$MGR_shell_aut_usr" ] && return      # Don't do anything
    collect_mgr_master
    [ $MGR_is_master == 0 ] && return                           # Bailout not master OAM

    # Do not deactivate as a element alone cannot activate and could still need it
    #cmd_tp "Deactivating $MGR_shell_usr" $MGR_auth_cmd deactivate -n=\'$MGR_shell_usr\'
}

: <<=cut
=func_frm
Set MGR setting in: Settings -E<gt> Network Layout -E<gt> Devices.
Current allowed actions are:
* activate : To activate a device
* deactivate : To deactivate a device 
=cut
function MGR_device() {
    local action="$1"       # (M) The action to execute
    local who="$2"          # (M) A 'device' name  or 'comp_grp' 
    local what="$3"         # (M) The device or component to act upon

    check_in_set "$action" 'activate,deactivate'
    check_in_set "$who" 'device,comp_grp'
    
    if [ "$who" == 'device' ]; then
        local dev_idx=$(MGR_get_table_idx '' $ME_device "$what")
        MGR_shell "$action device($pol_idx)" "--$action $MT_device -i $dev_idx"
    else
        log_info "TODO: Find all $what and Execute MGR $action device name"
    fi
}

: <<=cut
=func_frm
Check if this is the master OAM node. The data will only be looked-up once
and will require a running MGR otherwise it will indicate not master.
=ret bool
0 this is not the master, 1 this is the current master 
=cut
function MGR_is_master() {
    # Currently collect it only once
    if [ "$MGR_is_master" == '' ]; then
        collect_mgr_master
    fi
    return $MGR_is_master

    [ -z help ] && ret_vals[0]="This node does not have a MGR or is a slave MGR"
    [ -z help ] && ret_vals[1]="This node is the master MGR"
}


: <<=cut
=func_frm
Execute a tp_shell command with the  default user password, domain.
The tp_shell will be connected to the master OAM node or local in case this
node is identified as the local OAM master.
=ret func_return
This will hold the output of the tp_shell command.
=return
0 if succesful and no error found, 1 if successful but the error matched the allow_err
=cut
function MGR_shell() {
    local info="$1"         # (O) The information to add
    local cmd="$2"          # (M) A valid tp_shell command
    local allow_err="$3"    # (O) An optional error string which is allowed e.g. 'Connection refused'
    local retries_left="$4" # (O) Only set if already retried

    MGR_init_shell      # make sure passwords are set.

    retries_left=${retries_left:-$STR_tpshell_max_retries};

    local hostname=''
    if [ "$hw_node" != "$dd_oam_master" ]; then # Not on master OAM, use master OAM node
        hostname="--hostname=$(get_oam_ip $dd_oam_master)"  # Get IP based on out own config as not all hosts files seemed filled
    fi
    cmd_tp "$info" $MGR_shell_cmd --user=$MGR_shell_usr --password=$MGR_shell_pwd $hostname --domain=$MGR_domain "$cmd"

    # Check if the command log has an error, tp_shell will not always use $? properly
    local ret=0
    func_return=''
    if [ -f $LOG_prv_cmds ]; then
        func_return="$(cat $LOG_prv_cmds)"
        if [ "$(grep -i 'Request failed' $LOG_prv_cmds)" ]; then    # generic failure
            log_exit "$extra${nl}MGR_shell request failed: $info"
        fi

        local error="$(grep 'failed:' $LOG_prv_cmds)"
        if [ "$error" != '' ]; then
            local extra=`cat $LOG_prv_cmds`
            if [ "$allow_err" != '' -a "$(echo -n "$error" | grep "$allow_err")" != '' ]; then
                log_info "MGR_shell error passed upon request ($allow_err): $info$nl$extra"
                ret=1
            # Check for retry later due to synching (see Bug 26960)
            # Something like:
            #  Configuration update or synching currently in progress, hence 
            #  updates are not allowed. Please try after some time
            # Do not check exact only specifics, to mitigate risk of changes
            # The exit value of tp_shell is not useful. Actually tp_shell
            # is nto usefull and bug 27026
            elif [ "$(echo -n "$error" | grep 'update' | grep 'synching' | grep 'try' | grep 'after' | grep 'time')" != '' ]; then
                if [ "$retries_left" != "" -a "$retries_left" -gt 0 ]; then
                    ((retries_left--))
                    log_screen_info '' "MGR seems busy, waiting and retrying after $STR_tpshell_retry_time sec ($retries_left left)"
                    log_info "MGR_shell: Extra info on attempt: $info$nl$extra"
                    sleep $STR_tpshell_retry_time
                    MGR_shell "$info" "$cmd" "$allow_err" "$retries_left"
                    ret=$? 
                else
                    log_exit "$extra${nl}MGR_shell failed $STR_tpshell_max_retries times: $info"
                fi
            else
                log_exit "$extra${nl}MGR_shell failed: $info"
            fi
        fi
    fi
    return $ret
}

: <<=cut
=func_frm
Activates/Deactivates an row entity of a specific table, depending of the right 
version of tp_shell.
=func_note
The version selection is needed because not all tp_shells can do the same.
It is based on MM release though it might have been nicer to do it on the 
MGR release. This however has the same effect. and is easier and more common.

The fallback method will only work if the {tab_name}AdminState field exists and works.
=cut
function MGR_set_state() {
    local info="$1"     # (O) The information to add
    local what="$2"     # (M) what todo 'activate' or 'deactivate'
    local tab_name="$3" # (M) The table name withut the word Table
    local idx="$4"      # (M) The index of the row to activate

    check_in_set "$what" 'activate,deactivate'

    # As of version 11.0 the --active/--deactivate command is supported which is preferred
    STR_MM_cur_relnum=${STR_MM_cur_relnum:-$MM_cur_relnum}      # backwards compatibility
    if [ $STR_MM_cur_relnum -ge '110000' ]; then
        MGR_shell "$what : $info" "--$what ${tab_name}Table -i $idx"
    else        # Fallback to updating the adminstate
        local state=$([ "$what" == 'activate' ] && echo -n '1' || echo -n '0')
        MGR_shell "$info" "--update ${tab_name}Table -i $idx -f ${tab_name}AdminState=$state"
    fi
}

: <<=cut
=func_frm
Set a new password for a specific MGR user.
=cut
function MGR_set_password() {
    local user="$1"     # (M) The user to change the password for
    local pwd="$2"      # (M) The new password to set

    [ -z help ] && show_desc[0]="Set a new MGR password using:"
    [ -z help ] && show_desc[1]="- [$MM_user]$ $MGR_auth_cmd set --name=\"$user\" --password=\"$pwd\""
    [ -z help ] && show_trans=0

    cmd_tp "Setting new MGR password for '$user'" $MGR_auth_cmd set --name="$user" --password="$pwd"
}

: <<=cut
=func_frm
Add a poller for a specific node. This is only done if the actual node
has poller STV devices. The poller is also activated if needed.
=func_note
If this is not the local active manager then this will be executed on
the remote active MGR
=set mgr_pol_detail
A filled detail sting, which will only be filled if the detail is
requested it will become detail_str=$pol_idx or '' if not found
=cut
function MGR_add_poller() {
    local node="$1"         # (M) Refers to a node/section to add this poller for.
    local detail_str="$2"   # (M) Optional detail string to fill mgr_pol_detail

    mgr_pol_detail=''

    # First check if this node needs a poller
    [ "$C_STV" == '' ]                    && return
    is_poller_needed "$node"; [ $? == 0 ] && return

    select_oam_ip $node

    local name="poller-$node"     # We use a fixed name for now, why bother with more configuration
    local pol_idx=$(MGR_get_table_fld '' $ME_poller "$sel_ip" opt /hostName)
    if [ "$pol_idx" == '' ]; then
        # Not found add it
        MGR_shell "Add poller for '$node'" "--add $MT_poller --fields pollerName='$name',domain='$MGR_domain',hostName='$sel_ip'"
        pol_idx=$(MGR_get_table_fld '' $ME_poller "$sel_ip" '' /hostName)
    else
        log_debug "The poller on '$sel_ip' already exists with id:$pol_idx"
    fi

    # existing or not always make sure it is activated
    check_is_pos_number "$pol_idx"

    MGR_set_state "poller($pol_idx)" 'activate' $ME_poller "$pol_idx"

    mgr_pol_detail="$detail_str$pol_idx"  # Always make even if not needed
}

: <<=cut
=func_frm
Returns an specific field belonging to an entry in a table. This is a helper function
which relies on tp_shell. By default it searches on the name and returns the
index but this could be overruled.
=stdout
=cut
function MGR_get_table_fld() {
    local db="$1"           # (O) Defaults to MGR_db_mgr, use MGR_db_main for main attribute database
    local base_name="$2"    # (M) The base name of the table
    local search_val="$3"   # (M) The search value by default searched in <base_name>Name
    local opt="$4"          # (O) If set then existence check is ignored.
    local search_base="$5"  # (O) If set then the default search base of Name is overruled. If start with / then no base is added.
    local return_base="$6"  # (O) If set then the default return base of Index is overruled.  If start with / then no base is added.

    db=${db:-$MGR_db_mgr}
    search_base=${search_base:-Name}
    return_base=${return_base:-Index}
    local table="${base_name}Table"
    local search_col=$([ "${search_base:0:1}" == '/' ] && echo -n "${search_base:1}" || echo -n "$base_name$search_base")
    local return_col=$([ "${return_base:0:1}" == '/' ] && echo -n "${return_base:1}" || echo -n "$base_name$return_base")
    MGR_shell "Get table id for $table:$search_col" "--show $table"
    if [ "$func_return" == '' ] || [ "$(echo -n "$func_return" | grep -i 'No entries found')" != '' ]; then
        check_set "$opt$func_return" "No data found for $table in db '$db'"
        return
    fi

    local header="$(echo "$func_return" | grep '^Table'  | tr -d ' ' | tr '|' ' ')"   # Copy header, remove spaces, change sep into space
    local out="$(   echo "$func_return" | grep "^$table" | tr -d ' ')"   # safe copy to prevent changing, remove spaces, filter data rows

    # Find the Index and Search column
    check_set "$header" "No header found for $table."
    local err="header for $table."
    local return_fld=$(get_index_from_str "$header" "$return_col" "$err")
    local search_fld=$(get_index_from_str "$header" "$search_col" "$err")

    local line
    local ret=''
    while read line; do
        if [ "$(get_field $search_fld "$line" '|')" == "$search_val" ]; then
            ret=$(get_field $return_fld "$line" '|')
            break
        fi
    done <<< "$out"

    check_set "$opt$ret" "$return_col not found for '$search_val' in db '$db'"

    echo -n "$ret"
}

: <<=cut
=func_frm
Returns an index belonging to an entry in a table. This is a helper function
which relies on tp_shell .
=stdout
=cut
function MGR_get_table_idx() {
    local db="$1"           # (O) Defaults to MGR_db_mgr, use MGR_db_main for main attribute database
    local base_name="$2"    # (M) The base name of the table, index and name
    local search_val="$3"   # (M) The search value by default searched in <base_name>Name
    local opt="$4"          # (O) If set then existence check is ignored.
    local search_base="$5"  # (O) If set then the default search base of Name is overruled

    # I could have change the calls from MGR_get_table_idx to MGR_get_table_fld
    # (as the return base defualts to Index).
    # But this is more explicit and might be more understandble that the index
    # is wanted. This can always be changed if wanted.
    MGR_get_table_fld "$db" "$base_name" "$search_val" "$opt" "$search_base" 'Index'
}

: <<=cut
=func_frm
Return the server index belong to a specific node. The node is looked up
using the IP address which connected to the OAM lan. Optionally it is
allowed to supply the IP address. Output is send to stdout.
=cut
function MGR_get_server_idx() {
    local node="$1"         # (M) Refers to a node/section to search for.
    local ip="$2"           # (O) If given then this ip is used.
    local opt="$3"          # (O) If set then existence check is ignored.

    if [ "$ip" == '' ]; then
        ip=$(get_oam_ip $node)
    fi
    MGR_get_table_idx '' server "$ip" "$opt" Ip
}

: <<=cut
=func_frm
Retrieves the index of a specific device. Which has to exist.
=stdout
The found index.
=cut
function MGR_get_device_idx() {
    local dev="$1"          # (M) The device to update
    local ins="$2"          # (M) The instance number on which the device runs
    local srvr_idx="$3"     # (M) The server index for this device
    local dev_type="$4"     # (M) The device type for this device
    local dev_port="$5"     # (M) The device port for this device
    local srvr_ip="$6"      # (O) The ip to be used can deviceServerInder is not supported

    MGR_shell 'Get devices' "--show $MT_device"
    if [ "$func_return" == '' ]; then
        log_exit "Did not find any devices"
    fi

    local header="$(echo "$func_return" | grep '^Table'      | tr -d ' ' | tr '|' ' ')"   # Copy header, remove spaces, change sep into space
    local out="$(   echo "$func_return" | grep "^$MT_device" | tr -d ' ')"    # safe copy to prevent changing, remove spaces, filter rows

    # Find the columns
    check_set "$header" "No header found for $table."
    local err="header for $table."
    local idx_fld=$( get_index_from_str "$header" "${ME_device}Index"       "$err")
    local type_fld=$(get_index_from_str "$header" "${ME_device}Type"        "$err")
    local port_fld=$(get_index_from_str "$header" "${ME_device}Port"              )  # This is optional and introduced in 11.0 *most likely multi instance.
    local sidx_fld=$(get_index_from_str "$header" "${ME_device}ServerIndex"       )  # This does no seem to be available in pre 11.0
    # NO server index, then use ip if available (overrule variables)
    if [ "$sidx_fld" == '' ]; then
        check_set "$srvr_ip" "Var 'srvr_ip' not set cannot fallback using '${ME_device}Ip'"
        log_info "This version does not support '${ME_device}ServerIndex', trying via '${ME_device}Ip'"
        sidx_fld=$(get_index_from_str "$header" "${ME_device}Ip" "$err")
        srvr_idx="$srvr_ip"
    fi

    local line
    local fnd_idx=''
    local found=0
    while read line; do
        local idx=$( get_field $idx_fld  "$line" '|')
        local type=$(get_field $type_fld "$line" '|')
        local sidx=$(get_field $sidx_fld "$line" '|')
        if [ "$type" == "$dev_type" -a  "$sidx" == "$srvr_idx" ]; then
            if [ "$port_fld" != '' ]; then                              # Check the port if available
                local port=$(get_field $port_fld "$line" '|')
                [ "$port" == "$dev_port" ] && found=1
            else
                found=1
            fi
        fi
        if [ $found != 0 ]; then
            fnd_idx=$idx
            break
        fi
    done <<< "$out"

    local info="for: dev=$dev, ins=$ins, srv=$srvr_idx, type=$dev_type, port=$dev_port"
    if [ "$fnd_idx" == '' ]; then
        log_exit "Did not find any device $info"
    fi
    log_info "Found device with index $fnd_idx $info"

    echo -n "$fnd_idx"
}

: <<=cut
=func_frm
Find the closest version or latest version from the a product ReleasesTable
Failing to find a version results in failure.
=stdout
The found version.
=cut
function MGR_get_rel_version() {
    local prod="$1" # (M) The product to query (in lower case)
    local sver="$2" # (O) The version to check for. If empty than the latest is returned


    local table="${prod}ReleasesTable"
    MGR_shell "Get release for $prod" "--show $table"
    if [ "$func_return" == '' ]; then
        log_exit "Did not find any release in $table"
    fi

    local header="$(echo "$func_return" | grep '^Table'  | tr -d ' ' | tr '|' ' ')"   # Copy header, remove spaces, change sep into space
    local out="$(   echo "$func_return" | grep "^$table" | tr -d ' ')"    # safe copy to prevent changing, remove spaces, filter rows

    # Find the version column
    check_set "$header" "No header found for $table."
    local ver_fld=$( get_index_from_str "$header" 'releasesValue' "header for $table.")


    local line
    local lver=''
    while read line; do
        local ver=$(get_field $ver_fld "$line" '|')
        if [ "$ver" == '' -o ${ver:0:1} != 'R' ]; then
            continue            # Not a version line
        fi

        # See if this version could fit in the search version
        if [ "$sver" != '' ]; then
            if [[ "$ver" > "$sver" ]]; then
                continue            # nope skip it
            fi
            if [ "$ver" == "$sver" ]; then
                lver=$ver
                break               # Exact match, is always good
            fi
        fi

        if [ "$lver" == '' ] || [[ "$ver" > "$lver" ]]; then    # No version yet or a closer match
            lver=$ver
        fi
        log_debug "$sver: Found '$ver', current best '$lver'"
    done <<< "$out"

    if [ "$lver" == '' ]; then
        log_exit "Did not find any version for $prod product (search for '$sver')"
    fi

    log_info "Found release version '$lver' for '$ver', for $prod product"

    echo -n "$lver"
}

: <<=cut
=func_frm
Adds a server to the MGR configuration. This is only done id it does not
exists yet.
=ret server_idx
The server index of the existing or just created server.
=cut
function MGR_add_server() {
    local node="$1"         # (M) Refers to a node/section to add this poller for.

    MGR_add_poller $node ',serverPoller='

    select_oam_ip $node
    local srvr_idx=$(MGR_get_server_idx $node $sel_ip optional)
    if [ "$srvr_idx" == '' ]; then
        MGR_shell 'Add server' "--add serverTable --fields serverName='$node',domain='$MGR_domain',serverIp='$sel_ip'$mgr_pol_detail"
        srvr_idx=$(MGR_get_server_idx $node $sel_ip)
    fi

    return $srvr_idx
}

: <<=cut
=func_frm
Add a single device of a node to the MGR configuration
=cut
function MGR_add_device() {
    local node="$1"         # (M) Refers to a node/section to add this device for
    local ins="$2"          # (M) The instance number on which the device runs
    local dev="$3"          # (M) The device to add
    local srvr_idx="$4"     # (M) The server index for this node

    MGR_init_shell          # For speed: make sure defined at this level

    find_component $dev
    if [ "$comp_idx" == '0' ]; then
        log_exit "Did not find referred component '$dev'"
    fi
    if [ "$comp_device" == 'N' -o "$comp_snmp_port" == '0' ]; then
        return               # Skip this device
    fi
    
    local dev_lc=`echo -n "$dev" | tr '[:upper:]' '[:lower:]'`
    local rel=$(MGR_get_rel_version $dev_lc)
    local dev_name="$dev-$node-$ins"
    log_info "Adding the device : '$dev_name'"

    MGR_add_poller $node ',poller='             # Will add if needed, none if not

    local snmp_port=$(get_instance_port "$comp_snmp_port" snmp "$ins" "$comp_snmp_offs")

    # Some dev have special handling
    local ext_ip=''
    local ext_ipv6=''
    local sec_ext_ip=''
    local add_par=''
    local allow_err=''
    case $dev in
        AMS) add_par=',qcliServer='$(get_instance_port '' cm_port  $ins); ;;
        LGP) add_par=',lgpQuery='$(get_instance_port '' lgp_port $ins)
             # Somehow the LGP from tp_shell does not allow device addition if 
             # devce is not running, which is a chicken an an egg. Even though
             # an error is given the device is added. So in this case ignore the
             # error. Yes ths is ugly tp_shell should be fixed. 
             allow_err='Connection refused'
             ;;
        HUB) 
            ext_ip=$(get_all_fld_data "$node#$ins" "$fld_hub_ext_ip")
            ext_ipv6=$(get_all_fld_data "$node#$ins" "$fld_hub_ext_ipv6")
            if [ "$ext_ip" == '' ]; then
                ext_ip=$(get_all_fld_data "$node" "$fld_hub_ext_ip")
            fi
            if [ "$ext_ipv6" == '' ]; then
                ext_ipv6=$(get_all_fld_data "$node" "$fld_hub_ext_ipv6")
            fi
            if [ "$ext_ip" == '' ]; then
                # If external IP is not defined by user, then taking external ip address 0.0.0.0 (default value)to configure HUB device
                ext_ip=${ext_ip:-'0.0.0.0'}
            fi
            ;;
        IIW)
            ext_ip=$(get_all_fld_data "$node#$ins" "$fld_iiw_ext_ip")
            if [ "$ext_ip" == '' ]; then
                ext_ip=$(get_all_fld_data "$node" "$fld_iiw_ext_ip")
            fi
            sec_ext_ip=$(get_all_fld_data "$node#$ins" "$fld_iiw_sec_ext_ip")
            if [ "$sec_ext_ip" == '' ]; then
                sec_ext_ip=$(get_all_fld_data "$node" "$fld_iiw_sec_ext_ip")
            fi
            if [ "$ext_ip" == '' ]; then
                # If external IP is not defined by user, then taking external ip address 0.0.0.0 (default value)to configure HUB device
                ext_ip=${ext_ip:-'0.0.0.0'}
            fi
            ;;
        *) : ;; # No extra processing
    esac

    if [ "$ext_ip" != '' -a "$ext_ipv6" != '' ]; then
        local man_ip=", External IP: $ext_ip ,External IPv6: $ext_ipv6 "
        ext_ip=",${dev_lc}ExternalIp=$ext_ip,${dev_lc}ExternalIpv6=$ext_ipv6"
    elif [ "$ext_ip" != '' -a "$sec_ext_ip" != '' ]; then
        local man_ip=", External IP: $ext_ip ,Secondary External IP: $sec_ext_ip"
        ext_ip=",${dev_lc}ExternalIp=$ext_ip,${dev_lc}SecondaryExternalIp=$sec_ext_ip"
    elif [ "$ext_ip" != '' ]; then
        local man_ip=", External IP: $ext_ip"
        ext_ip=",${dev_lc}ExternalIp=$ext_ip"
    elif [ "$ext_ipv6" != '' ]; then
        local man_ip=", External IPv6: $ext_ipv6"
        ext_ip=",${dev_lc}ExternalIp=$ext_ipv6"
    elif [ "$sec_ext_ip" != '' ]; then
        local man_ip=", Secondary External IP: $sec_ext_ip"
        ext_ip=",${dev_lc}SecondaryExternalIp=$sec_ext_ip"
    fi
    local dev_str=",deviceType=$comp_device,${dev_lc}Release='$rel',${dev_lc}Port='$snmp_port'$ext_ip$add_par$mgr_pol_detail"

    # Adding the release only seem to work from 11.0 and beyond. so just make a list what to do manual
    # Any verison beyond RH7 will also be good engough (prevent problems identify MM release
    STR_MM_cur_relnum=${STR_MM_cur_relnum:-$MM_cur_relnum}      # backwards compatibility
    if [ $STR_MM_cur_relnum -ge '110000' ] || [ "$OS" == "$OS_linux" -a $OS_ver_numb -ge 70 ]; then
        MGR_shell "Add device '$dev_name'" "--add $MT_device --fields deviceName='$dev_name',deviceServerIndex='$srvr_idx',domain='$MGR_domain',connectFlag=1$dev_str" "$allow_err"
        local dev_idx=$(MGR_get_table_idx '' $ME_device "$dev_name")
        MGR_set_state "device '$dev_name'" 'activate' $ME_device "$dev_idx"

        log_info "Added the device : '$dev_name', idx:$dev_idx"
    else
        local poll=$([ "$mgr_pol_detail" != '' ] && echo ", poller: poller-$node") 
        MGR_devices_to_add+="Name: $dev_name, Type: $dev, Server: $node, Release: $rel$poll$man_ip$nl"
    fi
}

: <<=cut
=func_frm
Update a device in the MGR configuration. This will retrieve the currentMGR_get_table_idx
device info (needs to exists), deactivate the device, update the information
and the reactive (if needed)
=cut
function MGR_upd_device() {
    local node="$1"         # (M) Refers to a node/section to add this device for
    local dev="$2"          # (M) The device to update
    local ins="$3"          # (M) The instance number on which the device runs
    local ver="$4"          # (M) The new version of the device

    MGR_init_shell          # For speed: make sure defined at this level

    find_component $dev
    if [ "$comp_idx" == '0' ]; then
        log_exit "Did not find referred component '$dev'"
    fi
    if [ "$comp_device" == 'N' -o "$comp_snmp_port" == '0' ]; then
        return               # Skip this device silently
    fi
    local snmp_port=$(get_instance_port "$comp_snmp_port" snmp "$ins" "$comp_snmp_offs")

    local dev_lc=`echo -n "$dev" | tr '[:upper:]' '[:lower:]'`
    local rel=$(     MGR_get_rel_version "$dev_lc" "$ver")
    local srvr_ip=$( get_oam_ip "$node")
    local srvr_idx=$(MGR_get_server_idx "$node" "$srvr_ip")
    local dev_idx=$( MGR_get_device_idx "$dev" "$ins" "$srvr_idx" "$comp_device" "$snmp_port" "$srvr_ip")
    local cur_as=$(  MGR_get_table_fld '' $ME_device $dev_idx '' 'Index' 'AdminState')
    MGR_set_state "device '$dev@$node:$ins'" 'deactivate' $ME_device "$dev_idx"
    MGR_shell "Update version of $dev to $rel" "--update $MT_device --index=$dev_idx --field ${dev_lc}Release=$rel"
    if [ "$cur_as" == '1' ]; then   # Onyl activate it it was activated
        MGR_set_state "device '$dev@$node:$ins'" 'activate' $ME_device "$dev_idx"
    fi

    log_info "Updated the device : '$dev@$node:$ins', idx:$dev_idx to release:$rel"
}

: <<=cut
=func_frm
Will add  all devices of a node to the MGR configuration. This includes
adding the server and or pollers if needed.
=cut
function MGR_add_devices() {
    local node="$1"         # (M) Refers to a node/section to add this poller for.

    [ -z help ] && show_desc[0]="Add all the devices of the <node>."
    [ -z help ] && show_desc[1]="This includes the server and the pollers if needed."
    [ -z help ] && show_desc[2]="This uses tp_shell command and done for all the"
    [ -z help ] && show_desc[3]="components on the given node. But only those who"
    [ -z help ] && show_desc[4]="are manageable by the MGR."
    [ -z help ] && show_desc[5]="${COL_bold}Manually it would be done by using the GUI.$COL_no_bold"
    [ -z help ] && show_trans=0

    log_info "Adding all the devices on node: '$node'"

    MGR_add_server $node 
    local srvr_idx=$?

    local ins
    for ins in $(map_get $map_instance "$node"); do
        local components=$(get_all_fld_data "$node#$ins" $fld_comp)
        if [ "$components" != '' ]; then
            log_info "Adding all the devices on node instance: '$node-$ins'"
            local device
            for device in $components; do
                MGR_add_device $node $ins $device $srvr_idx 
            done
        fi
    done
}

: <<=cut
=func_frm
Will update all devices of a node in the MGR configuration. The device
should already be existing.
=cut
function MGR_upd_devices() {
    local node="$1"         # (M) Refers to a node/section to add this poller for.

    [ -z help ] && show_trans=0 && show_short="Update all the devices on $node to current version"

    log_info "Updating all the devices on node: '$node'"

    local ins
    for ins in $(map_get $map_instance "$node"); do
        local components=$(get_all_fld_data "$node#$ins" $fld_comp)
        if [ "$components" != '' ]; then
            log_info "Updating all the devices on node instance: '$node-$ins' comp: '$components'"
            local device
            for device in $components; do
                find_install "$device"
                if [ "$install_cur_ver" != '' ]; then
                    MGR_upd_device $node $device $ins "$install_cur_ver"
                elif [ "$install_alias" == '' ]; then
                    log_warning "Did not find current version for '$device', skipped MGR update!"
                fi
            done
        fi
    done
}

: <<=cut
=func_frm
Will add any standard table to to the database. This is prevent to repeat useless
names over and over again (as our tables have prefixes.
=optx
All fields to set which should be <field>=<setting> no quotes needed around
setting as long as this is one par. So "Name=test" is enough.
=cut
function MGR_add_entity_row() {
    local pfx="$1"  # (M) The prefix both the table and all given fields

    local flds=''
    shift 1
    while [ "$1" != '' ]; do
        if [ "$flds" != '' ]; then
            flds+=','
        fi
        flds+="$pfx$(get_field 1 "$1" '=')='$(get_field 2- "$1" '=')'"
        shift 1
    done
    
    MGR_shell "Adding row for $pfx" "--add ${pfx}Table --fields $flds"
}

: <<=cut
=func_frm
This function will translated a component into a device type (number) or
return it is partly managed 'Y' or not managed at all 'N'. This stupid
list is need and cannot be retrieved because the MGR does not real share this
information in a table (whcih I think it should).

This is made a MGR function and not part of the component as it is the manager
translating this.
=stdout
Will hold the device type of 'Y' in case partially managed or 'N' in 
case not managed (unknown).
=cut
function MGR_get_comp_type() {
    local comp="$1" # The textpass component to translate

    local type
    case $comp in
        RTR    ) type='1' ; ;;
        HUB    ) type='2' ; ;;
        AMS    ) type='3' ; ;;
        FAF    ) type='4' ; ;;
        LGP    ) type='5' ; ;;
        STV    ) type='6' ; ;;
        BAT    ) type='7' ; ;;
        EMG    ) type='9' ; ;; 
        SPFCORE) type='10'; ;;
        SPFSMS ) type='11'; ;;
        SPFSOAP) type='12'; ;;
        PBC    ) type='13'; ;;
        XSCPY  ) type='14'; ;;
        XSFWD  ) type='15'; ;;
        XSARP  ) type='16'; ;;
        XSSIG  ) type='17'; ;;
        XSDIL  ) type='18'; ;;
        XSBWL  ) type='19'; ;;
        IIW    ) type='20'; ;;
        CCI    ) type='Y' ; ;;
        NAF    ) type='Y' ; ;;
        *      ) type='N' ; ;; # No warning, rember adding a device/component needs adapting this list
    esac

    echo -n $type
}
