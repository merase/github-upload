#!/bin/sh

: <<=cut
=script
This script is capable of syncing nodes and continue once all (given) nodes
are synced. This will make sure all continue at the same point.
There are a couple of problems to solve:
=le There is no dedicated master
=le a 2 way hand hand shake is needed because the fact that I'm ready does not have to mean the others are (communication problems)
=le Need support for multiple 'named' sync points
=le Need support for continue without sync (wait time)
=
=fail
Make sure automate is running at the same sync point on all expected nodes.
This is a sync point required by the calling procedure. It is not wise to skip
unless you are sure that all actions it is waiting for is done (which
depends on the sync reason). Also be ware that is you continue one nodes,
that other nodes might not be able to continue. This syncs is build in such
a way that all continue if they are synced with the given point.
This is for example used in the SPF installation/upgrade.

Another reason of failure could be network related, e.g.:
- Network cabling, configuration
- Firewall blocking the port being used: 9953

Best advise try no to bypass this and have them all running as you should.
But if you have to make sure you know all is done (e.g. processes started),
this sync is not there because I was having fun making it.
=version    $Id: sync_Nodes.1.sh,v 1.6 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local nodes="$1"    # (M) The nodes to sync (sep ,)m use 'All' for all configured nodes, SubProvPlat for all related to SPP
local name="$2"     # (M) The named sync point (no spaces)
local time="$3"     # (O) The time to wait before retrying, default is STR_syn_retry_time
local retries="$4"  # (O) The amount of retries, default is STR_syn_max_retries 

check_set "$nodes" 'Nodes to sync with are mandatory'
check_set "$name"  'Sync point name is mandatory.'
time=${time:-$STR_syn_retry_time}
retries=${retries:-$STR_syn_max_retries}

local SYNC_file="$OS_tmp/sync_stat.syn"

SYNC_name=$name
local org_nodes="$nodes"        # This is here for document generation!
case $nodes in
    All|all)
        #=# use nodes=[$dd_all_sects]
        nodes=$dd_all_sects
        ;;
    SubProvPlat|subprovplat) 
        #=# use nodes=[$dd_prov_plat_nodes]
        nodes=$dd_prov_plat_nodes
        ;;   
    *)  
        #=# use nodes=[$org_nodes]
        nodes=$(echo -n "$nodes" | tr ',' ' ')
        ;;
esac

#=* Filter out our own node, none left then return $STAT_not_applic
#=skip_until_marker
SYNC_mlen=0
SYNC_nodes=''
local node
for node in $nodes; do      # We have to filter our own node!
    if [ "$node" != "$hw_node" ]; then
        SYNC_nodes=$(get_concat "$SYNC_nodes" "$node")
        if [ "${#node}" -gt "$SYNC_mlen" ]; then
            SYNC_mlen="${#node}"
        fi
    fi
done
if [ "$SYNC_nodes" == '' ]; then
   return $STAT_not_applic
fi

cmd '' $CMD_rm $SYNC_file
echo -n '' > $SYNC_file
#=skip_until_here
# Start the listener to store the last information
# The information has the following format: <time sec epoch>:<node>:<name>:<status>
# status = waiting - not all has been received)
# status = synced  - all has been received by the given node
NCAT_start_listener $NCAT_syn_idx "read s; echo \"\$s\" >> $SYNC_file"


: <<=cut
=func_int
Checks if all nodes the correct last status
=set WAIT_pass_request
Will hold information in case not all file have been updated. <empty> if finished.
=need SYNC_name
=need SYNC_nodes
=need SYNC_mlen
=cut
function verify_sync_points() {
    WAIT_pass_request="Not all required nodes have synced with '$SYNC_name', status:$nl"

    [ -z help ] && show_trans=0 && show_short="all required nodes have synced with <name>"

    local map_info='SYNC_info'
    map_init $map_info

    local node
    local our_state='synced'  # Assume we are synced until proven otherwise
    for node in $SYNC_nodes; do
        map_put $map_info "$node" 'unknown'
    done

    local line
    IFS=''
    while read line; do
        node=$(get_field 2 "$line" ':')
        if [ "$(map_get $map_info "$node")" != '' ]; then
            local name=$(get_field 3 "$line" ':')
            if [ "$name" == "$SYNC_name" ]; then
                map_put $map_info "$node" "$(get_field 4 "$line" ':')"
            fi
        fi  # else:  Not of our interest at the moment
    done < $SYNC_file
    IFS=$def_IFS

    local col
    for node in $SYNC_nodes; do
        local state="$(map_get $map_info "$node")"
        case "$state" in
            unknown)        col=$COL_info; our_state='waiting'; ;;
            waiting|synced) col=$COL_ok;                      : ;;
            *) our_state='waiting'
               log_debug "Unexpected state '$state' received for node '$node'"
               ;;
        esac
        WAIT_pass_request+="$(printf "%-${SYNC_mlen}s : $col$state$COL_def" "$node")$nl"
    done

    # Send our update around
    for node in $SYNC_nodes; do
        NCAT_send_data $(get_oam_ip "$node") $NCAT_syn_idx "$(date +%s):$hw_node:$SYNC_name:$our_state"
    done

    if [ "$our_state" == 'synced' ]; then
        WAIT_pass_request=''
    else
        WAIT_pass_request+="Synchronization will be re-checked in a short while "
    fi
}

wait_until_passed "$time" "$retries" verify_sync_points
if [ $? == 0 ]; then
    # Decide not to make this blocking at the moment, so warning only
    log_warning "Exceeded max attempts, please check problem manually."
fi
NCAT_stop_listener $NCAT_syn_idx

return $STAT_passed
