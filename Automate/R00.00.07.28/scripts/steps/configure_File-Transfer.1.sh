#!/bin/sh

: <<=cut
=script
This step configures the File Transfer.
=version    $Id: configure_File-Transfer.1.sh,v 1.3 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# Only a combined element can have both MGR and other components
is_component_selected $hw_node $C_MGR 
if [ $? == 1 ]; then    # This node a MGR does it have manageable devices
    has_managable_device $hw_node
    if [ $? -gt 0 ]; then
        log_info "Configuring File Transfer on combined node"
        cmd '' $CMD_cd $MM_etc
        cmd 'Remove none gzipped version' $CMD_rm MGRdata.xml
        cmd 'Remove potential link file' $CMD_rm MGRdata.xml.gz
        cmd 'Make new link for MGRdata file' $CMD_ln $MM_etc/MGRdata.xml.$dd_oam_ip.gz $MM_etc/MGRdata.xml.gz
    else
        log_info "Skipping File Transfer. MGR without manageable devices"
    fi
    # FileTransfer is enabled/disabled in the Host-Specific configuration
else
    log_info "Skipping File transfer this node does not have a MGR installed"
fi

return $STAT_passed
