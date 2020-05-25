#!/bin/sh
: <<=cut
=script
This function set the Linux specific CMD variables.
=version    $Id: set_CMD_vars.3.Linux.-RH7_0.sh,v 1.2 2017/06/08 11:45:10 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# Definition of install options (for future multi platform support)
readonly CMD_iopt_nodep='--nodeps'
readonly   CMD_iopt_aid='--aid'

# DO NOT USE IN NEW CODE, left in for backwards compatible (older baselines).
readonly     CMD_uninstall_nodep="$CMD_uninstall $CMD_iopt_nodep"
# END DO NOT USE

