
#!/bin/sh

: <<=cut
=script
This function decides if this node requires to create/share SSH keys with other nodes.
The function itself does nothing else. It is made in such a way that this is the place
to change if a new share type is needed. AT the moment the follow entities require
SSH sharing:
- OAM/MGR (towards the BAT)
- LGP (towards the RTR)
- STV (towards the Poller nodes)
It keep in mind if the actual remote is also being installed something otherwise it
has no use. It uses the current config setting and data file information to collects
its information.

The function behaves slightly different depending on the mode it is running in.
If the mode is 'install/recover' then all LGP<->RTR nodes are defined
If the mode is 'upgrade' then only defined (from config files) 'LGP->RTR' nodes are
defined and no LGP<-RTR nodes. So collect_SSH-Keys will not work during upgrade.
=short_help
Decides which SSH keys need to be configured, using following rules:
[MGR towards BAT], [LGP towards RTR] and [STV towards STVPol nodes]
=set SSH_pwl_peers
A node list with peers to which this server should be able to connect to (so it
has to share its pubic key and should try a password less connection).
=set SSH_pwl_servers
The nodes names which act as server. Meaning this node need to get the public 
key so that the server can connect without a password.
=version    $Id: get_SSH_share_nodes.1.sh,v 1.7 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

func STV define_vars    # Need this for STV information

SSH_pwl_peers=''
SSH_pwl_servers=''

local sep=''
local search=''

#
# First get the pwl peers
#
if [ "$(echo "$dd_oam_nodes" | grep "$hw_node")" != '' ]; then  # is_oam
    search=$C_BAT; sep=' '
fi

local lgp_peers=''
if [ "$(echo "$dd_components" | grep "$C_LGP")" != '' ]; then   # is_lgp
    if [ "$STR_run_type" != "$RT_upgrade" ]; then               # install/recover add all
        search+="$sep$C_RTR"; sep=' '
    else                                                        # upgrade (only configured
        # First get all the script which are all the 'name' within <lgprouternode>
        local cfg
        for cfg in $MM_all_cfg; do
            if [ ! -e "$cfg" ]; then
                log_warning "Did not found '$cfg', LGP SSH peers might be incomplete."
            else
                local names="$(cat $cfg | tr -d '\n' | sed -e 's/</\n</g' -e 's/"/|/g' -e "s/'/|/g" | grep 'lgprouternode' | grep 'name' | sed -e 's/.*name=|\([^|]*\).*/\1/')"
                local peer
                for peer in $names; do
                    local node="$(get_node_from_ip_or_host "$peer")"
                    lgp_peers="$(get_concat "$lgp_peers" "$node")"
                done
            fi
        done
        if [ "$lgp_peers" == '' ]; then
            log_warning "Did not find any configured LGP Router Nodes, which is kind of strange."
        fi
    fi
fi
if [ "$(get_substr "$C_STV" "$dd_components")" != '' ]; then     # is_stv
    search+="$sep$C_STVPol"; sep=' '
fi
SSH_pwl_peers="$(get_concat "$(get_nodes_where_comp_installed "$search")" "$lgp_peers")"    
log_debug "get_SSH_share(peer):  $search -> $SSH_pwl_peers"   

#
# Next the the pwl servers which is the opposite approach
#
sep=''
search=''
if [ "$(echo "$dd_components" | grep "$C_BAT")" != '' ]; then   # is_bat
    search=$C_MGR
    sep=' '
fi
if [ "$(echo "$dd_components" | grep "$C_RTR")" != '' ] &&
   [  "$STR_run_type" != "$RT_upgrade" ]; then                  # is_rtr and install/recover mode
    search+="$sep$C_LGP"; sep=' '
fi
if  [ "$(echo "$STV_poller_nodes" | grep "$hw_node")" != '' ]; then # has_poller
    search+="$sep$C_STV"; sep=' '
fi
SSH_pwl_servers=$(get_nodes_where_comp_installed "$search") 
log_debug "get_SSH_share(server): $search -> $SSH_pwl_servers"   
