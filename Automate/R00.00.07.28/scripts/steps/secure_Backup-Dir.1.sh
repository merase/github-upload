#!/bin/sh

: <<=cut
=script
This step will secure the current backup dir.
=brief If configured: Copies the current backup dir to a remote server.
=version    $Id: secure_Backup-Dir.1.sh,v 1.3 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local what="$1" # (M) what to do 'remote; 

check_in_set "$what" 'remote'       # Currently for show prupose only

check_set "$BCK_dir"     "Please define [$sect_backup]link_dir="

if [ "$BCK_rem_server" == '' ]; then
    return $STAT_not_applic
fi
if [ ! -d "$BCK_dir/$hw_node" ]; then
    log_warning "Nothing to backup, skipping (no dir '$BCK_dir/$hw_node')"
    return $STAT_skipped
fi

BCK_rem_user=${BCK_rem_user:-root}

test_password_less_ssh $BCK_rem_server $BCK_rem_user
if [ $? == 0 ]; then    # It works fine lets happily copy it
    cmd 'Secure Backup' $CMD_scp -rp "$BCK_dir/$hw_node" "$BCK_rem_user@$BCK_rem_server:$BCK_rem_path"
else
    log_screen_info '' "Password-less login does not seem supported:"
    log_screen_info '' "* If needed add host finger print [yes]"
    log_screen_info '' "* If conflicting, stop, fix and continue automate (no par)."
    log_screen_info '' "* Type correct password for $BCK_rem_user@$BCK_rem_server"
    log_screen_info '' "--------------------------------------------------------------------"
    # Cannot do it underwater so use regular scp and wait for login prompt
    $CMD_scp -rp "$BCK_dir/$hw_node" "$BCK_rem_user@$BCK_rem_server:$BCK_rem_path"
    if [ $? != 0 ]; then    #= scp failed
        log_exit "Secure Backup failed, please check errors above."
    fi
fi


return $STAT_passed
