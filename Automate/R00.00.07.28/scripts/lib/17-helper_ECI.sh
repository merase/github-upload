#!/bin/sh

: <<=cut
=script
This script contains simple helper functions which are related to the ECI 
configuration.
=version    $Id: 17-helper_ECI.sh,v 1.3 2014/12/01 13:13:50 fkok Exp $
=author     Frank.Kok@newnet.com

=feat ability to configure ECI clients for entities who need them
A basic ocnfiguration is established for entities who need ECI connections.
By default an ECI entity will establish a connection to all available
RTR in the system.

=feat ability to configure simple ECI application in the RTR.
Each entity type in need of ECI also needs to have a valid ECI application.
A default one will be registered.
=cut

: <<=cut
=func_frm
Create an EC application within the manager.
=func_note
This function will take the additional variable from the variable 
${ent}_ec_include_flds. If it exists then those includes fields will be appended.
The name should be without the <table prefix>Include<xxx>Field. So <xxx>=1
${ent}_ec_other_flds. Will also be appended. This is without table prefix. 
=need ${ent}_eci_uid
Should hold the UID to use for ECI
=need ${ent}_eci_pw
Should hold the PWD to use for ECI
=need ${ent}_eci_max_inact
Optional which can hold an inactivity time to configure.
=need {$ent}_ec_include_fields
Optional list (sp separated) with include fields to set. The fields will be
appended. The item are bare minum, not table, no 'Include' nor 'Field' So
ExternalApplicationInclude<xxx>Field becomes <xxx>=1
=need ${ent}_ec_other_fields
Other field to be append, the tbale name does not need to be included.
=cut
function create_ec_application() {
    local ent="$1"       # (M) The comp requesting this

    log_info "Creating EC-App for $ent"

    func $ent define_vars                       # make sure vars are always set

    local eci_uid="${ent}_eci_uid"
    local eci_pw="${ent}_eci_pw"
    local eci_inact="${ent}_eci_max_inact"  # Optional
    local t="${ent}_ec_include_flds"
    local inc_flds=$(echo -n "${!t}" | sed 's/(^| )+\(.*\)=/Include\1Field/g')
          t="${ent}_ec_other_flds"
    local oth_flds="${!t}"
    if [ "${!eci_inact}" != '' ]; then
        oth_flds+="MaxInactivityTime=${!eci_inact}"
    fi

    MGR_add_entity_row 'externalCondition'                               \
                            "Name=$ent-ECApp"                            \
                            "Description=Auto generated EC-App for $ent" \
                            "UserIdentity=${!eci_uid}"                   \
                            "Password=${!eci_pw}"                        \
                            $oth_flds $inc_flds 'AdminState=1'
}

: <<=cut
=func_frm
Creates the ECI connections for the given entity/section. In the comman
=func_note
This function assumes the xml template has been initialized, which could be
the common config or the host-specific (the function does not know the difference).
If will make sure the variable of the given entity are read.
=need ${ent}_eci_uid
Should hold the UID to use for ECI
=need ${ent}_eci_pw
Should hold the PWD to use for ECI
=need ${ent}_eci_max_inact
Optional which can hold an inactivity time to configure.
=cut
function define_eci_connections() {
    local ent="$1"       # (M) The comp requesting this
    local main="$2"      # (M) The xpath to start from so e.g. $XP_tpcfg or $XP_tpfcfg/XS#0/xscpy#0
    local sub="$3"       # (M) The last sub xpath which holds the config e.g. pbeci or xseci
    local nof_con="$4"   # (O) The amount of nodes to connect to, empty all (other not implemented yet)

    log_info "Creating ECI definitions for $ent"

    # This is an ugly exception for the FAF who is the only one against the
    # other 10+ eci application which do it the same! Would be nice if FAF was in line.
    local fld_uid=$([ "$ent" != "$C_FAF" ] && echo -n 'useridentity' || echo -n 'user')
    local fld_pwd=$([ "$ent" != "$C_FAF" ] && echo -n 'password'     || echo -n 'pass')
    local fld_nam=$([ "$ent" != "$C_FAF" ] && echo -n 'name'         || echo -n ''    )

    func $ent define_vars                       # make sure vars are always set

    local eci_uid="${ent}_eci_uid"
    local eci_pw="${ent}_eci_pw"
    local eci_inact="${ent}_eci_max_inact"  # Optional

    local rtr_comps="$(echo -n "$dd_full_system" | grep "^$C_RTR")"
    if [ "$numb" != '' ]; then
        log_warning "Selecting an amount is not implemented, selecting all"
        # TODO make an adapted comps list which is predictable for this hw_node
        # and which has preferable multiple routers on multiple nodes (if numb allows)
        # for now leave it is not needed!
    fi

    #
    # The ECI entity should connect to all given routers in the system through ECI
    #
    local comp
    local idx=0
    for comp in $rtr_comps; do
        local data=$(get_field 2 "$comp" '@')
        local node=$(get_field 1 "$data" ':')
        local inst=$(get_field 2 "$data" ':');  inst=${inst:-0}
        local xp="$main/$sub#$idx"
        ((idx++))
    
        if [ "$fld_nam" != '' ]; then
            xml_set_var "$xp" "$fld_nam" "RTR-$node-$inst"                     "$ent"
        fi
        xml_set_var "$xp" 'host'     "$(get_oam_ip "$node")"                   "$ent" 
        xml_set_var "$xp" "$fld_uid" "${!eci_uid}"                             "$ent" 
        xml_set_var "$xp" "$fld_pwd" "${!eci_pw}"                              "$ent" 
        xml_set_var "$xp" 'port'     "$(get_instance_port '' eci_port  $inst)" "$ent" 
        if [ "${!eci_inact}" != '' ]; then
            xml_set_var "$xp" 'maxinactivitytime' "${!eci_inact}"              "$ent" 
        fi
    done
}
