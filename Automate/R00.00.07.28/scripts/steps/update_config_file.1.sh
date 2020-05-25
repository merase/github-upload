#!/bin/sh

: <<=cut
=script
This step will update the host config file to set the parameters.
=brief will check if parameter runtpfclientprocess and tpmgrdprocess in host config file.
=version    $Id: update_config_file.1.sh,v 1.4 2017/02/15 13:35:30 fkok Exp $
=author     nisha.gilhotra@newnet.com
=cut

local par="$1"              # (M) parameter present in NMM config file  
local set_value_to="$2"     # (<) value of paramter to set in NMM config file

is_component_selected "$hw_node" "$C_MGR"
if [ $? != 0 ]; then
    is_component_selected "$hw_node" "$C_BAT"
    if [ $? == 0 ]; then
          return $STAT_not_applic
    else 
        if [ "$par" == 'runtpfclientprocess' ]; then
            return $STAT_not_applic
        fi
    fi
fi

#check if parameter does not exists in host config file, if not then add this parameter.
#if parameter exists in NMM host config file, then change its value to $set_value_to.
local var=$(cat $MM_host_cfg  | grep "$par") 
if [ "$var" == '' ]; then   #= parameter not found yet
    cmd_hybrid 'add parameter in NMM host config file'  "$CMD_sed -i '/<tpconfig/a \ \ \ \ $par=\"$set_value_to\"' $MM_host_cfg"
else
    cmd_hybrid "set $par to $set_value_to" "$CMD_sed -i 's/$par.*/$par=\"$set_value_to\"/' $MM_host_cfg"
fi

return $STAT_passed
