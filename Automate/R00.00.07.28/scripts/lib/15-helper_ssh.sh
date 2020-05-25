#!/bin/sh

: <<=cut
=script
This script contains simple helper functions which are related to direct
SSH commands.
=version    $Id: 15-helper_ssh.sh,v 1.10 2018/02/28 13:52:17 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

: <<=cut
=func_frm
Retrieves and stores a specific SSH host key from a given host
=ret
0 if stored correctly otherwise 1
=cut
# Some local functions first
function store_ssh_host_key() {
    local ip="$1"       # (M) The related ip address
    local host="$2"     # (O) The host name, does require DNS host file configuration
    
    check_set "$ip" 'IP missing'

    local ret=1
    if [ -w $MM_known_hosts ]; then
        # First delete it. Assumes ip is stored
        cmd '' $CMD_sed "/$ip/d" -i $MM_known_hosts
    fi
    # currently locate here not within cmd as resut
    if [ "$host" != '' ]; then
        key=$(su - textpass -c "ssh-keyscan -t rsa $host,$ip" 2>/dev/null)
    else
        key=$(su - textpass -c "ssh-keyscan -t rsa $ip" 2>/dev/null)
    fi
    if [ "$(echo "$key" | grep "$ip")" != '' ]; then
        echo "$key" | sed '/^#/d' >> $MM_known_hosts
        log_info "Stored SSH host key for '$ip/$host'"
        cmd '' $CMD_chown $MM_usr:$MM_grp $MM_known_hosts
        ret=0
    else
        log_info "Failed SSH host key retrieval: $key"
    fi 

    return $ret
}

: <<=cut
=func_frm
Retrieves a SSH public key from a remote server and stored it into 
the authorized file
=ret
=cut
function retrieve_ssh_pub_key() {
    local ip="$1"       # (M) The ip address to retrieve the key from
    local chk_id="$2"   # (O) Optional id to check for existance  if NCAT unavalible and id already exists.

    local key=$(NCAT_get_data $ip $NCAT_ssh_idx)
    if [ "$key" == '' ]; then
        if [ "$chk_id" != '' ] && [ -e $MM_auth_keys_file ] && \
           [ "$(cat $MM_auth_keys_file | grep "$chk_id")" != '' ]; then
            return 2 # Indicate it exists.
        fi
        return 1     # Bailout less indenting, failure
    fi

    # Check if the identity is availble
    local id="$(get_field 3 "$key")"
    if [ "$id" == '' ]; then
        log_exit "Error: Received string does not look like a key:$nl$key"
    fi

    if [ ! -d $MM_ssh_dir ]; then
        cmd_tp 'Create .ssh dir' $CMD_mkdir $MM_ssh_dir
        cmd_tp 'Enforce correct access mode' $CMD_chmod 700 $MM_ssh_dir 
    fi

    # The current procedure never says anything about existence checking 
    # However it is possible to check so lets do so.
    if [ -e $MM_auth_keys_file ]; then
        if [ "$(cat $MM_auth_keys_file | grep "$id")" != '' ]; then     # Remove the entry
            cmd '' $CMD_sed -i "/$id/d" $MM_auth_keys_file
        fi
    fi
    # Now it can be safely added
    echo "$key" >> $MM_auth_keys_file 
    check_success "Add pub-key to $MM_auth_keys_file" "$?"
    cmd '' $CMD_chown $MM_usr:$MM_grp $MM_auth_keys_file
    cmd 'Enforce correct access mode' $CMD_chmod 600 $MM_auth_keys_file

    return 0
}

: <<=cut
=func_frm
Test if password-less communication to an ip address
using a specific user is possible
=ret
0 if communication is setup properly, otherwise 1
=cut
function test_password_less_ssh() {
    local ip="$1"   # (M) The remote ip address
    local usr="$2"  # (O) The use to text it for, defualts to $MM_usr
    
    usr="${usr:-$MM_usr}"
    
    [ -z help ] && show_trans=0 && show_short="Test password-less communication to '$usr@$ip'"
    
    # The command is local as it may fail and uses output
    local res=$(su - $usr -c "ssh -q -o 'BatchMode=yes' $ip 'echo -n It works!'")
    local ret=1
    if [ "$res" == 'It works!' ]; then
        ret=0
    else
        log_info "Password-less ssh does not work yet: $res"
    fi
    return $ret
    
    [ -z help ] && ret_vals[0]="Password-less communication to '$usr@$ip' succeeded"
    [ -z help ] && ret_vals[1]="Password-less communication to '$usr@$ip' failed"
}

