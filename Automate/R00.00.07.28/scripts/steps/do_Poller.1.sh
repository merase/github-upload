#!/bin/sh
: <<=cut
=script
Some specific functionality for an (STV) Poller. This is put in its separate
file because it cannot be part of STV. STV is not requested as package and
therefor not installed. Currently similar functionality is located in this
file to prevent double code for checking if it is a poller.
=script_note
It only does something if a poller is required on this node.
=script_note
Perhaps this approach need revising as it is some-kind of separate package
but some combined with he STV.
=version    $Id: do_Poller.1.sh,v 1.5 2015/10/01 07:01:49 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local task="$1" # (M) The task to execute like install, backup, recover

#
# This script should be removed at some point!
# It is left in incase somebody for upgrade with an OS from an older automate
# version! In which case the warning should be noted but can be ignored.
#
log_warning "The do_Poller script is called, which is obsoleted, 
please check steps file and make component STVPol is used."

is_poller_needed
if [ $? == 0 ]; then
    return $STAT_not_applic         # not needed, show it
fi

case "$task" in
    backup)
        backup_init $BCK_type_tar "$C_STV" "poller_backup" '' "STV Poller Backup for $hw_node"
        backup_base_dir "$MM_var/STV"
        backup_inf 'Poller configuration files'
        backup_add 'poller/*'
        backup_verify
        backup_execute
        backup_cleanup
        ;;

    recover)
        recover_files $C_STV 'poller_backup' "${MM_var:1}/STV/poller/config/*" / "$MM_usr:$MM_grp"
        ;;

    install)
        find_install "$C_STV"
        if [ "$install_cur_ver" != '' ]; then
            # it is already installed, so pass it
            return $STAT_passed
        fi

        # If we come here we have to install the STV, including poller, just execute step
        execute_step 0 "install_package $C_STV"
        ;;

    start|stop)
        if [ -e $MM_bin/stv_poller ]; then  # STV_poller only available if installed
            cmd_tp '' stv_poller --$task
        else
            return $STAT_not_applic
        fi
        ;;

    *) log_exit "The requested task ($task) is not recognized!"; ;;
esac
    
return $STAT_passed