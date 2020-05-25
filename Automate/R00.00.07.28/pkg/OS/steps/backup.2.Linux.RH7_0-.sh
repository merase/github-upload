#!/bin/sh

: <<=cut
=script
This step will do additonal backup of the OS:
- So far this is valid for a backup from RH7.0 and beyond
- backup iptables (if needed/fully configured)
=version    $Id: backup.2.Linux.RH7_0-.sh,v 1.1 2017/12/06 12:05:40 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local svc
local var
local output
for svc in iptables ip6tables; do
    # Get the status
    var="OS_col_${svc}_stat"
    $CMD_systemctl status $svc>> "${!var}"

    # backup the rules if any, the manual deos not mention saving anymore
    var="OS_col_$svc"
    if [ -e "$OS_sysconfig/$svc" ]; then
        cmd '' $CMD_cp "$OS_sysconfig/$svc" "${!var}"
    else
        log_info "No rule file found for $svc"
    fi
done

return $STAT_passed
