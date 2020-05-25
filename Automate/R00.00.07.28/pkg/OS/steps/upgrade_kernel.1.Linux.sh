#!/bin/sh

: <<=cut
=script
This script will upgrade a kernel (patch it). It will be need to be run under
runlevel 1, which is checked and fails if not.
=version    $Id: upgrade_kernel.1.Linux.sh,v 1.5 2017/06/08 11:45:10 fkok Exp $
=author     Frank.Kok@newnet.com
=cut


#
# Pre-checks
#
cur_runlevel="$($CMD_runlevel 2>/dev/null | cut -d ' ' -f 2)"
if [ "$cur_runlevel" != '1' -a "$cur_runlevel" != 's' -a "$cur_runlevel" != 'S' ]; then #= current run-level is not 1
    log_exit "Updating kernel only possible as run-level '1', current is '$cur_runlevel'"
fi
check_upgrade_plan_readable 
if [ ! -d $tmp_os_pkgs ]; then
    log_exit "Did not find temporary packages directory '$tmp_os_pkgs'"
fi
cmd '' $CMD_cd "$tmp_os_pkgs"

#=* Collect all kernel packages identifiable by '$upg_act_upgrade $upg_ref_kernel'
#=- Filtered content of: $STR_upg_plan_file
#=grep $STR_upg_plan_file "$upg_act_upgrade $upg_ref_kernel" 
#=- If found add package to upgrade list <krn_pkgs> as <ent>-<ver>*$OS_install_ext
#=skip_control
local line
local krn_inst=''
local krn_pkgs=''
IFS=''; while read line; do IFS=$def_IFS
    local act=$( get_field 1 "$line")
    local ref=$( get_field 2 "$line")
    local ent=$( get_field 3 "$line")
    local ver=$( get_field 5 "$line")
    [ "$ref" != $upg_ref_kernel  ] && continue
    case "$act" in
        $upg_act_upgrade) 
            if [ "$(get_substr "$ent" "$OS_kernel_inst")" != '' ]; then
                krn_inst+="$ent-$ver*.$OS_install_ext "
            else
                krn_pkgs+="$ent-$ver*.$OS_install_ext "
            fi
            ;;
        *)  log_warning "The action '$act' for '$ent' is not yet supported, ignoring."; ;;
    esac
IFS=''; done < $STR_upg_plan_file;  IFS=$def_IFS

#
# Now do the actual kernel upgrade part
#
set_install_comands '' '' 'rpm'     # TODO YUM for now use RPM until clear what and how to do it
if [ "$krn_pkgs" != '' ]; then
    cmd 'Upgrading kernel parts' $CMD_ins_upgrade $krn_pkgs
fi

# 
# Next the  kernel package(s) to be installed
#
if [ "$krn_inst" != '' ]; then
    cmd 'Installing kernel' $CMD_install $krn_inst
fi

log_info "New reboot advised, a reboot step will be executed later on."
STR_rebooted=0

return $STAT_passed
