#!/bin/sh
: <<=cut
=script
A script to allow auto start of an entity. This differentiates between 
Linux and Solaris. This is the Linux variant. 
Until RH7 chkconfig was used.
=version    $Id: set_autostart.1.Linux.-RH7_0.sh,v 1.2 2017/02/22 09:05:50 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local what="$1"     # (M) What to do add/del/on/off for the auto-start
local script="$2"   # (M) The script to add (should be located in init.d) 

check_set "$script" 'Need auto-start script'

case $what in
    add | del ) cmd '' $CMD_chkcfg "--$what" "$script"; ;;
    on  | off ) cmd '' $CMD_chkcfg "$script" "$what"  ; ;;
    *) log_exit "Unimplemeted type '$what' requested"
esac

