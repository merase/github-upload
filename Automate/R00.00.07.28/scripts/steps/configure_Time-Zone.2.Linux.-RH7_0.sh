#!/bin/sh

: <<=cut
=script
This step completes configuration of the Time-Zone for < RH7
=version    $Id: configure_Time-Zone.2.Linux.-RH7_0.sh,v 1.3 2017/10/30 13:10:20 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

if [ "$GEN_os_tz" != '' ] && [ "$OS_cnf_clock" != '' ]; then
    #Setting the /etc/sysconfig/clock same as the OS Timezone specified in data file.
    clock_timezone="ZONE=\"$GEN_os_tz\""
    if [ "$( cat $OS_cnf_clock | grep "$clock_timezone")" == '' ]; then #= Clock config is not properly set
        echo "$clock_timezone" > $OS_cnf_clock
        cmd '' $CMD_chmod "+r" $OS_cnf_clock
    fi
fi

return $STAT_passed
