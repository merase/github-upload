#!/bin/sh

: <<=cut
=script
This step disables the X11 port forwarding.
=version    $Id: disable_X11-Forwarding.1.sh,v 1.2 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local stat=$STAT_passed
if [ "$(grep -q "^X11Forwarding yes" /etc/ssh/sshd_config)" != '' ] then #= X11Forwarding enabled
    log_info "X11 forwarding is found to be enabled. Turning off X11 forwarding so it will not conflict on :6010 with AS apps"
    cmd '' $CMD_sed -i 's/X11Forwarding yes/X11Forwarding no/g' /etc/ssh/sshd_config
    func service restart ssh
else
    log_info "X11 forwarding already disabled."
    stat=$STAT_done
fi

return $stat
