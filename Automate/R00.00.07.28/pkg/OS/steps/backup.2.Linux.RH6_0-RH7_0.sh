#!/bin/sh

: <<=cut
=script
This step will do additonal backup of the OS:
- So far this is valid for a backup from RH6.x
- backup iptables (if needed/fully configured)
=version    $Id: backup.2.Linux.RH6_0-RH7_0.sh,v 1.1 2017/09/07 06:46:08 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local svc
local var
local output
for svc in iptables ip6tables; do
    # Get the status
    var="OS_col_${svc}_stat"
    $OS_initd/$svc status >> "${!var}"

    # backup the rules if any, the manual talk about .save that is however the previous one
    var="OS_col_$svc"
    output="$(service $svc save)"
    if [ "$(echo -n "$output" | grep -i 'OK')" != '' ]; then
        cmd '' $CMD_cp "$OS_sysconfig/$svc" "${!var}"
    elif [ "$(echo -n "$output" | grep -i 'nothing to save')" != '' ]; then
        log_info "No rules defined for $svc"
    else
        log_warning "Could not save rules for $svc, investigate manually."
    fi
done

return $STAT_passed
