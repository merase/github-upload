#!/bin/sh

: <<=cut
=script
This step completes configuration of the Time-Zone for RH7 >
=version    $Id: configure_Time-Zone.2.Linux.RH7_0-.sh,v 1.4 2017/10/30 13:10:20 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

if [ "$GEN_os_tz" != '' ]; then
    cmd '' $CMD_timedatectl set-timezone "$GEN_os_tz"
fi

return $STAT_passed
