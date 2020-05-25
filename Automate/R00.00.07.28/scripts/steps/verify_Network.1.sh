#!/bin/sh

: <<=cut
=script
This step verifies the Network setup. 
=brief Validation: Only 1 card (4 ports) supported, warn for more.
=version    $Id: verify_Network.1.sh,v 1.7 2017/02/22 09:05:51 fkok Exp $
=author     Frank.Kok@newnet.com

=feat configure easy network
During the process the easy network will be configured. Which will setup the 
configured interface and will allow for network access to the system.
Depending on the customer layout additional configuration might be needed.

=cut

local extra="$1"    # (O) e.g. skip_device_check
#
# Mandatory parameter checking
#
local prefix='NTW'
process_section_vars "$hw_node" "${prefix}_"
check_set "$NTW_host" "Hostname not defined for [$hw_node]"
local cur_host="$(hostname)"
if [ "$NTW_host" != "$cur_host" ]; then
    log_exit "Current hostname ($cur_host) is different then configured ($NTW_host), please fixed config!"
fi

#=# Ability to skip step as it is could be annoying in maintenance/feature upgrade.
if [ "$extra" == 'skip_device_check' ]; then
    return $STAT_passed
fi

#
# Check if there are more then 4 Ethernet devices. Which is a simple approach
# (= means cheap and not watertight) to find problem of an RHEL5.x to > RHEL6.x
# with the use of external PCI Ethernet slots. It was found that difference in 
# default udev behavior can swap the internal and external card and therefore
# the eth0-3, eth4-7 assignments would change. If that happens then then the
# standard R&D upgrade procedure (just copy the ifcfg-* and rout-* files would
# fails. 
#
# Due to the fatc that it went wrong at multiple customer it was decided to 
# let it let it solve by the tool. Still a screen info is given to notice it
# and to give Theoretically it could be solve by the tool but the resolution was
# put on hold due the expected exception of our lab. The message was changed into
# a log_manual to make sure extra attention can be given.
#
#
local max_devs=${STR_max_eth_devs:-4}   # Default here (not store lib) to shield existence. Define in automate section if ever needed
local eths="$(dmesg | $CMD_egrep 'eth[0-9]+' | $CMD_egrep -e 'node addr' -e '[0-9a-fA-F:]{17}$')"
if [ "$(echo -n "$eths" | wc -l)" -gt "$max_devs" ]; then #= more then $max_devs configured
    log_manual "Double check Ethernet configuration" "The system has more then $max_devs real Ethernet devices.
This could lead to potential problems in the 'recover Network' step.
This exceptional procedure has been automated and should fix the Ethernet
configuration. It is however advised to check the proper Ethernet assignments
$LOG_isep
Old Configuration Found:
$eths"
else
    log_info "Found Ethernet devices:$nl$eths"
fi

return $STAT_passed

