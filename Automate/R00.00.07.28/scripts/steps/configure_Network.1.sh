#!/bin/sh

: <<=cut
=script
This step configure the Network setup. 
=version    $Id: configure_Network.1.sh,v 1.8 2017/06/08 11:45:11 fkok Exp $
=author     Frank.Kok@newnet.com

=feat configure easy network
During the process the easy network will be configured. Which will setup the 
configured interface and will allow for network access to the system.
Depending on the customer layout additional configuration might be needed.

=cut

#
# Interface configuration
#
local prefix='NTW'
process_section_vars "$hw_node" "${prefix}_"
local ntw_vars=`set | grep "^${prefix}_"`

#=* Configure each defined network
#=- This means processing the vars starting with
#=- NTW_eth[0-9_]+ and NTW_bond[0-9_]+
#=- All found configuration will result in additional step to be executed.
#=- Example of a normal ethernet:
#=inc_indent
#=- [$hw_node]eth0 = '10.41.129.32 255.255.255.0'  
#=queue_step network_add_eth eth0 10.41.129.32 255.255.255.0
#=dec_indent
#=- Example of a bonded VLAN tagged configuration:
#=inc_indent
#=- [$hw_node]bond0_1129 = '10.41.129.58 255.255.255.0 eth0 eth1' 
#=queue_step network_add_bond bond0_1129 10.41.129.58 255.255.255.0 eth0 eth1
#=dec_indent
#=skip_until_marker

local var
local type              # Do the supported types in a loop
for type in eth bond; do    
    local ntw=$(echo "$ntw_vars" | $CMD_ogrep "${prefix}_${type}[0-9_]+")
    local intf
    for intf in $ntw; do    #= Var starting
        var="${!intf}"
        intf=$(get_field 2- "$intf" '_')
        queue_step "network_add_$type $intf $var" 
    done
done

#=skip_until_here

execute_queued_steps 
if [ $? == 0 ]; then    # none would mean no network, which is a failure
    log_exit "Did not found any network configuration, need at least 1!"
fi

# This step is for showing proper information as it can take a while to get 
# connection with the the default gateway (otherwise one would not see what it
# going on.
execute_step 0 "wait_for_default_Gate-Way"

return $STAT_passed

