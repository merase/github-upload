#!/bin/sh
: <<=cut
=script
This function set the Linux specific CMD variables.
=version    $Id: set_CMD_vars.3.Linux.RH7_0-.sh,v 1.4 2018/08/02 08:10:05 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly CMD_yum='yum'                  # This should only be used locally or testing
readonly CMD_systemctl='systemctl'      # systemctl      : Parameters just like 'systemctl'
readonly CMD_timedatectl='timedatectl'

# Definition of install options (for future multi platform support)
readonly CMD_iopt_nodep=''           # Not set for yum base install it should always check dependencies
readonly   CMD_iopt_aid=''           # Not set this is actually the default and wanted behavior


# YUM related Install commands
readonly             CMD_yum_install="$CMD_yum -y install" # install : Installs an file (in this case an RPM). Expect a file name
readonly         CMD_yum_ins_freshen="$CMD_yum -y update"  # Freshen will only upgrade existing install packages
readonly         CMD_yum_ins_upgrade="$CMD_yum -y upgrade" # Upgrade will upgrade or install and remove old versions if applicable
readonly           CMD_yum_uninstall="$CMD_yum -y erase"   # uninstall : Uninstall a package (in this case an RPM). Expect named install

readonly             CMD_yum_cfg_mgr="yum-config-manager"
readonly         CMD_yum_enable_repo="$CMD_yum_cfg_mgr --enable"  # enable repo, name or wildcard (e.g. \* or \lithium*)
readonly        CMD_yum_disable_repo="$CMD_yum_cfg_mgr --disable" # disbale repo, name or wildcard

readonly CMD_use_systemctl=1         # set to 1 if you want to use systemctl is service
