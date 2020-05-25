#!/bin/sh

: <<=cut
=script
This step verifies the batery or capacitator on HP GL G6-8 this to assure
the AMS preformance.
=version    $Id: verify_disk_cache.1.Linux.sh,v 1.4 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

ams=`echo $dd_components | $CMD_ogrep "AMS" | wc -l`
if [ $AMS == 0 ]; then                  #= AMS not installed in this node
    return $STAT_not_applic
fi

add_cmd_require $CMD_da_cli

#=* Information from controller is checked using:
#=- [root]# $CMD_da_cli 'ctrl all show config detail' | egrep -i -e cache -e battery
#=- Check value of 'Cache Board Present: ' should be 'True'
#=- Check value of 'Cache Status: ' should be 'OK'
#=- Correct if both set as expected, otherwise it should be checked!
#=skip_until_marker
local out=`$CMD_da_cli 'ctrl all show config detail' | egrep -i -e cache -e battery`
check_success 'Get Battery status' "$?"

local present=`echo -n "$out" | grep 'Cache Board Present: ' | $CMD_ogrep 'True'`
if [ "$present" != 'True' ];
    log_warning "The Cache Board is not present:$nl$out" 30
else
    local status=`echo -n "$out" | grep 'Cache Status: ' | $CMD_ogrep 'OK'`
    if [ "$status" != 'OK' ]; then
        log_warning "The cache is not OK, please check:$nl$out" 30
    fi
fi
#=skip_until_here

return $STAT_passed
