#!/bin/sh

: <<=cut
=script
This step will backup the Operating System Configuration Files.
Valid for before RHEL7.0
=version    $Id: backup_configuration.3.Linux.-RH7_0.sh,v 1.1 2017/10/30 13:10:19 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

backup_inf 'Network Configuration (pre RHEL7)'
backup_add 'etc/sysconfig/clock'

