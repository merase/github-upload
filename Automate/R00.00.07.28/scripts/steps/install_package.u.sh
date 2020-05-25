#!/bin/sh

: <<=cut
=script
This step uninstalls any package delivered by NewNet and which is part
of the package list of the automation tool.

This routine only uninstall the actual package no pre-remove is called (yet)
=version    $Id: install_package.u.sh,v 1.9 2017/06/08 11:45:11 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local name="$1"		# (M) Name of package to be installed.

find_install "$name" # Find the install information, keep copies as func calls tend to change the globals
local ins_ent=$install_ent      
local ins_dire=$install_dir
local ins_pkgs=$install_pkgs    # Want all to allowed old and new

func "$name" pre_uninstall    # Execute optional pre uninstall (up-to the package)

local stopped=0
local pkg
local ins
for pkg in $ins_pkgs; do            # Do all listed packages
    func get_pkg_version $ins_ent $ins_dire $pkg
    if [ "$func_return" != '' ]; then
        local cur_ver="$func_return"
        if [ $stopped == 0 ]; then
            for ins in $(get_all_components "$hw_node" ins_comp "$ins_ent"); do   #= all instances of $ins_ent on $hw_node
                set_MM_instance "$ins"
                func $ins_ent service stop
            done
            stopped=1
        fi
        set_install_comands "$name" "$cur_ver"
        default_cmd_user                 # to be sure and indicate if needed
        if [ "${pkg:0:1}" == '*' ]; then # Wildcard package
            local wc_pkg
            for wc_pkg in $($CMD_ins_query_all | grep "^${pkg:1}"); do
                cmd 'Uninstalling (wildcard)' $CMD_uninstall $CMD_iopt_nodep $wc_pkg
            done
        else
            cmd 'Uninstalling (single)' $CMD_uninstall $CMD_iopt_nodep $pkg
        fi
        update_install_pkg_field $name $pkg "$INS_col_cur_version" ''
    else
        log_debug " The package '$name' is not installed"
    fi
done

func "$name" post_uninstall    # Execute optional post uninstall (up-to the package)

return $STAT_passed
