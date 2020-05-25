#!/bin/sh

: <<=cut
=script
This step disables the SElinux feature. Only needed if not done by KickStart
installation yet.
=version    $Id: disable_SElinux.1.Linux.sh,v 1.2 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

cmd 'Turning off SELinux' setenforce 0
cmd '' $CMD_sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config

return $STAT_passed
