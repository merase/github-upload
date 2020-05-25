#!/bin/sh

: <<=cut
=script
This step will backup the Operating System Configuration Files.
Valid for after RHEL7.0
=version    $Id: backup_configuration.3.Linux.RH7_0-.sh,v 1.1 2017/12/06 12:05:40 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# Entries for grub config 
backup_inf 'Grub Config'
backup_add 'etc/grub2.cfg'              'Grub Configuration' 'opt'
backup_add 'etc/grub.d/*'               'Grub Files'         'opt'
