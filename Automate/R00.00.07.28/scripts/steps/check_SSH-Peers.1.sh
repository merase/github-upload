#!/bin/sh

: <<=cut
=script
This step checks all the 'needed' SSH-Peers and sees if they can be 
reached with password-less communication. What is needed depends
on the installed component within this data set.
=script_note
The calculated nodes will be visible and can be used to manually
verify/fix the SSH-Peers.
The following states are being used:
- waiting     : A connection attempt is being prepared/tried
- unreachable : The node is not reachable
- accessible  : The node is correctly accessible

This is a very complex step, one should only continue if the given nodes 
are accessible. Automate does this is several steps:
- create SSH-Keys  : Creates local keys       [passed ?    ]
- collect SSH-Keys : Collects the remote keys [passed ?    ]
- check SSH-Peers  : Check the SSH Peers      [current step]
=version    $Id: check_SSH-Peers.1.sh,v 1.14 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com

=feat check SSH operation
SSH-keys are distributed through an easy protocol not requiring password login.
If the nodes are available then this can allow a smooth installation. 
The process waits until all remote peers are available. This is limited
to a configurable time. Only nodes which need SSH connectivity are checked.
=cut

#=include_hlp manually_add_SSH_pwdless_peer.txt

local what="$1"  # (O) Empty or keyword node to identify a single node being requested
local extra="$2" # (O) The node being specified.


check_in_set "$what" "'',node"

: <<=cut
=func_int
Checks if all peers are accessible. This will be called by wait_until_passed.
This function need proper definition of the hosts/statuses.
=set WAIT_pass_request
Will hold information in case not all peers are accessible. <empty> if finished.
=need TMP_stat
=need TMP_host
=cut
function verify_all_peers_accessible() {
    [ -z help ] && show_trans=0 && show_short="All needed SSH-peers are accessible [if not fix manually]"
    local num=${#TMP_host[@]}
    local idx=1
    local ok=0
    while [ $idx -le $num ]; do
        if [ "${TMP_stat[$idx]}" == 'waiting' ]; then
            TMP_stat[$idx]='unreachable'    # Back to unreachable in case the stored host key is wrong
        fi
        if [ "${TMP_stat[$idx]}" == 'unreachable' ]; then
            store_ssh_host_key "${TMP_oam_ip[$idx]}" # "${TMP_host[$idx]}" no host at the moment
            TMP_stat[$idx]=$([ $? == 0 ] && echo 'waiting' ||  echo 'unreachable')
        fi
        if [ "${TMP_stat[$idx]}" == 'waiting' ]; then
            test_password_less_ssh ${TMP_oam_ip[$idx]}
            TMP_stat[$idx]=$([ $? == 0 ] && echo 'accessible' || echo 'waiting')
        fi
        case ${TMP_stat[$idx]} in       # Simple check for wrong states (protection) + count
            waiting|unreachable) : ;; 
            accessible) ((ok++)) ; ;;   # Simply count
            *)  log_exit "Unexpected state '${TMP_stat[$idx]} in check SSH peers"; ;;
        esac
        ((idx++))              
    done

    if [ "$ok" -ge "$num" ]; then
        WAIT_pass_request=''    # Finished no more request
    else
        WAIT_pass_request="Not all SSH-peers are yet up and running, peer status:$nl"
        idx=1
        while [ $idx -le $num ]; do
            local col=$([ "${TMP_stat[$idx]}" == 'accessible' ] && echo -n "$COL_ok" || echo -n "$COL_info")
            WAIT_pass_request="$WAIT_pass_request"`printf "%-${TMP_mlen_host}s : $col${TMP_stat[$idx]}$COL_def" "${TMP_host[$idx]}"`"$nl"
            ((idx++))
        done
        WAIT_pass_request="${WAIT_pass_request}Peers will be re-tried in a short while "
    fi
}

func get_SSH_share_nodes
if [ "$SSH_pwl_peers" == '' ]; then
    return $STAT_not_applic
fi
local nodes="$SSH_pwl_peers"        # Safe it

#=# If <what> is 'node' then filter the node from <extra>, empty done with NOT_APPLIC
#=skip_control
if [ "$what" == 'node' ]; then
    check_set "$extra" 'The node should be specified'
    is_substr "$extra" "$nodes"
    if [ $? == 0 ]; then        # A node is requested which is not part of the full list
        return $STAT_not_applic
    fi
    nodes="$extra"              # Change list to the requested.
fi

# This is an interesting approach, the followings steps are taken
# - Need the host keys from all, delete once wait until all received
# - Need to be able to access, until all accessible

# It could be we skipped the create_SSH keys steps and that the listener
# never started so try to start if not runing.
NCAT_start_listener $NCAT_ssh_idx "cat $MM_id_rsa_pub"

translate_nodes_into_arrays "$nodes" 'unreachable'
[ $? == 0 ] && log_exit "Would expect array entries for '$nodes'" #=!

wait_until_passed "$STR_ssh_retry_time" "$STR_ssh_max_retries" verify_all_peers_accessible
if [ $? == 0 ]; then
    log_warning "Exceeded max attempts, please use 'automate --ssh' to finish SSH configuration."
fi

return $STAT_passed
