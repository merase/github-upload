#!/bin/sh

: <<=cut
=script
This script contains simple helper functions which are not bound to the
main automation script

There are currently little checks to the correct contents of the data
fields. This because a sunny day is assumed. The future assumption is that
the files are generated and therefore should not contain fundamental errors.
It is currently a wast of time to spent effort if making something secure 
which should be secure at a different spot. Tis approach might change but for 
now it safes time.
=version    $Id: 20-config_read.sh,v 1.54 2017/09/12 08:43:48 fkok Exp $
=author     Frank.Kok@newnet.com

=feat fully configurable Customer Data
The data file actually contains all the information needed to run the process.
It can contain the following configuration sections:
* automation too
* generic site
* configuration per component
* configuration per node/zone
* configuration per node-instance

=script_note
It would be nice if the deducing of data moves into a function as it has
'knowledge' and should not be in part of the main functionality.
=cut

# these var are used to return information
data_type=''        # The type actually defines the parameters
data_full=''        # Al the field parameters (the whole string)
data_par1=''        
data_par2=''
data_par3=''
data_par4=''

readonly   sect_automate='automate'
readonly    sect_generic='generic'
readonly     sect_backup='backup'
readonly        sect_cfg='cfg'   # A config section used for a product or other specific stuff
readonly        sect_dis='dis'   # A disabled section without the need to uncomment items just [dis/<org_sect>]
readonly        sect_iso='iso'   # An iso definition section

readonly           regex_ins='#[0-9]$' 
readonly     regex_step_comp='<components>'
readonly regex_step_spp_comp='<spp_components>'
readonly     regex_step_inst='<instances>'
readonly     regex_step_prod='<products>'
readonly     regex_step_supp='<supporting>'
readonly   regex_step_sw_iso='<sw_iso>'
readonly   regex_step_os_iso='<os_iso>'

readonly first_instance=0
readonly  last_instance=9

readonly            fld_sect='sect'
readonly            fld_comp='comp'
readonly         fld_element='element'
readonly            fld_host='host'
readonly              fld_ip='ip'
readonly          fld_serial='serial'
readonly       fld_ntp_sever='ntp_server'
readonly         fld_oam_lan='oam_lan'          # Either Ip of ethernet or bond
readonly          fld_oam_ip='oam_ip'           # An translated ip adress of oam_lan
readonly        fld_oam_role='oam_role'
readonly            fld_netw='network'          # Contains list of ips used for the <type>_lan
readonly      fld_hub_ext_ip='hubipaddressownexternal'
readonly    fld_hub_ext_ipv6='hubipv6addressownexternal'
readonly  fld_iiw_sec_ext_ip='iiwSecondaryExternalIp'
readonly      fld_iiw_ext_ip='iiwipaddressownexternal'

readonly   fld_type_netw_oam='oam'

readonly        fld_pfx_cfg='_'

readonly     map_sect='CFG_sect'        # The plain section used for acces trhough easy script file
readonly     map_data='CFG_data'        # The translated data items per section, for easier single access and deduce data
readonly map_instance='CFG_instance'
readonly   map_deduct='CFG_deduced'     # Deduced data. It is a start not all is in there (future)

# The selected information
hw_node=''              # The node name belonging this hardware
hw_info=''              # The info belong to this hardware
hw_serial_number=''     # The hardware serial number of this node
hw_sel_type=''          # How is the hardware node selected (identified,selected)

# The deducted data
dd_all_sects=''     # A list with all node sections (not generic,cfg, etc) not sub sections
dd_all_comps=''     # A list with all type of components on all the nodes
dd_components=''    # A list with the component on the selected node
dd_supporting=''    # A list with other supporting packages on the nodes
dd_full_comps=''    # A list with comps on the selected node (sep by \n). This is the full name <ent>@<sect>:<instance>
dd_full_system=''   # A list (not unique) with all component (sep by \n). This is the full name <ent>@<sect>:<instance>
dd_instances=''     # A list of all instance number. 0 if only main. Empty is no comps at all
dd_instanciated=0   # 0 if only one main instance, otherwise 1 
dd_host=''          # The host name being installed
dd_oam_master=''    # The designated master (normally first in the list below or define by OAM_master)
dd_oam_nodes=''     # A list with OAM nodes (first is potential designated master)
dd_oam_ip=''        # The ip of the local OAM lan
dd_is_oam=0         # !0 then this is an OAM node (either master or s;ave MGR)
dd_sw_iso_file=''   # The selected sw iso file (if selected and needed).

dd_ndb_needed=0       # 1 if NDB is installed somewhere within the system (1 SPF available)
dd_ndb_mgr_nodes=''   # The node(s) having a NDB MGR, empty if none needed.
dd_ndb_mysql_nodes='' # The node(s) which should install MySQL ndb sever (default to all SPF nodes)
dd_ndb_data_nodes=''  # THe node(s) which should install NDB Node (defaults to all SPF nodes)
dd_prov_plat_nodes='' # The nodes(s) involved, with subscriber provision platform (so all ndb + ndb_api users + SPF)
dd_prov_plat_comps='' # The components involved with the SPP


 
: <<=cut
=func_int
Retrieve all data belong to a section
=set sel_output
is set to the config found or exit if not found
=cut
function select_all_data() {
    local section="$1"      # (M) The node/section to select_all_data
    
    sel_output=$(map_get $map_sect $section)
    if [ "sel_output" == '' ]; then
        log_exit "Did not found data for [$section], wrong configuration?"
    fi
}

: <<=cut
=func_int
Set all the data of a specific line. For easyness a couple
of fields are exported.
=set data_type
The field type/name (the text in front of the '=' sign
=set data_full
The data (the text after the '=' sign
=set data_par[1-4]
Translated data parameters, which are seperated by spaces.
=cut
function set_fld_data() {
    local line="$1"     # (M) The input line to set

    if [ "$line" != '' ]; then
        data_type=`echo "$line" | cut -d'=' -f 1`
        data_full=`echo "$line" | cut -d'=' -f 2`
        data_par1=`echo "$data_full" | cut -d' ' -f 1` 
        data_par2=`echo "$data_full" | cut -d' ' -f 2` 
        data_par3=`echo "$data_full" | cut -d' ' -f 3` 
        data_par3=`echo "$data_full" | cut -d' ' -f 4` 
    else
        data_type=''
        data_full=''
        data_par1=''
        data_par2=''
        data_par3=''
        data_par4=''
    fi
}

: <<=cut
=func_int
Selects a specifc line out of the info of a given section
=man1 info
The info to select from.
=man2 field
The field to search for.
=cut
function select_line() {
    # Sed filters the '' for internal reading
    sel_line=`echo "$1" | grep "^$2" | sed "s/\(.*\)=[ \t]*'\(.*\)'.*/\1=\2/"`
}

: <<=cut
Always return the main section stripping of the instance number.
=stdout
The main section name. If already main then it is returned as is.
=cut
function get_main_sect() {
    section="$1"    # (M) The section to return the main for.

    echo "$section" | $CMD_ogrep '^[0-9a-zA-Z_/\-]+'
}

: <<=cut
Retrieves the instance number of a section (if any)
=stdout
The instance number or empty if none.
=cut
function get_instance() {
    section="$1"    # (M) The section to return the instance number for

    echo -n "$section" | $CMD_ogrep "$regex_ins" | cut -b 2-
}

: <<=cut
=func_int
Get all the components to be installed on a node. This includes
all the components of all the instances. It will not filter doubles
=opt2
Denotes what should be returned.
- <emtpty>: A list of entity names separated by space
- full          : A full list separated with \n. <ent>@<node>:<instance #>
- instances     : Only a list with instance number which have component separated by space
- instance      : A list of entities names on specific instance separated by space
- ins_comp_full : A list with instances (<name> [instance #] $nl) for a particular 
                  component/package. None components will return <name>. If not
                  insatnciated and thus on main then it will return <name>.
- ins_comp      : A list with only a instance # separated by space for a particular
                  component/package. None components will return '-'.
=opt3
An instance list, usage depends on what:
- instance : (O) Only entity for a specific instance or instances (separate by ,).
- ins_comp : (M) Single component to check for instancing. *Empty means assume not instanced.
=stdout
The list of all components separated by a space.
=cut
function get_all_components() {
    local section="$1"      # (M) The node/section to select it for.
    local what="$2"
    local ins_list="$3"     # (O) Only entity for a specific instance or instances (separate by ,).

    check_set "$section" "Section not given"
    check_in_set "$what" "'',full,instance,instances,ins_comp,ins_comp_full"
    
    # A pre-check before going into the mainloop
    case "$what" in
        instances)  echo -n "$(map_get $map_instance $section)"
                    return
                    ;;
        ins_comp*)  check_set "$ins_list" "A component has to be given for '$what'"
                    # Is it  a component? Or not incapacitated, if so return empty
                    if [ "$(get_substr "$ins_list" "$dd_components")" == '' ]; then
                        [ "$what" != 'ins_comp' ] && echo "$ins_list" || echo "-"
                        return
                    fi
                    ;;
    esac

    local instances="$(get_instance "$section")"
    if [ "$instances" == '' ]; then     # It is the main section
        instances="$(map_get $map_instance $section)"
    else                                # Make section the main
        section="$(get_main_sect "$section")"
    fi
    
    local ins
    for ins in $instances; do
        select_all_data "$section#$ins"
        select_line "$sel_output" "$fld_comp"
        set_fld_data "$sel_line"
        if [ "$data_full" != '' ]; then
            case "$what" in
                full)
                    local e
                    for e in $data_full; do 
                        echo "$e@$section:$ins"
                    done
                    ;;
                instance)
                    if [ "$ins_list" == '*' ]; then
                        echo -n "$sep$data_full"
                    elif [ "$(echo "$ins_list" | tr ',' '\n' | grep "$ins")" != '' ]; then
                        echo -n "$sep$data_full"
                    fi
                    ;;
                ins_comp_full)
                    # See if this component is on this instance
                    if [ "$(get_substr "$ins_list" "$data_full")" != '' ]; then
                        [ "$dd_instanciated" == '0' ] && echo "$ins_list" || echo "$ins_list instance $ins"
                    fi
                    ;;
                ins_comp)
                    # See if this component is on this instance main is allways 0
                    if [ "$(get_substr "$ins_list" "$data_full")" != '' ]; then
                        echo -n "$sep$ins"
                    fi
                    ;;
                '')       echo -n "$sep$data_full"; ;;
                *)        log_exit "Unhandled what ($what) for get_all_components."; ;;
            esac      
            sep=' '          
        fi
    done   
}

: <<=cut
Count the amount of components of a specific type.
=cut
function get_count_specific_comp() {
    # TODO
    echo -n "0"
}

: <<=cut
=func_int
Decudes some data for the selected node which can be
used at a later stage
=set dd_components
A list with all the components for this node
=set dd_full_comps
A list with all the compon
=set dd_instances
A list with instances who have a component installed
=set dd_instanciated
Will be 0 if only one main instance (or none). Anything else will set it to 1.
=set dd_host
The host name.
=set dd_oam_ip
The OAM IP.
=cut
function deduce_node_data() {
    # Find the components
    dd_components=$(get_all_components $hw_node)
    dd_full_comps=$(get_all_components $hw_node full)

    # find instances
    local instances=$(get_all_components $hw_node instances)
    if [ "$STR_instances" == '*' ]; then
        dd_instances=$instances
    else        # Filter on the instances on the list
        dd_instances=''
        local i
        local sep=''
        for i in $instances; do
            if [ "$(echo "$STR_instances" | tr ',' '\n' | grep "$i")"  != '' ]; then
                dd_instances="$sep$i"
                sep=' '
            fi
        done
    fi
    if [ "$dd_instances" == '' -o "$dd_instances" == '0' ]; then
        dd_instanciated=0
    else
        dd_instanciated=1
    fi
    
    # Find element type
    select_all_fld_data $hw_node $fld_element
    dd_element="$data_par1"

    # Find host data
    select_all_fld_data $hw_node $fld_host
    dd_host="$data_par1"

    # Find the OAM ip
    select_oam_ip $hw_node
    dd_oam_ip="$sel_ip"

    # See if this a potential OAM node
    is_substr $hw_node "$dd_oam_nodes"
    dd_is_oam=$?
}

: <<=cut
=func_int
Selects a given node/section. It is allowed that the section
cannot be found.
=set hw_node
The found node/section. '' if not found.
=set hw_info
The related informaion. '' if not found.
=cut
function select_section() {
    local section="$1"      # (M) The node/section to search for.
    
    hw_node=''
    hw_info="$(map_get $map_sect $section)"
    if [ "$hw_info" != '' ]; then
        hw_node="$section"
    fi
}

: <<=cut
=func_int
This will select a section and set all sct_<var> variables
Each variable in the section will become a vars. This is means variable can be
added without changing read functionality. You of-course need to access the var.
=opt2 
The prefix to use in front of the variables. If not given then none is used
otherwise <prefix>*. Make sure there are not conflict in no prefix is used.
=opt3
If givnen then only items starting with this are selected. This filter is also
removed from the name.
=cut
function process_section_vars() {
    local section="$1"  # (M) The section[#instance] to read
    local prefix="$2"
    local filter="$3"
    
    [ -z help ] && show_short="Info: Read vars, from [$section], add prefix: '$prefix'"
    [ -z help ] && [ "$filter" != '' ] && show_short+=", filter: '^$filter'"
    [ -z help ] && show_trans=0

    select_all_data $section
    local tmp="$(mktemp)"
    echo "#!/bin/sh" > $tmp
    # Remove space before and after '=' but also adds the section
    local regex="s/^$filter\([a-zA-Z0-9_]*\)[ \t]*=[ \t]*['\"]*\(.*\)['\"]/$prefix\1=\"\2\"/g"
    echo "$sel_output" | grep "^$filter" | sed "$regex" >> $tmp
    check_success "Create sections vars file into $tmp" "$?"
    chmod +x $tmp
    . $tmp
    check_success "Read sections vars from [$section] as '${prefix}*' filter '$filter'" "$?"
    remove_temp $tmp
}

: <<=cut
=func_int
This function can create handy deducted data for easy processing
as the data itself does not change it will only need a one time initialization
This is not done for data which is directly accessible. But e.g. for the
list of OAMD nodes. The information is taken from the currently read data.
=set dd_oam_nodes
A list with all the OAM nodes.
=set dd_all_comps
A list with all the components for all the nodes/sections.
=cut
function deduce_data() {
    dd_all_sects=''
    dd_oam_master=''
    dd_oam_nodes=''
    dd_oam_def_domain=''
    dd_oam_domains=''
    dd_all_comps=''
    dd_ndb_needed=0
    dd_ndb_mgr_nodes=''
    dd_ndb_mysql_nodes=''
    dd_ndb_data_nodes=''
    dd_prov_plat_nodes=''       # Clear only set in late_deduce_data
    dd_prov_plat_comps=''       # Clear only set in late_deduce_data

    local oam_master=''
    local oam_master_fnd=0
    if product_enabled "$PRD_TextPass"; then    # Setting them is only needed for textpass
        read_config_vars OAM
        [ "$OAM_master" != ''  ] && oam_master="$OAM_master"
        dd_oam_def_domain=${OAM_def_domain:-main}           # The default is main if not given
        dd_oam_domains=${OAM_domains:-$dd_oam_def_domain}   # Set to default if none defined.
    fi

    local sect
    for sect in $(map_keys $map_sect); do
        case $sect in
            $sect_automate|$sect_generic|$sect_backup|$sect_cfg|$sect_dis|$sect_iso)
                :       # Do nothing
                ;;
            '') log_exit "Syntax error: Empty section in data file"; ;;
            *)
                # Only for the main section.
                if [ "$(get_instance "$sect")" == '' ]; then
                    dd_all_sects=$(get_concat "$dd_all_sects" "$sect")

                    # Make a list of all the components. Uniqueness filtered later
                    dd_all_comps=$(get_concat "$dd_all_comps" "$(get_all_components $sect)")
                    dd_full_system="$(get_concat "$dd_full_system" "$(get_all_components $sect full)" "$nl")"
                fi

#
# TODO the oam node definition and ndb definition should move out of
# this generic location. For now left it in as it does not conflict with others
# yet.
                # Remember MGR and SPF-CORE may currently only run on a main instance#0 so 
                # If this ever changes then things has to be improved here!
                # First adapt the section to store the proper names only once.
                if product_enabled "$PRD_TextPass"; then
                    if [ "$dd_instanciated" == '0' ]; then
                        [ "$(get_instance "$sect")" != '' ] && sect=''     # Skip this section
                    elif [ "$(get_instance "$sect")" == '0' ]; then
                        sect="$(get_main_sect "$sect")"
                    else
                        sect=''
                    fi
                fi

                if product_enabled "$PRD_TextPass" && [ "$sect" != '' ]; then   # Safes indent level
                    # Make list of the OAM nodes. An OAM nodes is where a MGR is being installed
                    if [ "$C_MGR" != '' ]; then         # Can only be done if MGR is available
                        is_component_selected "$sect" $C_MGR
                        if [ $? != 0 ]; then
                            if [ "$sect" == "$oam_master" ]; then   # insert in front
                                oam_master_fnd=1
                                dd_oam_nodes=$(get_concat "$sect" "$dd_oam_nodes")
                                dd_ndb_mgr_nodes=$(get_concat "$sect" "$dd_ndb_mgr_nodes")
                            else
                                dd_oam_nodes=$(get_concat "$dd_oam_nodes" "$sect")
                                dd_ndb_mgr_nodes=$(get_concat "$dd_ndb_mgr_nodes" "$sect")
                            fi
                        fi
                    else
                        # MGR entity is kind of mandatory for a TextPass run.
                        log_exit "No MGR entity loaded (TextPassBaseline missing?)"
                    fi

                    # Remember spf_core may currently only run on a main instance so 
                    if [ "$C_SPFCORE" != '' ]; then
                        # Fill ndb paramaters 
                        is_component_selected "$sect" $C_SPFCORE
                        if [ $? != 0 ]; then
                            dd_ndb_needed=1
                            dd_ndb_mysql_nodes=$(get_concat "$dd_ndb_mysql_nodes" "$sect")
                            dd_ndb_data_nodes=$(get_concat "$dd_ndb_data_nodes" "$sect")
                        fi
                    else
                        log_info "No SPFCORE entity skipping NDB definition."
                    fi
                fi
                ;;
        esac
        ((idx++))
    done
    
    # If oam_master is defined then it has to be found, otherwise strange
    # things can happen (not expected to configuration)
    if [ "$oam_master" != '' -a $oam_master_fnd != 1 ]; then
        log_exit "Configured OAM master in [$sect_cfg/OAM]master='$oam_master' but it was not found as node section, please fix!"
    fi
    # Now get the deduce oam_master, which is the first in the list
    dd_oam_master=$(get_field 1 "$dd_oam_nodes")

    # Make dd_all_comps unique in one call
    dd_all_comps=$(get_unique_words "$dd_all_comps")

    #
    # If NDB is needed is defined, see if setting need overuling or wiping
    #
    if [ $dd_ndb_needed != 0 ]; then
        read_config_vars NDB
        
        if [ "$NDB_mgr_nodes" != '' ]; then
            dd_ndb_mgr_nodes="$NDB_mgr_nodes"
        fi
        check_all_elements 'Resolve NDB MGR nodes' 1 "$dd_ndb_mgr_nodes" "$dd_all_sects"
        
        if [ "$NDB_mysql_nodes" != '' ]; then
            dd_ndb_mysql_nodes="$NDB_mysql_nodes"
        fi
        check_all_elements 'Resolve NDB MySQL nodes' 1 "$dd_ndb_mysql_nodes" "$dd_all_sects"

        if [ "$NDB_data_nodes" != '' ]; then
            dd_ndb_data_nodes="$NDB_data_nodes"
        fi
        check_all_elements 'Resolve NDB nodes' 1 "$dd_ndb_data_nodes" "$dd_all_sects"
    else
        dd_ndb_mgr_nodes=''     # Wipe it was not needed
    fi
}

: <<=cut
=func_int
Store then information of a sector. This is stored as a whole which can be
quickly used to set variables. But it can also stored in the section data
which is there for more logical access and can be be used to deduce data
on the fly. Some data elements are checked for consistency as they may exists
only once.
=cut
function store_sect() {
    local sect="$1" # (M) The full section this belongs to (could include /
    local info="$2" # (O) The section info to added, containing variable. Ignored if fully empty. No empty nor full comment lines allowed are comments

    [ "$info" == '' ] && return                     # Empty nothing to store`
   
    local dat_entry="$map_data/$sect"
    if [ "$(map_get "$dat_entry" $fld_sect)" != '' ]; then
        log_exit "Found double section for [$sect], check configuration"
    fi
    
    map_put $map_sect "$sect" "$info"               # add the whole info first
    map_put "$dat_entry" $fld_sect "$sect"     # add section for reference (when links used)
    
    local line
    IFS=''; while read line; do IFS=$def_IFS
        [ "$line" == '' -o "${line:0:1}" == '#' ] && continue       # Just safety
        map_put "$dat_entry" "$(get_field 1 "$line" '=')" "$(get_field 2 "$line" '=')"
    IFS=''; done <<< "$(echo -n "$info" | $CMD_sed "s/\([a-zA-Z0-9_]*\)[ \t]*=[ \t]*['\"]\(.*\)['\"][ \t#\$]*.*/\1=\2/g")"; IFS=$def_IFS

    # Get the the OAM IP/Host and make a reference if available
    if [ "$(map_get "$dat_entry" $fld_oam_lan)" != '' ]; then
        # Create IP link
        select_oam_ip "$sect"       # If oam_lan set then it should exist and find ip (will be stored).
        local cnode="$(map_get "$map_deduct/$fld_netw/$fld_type_netw_oam/$fld_ip/$sel_ip" $fld_sect)"
        if [ "$cnode" == '' ]; then
            map_link "$map_deduct/$fld_netw/$fld_type_netw_oam/$fld_ip" "$sel_ip" $map_data $sect
        elif [ "$cnode" != "$sect" ]; then
            log_exit "Found IP '$sel_ip' referring to two nodes '$sect' != '$cnode', check configuration"
        fi

        # Create host link
        local host="$(map_get "$dat_entry" $fld_host)"
        if [ "$host" != '' ]; then
            local cnode="$(map_get "$map_deduct/$fld_netw/$fld_type_netw_oam/$fld_host/$host" $fld_sect)"
            if [ "$cnode" == '' ]; then
                map_link "$map_deduct/$fld_netw/$fld_type_netw_oam/$fld_host" "$host" $map_data $sect
            elif [ "$cnode" != "$sect" ]; then
                log_exit "Found host '$host' referring to two nodes '$sect' != '$cnode', check configuration"
            fi
        fi            
    fi
} 

: <<=cut
=func_int
Read all the data from the data file
=set map_sect
Fill the map sections with the info's of all sections stored.
=cut
function read_data() {
    local data_file="$1"    # (M) The data file to read in. Data files are section oriented

    local cur_info=''
    local cur_sect=''
    local lnr=0

    map_init $map_sect
    map_init $map_data
    map_init $map_instance
    map_init $map_deduct

    while read line
    do
        ((lnr++))
        # Make DOS format proof : tr -d '\r' and remove space front/end
        line="$(echo -n "$line" | tr -d '\r' | $CMD_sed -e "$SED_del_preced_sp" -e "$SED_del_trail_sp")"  
        [ "$line" == '' -o "${line:0:1}" == '#' ] && continue

        sect=$(echo "$line" | $CMD_ogrep '^\[[0-9a-zA-Z_/\-]+(#[0-9])?\]')
        if [ "$sect" != '' ]; then
            store_sect "$cur_sect" "$cur_info"
            cur_sect=`echo "$sect" | $CMD_ogrep "[0-9a-zA-Z_/\-]+(#[0-9])?"`
            cur_info=""
            log_screen_bs bs "$cur_sect"
        elif [ "$cur_sect" != '' ]; then
            if [ "$cur_info" == '' ];then
                cur_info="$line"
            else
                cur_info="$cur_info$nl$line"
            fi
        else
            log_exit "Found data outside a section in file $data_file on line $lnr"
        fi
    done < $1
    store_sect "$cur_sect" "$cur_info"              # Only store if some info

    # Make a list with instance which is stored in map_instance[section]. Empty
    # means no instance section. In case of only the main section that would
    # means to only search the main variables. In case instances are available
    # then the comp field is forbidden. Other can be used for default values
    for entry in $(map_keys $map_sect); do
        local ins=$(echo -n "$entry" | $CMD_ogrep '(#[0-9])?')
        if [ "$ins" != '' ]; then 
            # Get the main section so without the #[0-9]
            local main_sect="$(get_main_sect "$entry")"
            local check="$(map_get $map_sect $main_sect)"
            if [ "$check" == '' ]; then
                log_exit "Found an instanced section [$entry] but the main node [$main_sect] is not defined.
Please define it, in this case it has to be defined before using the instance 
section with the '#' marker. Remember the main node contains information like
serial number, IP-plan, generic node config but no components. The instances 
should have the components and optional private configuration."
            fi
            local cur="$(map_get $map_instance $main_sect)"
            if [ "$cur" == '' ]; then
                map_put $map_instance $main_sect "${ins:1}"
            else
                map_put $map_instance $main_sect "$cur ${ins:1}"
            fi
        fi
    done
    # Check for faulty comp reference. In there is 1 instance than no main
    # comp reference may be available
    for entry in $(map_keys $map_instance); do
        if [ "$(get_all_fld_data "$entry" $fld_comp)" != '' ]; then
            log_exit "A node section [$entry] contains a $fld_comp while there are instances."
        fi
    done
    # See if there are any main sections which have comp. If so then there should
    # not be any instance *which is an error). If there are no instance then
    # copy he comp to instance 0 which makes the rest of the code easier 
    # (less exceptions)
    for entry in $(map_keys $map_sect); do
        local ins=$(echo -n "$entry" | $CMD_ogrep '(#[0-9])?')
        if [ "$ins" == '' ]; then
            select_line "$(map_get $map_sect $entry)" $fld_comp
            if [ "$sel_line" != '' ]; then
                if [ "$(map_get $map_instance $entry)" != '' ]; then
                    log_exit "Component is defined in main while instances are defined as well."
                fi
                set_fld_data "$sel_line"
                map_put $map_instance  $entry    '0'        # force to instance 0
                store_sect "$entry#0" "$fld_comp='$data_full'"
            fi
        fi
    done
 
    # Read in some generic sections
    process_section_vars $sect_automate 'STR_'
    process_section_vars $sect_generic  'GEN_'
    process_section_vars $sect_backup   'BCK_'

    # 
    # Process the data, first locally, then optionaly package scripts
    #
    deduce_data
    local pkg
    for pkg in $(map_keys $map_cfg_ins); do
        is_pkg_alias $pkg
        [ $? != 0 ] && continue
        log_screen_bs bs "$pkg"
        func "*$pkg" process_data
        log_screen_bs add "$([  $? != 0 ] && echo -n " (done)" || echo -n " (skipped)")"
#        sleep 0.05   # Slightly slow down the output (disabled).
    done

    # Ability to debug the read information
    if [ "$FLG_dbg_enabled" != "0" ]; then
        log_debug "The following data has been retrieved"
        for entry in $(map_keys $map_sect); do
            log_debug "
Section : $entry
Instance: $CFG_instance[$entry]}
$(map_get $map_sect $entry)"
        done
    fi
}

: <<=cut
=func_int
This function deduce extra data which can only be done after a certain point.
E.g. after require initialized).
=set dd_prov_plat_nodes
A list with all the nodes having something related to the provisioning platform.
=set dd_prov_plat_comps
A list with all the components releated to the provisioning platform.
=set dd_supporting
A list with needed supporting software for this node like Mysql.
=cut
function late_deduce_data() {
    dd_prov_plat_nodes=''
    dd_prov_plat_comps=''
    dd_supporting=''

    #
    # Find out all provisiong platform nodes. Basicaly ndb + ndb_api + ndb_eng + SPFCORE
    # There is some funny sed'ing, tr, sort an uniue ongoing this to limit the
    # things to programm.
    #
    local nodes=''
    if [ $dd_ndb_needed != 0 ]; then
        nodes="$dd_ndb_mgr_nodes $dd_ndb_mysql_nodes $dd_ndb_data_nodes "
        dd_prov_plat_comps="$(get_who_uses_interface $IF_NDB_API "$dd_all_comps") $(get_who_uses_interface $IF_SPF_Service "$dd_all_comps")"
        dd_prov_plat_comps="$(get_unique_words "$dd_prov_plat_comps")"
        local comps="$(echo -n "$dd_prov_plat_comps" | tr ' ' '\n' | sed  -e 's/^/\^/' -e 's/$/@/' )"
        local fcomp="$(get_intersect "$dd_full_system" "$comps")"
        nodes+="$(echo -n "$fcomp" | cut -d ':' -f 1 | cut -d '@' -f 2 | tr '\n' ' ')"
        dd_prov_plat_nodes="$(echo -n "$nodes" | tr -s ' ' | tr ' ' '\n' | sort | uniq | tr '\n' ' ')"
        log_info "Found SPP nodes: $dd_prov_plat_nodes"
    fi

    # Get the list with the required help packages base on current components.
    dd_supporting="$(get_helper_pkgs "$hw_node" "$dd_components")"
}

: <<=cut
=func_ext
Read the given step file into memory so that it can be processed
later on. It also expands the <components> directive. Which means
this function has to called after reading the data configuration.
=set AUT_num_steps
The amount of steps to execute.
=set AUT_shutdown_store_state_step
Point to the step number of the 'shutdown_machine store_state' step. Or empty
if not found.
=cut
function read_steps() {
    local step_file="$1"    # (M) The step file to read in
    local type="$2"         # (O) Type of storage main/<empty> or queue
    
    if [ ! -r "$step_file" ]; then
        log_exit "Cannot read given step file '$step_file'"
    fi
    type=${type:-main}
    check_in_set "$type" 'main,queue'

    local idx=0
    local comp
    local -a step       # first a local copy
    local iso_checked=0

    #
    # FUTURE note: Some changes are need when the Baseline approach is dropped
    # in the future. Because it will mean we need to check if all in formation 
    # is available. when generating <components>/<supporting> for upgrades
    # it will mean all need to be available fro installation/recover the information 
    # needs to be available all collect_automation files.
    # A preparation was made in the dynamic definition where the product (e.g.
    # TextPass) declares the packages so that it can be matched against the 
    # actual packages collected.
    #

    AUT_shutdown_store_state_step=''

    if [ "$type" == 'main' ]; then step[((idx++))]="NotUsed"; fi
    while read line
    do
        line="$(get_field 1 "$line" '#')"               # Strip any comment after first #
        line=`echo -n "$line" | tr -d '\r' | tr '\t' ' ' | sed "$SED_del_spaces" | sed "$SED_del_preced_sp" | sed "$SED_del_trail_sp"`
        if [ "${line:0:1}" != '#' -a "$line" != '' ]; then
            local inst_wc=`echo "$line" | $CMD_ogrep "$regex_step_inst"`
            local comp_wc=`echo "$line" | $CMD_ogrep "$regex_step_comp"`
            local spp_comp_wc=`echo "$line" | $CMD_ogrep "$regex_step_spp_comp"`
            local prod_wc=`echo "$line" | $CMD_ogrep "$regex_step_prod"`
            local supp_wc=`echo "$line" | $CMD_ogrep "$regex_step_supp"`
            local sw_iso_wc=`echo "$line" | $CMD_ogrep "$regex_step_sw_iso"`
            local os_iso_wc=`echo "$line" | $CMD_ogrep "$regex_step_os_iso"`
            if [ "$inst_wc$comp_wc$spp_comp_wc$prod_wc$supp_wc$sw_iso_wc$os_iso_wc" == '' ]; then   # A normal line
                if [ "$STR_instances" == '*' ]; then
                    step[((idx++))]="$line"
                fi  # else skipping zone addition
            elif [[ $line =~ ^install ]] && [ "$comp_wc" == "$regex_step_comp" ]; then    # Install is only once
                # XS and EC are special they need all type to be installed. This 
                # due to a problem/bug in common config and mismatched XS installations
                # Which is theoretically allowed by the config and the system
                local need_xs=0
                local need_ec=0  
                for comp in $(get_unique_words "$(get_all_components $hw_node instance "$STR_instances")"); do
                    if [[ $comp =~ ^XS ]]; then need_xs=1; continue; fi
                    if [[ $comp =~ ^EC ]]; then need_ec=1; continue; fi
                    # Need to find the real install package due to aliases it does
                    # Not need to be the same, has to exist!
                    find_install $comp
                    if [ "$comp" != "$install_ent" ]; then  # Alias add subname
                        step[((idx++))]=$(echo -n "$line" | sed "s/$regex_step_comp/$install_ent $comp/")
                    else
                        step[((idx++))]=$(echo -n "$line" | sed "s/$regex_step_comp/$comp/")
                    fi
                done
                
                for comp in $dd_all_comps; do   # Loop could be optimized but more lines of code (one time only)
                    if [ $need_xs != 0 ] && [[ $comp =~ ^XS ]]; then     # XS should noot have subnames
                        step[((idx++))]=$(echo -n "$line" | sed "s/$regex_step_comp/$comp/")
                    fi
                    if [ $need_ec != 0 ] && [[ $comp =~ ^EC ]]; then     # XS should noot have subnames
                        step[((idx++))]=$(echo -n "$line" | sed "s/$regex_step_comp/$comp/")
                    fi
                done
            elif [ "$supp_wc" == "$regex_step_supp" ]; then
                for comp in $dd_supporting; do
                    step[$idx]=`echo -n "$line" | sed "s/$regex_step_supp/$comp/"`
                    could_step_file_be_found "${step[$idx]}" "$comp"
                    if [ $? == 1 ]; then    # yes found, accept
                        ((idx++))
                    else                    # no clear
                        step[$idx]=''
                    fi
                done
            elif [ "$sw_iso_wc" == "$regex_step_sw_iso" -o "$os_iso_wc" == "$regex_step_os_iso" ]; then
                if [ $iso_checked == 0 ]; then
                    STR_sel_sw_iso=${STR_sel_sw_iso:-$AUT_def_sw_iso}    # Set default if none given
                    read_iso_vars "$STR_sel_sw_iso"
                    if [ "$ISO_file" == '' ]; then
                        log_exit "Referenced iso '[iso/$STR_sel_sw_iso]' not found or no file associated."
                    fi
                    dd_sw_iso_file=$ISO_file
                    # OS iso does not have a default so leave empty if it is
                    if [ "$STR_sel_os_iso" != '' ]; then
                        read_iso_vars "$STR_sel_os_iso"
                        if [ "$ISO_file" == '' ]; then
                            log_exit "Referenced iso '[iso/$STR_sel_os_iso]' not found or no file associated."
                        fi
                        dd_os_iso_file=$ISO_file
                    else
                        dd_os_iso_file=''
                    fi
                    iso_checked=1
                fi
                step[((idx++))]=`echo -n "$line" | sed -e "s/$regex_step_sw_iso/$STR_sel_sw_iso/" -e "s/$regex_step_os_iso/$STR_sel_os_iso/"`
            elif [ "$prod_wc" == "$regex_step_prod" -a "$inst_wc" == '' ]; then     # Single product
                for comp in $(echo -n "$STR_products" | tr ',' ' '); do
                    step[((idx++))]=`echo -n "$line" | sed -e "s/$regex_step_prod/$comp/"`
                done
            else        # Instance related variables
                local add=''
                local ins
                for ins in $dd_instances; do
                    if [ $dd_instanciated != 0 ]; then
                        add="$KW_instance $ins"
                    fi
                    if [ "$prod_wc" == "$regex_step_prod" ]; then
                        for comp in $(echo -n "$STR_products" | tr ',' ' '); do
                            # No double combination of <> are allowed currently only 1 exception made for <products> <instances>
                            # A more intelligent approach could be made but that is complex and currently overkill (tbd).
                            step[((idx++))]=`echo -n "$line" | sed -e "s/$regex_step_prod/$comp/" -e "s/$regex_step_inst/$add/"`
                        done
                    elif [ "$inst_wc" == "$regex_step_inst" ]; then
                        step[((idx++))]=`echo -n "$line" | sed "s/$regex_step_inst/$add/"`
                    elif [ "$comp_wc" == "$regex_step_comp" ]; then
                        for comp in $(get_all_components $hw_node instance "$ins"); do
                            if [ "$add" == '' ]; then
                                step[((idx++))]=`echo -n "$line" | sed "s/$regex_step_comp/$comp/"`
                            else
                                step[((idx++))]=`echo -n "$line" | sed "s/$regex_step_comp/$comp $add/"`
                            fi
                        done
                    elif [ "$spp_comp_wc" == "$regex_step_spp_comp" ]; then
                        for comp in $dd_prov_plat_comps; do
                            [ "$(get_substr "$comp" "$dd_components")" == '' ] && continue  # Not in this node.
                            if [ "$add" == '' ]; then
                                step[((idx++))]=`echo -n "$line" | sed "s/$regex_step_spp_comp/$comp/"`
                            else
                                step[((idx++))]=`echo -n "$line" | sed "s/$regex_step_spp_comp/$comp $add/"`
                            fi
                        done
                    else
                        log_exit "Kind of unexpected."
                    fi
                done
            fi
        fi
    done < $step_file

    local num=$idx
    idx=0
    if [ "$type" == 'main' ]; then
        # check is last is finish installation if not add it.
        ((num--))
        if [ "${step[$num]}" != "$STEP_finish_automate" ]; then
            ((num++))
            step[$num]="$STEP_finish_automate"
        fi
        AUT_num_steps=$num

        # Store in main
        unset AUT_step
        local midx=0
        while [ $idx -le $num ]; do
            could_step_file_be_found "${step[$idx]}"
            if [ $? != 0 -o $idx == 0 ]; then
                # Putting it here safes complexity in automate script itself
                if [ "${step[$idx]}" == 'shutdown_machine store_state' ]; then
                    AUT_shutdown_store_state_step=$midx
                fi
                AUT_step[$midx]="${step[$idx]}"
                ((midx++))
            fi
            ((idx++))
        done
    else    # queue type
        # Store in queued (using standard function)
        while [ $idx -lt $num ]; do
            queue_step "${step[$idx]}"      # This one is currently not pruned
            ((idx++))
        done
    fi
    
}

: <<=cut
=func_ext
Reads the actual data file. THis is separated from the step files as
the step file needs both data and require. The require needs the data.
=cut
function read_data_file() {
    local data_file="$1"    # (M) The data file with the customer specific data set

    check_set "$data_file" 'Data configuration file missing'

    log_screen_bs init 'Read Data Cfg   : '
    log_screen_bs bs   'data file'
    # First read the data file which is needed to identify the system and components
    if [ -e "$data_file" -a -r "$data_file" ]; then
        read_data $data_file
    else
        log_screen_bs end 'data failed'
        log_exit "Cannot open data file: $data_file'"
    fi

    log_screen_bs bs   'identify'
    hw_serial_number="$(get_systen_var $SVAR_serial_number)"
    if [ $FLG_man_sel == 0 -a "$STR_selected_node" != '' ]; then
        sect_exists "$STR_selected_node"
        [ $? == 0 ] && log_exit "A selected node is given '$STR_selected_node', but was not found in the Data Set"
        hw_node="$STR_selected_node"
        hw_info="$(map_get $map_sect $hw_node)"
        deduce_node_data
        hw_sel_type='pre-selected'
    elif [ $FLG_man_sel == 0 ]; then
        # Now find the serial number (currently only one supported)
        select_hw_node "$hw_serial_number"
        hw_sel_type='identified'
        if [ "$hw_node" == '' ]; then       # Is there only one? If so select it
            if [ "$(echo -n "$dd_all_sects" | wc -w)" == '1' ]; then
                log_screen_bs bs 'use only'
                hw_node="$dd_all_sects"
                hw_info="$(map_get $map_sect $hw_node)"
                deduce_node_data
                hw_sel_type='used only-one'
            fi
  
        fi
        check_set "$hw_node" "This hardware serial number($hw_serial_number), was not found in the Data Set"
    else # Do a manual select
        local exit='EXIT'
        log_screen_bs end 'manual select'
        log_screen "Please select a hardware node from the following list:"
        select sect in $dd_all_sects $exit; do
            if [[ -n $sect ]]; then
                if [ $sect == $exit ]; then
                    log_screen "No hardware node selected, exiting."
                    exit 0
                fi
                select_section "$sect"
                check_set "$hw_node" "Strange the hardware node [$sect] was not found in the Data Set"
                deduce_node_data
                log_info "Manual selected hardware node: $sect"
                break
            else
                log_screen "invalid input, please retry or choose '$exit' option."
            fi
        done
        hw_sel_type='selected'
        log_screen_bs init 'Read Data Cfg   : '
    fi

    if [ "$FLG_dbg_enabled" != "0" ]; then
        log_debug "The following data has been deduced:$nl$(set | grep '^dd_')"
    fi

    log_screen_bs end "done -> $data_file"
}

: <<=cut
=func_ext
Reads the actual step file. Which needs the data and reuire info to be
initialized.
=cut
function read_step_file() {
    local step_file="$1"    # (M) The step file with all the steps to be executed

    check_set "$step_file" 'Step configuration file missing'

    log_screen_bs init 'Read Step Cfg   : '

    # Read the steps
    log_screen_bs bs   'step file'
    if [ -e "$step_file" -a -r "$step_file" ]; then
        read_steps $step_file
    else
        log_screen_bs end 'step failed'
        log_exit "Cannot open step file: '$step_file'"
    fi

    log_screen_bs end "done -> $step_file"
}

: <<=cut
=func_ext
Shows all steps to be executed. Depending on the option it may select the start
=cut
function show_steps_to_execute() {
    local select_start="$1"    # (O) If given then the start is selected, otherwise it is just shown
    local show_brief="$2"      # (O) If given the brief information is collected and shown.

    local num=${#AUT_step[@]}
    local idx=1
    local info
    local sel=''
    local exit='== Exit Automate Tool =='
    local brief='^=brief '      # how to recognize single brief liner a script

    if [ "$select_start" == '' ]; then
        log_screen "The following steps are configured:"
        while [ "$idx" -lt "$num" ]
        do
            info=`echo "${AUT_step[$idx]}" | sed "$SED_rep_us_w_sp"`
            if [ "$show_brief" != '' ]; then
                local file
                for file in $(find_step_files "${AUT_step[$idx]}"); do
                    if [ -r "$file" ]; then
                        local extra="$(grep "$brief" "$file" | sed "s/$brief//")"
                        if [ "$extra" != '' ]; then
                            info+="${nl}     * $extra"
                        fi
                    fi
                done
            fi
            log_screen "$(printf "%2d - $info" "$idx")"
            ((idx++))
        done
    else
        while [ "$idx" -lt "$num" ]
        do
            if [ "$info" == '' ]; then
                info=`echo "${AUT_step[$idx]}" | sed "$SED_rep_us_w_sp"`
            else
                info="$info|"`echo "${AUT_step[$idx]}" | sed "$SED_rep_us_w_sp"`
            fi
            ((idx++))
        done
        info="$info|$exit"
        log_screen "Please select the start step from the steps below:"
        IFS='|'
        select idx in $info; do
            IFS=$def_IFS
            if [[ -n $idx ]]; then
                if [ "$idx" == "$exit" ]; then
                    log_screen "Exiting automate tool upon request."
                    exit 0
                fi
                STR_exec_steps=`seq -s',' $REPLY $AUT_num_steps`
                log_info "Set steps to execute to $STR_exec_steps"
                break
            else
                log_screen "invalid input, please retry or choose '$exit' option."
            fi
            IFS='|'
        done
        IFS=$def_IFS
    fi
}

: <<=cut
=func_ext
Logs (using log_info) all steps to be executed (no brief).
=cut
function logsteps_to_execute() {

    local num=${#AUT_step[@]}
    local idx=1
    local info

    log_info "The following steps are configured:"
    while [ "$idx" -lt "$num" ]
    do
        info=`echo "${AUT_step[$idx]}" | sed "$SED_rep_us_w_sp"`
        log_info "$(printf "%2d - $info" "$idx")"
        ((idx++))
    done
}

: <<=cut
=func_frm
Select all field data. in this case the data is allowed to be not found
=remark
If the section is instanced and does not contain the field then the 
main section is tried.
=set data_type
The field type/name (the text in front of the '=' sign
=set data_full
The data (the text after the '=' sign
=set data_par[1-4]
Translated data parameters, which are seperated by spaces.
=cut
function select_all_fld_data() {
    local section="$1"      # (M) The node/section to select data for.
    local field="$2"        # (M) The field to search for.
    
    [ -z help ] && show_short="Select field '$field' from section [$section]"
    [ -z help ] && show_trans=0

    local info

    if [ "$section" != "$hw_node" ]; then
        select_all_data $section
        info="$sel_output"
    else
        info="$hw_info"
    fi
    select_line "$info" "$field"
    set_fld_data "$sel_line"

    if [ "$data_type" == '' ] && [ "$(get_instance "$section")" != '' ]; then
        # Yes I trust my function to make a main section and not cause infinite loop!
        select_all_fld_data "$(get_main_sect "$section")" "$field"
    fi
}

: <<=cut
=func_frm
Get the field data to standard out,  which is useful in the \$( ) calls.
The function is the same as select_all_fld_data and uses its functionality.
=cut
function get_all_fld_data() {
    local section="$1"      # (M) The node/section to select data for.
    local field="$2"        # (M) The field to search for.

    [ -z help ] && show_short="Get field '$field' from section [$section]"
    [ -z help ] && show_trans=0

    select_all_fld_data "$section" "$field"
    echo -n "$data_full"
}

: <<=cut
=func_frm
Find the actual IP belong to the OAM network. This is an IP which
refers to a  bond or an actual Ethernet device. If it does not refer to
any device but it is set then it is assumed (without further checking)
that it is a direct ip address. This can be useful in case of upgrades with a 
generated data file.
The IP has to be configured.
=set sel_ip
Stores the found ip.
=cut
function select_oam_ip() {
    local section="$1"  # (M) The node/section to select it for.

    [ -z help ] && show_short="Select OAM-IP from section [$section]"
    [ -z help ] && show_trans=0

    sel_ip="$(map_get "$map_data/$section" $fld_oam_ip)"
    [ "$sel_ip" != '' ] && return               # optimize if already stored.

    # Future:
    # I could rewrite the function to use map_data, however it is now cached so 
    # will not speed up much. It would only cost test time at the moment.

    select_all_fld_data "$section" $fld_oam_lan
    local interface="$data_par1"
    check_set "$interface" "No value configured for [$section]$fld_oam_lan"
    select_all_fld_data "$section" $interface
    sel_ip="$data_par1"
    if [ "$sel_ip" == '' ]; then
        # Try to see if it directly refers to an ip.
        check_ip 'OAM_lan' "$interface" opt
        if [ $? != 0 ]; then
            log_exit "IP $interface is not an IP, nor referring to [$section]$interface"
        fi
        sel_ip=$interface
    fi

    map_put "$map_data/$section" $fld_oam_ip "$sel_ip"  # Store for future quick access
}

: <<=cut
=func_frm
Get the oam_ip to standard out, which is useful in the \$( ) calls.
The function is the same as select_oam_ip and uses its functionality.
=stdout
=cut
function get_oam_ip() {
    local section="$1"  # (M) The node/section to get it for.

    [ -z help ] && show_short="Get OAM-IP from section [$section]"
    [ -z help ] && show_trans=0

    select_oam_ip "$section"
    echo -n "$sel_ip"
}

: <<=cut
=func_frm
Get the any data field from the data node and print it to stdout.
=stdout
=cut
function get_data_field() {
    local section="$1"  # (M) The node/section to get it for.
    local field="$2"    # (M) The field to selected, use fld_* if possible

    [ -z help ] && show_short="Get field '$field' from section [$section]"
    [ -z help ] && show_trans=0

    select_all_fld_data "$section" "$field"
    echo -n "$data_full"
}

: <<=cut
=func_frm
Checks if a specific component is selected for a node/section.
This includes all instances on the node.
=ret
0 not found 1 it is selected in data variables.
=cut
function is_component_selected() {
    local section="$1"      # (M) The node/section to select it for.
    local component="$2"    # (M) The component to search for.

    check_set "$component" 'No component given, is it available?'
    if [ "$component" == "$C_SYS" ]; then   # Special handling for SYS
        return 1
    fi
    local all_comp=$(get_all_components "$section")
    local found=`echo "$all_comp" | egrep "(^| )$component( |$)"`
    if [ "$found" != '' ]; then
        return 1
    fi
    return 0
    
    [ -z help ] && ret_vals[0]="${show_pars[2]} NOT configured on ${show_pars[1]}"
    [ -z help ] && ret_vals[1]="${show_pars[2]} configured on ${show_pars[1]}"

}

: <<=cut
=func_frm
Get all the nodes which has the given component isntalled.
Multiple components may be queried at the same time. A node however
will be returned only once.
=stdout
Returns a list with all the nodes separated by a space. Instances will
reuslt in one node, zones and VMS will return multiple nodes.
=cut
function get_nodes_where_comp_installed() {
    local search="$1"   # (O) The component(s) to search for, empty skips search

    if [ "$search" == '' ]; then
        return      # nothing to stdout
    fi    
    local node
    local sep=''
    for node in $dd_all_sects; do
        for comp in $search; do
            is_component_selected $node $comp
            if [ $? != 0 ]; then
                echo -n "$sep$node"
                sep=' '
                break 1       # Break the component loop and go to next node
            fi
        done
    done
}

: <<=cut
=func_frm
Check if there is device managed by the MGR
=ret
the amount of devices or 0 if none 
=cut
function has_managable_device() {
    local section="$1"  # (M) The node/section to select it for.
    
    local comps=$(get_all_components "$section")
    if [ "$comps" == '' ]; then
        return 0
    fi

    local found=0
    for i in $comps; do
        find_component "$i"
        if [ $comp_idx != 0 -a $comp_device != 'N' ]; then
            ((found++))
        fi
    done

    return $found
    
    [ -z help ] && ret_vals[0]="MGR has no device to manage on ${show_pars[1]}"
    [ -z help ] && ret_vals[1]="MGR has a least 1 device to manage on ${show_pars[1]}"
}

: <<=cut
=func_frm
Select a node/section based on the given serial number. 
It is allowed that the section cannot be found.
=set hw_node
The found node/section. '' if not found.
=set hw_info
The related informaion. '' if not found.
=cut
function select_hw_node() {
    local serial_number="$1"    # (O) The serial number of the node to find

    hw_node=''
    hw_info=''
    [ "$serial_number" == '' ] && return

    local entry
    for entry in $(map_keys $map_sect); do
        local info="$(map_get $map_sect $entry)"
        select_line "$info" $fld_serial
        if [ "$sel_line" != '' ]; then
            set_fld_data "$sel_line"
            if [ "$data_full" == "$serial_number" ]; then
                hw_node=$entry
                hw_info="$info"
                deduce_node_data
                return
            fi
        fi
    done
}

: <<=cut
=func_frm
Check if a node/section exists
=ret
0 it does not exists, otherwise 1
=cut
function sect_exists() {
    local entry="$1"    # (M) the section to check
    if [ "$(map_get $map_sect $entry)" != '' ]; then
        return 1
    fi
    return 0
}

: <<=cut
=func_frm
Reads a specific configuration section, which has to exists.
The variables get <component>_ as prefix. Or the given <prefix>_

If SCR_instance is set then the [hw_node#instance] will be looked for:
- lc<comp><var> which results in <pfx>__<var> without comp>
- _lc<comp>var> which results in <pfx>_<var>
Resulting in the same end variable. So
[cfg/AMS]
_masterstoragetype  = "nonvolatile"     # already supported for common config.
justavar            = '1'
[node#1]
_amsmasterstoragetype  = "volatile"     # already supported for host specific
amsjustavar         = '2'

Will both result in AMS__masterstoragetype and AMS_justavar, where the instance has the higher
priority (read last). This is done to have instance variable defined per type,
but also be able to identify the _<var> which has to go into host common/host
files.
=cut
function read_config_vars() {
    local component="$1"    # (M) The component to read in.
    local prefix="$2"       # (O) A prefix to overule (without _). If not given same as component

    prefix=${prefix:-$component}

    [ -z help ] && show_short="Info: Read vars, from [$sect_cfg/$component], add prefix: '${prefix}_'"
    [ -z help ] && show_trans=0

    clean_default_vars "$component"     # First cleanup potential default ones.

    # First read normal vars
    process_section_vars "$sect_cfg/$component" "${prefix}_"
    if [ "$SCR_instance" != '' ]; then
        process_section_vars "$hw_node#$SCR_instance" "${prefix}_"   "$(get_lower "$component")"
        process_section_vars "$hw_node#$SCR_instance" "${prefix}__" "_$(get_lower "$component")"
    fi
}

: <<=cut
=func_frm
Reads a specific iso section, which has to exists. 
The variables get ISO_ as prefix
=cut
function read_iso_vars() {
    local iso="$1"    # (M) The iso to read in.

    [ -z help ] && show_short="Info: Read vars, from [$sect_iso/$iso], add prefix: 'ISO_'"
    [ -z help ] && show_trans=0
    
    unset ISO_file    # Make sure clear if not set in config file
    unset ISO_md5
    process_section_vars "$sect_iso/$iso" 'ISO_'
}

: <<=cut
Reads a specific instance section, which has to exists.
Th varibles get the <prefix>_ as prefix
=cut
function read_instance_vars() {
    local section="$1"  # (M) The section/node to read in
    local instance="$2" # (M) The instance number to read in
    local prefix="$3"   # (O) The prefix to use for the variable.

    [ -z help ] && show_short="Info: Read vars, from [$section#$instance], add prefix: '${prefix}_'"
    [ -z help ] && show_trans=0

    process_section_vars "$section#$instance" "${prefix}_"
}

: <<=cut
=func_frm
Translates a ip of simple host name in a node name.
=stdout
The node name which refers to our internal section. Or <empty> if not found.
=cut
function get_node_from_ip_or_host(){
    local ip_or_host="$1"   # (M) The ip or host name to look up.
    local type="$2"         # (O) The type of network see fld_type_netw_*, defaults to oam

    type=${type:-$fld_type_netw_oam}
    # first look up if it is an IP
    local node="$(map_get "$map_deduct/$fld_netw/$type/$fld_ip/$ip_or_host" $fld_sect)"
    if [ "$node" = '' ]; then   # Next see if it an Host
        node="$(map_get "$map_deduct/$fld_netw/$type/$fld_host/$ip_or_host" $fld_sect)" 
    fi
    if [ "$node" == '' ]; then
        log_info "Could not translate '$ip_or_host' into a node."
    else
        echo -n "$node"
    fi
}

: <<=cut
=func_frm
Translate a nodes.section list into a nodes/host/ip/stat array which
can be used for further processing. 
=func_note
Do not use nested calls to this functions.
=set TMP_node
A node array with all the nodes (starting at idx 1)
=set TMP_host
A host array which holds all the associated host names of the given node
=set TMP_oam_ip
An ip which which all holds all the related OAM IPs.
=set TMP_stat
An status array all are set to 'init'
=set TMP_mlen_host
The maximimum length found for the host. Might be useful for printing nicely
=ret
The amount of entries in the array (excluding 0). So 1 mean idx 1 is filled,
array size will be 2. This make it easier to access later on.
=cut
function translate_nodes_into_arrays() {
    local nodes="$1"        # (M) The nodes to translates, separated by space
    local init_stat="$2"    # (O) The initial status to store

    [ -z help ] && show_ignore=1    # Internal data formatting don't show

    local num=$(get_word_count "$nodes")
    local idx=1
    local thost

    unset TMP_node
    unset TMP_host
    unset TMP_oam_ip
    unset TMP_stat
    TMP_mlen_host=0

    TMP_stat[0]='not used'
    while [ $idx -le $num ]; do  # init array (0 not used)
        TMP_node[$idx]=`echo -n "$nodes" | cut -d' ' -f$idx`
        TMP_host[$idx]=$(get_all_fld_data "${TMP_node[$idx]}" $fld_host)
        thost=${TMP_host[$idx]}
        if [ ${#thost} -gt $TMP_mlen_host ]; then
            TMP_mlen_host=${#thost}
        fi
        TMP_oam_ip[$idx]=$(get_oam_ip "${TMP_node[$idx]}")
        TMP_stat[$idx]="$init_stat"
        log_debug "trans_node_to_arr: Added $idx/$num, ${TMP_node[$idx]}, ${TMP_host[$idx]}, ${TMP_oam_ip[$idx]}"
        ((idx++))
    done

    return $num
}
