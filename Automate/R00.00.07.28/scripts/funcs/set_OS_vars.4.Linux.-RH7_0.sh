#!/bin/sh
: <<=cut
=script
This function sets the generic OS variables for < RHEL7
=version    $Id: set_OS_vars.4.Linux.-RH7_0.sh,v 1.4 2017/10/30 13:10:20 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly OS_grub_conf="$OS_etc/grub.conf"
readonly OS_cnf_sysctl="$OS_etc/sysctl.conf"
readonly OS_cnf_clock="$OS_sysconfig/clock"

