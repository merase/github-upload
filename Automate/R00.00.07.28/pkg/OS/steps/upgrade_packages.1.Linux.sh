#!/bin/sh

: <<=cut
=script
This script will upgrade OS packages which can, but do not necessarily be 
installed under run level 1 (so no check is done).
=script_note
It is currently the assumption it is not needed to run these at run-level 1.
This approach might be changed in the future.
=version    $Id: upgrade_packages.1.Linux.sh,v 1.6 2017/12/13 14:14:55 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

#
# Pre-checks
#
check_upgrade_plan_readable 
if [ ! -d $tmp_os_pkgs ]; then
    log_exit "Did not find temporary packages directory '$tmp_os_pkgs'"
fi
cmd '' $CMD_cd "$tmp_os_pkgs"

#=* Collect all os  packages upgrade identifiable by '<any action> $upg_ref_os_pkg'
#=- Filtered content of: $STR_upg_plan_file
#=grep $STR_upg_plan_file " $upg_ref_os_pkg" 
#=- Add to the correct list based on <action=1st column>
#=inc_indent
#=* Whenever action matches [ '$upg_act_none' ]
#=- skip os package
#=* Whenever action matches [ '$upg_act_upgrade' ]
#=- Add to list <upg_pks> as <ent>-<ver>*.<arch>.$OS_install_ext
#=* Whenever action matches [ '$upg_act_install' ]
#=- Add to list <add_pks> as <ent>-<ver>*.<arch>.$OS_install_ext
#=* Whenever action matches [ '$upg_act_remove' ]
#=- Add to list <rem_pks> as <ent>
#=dec_indent
#=skip_control

# Read all the upgrade package in a single liner
local line
local upg_pkgs=''
local add_pkgs=''
local rem_pkgs=''
IFS=''; while read line; do IFS=$def_IFS    #= there are lines in the plan
    local ref=$( get_field 2 "$line")
    [ "$ref" != $upg_ref_os_pkg  ] && continue
    local act=$( get_field 1 "$line")
    local ent=$( get_field 3 "$line")
    local ver=$( get_field 5 "$line")
    local arch=$(get_field 6 "$line")
    if [ "$arch" == '' ]; then
        log_info "No architecture defined for: $line, using wildcard."
        arch='*'
    fi
    case "$act" in
        $upg_act_none) : ;;
        $upg_act_upgrade) upg_pkgs+="$ent-$ver*.$arch.$OS_install_ext "; ;;
        $upg_act_install) add_pkgs+="$ent-$ver*.$arch.$OS_install_ext "; ;;
        $upg_act_remove)  rem_pkgs+="$ent "                            ; ;; # Remove only needs name
        *)  log_warning "The action '$act' for '$ent' is not yet supported, ignoring."; ;;
    esac
IFS=''; done < $STR_upg_plan_file;  IFS=$def_IFS

# This shuld not be called when YUM support is requested so RPM is the better choice
set_install_comands '' '' 'rpm'

#
# Upgrade existing packages
#
if [ "$upg_pkgs" != '' ]; then  #= any package to be upgraded
    cmd 'Upgrading OS packages' $CMD_ins_freshen $CMD_iopt_nodep $CMD_iopt_aid $upg_pkgs
    #=# New reboot advised.
    STR_rebooted=0
fi

# 
# Add new packages
#
if [ "$add_pkgs" != '' ]; then  #= any packages to be added
    # Manual uses upgrade but we could have used install instead
    cmd 'Adding OS packages' $CMD_ins_upgrade $add_pkgs
    #=# No reboot advised if only packages added.
fi

#
# Removing old packages
#
if [ "$rem_pkgs" != '' ]; then #= any packages to be removed
    cmd 'Removing OS packages' $CMD_uninstall $CMD_iopt_nodep $rem_pkgs
    #=# New reboot advised.
    STR_rebooted=0      # New reboot advised
fi

return $STAT_passed
