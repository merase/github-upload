#!/bin/sh

: <<=cut
=script
This will call yum update for a specific component. It does not check states
or anything else. The check has to be done by upgrade_package. Only call this
if a yum updat is supported, otherwise nothing will happen.
=version    $Id: yum_update.1.Linux.sh,v 1.2 2018/10/30 12:11:08 skrish10 Exp $
=author     Frank.Kok@newnet.com
=cut

local pkg="$1"      # (M) The short-name of a package to upgrade.

# 
# Verify package existence
#
find_install "$pkg"
if [ "$install_idx" == '0' ]; then
    log_info "update $pkg: Not defined so no upgrate (not applicable)"
    return $STAT_not_applic
fi
local act_pkgs="$install_act_pkgs"
    
set_install_comands "$pkg" 
if [ $? != 0 ]; then    #= yum supported?
    #=# Let yum do this package and dependencies if needed
    if [ "$pkg" == 'STV' ]; then
        # this is a hack for the STV, it will remove the current STV packages
        # and yum install the new ones
        if [ -x $MM_bin/stv_uninstall ]; then
            cmd 'Uninstall STV' $MM_bin/stv_uninstall --no_prompt
        fi
        cmd "Use yum update for $pkg" $CMD_install $act_pkgs
    else
        cmd "Use yum update for $pkg" $CMD_ins_freshen $act_pkgs
    fi
    # Yum update it, update our internal versioning.
    update_install_info_ent "$pkg" get_pkg_version "$INS_col_cur_version"
else
    # This shoudl nto happen but lets not fail on it
    log_warning "Yum update called while not supported, report and update $pkg manually"
    return $STAT_warning
fi

return $STAT_passed
