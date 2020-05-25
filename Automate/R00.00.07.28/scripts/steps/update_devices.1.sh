#!/bin/sh

: <<=cut
=script
This step configures the devices in the textpass system.
=brief Will update the device (as done in the GUI) for this all nodes to the latest version.
=fail
Collect all component version and make sure the MGR GUI in settings->devices
are updated to the correct version. In case of an upgrade execute the
long explanation given for updating the MGR to the new versions.
Only skip the step if all is done manually.
=version    $Id: update_devices.1.sh,v 1.8 2017/06/08 11:45:11 fkok Exp $
=author     Frank.Kok@newnet.com

=feat All Server, Devices and Pollers are configured in the MGR
Each available component will be configured with the necessary servers and 
pollers. Ips, ports and names.
=cut

[ "$C_MGR" == '' ] && return $STAT_not_applic                                #=!

local what="$1" # (O) Decide what todo <empty>/'all' = all node,  'on_this_node' = only comp from this node.

check_in_set "$what" "'',all,on_this_node"

if [ "$what" == 'on_this_node' ]; then
    log_info "Updating all the devices on node: '$hw_node'"
    MGR_upd_devices "$hw_node"
else
    log_info "Updating all the devices on node(s): '$dd_all_sects'"
    local node
    for node in $dd_all_sects; do
        MGR_upd_devices $node
    done
fi


#=#
#=# I've currently put the generation of the $MGR_install_cmd request in here.
#=# if it however should be automated, which is currently not done on purpose
#=# then it should get a separate step behind the syncing of the nodes (all should
#=# be upgraded). The single approach does not have it therefore it is currently
#=# put in here in case we are upgrading and in case this is the master oam
#
if [ "$STR_run_type" == "$RT_upgrade" ]; then
    MGR_is_master
    if [ $? != 0 ]; then
        log_manual 'Post upgrade MGR database update' "
If the Upgrade has been successfully completed on all the servers, then MGR
database needs to be updated for all the components.
"
        log_manual '' "Login to '$hw_node' Element with root user.$nl"
        log_manual '' "Execute the MGR database upgrade script:
  # ${COL_bold}cd $MM_bin$COL_def
  # ${COL_bold}./$MGR_install_cmd$COL_def
  a. If the database settings are correct, answer Y; otherwise, answer N and 
     adjust the settings as necessary.
  b. Answer 1 for the role as master MGR.
  c. Select the desired component from the list of components (for example, RTR).
  d. Select the new component software version. ${COL_bold}See next main point.$COL_def
  e. Repeat these steps for the remaining components on the Traffic Element, 
     Logging Element and Subscriber Element (for example, HUB, AMS, LGP, SPF,
     etc.).
  f. Apply the selected changes.
  g. Answer Y to continue with the upgrade.$nl"

        # Make a list of version just to help. I cannot actually look what is
        # is needed as manager does not use actual version.
        local ver=''
        local comp
        for comp in $dd_all_comps; do
            find_component "$comp" 
            [ $comp_device == 'N' ] && continue    # Not a managed object, skip
            find_pkg_version $CFG_dir_mm_software "${pfx_mm_pkg}$comp"
            ver+="  $(printf "%-7s $found_version" "$comp")$nl"
            # Do not add SYS assumed it stayed the same. Might need adapting.
        done
        log_manual '' "Component versions currently installed:
$ver"

        log_manual '' "If '$MGR_install_cmd' is executed before the upgrade of 
  component version, it gives below error:
    ${COL_dim}MGR Error: Can't call method 'get_available_charts' on an undefined value at
    /usr/TextPass/lib/perl5/StatView/StatsQuery.pm line 151.$COL_def
  The Above error will be removed after the component version is updated via
  '$MGR_install_cmd'. This error message can be ignored.$nl"
        log_manual '' "After the upgrade is complete, start the MGR:
  # ${COL_bold}$MM_bin/$MGR_start_cmd$COL_def$nl
  This process is finished when all MGRdata files are recreated.
  To ensure that all the updates are done, wait until the time stamps of those 
  files are later than $MGR_start_cmd was called. This can be verified using the
  following command:
    # ${COL_bold}ls -la $MM_etc/MGRdata*$COL_def$nl"

        # See if an STV could be available and if so add STV sync as well
        if [ "$C_STV" != '' ] && [ "$(get_substr "$C_STV" "$dd_all_comps")" != '' ]; then
            func $C_STV define_vars
            local pol_bck="$(get_bck_dir $C_STV 'poller_backup.tar')"

            log_manual '' "Switch to user $MM_usr.$nl"
            log_manual '' "Synchronize STV configuration data:
  $ $COL_bold$STV_admin_cmd --init_mgr_sync$COL_def$nl"
            log_manual '' "Verify stv_poller configuration files are available:
  If configuration files are not present in ‘/var/TextPass/STV/poller/config’ 
  path then copy the files from backup file:
  '$pol_bck'$nl"
            log_manual '' "Check if STV pollers ire running on all nodes involved (STVPol). In general the 
  poller will automatically restart if STVPol has been upgraded. However if the 
  node was done manually or the node did not upgrade but the OAM was then it
  would be wise to verify the STV pollers. The actual problem is in the 
  original upgrade procedure. This requires to stop all but starting depends on
  the upgraded node. Restarting did not keep in mind multiple upgrade windows.
  So verify with:
    $ $COL_bold$STV_poller_cmd --status$COL_def
  If needed start with:
    $ $COL_bold$STV_poller_cmd --start$COL_def
"
        fi
    fi
fi

return $STAT_passed

