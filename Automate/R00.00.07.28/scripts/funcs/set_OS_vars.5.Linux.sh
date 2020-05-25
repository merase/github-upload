#!/bin/sh
: <<=cut
=script
This function sets the generic OS variables which are valid for all Linux versions
=version    $Id: set_OS_vars.5.Linux.sh,v 1.4 2017/10/30 13:10:20 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

#continue syslog parameters generic linux
readonly OS_syslogd="$OS_etc/$OS_svc_syslog.d"
readonly OS_cnf_syslog="$OS_etc/$OS_svc_syslog.conf"
readonly OS_sys_syslog="$OS_sysconfig/$OS_svc_syslog"

# Set fstab variable readonly
readonly OS_fstab_options
readonly OS_fstab_dump
readonly OS_fstab_pass

readonly OS_cnf_modp_bonding
