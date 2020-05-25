#!/bin/sh

: <<=cut
=script
This script is capable of creating XML files out of existing xml template files.
In particular the common_config and host specific templates used by the MM
software. In theory it can handle other XML templates as well.
There is one main assumption and that is that every field between {} in the
value is seen as a  mandatory field. 
=version    $Id: 20-create_xml_files.sh,v 1.19 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com

=feat merge xml files
Capability to read multiple input files and create one merged file. Un-Resolvable
conflicts are reported.

=feat add xml data
XML data can be added before writing out the merged file.

=cut

readonly XE_tpconfig='tpconfig'
readonly XV_true='true'
readonly XV_false='false'

readonly        map_xml_data='XML_data'         # The map holding all the data entries [xpath][/xpath]*[:variable]
readonly map_xml_sub_allowed='XML_sub_allowed'  # A map with allowed sub paths
readonly   map_xml_exception='XML_exception'    # A map with allowed exception for being unique
readonly       map_xml_depth='XML_depth'        # Used for stored depth counters.

xml_indent='    '


: <<=cut
=func_int
Get the lasts section from a xpath. The dpeth will be removed
=stdout
=cut
function get_last_sect() {
    local xpath="$1"    # (M) The xpth to analyze

    xpath=$(get_field 1 "$xpath" '|')      # strip potential var
    local num=$(get_word_count "$xpath" '/')
    ((num++))                              # It is one more due to 1st /
    local sect="$(get_field $num "$xpath" '/')" 
    echo -n "$(get_field 1 "$sect" '#')"   # remove potential depth
}

: <<=cut
=func_int
Get the plain path without any depth
=stdout
=cut
function get_plain_path() {
    local xpath="$1"    # (M) The xpath to remove depth form,may includ a var
    
    echo -n "$xpath" | sed -r -e 's/#[0-9]+//g'
}

: <<=cut
=func_int
Get an xpath from a config variable. This does config variable names itself
should not contain any _. A xpath contains of path_#_[<path_#_]<var>
=cut
function get_xpath_from_cfg () {
    local cfg_var="$1"  # (M) the configuration variable to translate
    
    local flds=$(get_word_count "$cfg_var" '_')
    if [ "$flds" -le '1' ]; then
        echo -n "$XP_tpcfg/$cfg_var"      # just add var as it was
        return
    fi
    # There should be an odd number of words
    if [ $((flds % 2)) -ne 1 ]; then
        log_warning "Wrong cfg variable found (path): $cfg_var"
        echo -n ''
        return      # Don't add var
    fi
    local fld=1
    echo -n "$XP_tpcfg"
    while [ "$fld" -lt "$flds" ]; do
        echo -n "/$(get_field $fld "$cfg_var" '_')#"
        ((fld++)) 
        echo -n "$(get_field $fld "$cfg_var" '_')"
        ((fld++))
    done
    echo -n "/$(get_field $fld "$cfg_var" '_')"    
}

: <<=cut
=func_int
Write a xpath with it subordinates
=cut
function write_xpath() {
    local file="$1"     # (M) The file to write to
    local xpath="$2"    # (M) The full xpath to write
    local ind="$3"      # (O) The current indentaiton (spaces)

    log_debug "write_xpath: $xpath"

    local entry
    local topl=$([[ "$ind" == '' ]] && echo '1' || echo '0')   # Inidcates toplevel
    local n_ind="$ind$xml_indent"

    local a_items="$(map_keys "$map_xml_data/$xpath" 'sort' | tr ' ' '\n')"
    if [ "$a_items" == '' ]; then
        log_debug "No Items found on this path $xpath"
        return
    fi

    local sect=$(get_last_sect "$xpath")
    local main="$ind<$sect"
    echo -n "$main" >> $file

    # Find all entries and pathc within this xpath
    local s_items="$(echo -n "$a_items" | grep -v '#[0-9]*$' | tr '\n' ' ')"
    local x_items="$(echo -n "$a_items" | grep    '#[0-9]*$' | tr '\n' ' ')"

    # For beautifying stuff I need to know the total length of the items
    # this to see if it fits on a average size line. only look at val
    local len=${#main}
    local var
    for var in $s_items; do
        local t=" $var=\"$(get_field 4 "$(map_get "$map_xml_data/$xpath" "$var")" ':')\""
        local lt=${#t}
        len=$((len + lt))
    done
    local nnl=''
    if [ $len -lt 80 -a  $topl == 0 ]; then
        nnl='-n'
        n_ind=' '
    fi
    if [ "$s_items" != '' ]; then
        echo $nnl '' >> $file    # We have entries within the xpath
        local pfx=''
        for var in $s_items; do
            local data="$(map_get "$map_xml_data/$xpath" "$var")"
            [ "$data" == '' ] && log_exit "No data found for '$xpath/$var'"

            local reqs=$(get_field 1 "$data" ':')
            local type=$(get_field 2 "$data" ':')
            local val=$( get_field 4 "$data" ':')
            
            if [ $topl == 1 -a "$pfx" != '' -a "$pfx" != "${var:0:3}" ]; then # beautifying 
                echo $nnl '' >> $file # Just group names (onyl toplevel)
            fi
            pfx=${var:0:3}

            case $type in
                D|S) echo $nnl "${n_ind}${var}=\"$val\"" >> $file; ;;
                O) echo $nnl "${n_ind}<!-- ${var}=\"$val\" -->" >> $file; ;;
                M) log_warning "Mandatory variable $xpath/$var from '$reqs' has not been defined, installation may fail"; ;;
                *) log_exit "Unknown type '$type' found from '$reqs' in '$xpath/$var'."; ;;
            esac
        done
    fi

    # Find all sub xpath, by calling recursively. The last part of egrep will
    # filter only the next sub level, not all below
    local x_cnt=0
    if [ "$x_items" != '' ]; then
        echo "$n_ind>" >> $file
        local pfx=''
        for entry in $x_items; do
            local ts=$(get_last_sect "$entry")                  # beautifying
            if [ "$pfx" != '' -a "$pfx" != "${ts:0:3}" ]; then
                echo '' >> $file # Akways group sub paths
            fi
            pfx=${ts:0:3}

            write_xpath "$file" "$xpath/$entry" "$ind$xml_indent"
            ((x_cnt++))
        done
    elif [ $topl == 0 ]; then     # the 1st level need </xpath> 
        # It should not be possible that both are 0 (assumed due to definition)
        echo "$n_ind/>" >> $file
    else
        echo "$n_ind>" >> $file
    fi
    
    if [ $x_cnt != 0 -o $topl == 1 ]; then
        echo "$ind</$sect>" >> $file
    fi

    if [ "$ind" == "$xml_indent" ]; then    # extra line at first ident level
        echo "" >> $file
    fi
}

: <<=cut
=func_int
Processes configuration vars
=need XML_sorted_items
An already created list with the sorted items (separated by \n)
=cut
function process_vars() {
    local prefix="$1"       # (M) the prefix of the variables to process
    local enable_add="$2"   # (O) If set then adding of variables is enabled)

    log_debug "process_vars: '$prefix' ($enable_add)"
    local var
    for var in $(set | $CMD_ogrep "^${prefix}[a-zA-Z0-9_]+"); do
        local cfg_var=$(echo -n "$var" | sed "s/$prefix//")
        local entry=$(get_xpath_from_cfg $cfg_var)
        local data="$(map_get $map_xml_data "$entry")"
        if [ "$data" == '' ]; then 
            if [ "$enable_add" != '' ]; then    # Only add if enabled, otherwise silently ignore
                # It is not predefined fit the rules (cfg section or starts with cfg prefix so add it
                map_put $map_xml_data "$entry" "CFG:S::${!var}"
                if [ $FLG_dbg_enabled != 0 ]; then
                    log_debug "process_vars(add): $entry = $(map_get $map_xml_data "$entry")"
                fi
            fi
        else 
            local reqs=$(get_field 1 "$data" ':')
            local type=$(get_field 2 "$data" ':')
            local mand=$(get_field 3 "$data" ':')
            local val=$( get_field 4 "$data" ':')

            if [ "$type" != 'S' ]; then
                val="${!var}"
                type='S'
            elif [ "$val" != "${!var}" ]; then
                log_warning "Field $entry set twice and differently '$val' != '${!var}'"
            fi
            map_put $map_xml_data "$entry" "$reqs:$type:$mand:$val"
            if [ $FLG_dbg_enabled != 0 ]; then
                log_debug "process_vars(update): $entry = $(map_get $map_xml_data "$entry")"
            fi
        fi
    done
}

: <<=cut
=func_frm
Initializes the variables used for a section xml configuration file.
This should still be followed by calls to xml_read_tmpl.
The final data can be read/split over multiple file.
Call xml_cleanup when the xml file is written/handled.
=optx
The other files to be written.
=cut
function xml_init() {
    [ -z help ] && show_ignore=1

    XML_file=''             # No file yet
    XML_validate_only=0     # Current files are mandatory
    XML_main_xpath=''       # Empty main path

    map_init $map_xml_data
    map_init $map_xml_exception
    map_init $map_xml_sub_allowed
    map_init $map_xml_depth
}

: <<=cut
=func_frm
Defines which exceptions are allowed in conflict resolution double are allowed
or if set to a value then that specific value takes  preference.
=func_note
Use the define_allowed_config_vars func to call this if needed.
=cut
function xml_exception() {
    local rpath="$1"    # (M) The normal path to the exception
    local par="$2"      # (M) The parameter name of the exception
    local val="$3"      # (O) Empty means doubles allowed otherwise the preferred value

    [ -z help ] && show_ignore=1

    val=${val:-1}       # set to 1 if empty == double allowed
    map_put $map_xml_exception "$rpath/$par" "$val"
}

: <<=cut
=func_frm
Defines which sub path are allowed from the templates files. All path
which are not defined during reading are ignore.
=func_note
Use the define_allowed_config_vars func to call this if needed.
=cut
function xml_sub_allowed() {
    local rpath="$1"    # (M) The normal path to the allowed section

    [ -z help ] && show_ignore=1

    map_put $map_xml_sub_allowed "$rpath" "1"
}

: <<=cut
=func_frm
This function should be called after the current sectioned file is process.
So if a call to xml_init is done then this should be called at the end.
Do not cleanup the maps (debugging) they will be cleaned up by init id needed.
=cut
function xml_cleanup() {
    [ -z help ] && show_ignore=1

    XML_file=''
}

: <<=cut
=func_frm
Gives the number of keys in the current xml data structure.
=stdout
The amount of keys.
=cut
function xml_count() {
    map_cnt $map_xml_data
}

: <<=cut
Adds the variables read from a template file.
=func_note
The template file has to obey to certain rules:
-le <xpath var="" > 
-le <xpath> <xpath  /> </xpath>
=cut
function xml_read_templ() {
    local templ="$1"    # (M) The template file
    local req="$2"      # (M) The requester, a free string pref small and only [a-zA-z\-_]
    local validate="$3" # (O) If set then validate only is activated. Meaning check for double only don't read
    
    if [ ! -r $templ ]; then
        log_exit "Cannot read template file '$templ'"
    fi
    if [ "$validate" != '' ]; then
        XML_validate_only=1
    else
        XML_validate_only=0
    fi
    XML_file=$templ
    XML_cur_xpath=''
    XML_cur_ppath=''
    XML_req=$(echo -n "$req" | $CMD_ogrep '^[a-zA-Z_-]+')
    XML_req=${XML_req:-?}
    XML_main_xpath=''
    
    # We are going to make a file which has the capabilities to get and set all 
    # configure file. The follwoing will be recognised.
    # <xpath    will be called with : xml_xpath 'xpath'
    # </xpath>  will be called with : xml_up 'xpath
    # />        will be called with : xml_up)
    # var="val" will be called with : xml_val 'var' 'val'
    # The temp file will only be used to read in the data
    # Yes the cmd below has 2 sed pipes, as we first need to separet all vals on a newline

    local tmp=$(mktemp)
    echo "#!/bin/sh" > $tmp
    cat $templ |  sed -r -e "s/<([a-z]+)/<\n\$xml_path '\1'\n/g" \
                         -e "s/<\/([a-z]+)>/<\/\n\$xml_up '\1'\n/g" \
                         -e "s/\/>/\n\$xml_up\n/g" \
                         -e "s/([a-z]+)=/\n\1=/g" | \
                  sed -r -e "s/([a-z]+)=[\"\']([[:space:][:alnum:][:punct:]]*)[\"\']/\$xml_var '\1' '\2'\n/g" | \
                  grep '^\$' | sed -r -e 's/^\$(.*)$/\1/' >> $tmp
    check_success "Created temp file '$tmp' for '$templ'" "$?"

    # Clean the depth as each file should start over.
    map_init $map_xml_depth

    cmd '' $CMD_chmod +x $tmp
    log_info "Reading xml template from '$tmp'"
    . $tmp 
    check_success "Read xml template values from '$templ'" "$?" 
    remove_temp $tmp
}

: <<=cut
=func_frm
Write the current xml data to the given file.
=cut
function xml_write_file() {
    local file="$1"     # (M) The file to write the configuration to
    local header="$2"   # (O) Optional header to add, written as is. So it should contain comment signs <!-- -->

    
    check_set "$file" 'Output xml file not set'

    echo -n '' > $file
    [[ "$header" != '' ]] && echo "$header" >> $file

    if [ "$XML_main_xpath" == '' ]; then
        log_exit "No main xpath found in any xml template file"
    fi

    XML_sorted_items=$(echo -n "$(map_keys $map_xml_data)" | tr ' ' '\n' | sed 's/^/\//' | sort -f -d)
    write_xpath "$file" "$XML_main_xpath"

    [ -s $file ] && log_info "Created xml file '$file'"       # Only check if created with size
}

: <<=cut
=func_frm
Retrieves the value of a specific entry. Stored within the current XML tree.
=stdout
The value retrieved or empty if not found
=cut
function xml_get_var() {
    local xpath="$1"    # (M) The full xpath except the var. Including the proper depths
    local var="$2"      # (M) The variable to get

    local data="$(map_get $map_xml_data "$xpath|$var")"
    get_field 4 "$data" ':'        # get the actual value
}

: <<=cut
=func_frm
Allow the caller to set a specif variable. If if does not exist then it is
added. If it was mandatory data then only the mandatory field is replaced.
=ret
=cut
function xml_set_var() {
    local xpath="$1"    # (M) The full xpath except the var. Including the proper depths
    local var="$2"      # (M) The variable to set
    local val="$3"      # (M) The value to set
    local req="$4"      # (O) Requester for help info
    local replace="$5"  # (O) A part of the string to replace (only if type is Data and not Set yet). Do not use \

    req=${req:-set}
    local entry="$xpath/$var"
    local data="$(map_get $map_xml_data "$entry")"
    if [ "$data" == '' ]; then
        map_put $map_xml_data "$entry" "$req:S::$val"
    else
        local reqs="$(get_field 1 "$data" ':'),$req"
        local type=$( get_field 2 "$data" ':')
        local mand=$( get_field 3 "$data" ':')

        if [ "$type" == 'M' ]; then
            val=$(echo -n "$(get_field 4 "$data" ':')" | sed "s/{.*}/$val/")
        elif [ "$type" == 'D' -a "$replace" != '' ]; then 
            val=$(echo -n "$(get_field 4 "$data" ':')" | sed "s\\$replace\\$val\\")
        fi

        map_put $map_xml_data "$entry" "$reqs:S:$mand:$val"
    fi
    if [ $FLG_dbg_enabled != 0 ]; then
        log_debug "xml_set_var: $entry = $(map_get $map_xml_data "$entry")"
    fi
}

: <<=cut
=func_frm
Will set the configuration data from a specific entity into the available
xml data. It start by adding the global entity data and then if possible then
host/instance data. If there are conflict then it will be mentioned as a warning.
=cut
function xml_set_data() {
    local enable_add="$1"  # (O) If set then adding of variables is enabled)
    local cfg="$2"         # (O) The cfg/component to read it for
    local section="$3"     # (O) The section to read it from (omitted not read)
    local instance="$4"     # (0) The instance to read it from (omitted not read) 

    local prefix='CXML_'
    local regex_unset="^${prefix}[a-zA-Z0-9_]*"

    #
    # Reading the config section (if requested))
    #
    if [ "$cfg" != '' ]; then
        unset $(set | $CMD_ogrep "$regex_unset")  # first make sure all previous are unset
        if [ "$cfg" == 'common' ]; then    # Special case do not prefix with comp
            process_section_vars "$sect_cfg/$cfg" "${prefix}" "$fld_pfx_cfg"
        else
            process_section_vars "$sect_cfg/$cfg" "${prefix}$(get_lower "$cfg")" "$fld_pfx_cfg"
        fi
        process_vars "$prefix" "$enable_add"
    fi

    #
    # Read the node/section data. This require the lc<comp> to be appended to the vars!
    #
    if [ "$section" != "" ]; then
        unset $(set | $CMD_ogrep "$regex_unset")  # first make sure all previous are unset
        process_section_vars "$section" "${prefix}" "$fld_pfx_cfg"
        process_vars "$prefix" "$enable_add"

        # See if there is instance data
        if [ "$instance" != '' ]; then
            unset $(set | $CMD_ogrep "$regex_unset")  # first make sure all previous are unset
            process_section_vars "$section#$instance" "${prefix}" "$fld_pfx_cfg"
            process_vars "$prefix" "$enable_add"
        fi
    fi
}

: <<=cut
=func_frm
Sets the next xpath (useful for xml_val function.
This is to be used during read of the template file.
=cut
function xml_path() {
    local cur_path="$1"   # (M) The current xpath
    
    local path="$XML_cur_xpath/$cur_path"
    local depth=0
    local tdepth="$(map_get $map_xml_depth "$path")"
    if [ "$tdepth" != '' ]; then
        depth=$tdepth
        ((depth++))
    fi
    map_put $map_xml_depth "$path" "$depth"
    
    XML_cur_xpath="$XML_cur_xpath/$cur_path#$depth"
    XML_cur_ppath=$(get_plain_path "$XML_cur_xpath")
    if [ "$XML_main_xpath" == '' ]; then
        XML_main_xpath="/$cur_path#$depth"     # The first is main
    fi
    
    log_debug "xml_xpath: $XML_cur_xpath | $XML_cur_ppath"
}

: <<=cut
=func_frm
Goes one xpath up.
=cut
function xml_up() {
    local prv_xpath="$1"  # (O) Previous x path not really needed

    [ -z help ] && show_ignore=1

    XML_cur_xpath=${XML_cur_xpath%/*} 
    XML_cur_ppath=$(get_plain_path "$XML_cur_xpath")

    log_debug "xml_up($prv_path): $XML_cur_xpath | $XML_cur_ppath"
}

: <<=cut
=func_frm
Set a value from the template file.
=opt2
The default value to set. Empty is optional, no default. Including any {} means
no value given, mandatory to set. 
=cut
function xml_var() {
    local par="$1"  # (M) The parameter to get
    local val="$2"  # (O) The value to set. Empty is optional, {} is mandatory

    local type='D'
    local mand=$(echo -n "$val" | $CMD_ogrep '\{.*\}')
    if [ "$XML_cur_xpath" !=  "$XML_main_xpath" ] && \
       [ "$(map_get $map_xml_sub_allowed "$XML_cur_ppath")" == '' ]; then # contains a not allowed subpath
        log_debug "xml_var: ignoring $XML_cur_xpath | $XML_cur_ppath"
        return
    fi    
    if [ "$val" == '' ]; then
        type='O'
    elif [ "$mand" != '' ]; then
        type="M"
    fi
        
    local ind="$XML_cur_xpath/$par"
    local pind="$XML_cur_ppath/$par"
    local reqs
    local data="$(map_get $map_xml_data "$ind")"
    if [ "$data" != '' ]; then
        reqs=$(       get_field 1 "$data" ':')
        local ctype=$(get_field 2 "$data" ':')
        local cval=$( get_field 4 "$data" ':')
        local excep="$(map_get $map_xml_exception "$pind")"
        # Check the exception list
        if [ "$excep" == '' ]; then
            log_warning "Unexpected double for: $pind, by $XML_req others: $reqs"
        fi        
        if [ "$type" != "$ctype" ]; then
            log_warning "Double not same type ($type != $ctype) for $ind, by $XML_req others: $reqs"
        fi
        if [ "$val" != "$cval" ]; then
            if [ "$excep" != '1' ]; then
                val=$excep
                log_debug "Chosen preferred val of '$excep' for $pind"
            else 
                log_warning "Double not same value ($val != $cval) for $ind, by $XML_req others: $reqs"
            fi
        fi
        log_debug "Found double ($ind) expected and checked."
        if [ "$reqs" == '' ]; then
            reqs="$XML_req"
        else
            reqs="$reqs,$XML_req"
        fi
    else
        reqs="$XML_req"
    fi

    if [ $XML_validate_only == 0 ]; then
        map_put $map_xml_data "$ind" "$reqs:$type:$mand:$val"
    fi
    if [ $FLG_dbg_enabled != 0 ]; then
        log_debug "xml_var($XML_validate_only): $ind = $(map_get $map_xml_data "$ind")"
    fi
}
