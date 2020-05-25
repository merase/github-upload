#!/bin/sh
: <<=cut
=script
A script to allow auto start of an entity. This differentiates between 
Linux and Solaris. This is the Solaris variant.
component to be started in a service way.
=version    $Id: set_autostart.1.SunOS.sh,v 1.2 2014/11/27 12:33:15 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local what="$1"     # (M) What to do add/del/on/off for the auto-start
local script="$2"   # (M) The script to add (should be located in init.d) 
local rc_lst="$3"   # (M) A list where to instal e.g. S:K15,0:K15,3:S91)

check_in_set "$what" 'add,del'  # On/off still todo
check_set "$script"  'Need autostart script'

script="$OS_initd/$script"
    
IFS=','
local rc
for rc in $rc_lst; do
    local rcd="rc$(get_field 1 "$rc" ':').d"
    local level=$(get_field 2 "$rc" ':')
    local rcscript="$OS_etc/$rcd/$level$script"
    cmd '' $CMD_rm "$rcscript"
    if [ "$what" == 'add' ]; then
        cmd '' $CMD_ln -f "$script" "$rcscript"
    fi
done
IFS=$def_IFS

return 0