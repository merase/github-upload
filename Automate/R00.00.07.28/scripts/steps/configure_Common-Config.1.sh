#!/bin/sh

: <<=cut
=script
This step configures the Common-Config-Files.
The common config is build out-off all the template files of all the components
within the domain (not node). Each component can have their own template
defined. 
See: '/var/automate/pkg/<COMP>/<ver>/etc/common_config.txt_template_<comp>

The source template should be setup in such a way that conflicts are resolved.

The source file only contains the standard items and assumes default for the
others. It is possible to add common config fields into the file by defining
them in the customer-data file under the [cfg/<comp>] section starting with an 
'_'. The name of the variable should match the exact name to be included.
=script_note
If this fails then make sure a minimal common_config.txt is created on the 
OAM nodes, before continuing any other steps.
=version    $Id: configure_Common-Config.1.sh,v 1.16 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

is_substr $hw_node "$dd_oam_nodes"
if [ $? == 0 ]; then
    log_info "Common config is only needed to run on a OAM element"
    return $STAT_not_applic
fi

# Check if a file exist, if so make a back-up
if [ -e $MM_common_cfg ]; then
    local time=`date +%T_%F`
    cmd 'Make backup of existing common cfg' mv $MM_common_cfg "$MM_common_cfg.$time"
fi

#=* Steps done to create the common_config file:
#=- Determining allowed config vars;
#=- Reading the common_config template files;
#=- Validating for conflicts with the host-specific files;
#=- Adding configuration items from the customer-data file;
#=- Defining ECI configuration if applicable;
#=- Determine if there is complex component specific configuration todo.
#=- Write actual file to: $MM_common_cfg

#=skip_until_marker
xml_init

#
# First step is to let the components decide what they want to allow from the 
# template. This is only needed for sub sections. It can be that a a component
# wants/needs to create the sections themselves and not sue the template. It is
# not up-to the framework.
#
for comp in $IP_TextPass $dd_all_comps; do
    func $comp define_allowed_config_vars
done

# Next read the common config files
local comp
local templ
local ext
for comp in $dd_all_comps; do
    find_install $comp
    ext="$(get_lower "$comp")"
    if [ "${ext:0:2}" == 'xs' -o "${ext:0:2}" == 'ec' ]; then
        ext="${ext:0:2}-${ext:2}"
    fi
    templ="$install_aut/etc/${MM_common_cfg_file}_template_$ext"
    if [ -e "$templ" ]; then    # Not all component have templates
        xml_read_templ "$templ" "C-$comp"
    else
        log_info "Skipped common config template for $comp (not found)."
    fi
done

# Next validate if the host specific ones would have conflicts
# this cannot be done in the loop above as all common files need to be read in first
for comp in $dd_all_comps; do
    find_install $comp
    ext="$(get_lower "$install_ent")"
    if [ "${ext:0:2}" == 'xs' -o "${ext:0:2}" == 'ec' ]; then
        ext="${ext:0:2}-${ext:2}"
    fi
    templ="$install_aut/etc/${MM_host_cfg_file}_template_$ext"
    if [ -e "$templ" ]; then    # Not all component have templates
        xml_read_templ "$templ" "H-$comp" val_only
    else
        log_info "Skipped host config template for $comp ($templ not found)."
    fi
done

#
# Now start reading the configuration sections (add some defaults).
# As this is the common config all data in the config sections (starting
# with the cfg prefix '_') will be allowed to be added.
#
local items="common networkdiscovery $dd_all_comps"
for comp in $items; do
    xml_set_data add $comp
done

# 
# Next step is todo the configuration of the ECI applications which is
# common to all XS and almost similar for PBC EC. So lets do it all the same
#
local ent
for ent in $(get_who_uses_interface $IF_tcp_ECI "$dd_all_comps"); do
    local lc_ent="$(get_lower "$ent")"
    case $ent in
        XS*) define_eci_connections $ent "$XP_tpcfg/xs#0/$lc_ent#0" 'xseci'  ; ;;
        EC*) define_eci_connections $ent "$XP_tpcfg/ec#0/$lc_ent#0" 'eci'    ; ;;
        PBC) define_eci_connections $ent "$XP_tpcfg"                'pbceci' ; ;;
        FAF) define_eci_connections $ent "$XP_tpcfg"                'fafeci' ; ;;
        *)   log_warning "Entity '$ent' says using ECI it is not yet known as type!"; ;;
    esac
done

#
# Next step is to see if there is a component common config function to do
# complex configuration.
#
for comp in $dd_all_comps; do
    func $comp define_vars                      # make sure vars are always set
    func $comp define_common_config_vars $comp
done

local date=`date +%Y`
local time=`date`
local header="<!--
    Common configuration file for the TextPass Product Suite
    (c) Copyright 2007-$date NewNet

    Create by Automation tool on : $time
-->
    <!--
        In order to avoid having to keep the configuration files on
        potentially many Traffic nodes in sync, all semi-static configuration
        parameters that apply to all Traffic nodes equally should be specified
        in the common_config.txt file, distributed from the OAM node.
        (See fxferfile-tag in {hostname}_config.txt.)
    -->
    
"

xml_write_file "$MM_common_cfg" "$header"

xml_cleanup
#=skip_until_here

cmd '' $CMD_chown $MM_usr $MM_common_cfg
cmd '' $CMD_chgrp $MM_grp $MM_common_cfg 

return $STAT_passed
