#!/bin/sh
: <<=cut
=script
This function sets the generic OS variables for >= RHEL7
=version    $Id: set_OS_vars.4.Linux.RH7_0-.sh,v 1.7 2017/10/30 13:10:20 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly OS_cnf_sysctl="$OS_sysctld/99-sysctl.conf"
readonly OS_cnf_snmpd="$OS_sysconfig/snmpd"
readonly OS_cnf_snmptrapd="$OS_sysconfig/snmptrapd"
readonly OS_cnf_system="$OS_systemd/system.conf"    # indicates supported

# AS of RHEL7 no modprope bonding is required. So disable it by emptying it.
OS_cnf_modp_bonding=""