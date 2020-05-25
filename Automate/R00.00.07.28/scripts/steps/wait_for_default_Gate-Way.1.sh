#!/bin/sh

: <<=cut
=script
This step activates and wait for the default gateway to become available.
=version    $Id: wait_for_default_Gate-Way.1.sh,v 1.1 2015/01/19 14:07:10 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

#
# Mandatory parameter checking
#
local prefix='NTW'
process_section_vars "$hw_node" "${prefix}_"
check_set "$NTW_host" "Host-name not defined for [$hw_node]"
check_mandatory_genvar GEN_netw_def_gw

#
# Setting default gateway
#
func netw_set_def_gw $GEN_netw_def_gw

#
# Set the hostname
#
set_hostname $NTW_host

return $STAT_passed

