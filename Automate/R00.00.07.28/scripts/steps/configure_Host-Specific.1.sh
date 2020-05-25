#!/bin/sh

: <<=cut
=script
This step configures the Host-Specific-Config-Files.
The host  config is build out-off all the template files of all the components
of a specific node. Each component can have their own template defined. 
See: '/var/automate/pkg/<COMP>/<ver>/etc/hostname_config.txt_template_<comp>

The source template should be setup in such a way that conflicts are resolved.

The source file only contains the standard items and assumes default for the
others. It is possible to add host config fields into the file by defining
them in the customer-data file under the [<node>] section starting with an 
'_<pkg>'. The name of the variable should match the exact name to be included.
=fail
If this fails then make sure a minimal <node>_config.txt is created on this
specific node, before continuing any other steps. This by taking all the 
templates from the entities and adapt the settings as configured in 
the host specific file.
=version    $Id: configure_Host-Specific.1.sh,v 1.12 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local type="$1"     # (O) The type of prepare currently instance/<empty>
local extra="$2"    # (O) Extra information (e.g. instance number or zone name)

check_in_set "$type" "'',instance"
type=${type:-instance}
local instance=${extra:-0}

set_MM_instance "$instance"

#=* Only continue steps if there are configurable components on '$hw_node#$instance'
#=skip_control
local our_comps=$(get_all_components $hw_node instance "$instance")
if [ "$our_comps" == '' ]; then
    log_info "No components found on $hw_node#$instance"
    return $STAT_not_applic
fi

# Check if a file exist, if so make a back-up
if [ -e $MM_host_cfg ]; then
    local time="$(date +%T_%F)"
    cmd 'Make backup of existing host specific cfg' mv $MM_host_cfg "$MM_host_cfg.$time"
fi

#=* Steps done to create the host_specific file:
#=- Determining allowed config vars;
#=- Reading the host-specific template files;
#=- Stop creating if no data at all;
#=- Adding configuration items from the customer-data file;
#=- Fix settings for default fxfer items;
#=- Determine if there is complex component specific configuration todo.
#=- Write actual file to: $$MM_host_cfg

#=skip_until_marker

xml_init

#
# First step is to let the components decide what they want to allow from the 
# template. This is only needed for sub sections. It can be that a a component
# wants/needs to create the sections themselves and not sure the template. It is
# not up-to the framework.
#
for comp in $IP_TextPass $dd_all_comps; do
    func $comp define_allowed_config_vars
done

# Read the host specific files. We do not care about common config. those double
# will be checked by the common config creation.
local comp
local templ
local ext
for comp in $our_comps; do
    find_install $comp
    ext="$(get_lower "$install_ent")"
    if [ "${ext:0:2}" == 'xs' -o "${ext:0:2}" == 'ec' ]; then
        ext="${ext:0:2}_${ext:2}"
    fi
    templ="$install_aut/etc/${MM_host_cfg_file}_template_$ext"
    if [ -e "$templ" ]; then    # Not all component have templates
        xml_read_templ "$templ" "H-$comp"
    else
        log_info "Skipped host config template for $comp ($templ not found)."
    fi
done

if [ "$XML_main_xpath" == '' ]; then
    log_info "Did not find any components with host templates ($our_comps), skipping"
    xml_cleanup
    return $STAT_not_applic
fi

#
# The host specific file is filled with existing data from the config sections
# but more important any added data from the node/instance section. Therefore
# we read the config sections first (no add) and then the node instance data
# with add.
# The assumption for run<xxx>process is implicitly done bu proper template file
#
for comp in common $our_comps; do
    xml_set_data '' $comp
done
xml_set_data add '' $hw_node $instance

local set_fxfer=1
is_component_selected $MM_hw_node $C_MGR
if [ $? != 0 ]; then    # Disable file transfer on local mgr hw_node
    find_component $C_FCLIENT
    if [ "$comp_cfg_run" != '' ]; then
        xml_set_var $XP_tpcfg $comp_cfg_run $XV_false 'HS'
        set_fxfer=0     # No tpfclient do not force fxfer as not needed.
    fi
fi
 
#
# The host specific has some predefined value (no use to set them again in the data file
# The FXFER dependency is not the nicest but it works fro now
#
xml_set_var $XP_tpcfg 'ipaddress' $dd_oam_ip 'HS'
if [ $set_fxfer != 0 ]; then
    xml_set_var "$XP_fxfer1" 'serverpath' $dd_oam_ip 'HS'
    # These should have been real defines like {home} it is not,. not chnaging all templates.
    xml_set_var "$XP_fxfer0" 'localpath' "$MM_home" 'HS' "/usr/TextPass"
    xml_set_var "$XP_fxfer1" 'localpath' "$MM_home" 'HS' "/usr/TextPass"
fi

#
# Next step is to see if there is a component host specific function to do
# complex configuration.
#
for comp in $dd_components; do
    func $comp define_vars                      # make sure vars are always set
    func $comp define_host_config_vars
done

local date=`date +%Y`
local time=`date`
local header="<!--
    Host Specific configuration file for the TextPass Product Suite
    (c) Copyright 2007-$date NewNet

    Create by Automation tool on : $time
-->

"
xml_write_file "$MM_host_cfg" "$header"

xml_cleanup
#=skip_until_here

cmd '' $CMD_chown $MM_usr $MM_host_cfg 
cmd '' $CMD_chgrp $MM_grp $MM_host_cfg 

return $STAT_passed
