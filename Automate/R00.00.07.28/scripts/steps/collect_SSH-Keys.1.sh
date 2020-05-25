#!/bin/sh

: <<=cut
=script
This step collects the SSH-Keys from the required servers. It will retry if it 
does not succeed right away.
=script_note
The calculated nodes will be visible and can be used to manually
verify/fix the SSH-Peers.
The following states are being used:
- init        : A short state when intializing the data structures.
- unreachable : The node is not reachable [automate --ssh running?, network issue?]
- unexpected  : Som uexpected result was return, retry or fix manually.
- exists      : The from this node was already retrieved before.
- retrieved   : The key from this node was successfully retrieved  

This is a very complex step, one should only continue if the given nodes 
are accessible. Automate does this is several steps:
- create SSH-Keys  : Creates local keys       [passed ?    ]
- collect SSH-Keys : Collects the remote keys [current step]
- check SSH-Peers  : Check the SSH Peers      [todo        ]
=version    $Id: collect_SSH-Keys.1.sh,v 1.6 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com

=feat collect SSH keys
SSH-keys are distributed through an easy protocol not requiring password login.
If the nodes are available then this can allow a smooth installation. 
The process waits until all remote peers are available. This is limited
to a configurable time. Only nodes which need SSH connectivity are retrieved.

=cut

#=include_hlp manually_add_SSH_pwdless_peer.txt

: <<=cut
=func_int
Checks if all keys are collected from the peers. 
This will be called by wait_until_passed. This function need proper definition 
of the hosts/statuses.
=set WAIT_pass_request
Will hold information in case not all peers were collected. <empty> if finished.
=need TMP_stat
=need TMP_host
=cut
function verify_all_peers_collected() {
    [ -z help ] && show_trans=0 && show_short="All SSH-peers are collected [if not fix manually]"

    local num=${#TMP_host[@]}
    local idx=1
    local ok=0
    while [ $idx -le $num ]; do
        case ${TMP_stat[$idx]} in
            init|unreachable|error)    # Still need to get the host key
                retrieve_ssh_pub_key "${TMP_oam_ip[$idx]}" "${MM_usr}@${TMP_host[$idx]}"
                case $? in
                    0) TMP_stat[$idx]='retrieved'  ; ((ok++)); ;;
                    1) TMP_stat[$idx]='unreachable'          ; ;;
                    2) TMP_stat[$idx]='exists'     ; ((ok++)); ;;
                    *) TMP_stat[$idx]='unexpected'           ; ;;
                esac                    
                ;;
            retrieved|exists) ((ok++)); ;;
            *)  log_exit "Unexpected state '${TMP_stat[$idx]} in collect SSH keys (1)"; ;;
        esac
        ((idx++))              
    done

    if [ "$ok" -ge "$num" ]; then
        WAIT_pass_request=''    # Finished no more request
    else
        WAIT_pass_request="Did not retrieve all SSH  public keys, status:$nl"
        idx=1
        while [ $idx -le $num ]; do
            local col
            case ${TMP_stat[$idx]} in       # Decide on colors
                init|unreachable) col=$COL_info; ;;
                unexpected      ) col=$COL_fail; ;;
                exists          ) col=$COL_warn; ;; 
                retrieved       ) col=$COL_ok  ; ;;
                *)  log_exit "Unexpected state '${TMP_stat[$idx]} in collect SSH keys (2)"; ;;
            esac            
            WAIT_pass_request+=`printf "%-${mlen}s : $col${TMP_stat[$idx]}$COL_def" "${TMP_host[$idx]}"`"$nl"
            ((idx++))
        done
        WAIT_pass_request+="Servers will be re-tried in a short while."
    fi
}

func get_SSH_share_nodes
if [ "$SSH_pwl_servers" == '' ]; then
    return $STAT_not_applic
fi

# It could be we skipped the create_SSH keys steps and that the listener
# never started so try to start if not runing.
NCAT_start_listener $NCAT_ssh_idx "cat $MM_id_rsa_pub"

local nodes=$SSH_pwl_servers        # Safe it

translate_nodes_into_arrays "$nodes" 'init'
[ $? == 0 ] && log_exit "Would expect array entries for '$nodes'"   #=!

wait_until_passed "$STR_ssh_retry_time" "$STR_ssh_max_retries" verify_all_peers_collected
if [ $? == 0 ]; then
    log_exit "Exceeded max attempts, please make sure peers are enabled to share,${nl}with 'automate --ssh' and run 'automate' on this node again."
fi

return $STAT_passed
