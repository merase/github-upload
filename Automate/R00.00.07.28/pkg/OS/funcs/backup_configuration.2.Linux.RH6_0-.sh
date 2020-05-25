#!/bin/sh

: <<=cut
=script
This step will backup the Operating System Configuration Files.
Valid for RHEL6.0 and beyond
=version    $Id: backup_configuration.2.Linux.RH6_0-.sh,v 1.3 2017/09/06 11:40:28 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

backup_inf 'TimeZone'
backup_add 'etc/profile.d/tz.sh'        'timezone configuration'

