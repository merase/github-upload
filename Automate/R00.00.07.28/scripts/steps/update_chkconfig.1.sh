#!/bin/sh

: <<=cut
=script
This step will update the chkconfig settings.
=brief will check if process is present in chkconfig and update it accordingly
=version    $Id: update_chkconfig.1.sh,v 1.2 2017/02/15 13:35:30 fkok Exp $
=author     sanjeev.krishan@newnet.com
=cut

local process="$1"   # (M) process in chkconfig 
local state="$2"     # (M) New state for autostart : add/del/on/off

if [ "$($CMD_chkcfg | grep $process)" != '' ]; then #= $process configured exist in $CMD_chkcfg
    func $IP_OS set_autostart $state $process
else
    log_warning "$process does not exist in chkconfig."
fi

return $STAT_passed
