#!/bin/sh
: <<=cut
=script
This function set the Solaris specific OS variables.
=version    $Id: set_OS_vars.2.SunOS.sh,v 1.5 2015/06/03 07:11:33 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly OS_cnf_syslog='TODO ?'
readonly OS_svc_syslog='TODO ?'

readonly OS_install_ext='pkg'          # used to identify package extension

readonly OS_adm="$OS_var/adm"
readonly OS_messages="$OS_adm/messages"
readonly OS_commands="$OS_adm/commands.log" # Migth not be used on solaris

readonly OS_sfw="$OS_usr/sfw/bin"

readonly OS_system_mem_MB=$(prtconf -v | grep \"Memory size:\" | awk '{print \$3}')
readonly OS_system_mem_GB=$(((OS_system_mem_MB + 1023) / 1024))

readonly OS_fstab_options='defaults'
readonly OS_fstab_dump='1'
readonly OS_fstab_pass='2'
