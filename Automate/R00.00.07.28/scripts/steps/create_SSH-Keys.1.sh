#!/bin/sh

: <<=cut
=script
This step creates a public SSH-Keys and sets-up a communication listner to
prevent the need to login.
=script_note
This is a very complex step, one should only continue if the given nodes 
are accessible. Automate does this is several steps:
- create SSH-Keys  : Creates local keys       [current step]
- collect SSH-Keys : Collects the remote keys [todo        ]
- check SSH-Peers  : Check the SSH Peers      [todo        ]

=version    $Id: create_SSH-Keys.1.sh,v 1.3 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

#=include_hlp manually_add_SSH_pwdless_peer.txt

func get_SSH_share_nodes
if [ "$SSH_pwl_peers" == '' ]; then
    return $STAT_not_applic
fi

set_cmd_user $MM_usr
cmd '' $CMD_rm $MM_id_rsa
cmd_input 'Generate public key pair' "$nl$nl$nl" ssh-keygen -t rsa
default_cmd_user

# we are not actively distributing, we start a server which can be
# accessed to get keys. At the end this node will wait until all nodes
# in the list can be accessed (which mean the others executed their task)
NCAT_start_listener $NCAT_ssh_idx "cat $MM_id_rsa_pub"

return $STAT_passed
