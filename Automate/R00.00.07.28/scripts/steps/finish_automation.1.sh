#!/bin/sh

: <<=cut
=script
Special script to finish the installation. 
=brief Will finish the automation and makes sure it is in a clean state.
=fail
If this step would fail then it can be skipped/ignored. It should be the last
cleanup step in the process. An new automate --restart will also get a next
run into a clean state.
=version    $Id: finish_automation.1.sh,v 1.9 2017/06/08 11:45:11 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# The store file could be in a secondary place like backup. TO make sure that
# that is will be located in the one and only place, remove it an then request
# a new name a write it
if [ "$AUT_store_file" != '' ] && [ "$AUT_store_file" != "$AUT_pref_store_file" ] && [ -e "$AUT_store_file" ]; then #= Store no in preferred place
    cmd 'Finishing, remove store file' $CMD_rm "$AUT_store_file"
    select_store_file $AUT_pref_store_file
fi

# Also remove any recovery boot data like automate --clean
func store_boot_data clean

# The store file sticks, just make sure the STR_exec_steps are cleared
STR_exec_steps=''
store_current_state

# See if we should/can disable the MGR shell, will only do something on master 
# OAM and does not matter if fails.
[ "$C_MGR" != '' ] && MGR_disable_shell     #=!

log_info 'Finished automation process.'

return $STAT_passed
