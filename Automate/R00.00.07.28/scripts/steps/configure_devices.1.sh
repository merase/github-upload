#!/bin/sh

: <<=cut
=script
This step configures the devices in the textpass system.
=version    $Id: configure_devices.1.sh,v 1.7 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com

=feat All Server, Devices and Pollers are configured in the MGR
Each available component will be configured with the necessary servers and 
pollers. Ips, ports and names.
=cut

MGR_is_master
if [ $? == 0 ]; then
    return $STAT_not_applic
fi

log_info "Adding all the devices on nodes: '$dd_all_sects'"
MGR_devices_to_add=''
local node
for node in $dd_all_sects; do
    MGR_add_devices $node
done

if [ "$MGR_devices_to_add" != '' ]; then    #= Your MGR is too old
    # Oops an too old version of tp_shell. lets make it it manual request
    log_info "MGR too old, cannot add:$nl$MGR_devices_to_add"   #=!
    manual_step "${COL_warn}Your MGR version is too old cannot add device automatically$COL_def
Please add the following devices in Settings->Network Layout->Devices :
$MGR_devices_to_add"
fi

return $STAT_passed

