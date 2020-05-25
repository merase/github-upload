#!/bin/sh

: <<=cut
=script
This script contains helper function related to modifying configuration files
=version    $Id: 20-modify_conf_files.sh,v 1.13 2017/06/08 11:45:10 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

SHM_cur_sect="$OS_shm/AUT_cur_sect"

SCT_tmp_cnf=''

readonly map_cnf_data='CNF_data'

: <<=cut
=func_int
Writes a line including comment to a file (appending).
=set cur_comment
Uses the current comment which will be used if needed. The
variable is always cleared.
=cut
function write_line() {
    local dst="$1"         # (M) The file name to write to.
    local full_par="$2"     # (M) Full parameter e.g.: <param> = <content>
    local pref_comment="$3" # (O) Preferred optional comment, comment sign should be included (multi lines)
    
    if [ "$pref_comment" != '' ]; then     # A new comment is given
        echo "$pref_comment" >> $dst
    elif [ "$cur_comment" != "" ]; then # Otherwise existing comment (if any)
        echo "$cur_comment" >> $dst
    fi
    cur_comment=''
    echo "$full_par" >> $dst
}

: <<=cut
=func_int
Get the indicator using the section info and the given parameter. This
function uses the shared memory under SHM_cur_sect
=stdout
The full section/par indicator
=cut
function get_ind() {
    local par="$1"  # (M) The parameter to get the indicator for.

    if [ ! -r $SHM_cur_sect ]; then
        log_exit "Shared memory ($SHM_cur_sect) for current section does not exist"
    fi
    echo -n `cat $SHM_cur_sect`"/$par"
}


: <<=cut
=func_int
Get a sectioned number which in this case may have metric prefixes 'kMGT' extension.
=stdout
If it is a number the normalized number 1024. or empty if no number. If 
the given input was empty then it will return 0.
at all.
=cut
function get_norm_number() {
    local numb="$1"     # (O) The number to check and normalize
    local def="$2"      # (O) The default to return if numb is empty

    if [ "$numb" == '' ]; then
        echo -n "$def"
    elif [ "$(echo "$numb" | $CMD_ogrep '^[0-9]{1,}[kMGT]{0,1}$')" == "$numb" ]; then
        local num=`echo "$numb" | $CMD_ogrep '^[0-9]{1,}'`
        local metric=`echo "$numb" | $CMD_ogrep '[kMGT]'`
        local k=1024
        case $metric in
            k ) num=$(($num * $k));                ;;
            M ) num=$(($num * $k * $k));           ;;
            G ) num=$(($num * $k * $k * $k));      ;;
            T ) num=$(($num * $k * $k * $k * $k)); ;;
            '') :                                  ;;
            * ) log_exit "Unhandled metric ($metric)?" 
        esac
        echo -n "$num"
    fi
}

: <<=cut
=func_frm
Modifies a parameter in sectioned config file. E.g.:
=le [section]
=le <parameter> = <content>
=
=opt5
If given than any comments in front of an existing
parameter are removed as well. All lines should have # included (multi also)
=cut
function modify_sectioned_config() {
    local dst="$1"      # (M) The file to modify.
    local mod_sect="$2" # (O) The section to modify, leave empty to edit file without sections
    local par="$3"      # (M) The parameter to modify (or add).
    local content="$4"  # (M) The parameter contents.
    local comment="$5"  # (O) Optional comment to log
    
    [ -z help ] && show_short="Modify '$dst' : "
    [ -z help ] && [ "$mod_sect" != '' ] && show_short+="[$mod_sect]"
    [ -z help ] && show_short+="$par = $content"
    [ -z help ] && [ "$comment" != '' ] && show_short+=" # comment : $comment"
    [ -z help ] && show_trans=0
    
    local fnd_sect=0
    local fnd_param=0
    local cur_comment=""      # stored comment until written out
    local inp="$(mktemp)"
    local out="$1"
    local section

    cmd '' $CMD_cp -L $dst $inp

    echo -n "" > $out       # Empty file
    IFS=''                  # Change Internal Field Seperator to read all as is
    while read line
    do
        IFS=$def_IFS
        if [ $fnd_param == 0 ]; then # go into copy mode once modified
            # First we need to find the section or skipp searching
            if [ "$mod_sect" == '' ]; then
                section=''
                fnd_sect=1
            else
                section=$(echo -n "$line" | $CMD_ogrep '^\[[0-9a-zA-Z ]+\]')
            fi

            if [ "${line:0:1}" == '#' ]; then
                # There is a special case where ^#<followed by param>$ which should be replaced
                param=$(echo -n "$line" | $CMD_ogrep '^#[0-9a-zA-Z_]+$')
                if [ "$param" == "#$par" ]; then
                   write_line $out "$par = $content" "$comment"
                   fnd_param=1    
                elif [ "$cur_comment" == "" ]; then
                    cur_comment="$line"
                else
                    cur_comment="$cur_comment"$'\n'"$line"
                fi
            elif [ "$section" != "" ]; then
                if [ $section == "[$mod_sect]" ]; then
                    fnd_sect=1      # This is the section we are looking for
                else
                    if [ $fnd_sect == 1 ]; then # we were in right section which we would end
                        write_line $out "$par = $content" "$comment"
                        fnd_param=1    
                    fi
                    fnd_sect=0
                fi
                write_line $out "$line"
            elif [ $fnd_sect == 1 ]; then
                param=$(echo -n "$line" | $CMD_ogrep '^[0-9a-zA-Z_ \t]+=[ ]?')
                if [ "$param" != '' ]; then
                    if [ "$(echo -n "$param" | $CMD_ogrep '[0-9a-zA-Z_]+')" == "$par" ]; then
                        write_line $out "$param$content" "$comment"
                        fnd_param=1
                    else
                        write_line $out "$line"
                    fi
                else
                    write_line $out "$line"
                fi
            else # Anything else write out and clear comment
                write_line $out "$line"
            fi
        else    # Currenly simple copy mode
            write_line $out "$line"
        fi
        IFS=''
    done <  $inp
    IFS=$def_IFS

    # In case the section did not existed, then add section and param
    if [ $fnd_param == 0 ]; then
        if [ "$mod_sect" != '' ]; then
            write_line $out "[$mod_sect]"
        fi
        write_line $out "$par = $content" "$comment"
    fi
    remove_temp $inp

    log_info "Modified config parameter '$par = $content'"
}

: <<=cut
=func_frm
Initializes the variables used for a section configuration file.
This is done by reading a given template file. Call sc_cleanup when
the sectioned file is written/handled.
=func_note
The template file has to obey to certain rules:
-le ^# <comment> : Is comment line
-le ^#<par> : Is a parameter currently not set
-le ^<par> : Is a parameter with a default which is set
-le <par> can be a single par (no space no =) or
-le <par = val> 

A special meaning is for [sect~] which allows the definition of a repeating
section. In which all parameters need to be set by the framework. This is
for example being used in the MySQL-Custer module (configure_Ndb-Mgr.1.sh)
=cut
function sc_init() {
    local templ="$1"    # (M) The template file
    
    if [ ! -r $templ ]; then
        log_exit "Cannot read template file '$templ'"
    fi

    map_init $map_cnf_data

    cmd '' $CMD_rm $SHM_cur_sect
    
    # We are going to make a file which has the capabilities to get and set all 
    # configure file.
    # [section] will be replaced with  : $(sc_sect section)
    # par = val will be replaced with  : $(sc_get 'par' 'val' )
    # par       will be replaced with  : $(sc_get 'par' '' )
    # #par = val will be replaced with : $(sc_get 'par' 'val' #)
    # #par       will be replaced with : $(sc_get 'par' '' #)
    # The temp file will be prepared to create the config file

    local tmp=$(mktemp)
    echo "#!/bin/sh" > $tmp
    echo "out=\${1:-/dev/null}" >> $tmp
    echo "cat << EOF > \$out" >> $tmp
    cat $templ |  sed -r -e "s/^\[(.*)\]/\$(sc_sect '\1')/" \
        -e "s/^(#?)([a-zA-Z_-]+)[ \t]*=[ \t]*(.*)/\$(sc_get '\2' '\3' '\1')/" \
        -e "s/^(#?)([a-zA-Z_-]+)$/\$(sc_get '\2' '' '\1')/" >> $tmp
    echo "EOF" >> $tmp
    cmd '' $CMD_chmod +x $tmp
    SCT_tmp_cnf=$tmp
    log_info "Create template file for '$templ' using '$tmp'"

    # The initial default cannot be read in directly as they have to be run from
    # the local context and not the $( ). $( ) is able to read vars, not set it
    SCT_writing=''
    tmp=$(mktemp)
    echo "#!/bin/sh" > $tmp
    cat $SCT_tmp_cnf | grep '^\$(' | sed -r -e 's/^\$\((.*)\)$/\1/' >> $tmp
    . $tmp > /dev/null
    check_success "Read default value for '$templ' using '$tmp'" "$?" 
    remove_temp $tmp
}

: <<=cut
=func_frm
This function should be called after the current sectioned file is process.
So if a call to sc_init is done then this should be called at the end.
=cut
function sc_cleanup() {
    if [ "$SCT_tmp_cnf" != '' ]; then
        remove_temp $SCT_tmp_cnf
    fi 
    cmd '' $CMD_rm $SHM_cur_sect
    SCT_tmp_cnf=''
}

: <<=cut
=func_frm
Write the current configuration data to the given file.
=cut
function sc_write_file() {
    local cnf="$1"  # (M) The file to write the configuration to
    
    check_set "$cnf" 'Output configuration file not set'
    check_set "$SCT_tmp_cnf" 'Template file should be set sc_init() called?'
    
    # This is actualy easy call the temp file.lets check if executable
    if [ ! -x $SCT_tmp_cnf ]; then
        log_exit "Template file is not found or not executable '$SCT_tmp_cnf'"
    fi 
    log_debug "Next step write cnf file '$cnf' using '$SCT_tmp_cnf'"
    SCT_writing="$cnf"
    . $SCT_tmp_cnf "$cnf"
    check_success "Create configuration file  '$cnf' using '$SCT_tmp_cnf'" "$?"

    if [ "$AUT_strip_sc_comment" != '' ]; then
       cmd "Stripping all comment from $cnf" $CMD_sed -i -e 's/^#.*$//g' $cnf
    fi
}

: <<=cut
=func_frm
Gets a data value from a specific section name. It will not return the defaults.
=stdout
The requested value of empty if not set (yet).
=cut
function get_sc_data() {
    local sect="$1"     # (M) The section to query.
    local par="$2"      # (M) The parameter to query.

    sect="$(echo -n "$sect" | sed 's/ /=/g')"
    local data="$(map_get $map_cnf_data "$sect/$par")"
    if [ "$(get_field 3 "$data")" != '#' ]; then
        echo -n $(get_field 1 "$data")
    fi
}

: <<=cut
=func_frm
Set a value for a specific section name. The setting has to be accompanied
with a requirement type. This allows to define a range. Stetting the min and max
the same will cause it to be an exact value.
=cut
function set_sc_data() {
    local req="$1"      # (M) The entity requesting this
    local sect="$2"     # (M) The section to set.
    local par="$3"      # (M) The parameter to set.
    local val="$4"      # (M) The value to set
    local min_num="$5"  # (M) The minimum required val (only for numbers)
    local max_num="$6"  # (M) The maximum required val (only for numbers)

    [ -z help ] && show_short="[$sect]$par='$val'"
    [ -z help ] && [ "$min_num$max_num" != '' ] && show_short+=" [$min_num..$max_num]"
    [ -z help ] && show_trans=0

    local num=$(get_norm_number $val 0)
    local min_num=$(get_norm_number $min_num)
    local max_num=$(get_norm_number $max_num)
    local ind="$(echo -n "$sect" | sed 's/ /=/g')/$par"
 
    if [ "$(map_get $map_cnf_data "$ind")" == '' ]; then   # Not there yet, may be auto indexed one?
        if [ "$(echo -n "$sect" | grep '~')" != '' ]; then     # Create data for it
            map_put $map_cnf_data "$ind" "$val $val *"
        else    # There should be a default otherwise it wont be written
            log_exit "No default/location known for [$sect]$par=, fix template!"
        fi
    fi

    local data="$(map_get $map_cnf_data "$ind")"
    local cval=$(get_field 1 "$data")
    local cnum=$(get_field 2 "$data")
    local reqs=$(get_field 3 "$data")
    local minn=$(get_field 4 "$data")
    local maxn=$(get_field 5 "$data")

    if [ $FLG_dbg_enabled != 0 ]; then
        log_debug "data[$ind]='$(map_get $map_cnf_data "$ind")'" 
        if [ "$min_num" != '' -o "$max_num" != '' ]; then
            log_debug "set_sc_data $@, reqs:'$reqs', cval:'$cval' '$minn'<'$cnum'<'$maxn'"
        else
            log_debug "set_sc_data $@, reqs:'$reqs', cval:'$cval'"
        fi
    fi

    if [ "$reqs" == '#' -o "$reqs" == '*' ]; then   # It is an default always allowed
        req="$req"      # Set requester
    else
        if [ "$num" != '' ]; then
            if [ "$min_num" != '' ] && [ "$minn" != '' ] && [ "$min_num" -lt "$minn" ]; then
                min_num=$minn       # Do not update with new value
            fi
            if [ "$max_num" != '' ] && [ "$maxn" != '' ] && [ "$max_num" -gt "$maxn" ]; then
                max_num=$maxn       # Do not update with new value
            fi
            if [ "$cnum" != '' ] && [ "$num" -lt "$cnum" ]; then
                # Note currently the assumption is bigger is better!
                val=$cval
                num=$cnum
            fi
            if [ "$min_num" != '' ] && [ "$num" -lt "$min_num" ]; then
                log_exit "Incompatible setting requested by: $req($reqs), par='$par', val<$val | $cval, sub-range: [$min_num..$max_num]"
            elif [ "$max_num" != '' ] && [ "$num" -gt "$max_num" ]; then
                log_exit "Incompatible setting requested by: $req($reqs), par='$par', val>$val | $cval, sub-range: [$min_num..$max_num]"
            elif [ "$min_num" == '' ] && [ "$max_num" == '' ] && [ "$num" != "$cnum" ]; then
                # No exact mach, but no raneg given, so allowed, but give a log_info
                log_info "Different setting requested by but no boundary: $req($reqs), par='$par', val:'$cval' != '$val'"
            fi
        elif [ "$val" != "$cval" ]; then
            log_exit "Different setting requested for $ind, by: $req($reqs), par='$par', val:'$cval' != '$val'"
        fi
        req="$reqs,$req"        # add requester
    fi
    if [ "$num" != '' ]; then
        map_put $map_cnf_data "$ind" "$val $num $req $min_num $max_num"
    else
        map_put $map_cnf_data "$ind" "$val $val $req $min_num $max_num"
    fi
}

: <<=cut
=func_frm
Sets a new section to be accessed (useful for sc_get functions.
This is to be used during creating of the config file.
=stdout
Returns the given section in the proper output like [<sect>]
=cut
function sc_sect() {
    local cur_sect="$1"   # (M) The current section

    local str_sect="$(echo -n "$cur_sect" | sed 's/ /=/g')" # Section used for storing in map
    log_debug "sc_sect: $cur_sect | $str_sect"
    echo -n "$str_sect" > $SHM_cur_sect

    if [ "$SCT_writing" == '' -o "$(echo -n "$cur_sect" | grep '~')" == '' ]; then
        echo -n "[$cur_sect]"           # Not writing or normal echo
    else        # Contains a ~ and writing write out all data belong to an index
        local sect
        for sect in $(map_keys $map_cnf_data | tr ' ' '\n' | grep "^$str_sect" | sort | tr '\n' ' '); do
            local entry
            echo "[$(get_field 1 "$sect" '~' | sed 's/=/ /g')]"
            for entry in $(map_keys "$map_cnf_data/$sect"); do
                local set="$(get_field 1 "$(map_get "$map_cnf_data/$sect" "$entry")")"
                echo "$entry = $set"
            done
            echo ""
        done
    fi
}

: <<=cut
=func_frm
Gets a value from the configuration while giving a default value if not overruled.
This is to be used during creating of the config file.
=stdout
Returns the given value or the default fit not overrule. Like: <par> = <val>
=cut
function sc_get() {
    local par="$1"  # (M) The parameter to get
    local val="$2"  # (O) The value to set. If empty then this is supposed to be a switch. If ~ then it is an empty string
    local req="$3"  # (O) Requester either # or *, empty. # indicate a default is given but out commented

    case "$req" in
        '#')    req='#'; ;; # Default but outcommented
        '*'|'') req='*'; ;; # Default and set
        *) log_exit "Wrong requester either use #, * or empty"
    esac
    
    if [ "$val" == '' ]; then
        val='!'             # indicates a switch
    fi
    
    local ind=$(get_ind "$par")
    local data="$(map_get $map_cnf_data "$ind")"
    local set=$(get_field 1 "$data")
    local reqs=$(get_field 3 "$data")
    log_debug "sc_get: ind:'$ind', val:'$val', set:'$set', req:'$req', reqs:'$reqs'"
    if [ "$set" == '' ]; then       # Not yet set, so set default
        local num=$(get_norm_number "$val")
        if [ "$num" != '' ]; then
            map_put $map_cnf_data "$ind" "$val $num $req"
        else
            map_put $map_cnf_data "$ind" "$val $val $req"
        fi
        set=$val
        reqs=$req
    fi
    
    if [ "${set:0:1}" == '!' ]; then       # This is a switch
        if [ "$set" == '!0' ]; then
            echo -n "#$par"         # And is disabled out-comment it
        elif [ "$set" == '!1' ]; then
            echo -n "$par"          # Enabled so show it
        elif [ "$reqs" == '#' ]; then
            echo -n "#$par"      # Show but with potential disabled option
        else
            echo -n "$par"      # Show but with potential disabled option
        fi
    else
        if [ "$reqs" == '#' ]; then   # Use the default value not overrule
            echo -n "#"
        fi
        echo -n "$par = "
        case "$set" in     # Some values have special handling
            OFF) echo -n '0'   ; ;;
            ON)  echo -n '1'   ; ;;
            *)   echo -n "$set"; ;;
        esac
    fi
}
