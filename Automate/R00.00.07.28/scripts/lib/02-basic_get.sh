#!/bin/sh

: <<=cut
=script
This script contains simple but very important helper functions related
the basic get routines. The routine make life a lot easy and readable.
=version    $Id: 02-basic_get.sh,v 1.33 2017/06/08 11:45:10 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

: <<=cut
=func_frm
Gets the uppercase of the given string. This is used to make difference between
bash 4 and up (who has inline string commands).
=func_note
Yes this might be somewhat slower then directly using bash 4 command but it is 
compatible with older bash version. Be smart try to prevent performance issues.
=stdout
=cut
function get_upper() {
    local str="$1"  # (M) The string to convert to upper case. 
    if [ "$BASH_ver" -ge '4' ]; then
        echo -n ${str^^}
    else
        echo -n "$str" | tr '[:lower:]' '[:upper:]'
    fi
}

: <<=cut
-func_frm
Gets the lowercase of the given string. This is used to make difference between
bash 4 and up (who has inline string commands).
=func_note
Yes this might be somewhat slower then directly using bash 4 command but it is 
compatible with older bash version. Be smart try to prevent performance issues.
=stdout
=cut
function get_lower() {
    local str="$1"  # (M) The string to convert to lower case. 
    if [ "$BASH_ver" -ge '4' ]; then
        echo -n ${str,,}
    else
        echo -n "$str" | tr '[:upper:]' '[:lower:]'
    fi
}

: <<=cut
=func_frm
Get a field from a given string. The separator is by default a space but can be
changed.
=stdout
The request field or empty if not found.
=cut
function get_field() {
    local fld_num="$1"  # (M) The field number to retrieve (starts at 1), like -f from cut.
    local str="$2"      # (M) The string tor retrieve from.
    local sep="$3"      # (O) The optional separator (default to ' ') 

    # 1st field requested then omit -s parameter otherwise it would not give 
    # output see also bug 24937
    local single
    [ "$fld_num" != '1' ] && single='-s'

    if [ "$sep" == '' ]; then
        echo -n "$str" | cut -d ' ' -f $fld_num $single
    elif [ "$sep" == '\t' ]; then
        echo -n "$str" | cut -f $fld_num $single
    else
        echo -n "$str" | cut -d "$sep" -f $fld_num $single
    fi
}

: <<=cut
=func_frm
Gets an array of all the field  field from a given string. 
The separator is by default a space but can be changed.
=stdout
The request fields separated by \n or empty if not found.
=cut
function get_fields() {
    local str="$1"      # (M) The string tor retrieve from.
    local sep="$2"      # (O) The optional separator (default to ' ') 

    if [ "$sep" == "$nl" -o "$sep " == '\n' ]; then
        echo -n "$str"
    elif [ "$sep" == '' ]; then
        echo -n "$str" | tr ' ' '\n'
    else
        echo -n "$str" | tr "$sep" '\n'
    fi
}

: <<=cut
=func_frm
Adapt a single field within a fielded string
=stdout
Teh newly adapted string
=cut
function mod_field() {
    local fld_num="$1"  # (M) The field number to modify (starts at 1), like -f from cut.
    local str="$2"      # (M) The string tor modify.
    local new_fld="$3"  # (M) The new field
    local sep="$4"      # (O) The optional separator (default to ' ') 

    sep=${sep:- }
    local idx=1
    local fld
    for fld in $(echo "$str" | tr "$sep" '\n'); do
        if [ "$idx" -gt '1' ]; then
            echo -n "$sep"
        fi
        if [ "$idx" == "$fld_num" ]; then
            echo -n "$new_fld"
        else
            echo -n "$fld"
        fi
        ((idx++))
    done
}

: <<=cut
=func_frm
Concatenated 2 fields and adds seperator if needed.
=stdout
=cut
function get_concat() {
    local left="$1"     # (O) The left string
    local right="$2"    # (O) The right string
    local sep="$3"      # (O) The sperator, defualts to ' ' if not given.

    sep=${sep:- }
    if [ "$left" == '' ]; then
        if [ "$right" != '' ]; then
            echo -n "$right"
        fi
    elif [ "$right" != '' ]; then
        echo -n "$left$sep$right"
    else
        echo -n "$left"
    fi
}

: <<=cut
=func_frm
Gets the mount point which is the name after the / element
=stdout
Empty if not from root. / or /<1st dir>
=cut
function get_mount_point() {
    local path="$1"     # (M) a full directory/file
    
    if [ "${path:0:1}" != '/' ]; then
        return
    fi
    
    local prev=$path
    local cur=$(dirname $prev)
    while [ "$cur" != '' -a "$cur" != '/' ]; do
        prev=$cur
        cur=$(dirname $prev)
    done
    echo -n $prev
}

: <<=cut
=func_frm
Get the variable without traign spaces.
=cut
function rem_trail_sp() {
    local str="$1"      # (M) The string to remove the traling spaces for
    echo -n "$str" |  sed "$SED_del_trail_sp"
}

: <<=cut
=func_frm
Gets an a short (unit28)  hash of the given string. This is done
by calculating the the md5sum and take the first 7 digits. Which is
then translated in to base10
=stdout
=cut
function get_short_hash() {
    local str="$1"  # (M) The string to hash

    local hsh=$(echo "$str" | $CMD_md5 | cut -d' ' -f1)
    hsh="$(get_upper "$hsh")"
    echo "ibase=16; ${hsh:0:7}" | bc 
}

: <<=cut
=func_int
Translate an external version into a normalized version which can be easily
compared. This means stripping all non numeric and making an equal amount
of digits per sub version. This is currently set to 3 digits. A maximum of 
5 sub version is assumed. 
Version are separated by '_' or '.' or '-'. Any other none digits in the front and end
are removed. None digits in the middle will cause undefined behavior. 
=stdout
The translated version. An empty version will becomes all zero's
=cut
function get_norm_ver() {
    local ver="$1"     # (M) the version to normalized <empty> wil return min, ~ will return max
    local def_val="$2" # (O) The default value if not set or ~, otherwise it will return 0's

    local max=5
    local sub='000'
    local msub='999'
    local d=${#sub}

    if [ "$ver" == '' -o "$ver" == '~' ]; then       # Potential Send the default 0's max*def
        if [ "$def_val" == '' ]; then # Only zeros if empty
            local i=0
            while [ "$i" -lt "$max"  ]; do
                [ "$ver" == '' ] && echo -n $sub || echo -n $msub
                ((i++))
            done
        else
            echo -n $def_val            # otherwise echo the given
        fi
        return
    fi
    
    # The version might be normalized already if so check and don't do anything
    local m_len=$((max * d))
    if [ ${#ver} == $m_len ] &&
       [ "$(echo -n "$ver" | $CMD_ogrep '[0-9]+')" == "$ver" ]; then
        echo -n $ver
        return
    fi

    # I had a simple printf approach but it choked on 09 which was seen as octal
    # also 10#09 in a single liner did not work out. Therefor it is now written
    # out.
    local n=0
    local l
    local dig
    for dig in $(echo -n "$ver" | $CMD_ogrep '[0-9_.\-]+' | tr '_' ' ' | tr '.' ' ' | tr '-' ' '); do
        l=${#dig}
        while [ $l -lt $d ]; do
            echo -n '0'
            ((l++))
        done
        if [ $l -gt $d ]; then
            log_info "Version digit ($n) too big, chopping '$dig' to '${dig:0:$d}'"
        fi
        echo -n ${dig:0:$d}     # Always allows a string of 1 wont add more if 2 is wanted.
        ((n++))
    done
    # Add additional digits in case not all available
    while [ "$n" -lt '5' ]; do
        echo -n "$sub"
        ((n++))
    done
}

: <<=cut
=func_frm
Get the (script) file which fittest the best to the current OS/OS version.
The OSVersion can be ranged like this:
* <from>-<till> : A full range definition
* -<till>       : All versions until the given (not included)
* <from>-       : All version from the given (included)
* <ver>         : An exact match
It is not need to change older file, the tool will find the best fit. So if
there are the folowing files:
* RH5_7-
* RH6_5-
* Then the 6.5 (or 6.6 and up) will match the RH6_5- file not the RH5_7-
* However if the current is 6.4 The it will only match RH5_7-
* Direct matches will always be preferred.

Currently this is used for steps and func. The full file should be like
/path/func_name.<extra>.$OS.[ver]-[ver].sh
After this the fallback scheme is full OS and then no OS.
=stdout
The file which matches the best.
=cut
readonly GET_def_from_version=0
readonly GET_def_till_version="1$(get_norm_ver)"
function get_best_file() {
    local base="$1"      # (M) The base path + file name. No extension excluding the OS/OSver e.g. /scripts/backup.1
    local base_type="$2" # (O) The base type, empty default to $OS, could be used to 'Any' if any_ver should be checked
    local base_pfx="$3"  # (O) The version prefix, empty default to $OS_prefix, can be used for generic version definition.
    local base_ver="$4"  # (O) The base version number, allows to overrule $OS_version (e.g. during upgrades)
    local any_ver="$5"   # (O) The version used in case Any type is found. Defaults to $base_ver
    local ext="$6"       # (O) The extension to use, defaults to 'sh'. May be a regex e.g. '(steps|sh)'
    local add_ver="$7"   # (O) If set then version are added to the output (separated by ;)

    local init=0        # Prevent useless sets if not OS like files
    local best=''
    local best_from=''
    local best_till=''

    base_type=${base_type:-$OS}
    ext=${ext:-sh}

    local cur_type=''       # Only support 1 type not mixed
    local f
    local prev_best=''
    local best_ver=0
    for f in ${base}.*.*.*; do          # get all ext to allow regex in the extension
        local type=$(get_field 2 "${f:${#base}}" '.')                 # Skip base type start after 1st .
        [ ! -e $f ]       && continue                                 # Just a safety precaution
        [ "$type" == '' ] && continue                                 # There should be a type
        [ "$type" != 'Any' -a "$type" != "$base_type" ]   && continue # Not requested type
        [ "$cur_type" != '' -a "$cur_type" != "$type" ]   && continue # Only one type allowed
        [ "$(echo -n "$f" | $CMD_ogrep "$ext\$")" == '' ] && continue # Extension does not match given

        if [ $init == 0 ]; then # call init, safes time if never an OS file found
            cur_type=$type
            base_pfx=${base_pfx:-$OS_prefix}
            base_ver=${base_ver:-$OS_version}
            any_ver=${any_ver:-$base_ver}
            base_ver=$(get_norm_ver $base_ver)
            any_ver=$( get_norm_ver $any_ver)
            if [ "$type" == 'Any' ]; then base_ver="$any_ver"; fi
            
            rx_ver="(${base_pfx}[0-9_]+)"
            rx_opt_ver="$rx_ver{0,1}"
            rx_ver_range="${rx_opt_ver}-${rx_opt_ver}"

            min_from=$GET_def_from_version
            max_till=$GET_def_till_version

            init=1
            log_debug "Best File: Base='$base', type='$base_type', pfx='$base_pfx', ver='$base_ver'|'$any_ver', ext='$ext'"
        fi
        
        log_debug "Analyzing '$f'"

        # Get the range info translate them in full version numbers like OS_version
        local range=$(echo "$f" | $CMD_ogrep "$cur_type\.$rx_ver_range\.$ext" | $CMD_ogrep "$rx_ver_range")
        local exact=''; local from=''; local till=''
        if [ "$range" == '' ]; then     # no range involved, single version ?
            local exact=$(echo "$f" | $CMD_ogrep "$OS\.$rx_ver\.$ext" | $CMD_ogrep "$rx_ver" | sed 's/_//' | $CMD_ogrep '[0-9]+')
            if [ "$exact" == "$base_ver"  ]; then
                best="$f"  ; best_ver=$exact
                from=$exact; till=$exact
                break           # no need to continue
            fi
        else
            from=$(get_norm_ver "$(get_field 1 "$range" '-')" "$min_from")
            till=$(get_norm_ver "$(get_field 2 "$range" '-')" "$max_till")

            if [ $base_ver -ge $from -a $base_ver -lt $till ]; then 
                # it is a fit but is it better? Done by looking at match from/till or
                # closest match from/till.
                if [ $from -eq  $base_ver ]; then
                    best="$f"; best_ver=$from
                elif [ $till -eq $base_ver ]; then
                    best="$f"; best_ver=$till
                elif [ $from -ne $min_from -a $from -gt $best_ver ]; then
                    best="$f"; best_ver=$from
                elif [ $till -ne $max_till -a $till -lt $best_ver ]; then
                    best="$f"; best_ver=$till
                elif [ $from -eq $min_from -a $till -ne $max_till ]; then
                    best="$f"; best_ver=$till
                elif [ $till -eq $max_till -a $from -ne $min_from ]; then
                    best="$f"; best_ver=$from
                elif [ $from -eq $min_from -a $till -eq $max_till ]; then
                    best="$f"; best_ver=$base_ver
                else 
                    # don't know yet what went wrong, complete subrange?
                    log_info "Strange file version '$f' ($range, $from, $till, $base_ver, $best_ver), skip but investigate'"
                fi
            else
                log_debug "$f no fit: $from <= $base_ver < $till"
            fi
        fi

        if [ "$prev_best" != "$best" ]; then
            log_debug "Found better: $best_ver|$best"
            best_from=$from
            best_till=$till
            prev_best=$best
        fi
    done

    if [ "$init" == '0' ]; then
        log_debug "None Found 1st round: base='$base', type='$base_type', pfx='$base_pfx', ver='$base_ver'|'$any_ver', ext='$ext'"
    fi
    
    if [ "$best" != '' ]; then
        log_debug "Selected best file: '$best'"
        echo -n "$best"
    else
        # Do the fallback options (first found is okay)
        # Do not allow version definitions to be match (so exact mactch to base or base.base_type
        for f in $base.*; do
            if [ -e $f ]; then
                if [ "$(echo -n "$f" | $CMD_ogrep "^$base\.$base_type\.$ext\$")" != '' ] ||
                   [ "$(echo -n "$f" | $CMD_ogrep "^$base\.$ext\$")" != ''             ]; then
                    log_debug "Selected best fallback file: '$f'"
                    echo -n "$f"
                    break       # Only one match needed
                fi
            fi
        done
    fi

    if [ "$add_ver" != '' ]; then
        echo -n ";$best_from;$best_till"
    fi
}

: <<=cut
=func_frm
Get all the matching files within a specific ranges. How it checks ranges
depends on the macth_type parameter:
* base_from = bf, base_till = bt, file_range_from = rf, file_range_till = rt
* always   : the range file is min/max meaning always to be selected.(rf == min && rt == max) 
* match    : the base_from has to be within the range of the file    (rf >= bf < rt)
* subrange : the whole range should be within the file range         (rf <= bf && rt >= bt)
* moveout  : the from is within, but till is outside the file range  (bf < rt <= bt && bf > rf)
* moveover : the whole file range should be within the range         (bf < rf && rt <= bt)
* movein   : the till is within, but from is outside the file range  (bf < rf <= bt && rt >= bt)
belong to a exact version (the given version fits in the range of the file).
The Version can be ranged like this:
* <from>-<till> : A full range definition
* -<till>       : All versions until the given (not included)
* <from>-       : All version from the given (included)
* <ver>         : An exact match
Currently this is used for steps and func. The full file should be like
/path/func_name.<extra>.$OS.[ver]-[ver].sh
No fallback is applied (so the version should be there).
=func_note
Our shell and script files names should never have spaces in it!
=stdout
All the files which fit in the given range. Ordered by lowest version first.
One entry on each line, the content is: <from_ver>;<till_ver>;<file>
=cut
function get_matching_files() {
    local match_types="$1"  # (M) How to match (multiple allowed comma separated. 'match', 'subrange', 'movein', 'moveout'
    local base="$2"         # (M) The base path + file name. No extension excluding the OS/OSver e.g. /scripts/upgrade.1
    local base_type="$3"    # (O) The base type, empty default to $OS, could be used to 'Any' if only Any is allowed, otherwise combinatin type | Any is allowed.
    local base_pfx="$4"   # (O) The version prefix, empty default means none
    local base_from="$5"  # (O) The from version defaults to $GET_def_from_version (base_from is included)
    local base_till="$6"  # (O) The till version defaults to $GET_def_till_version (base_till is excluded)
    local ext="$7"        # (O) The extension to use, defaults to 'sh'. May be a regex e.g. '(steps|sh)'

    match_types="$(echo -n "$match_types" | tr ',' ' ')"
    min_from=$(get_norm_ver '')
    max_till=$(get_norm_ver '~')    # Will return 99999999 ... 
    base_type=${base_type:-$OS}
    base_from=${base_from:-$min_from}
    base_till=${base_till:-$max_till}
          ext=${ext:-sh}

    base_from=$( get_norm_ver  $base_from)
    base_till=$( get_norm_ver  $base_till)

    rx_ver="(${base_pfx}[0-9_]+)"
    rx_opt_ver="$rx_ver{0,1}"
    rx_ver_range="${rx_opt_ver}-${rx_opt_ver}"

    local found=''

    log_debug "Matching Files: Base='$base', type='$base_type', pfx='$base_pfx', ver='$base_from'-'$base_till', ext='$ext'"

    local f
    for f in ${base}.*.*.*; do          # get all ext to allow regex in the extension
        local type=$(get_field 2 "${f:${#base}}" '.')                 # Skip base type start after 1st .
        [ ! -e $f ]       && continue                                 # Just a safety precaution
        [ "$type" == '' ] && continue                                 # There should be a type
        [ "$type" != 'Any' -a "$type" != "$base_type" ]   && continue # Not requested type
        [ "$(echo -n "$f" | $CMD_ogrep "$ext\$")" == '' ] && continue # Extension does not match given

        log_debug "Analyzing '$f'"

        # Get the range info translate them in full version numbers like OS_version
        local range=$(echo "$f" | $CMD_ogrep "$type\.$rx_ver_range\.$ext" | $CMD_ogrep "$rx_ver_range")
        local from=''; local till=''
        if [ "$range" == '' ]; then     # no range involved, single version ?
            local exact=$(echo "$f" | $CMD_ogrep "$type\.$rx_ver\.$ext" | $CMD_ogrep "$rx_ver")
            if [ "$exact" != '' ]; then 
                exact=$(get_norm_ver "$exact" 'empty')
                from=$exact; till=$exact
            fi
        else
            from=$(get_norm_ver "$(get_field 1 "$range" '-')" "$min_from")
            till=$(get_norm_ver "$(get_field 2 "$range" '-')" "$max_till")
        fi

        local mt
        for mt in $match_types; do
#            echo "$nl>>$f : $from - $till | $mt | $base_from - $base_till<<" 1>&2

            local fnd=0
            case "$mt" in
                'always'  ) [ "$from" -eq "$min_from"  ] && [ "$till" -eq "$max_till"  ]                                 && fnd=1; ;;   # (rf == min && rt == max)
                'match'   ) [ "$base_from" -ge "$from" ] && [ "$base_from" -lt "$till" ]                                 && fnd=1; ;;   # (rf >= bf < rt)
                'subrange') [ "$from" -le "$base_from" ] && [ "$till" -ge "$base_till" ]                                 && fnd=1; ;;   # (rf <= bf && rt >= bt)
                'moveout' ) [ "$base_from" -lt "$till" ] && [ "$till" -le "$base_till" ] && [ "$base_from" -gt "$from" ] && fnd=1; ;;   # (bf < rt <= bt && bf > rf)
                'moveover') [ "$base_from" -lt "$from" ] && [ "$till" -le "$base_till" ]                                 && fnd=1; ;;   # (bf < rf && rt <= bt)
                'movein'  ) [ "$base_from" -lt "$from" ] && [ "$from" -le "$base_till" ] && [ "$till" -ge "$base_till" ] && fnd=1; ;;   # (bf < rf <= bt && rt >= bt)
                *)  log_exit "Found unknown ($mt) match_type, programming error"; ;;
            esac
            if [ $fnd != 0 ]; then
                log_debug "Found '$mt' with range for $f"
                found+="$from;$till;$f$nl"
            fi
        done
    done

    echo -n "$found" | sort
}

: <<=cut
Get the word count of a string. With the option to use a different separator 
then space. If given then the separator chars will be replace by space before
calling the actual word count utility.
=stdout
=cut
function get_word_count() {
    local str="$1"  # (O) The string to analyze
    local sep="$2"  # (O) If given then the default of wc (space) is overruled.

    if [ "$sep" == '' ]; then
        echo -n "$str" | wc -w
    else
        echo -n "$str" | tr "$sep" ' ' | wc -w
    fi
}

: <<=cut
=func_frm
Make all the words in the string unique. Words are separated by spaces
and without newlines
=stdout
The unique words, keep in mind the order may be different.
=cut
function get_unique_words() {
    line="$1"   # (M) the string to find words in (space separated no newlines)

    echo -n "$line" | tr -s ' ' | tr ' ' '\n' | sort | uniq | tr '\n' ' '
}

: <<=cut
=func_frm
Get the intersection (=lines macthing the right handside) of two newlines 
separated lists. 
=func_note
It is possible to call the function with a different separator
e.g. space, however that make the processing slightly more expensive. This is 
not measured and should not be a problem fro small lists (< 100)
=stdout
The intersection of the two list. The input order also defines the 
order of the output list.
=cut
function get_intersect() {
    local left="$1"     # (O) the left hand side of the intersection which defines the output order as well.
    local right="$2"    # (O) the right hand side. If empty than none is passed
    local sep="$3"      # (O) The single separator charter a single character. If omited then newline is assumed

    [ "$right" == '' ] && return    # do nothing, none should intersect
    if [ "$sep" == '' -o "$sep" == '\n' ]; then
        echo -n "$left" | grep "$right"
    elif [ "${#sep}" -gt 1 ]; then
        log_exit "Wrong usage on get_intersect, sep is more than 1 char '$sep', programming error!"
    else
        local nleft="$(echo -n "$left" | tr -s "$sep" | tr "$sep" '\n')"
        local nright="$(echo -n "$right" | tr -s "$sep" | tr "$sep" '\n')"
        echo -n "$nleft" | grep "$nright" | tr '\n' "$sep"
    fi
}

: <<=cut
=func_frm
Get the index (or line number) of a given entry from a string. The entries has 
to be unique and separated by space.
=opt3
If set then the string has to be found. This string contains the part of the 
error to show. The error will be '<entry> not found in <man_err>'
=stdout
The index of the entry, the first entry is index 1. Empty if not found.
=cut
function get_index_from_str {
    local str="$1"      # (M) The string with entries to search in
    local entry="$2"    # (M) The entry to search for (exact match)
    local man_err="$3"  # (O) Optional error to give and fail in case the result is empty. 

    # use grep to make line numbers
    local res=$(echo "$str" | tr ' ' '\n' | grep -n "^$entry\$" | cut -d':' -f1)
    if [ "$man_err" != '' ]; then
        check_set "$res" "$entry not found in $man_err"
    fi
    echo -n "$res"
}

: <<=cut
=func_frm
Translates a sequence seperated with comma to potential ranges (if possible).
=stdout
Each consecutive number range from more than two will be represented as [x..y]
If none digits are in the number (e.g. for uxx) then it will not be compacted.
=cut
function get_compact_seq() {
    local seq="$1"  # (M) The sequence to compact (separated by comma).

    IFS=','
    local num
    local start=''
    local next=''
    local sep=''
    seq+=",end" # Add a dummy to trigger last
    for val in $seq; do    
        if [ "$val" == '' ]; then
            log_debug 'Skipping empty value, removed from list.'
            continue
        fi
        IFS=$def_IFS
        local num=$(echo -n "$val" | $CMD_ogrep '[0-9]+')
        if [ "$val" == "$num" -o "$val" == 'end' ]; then
            if [ "$next" == "$num" ]; then  # Still in sequence
                ((next++))
            elif [ "$val" == 'end' ] || [ "$next" == '' -o "$next" != $num ]; then
                if [ "$start" != '' ]; then   # finish range
                    local cnt=$((next - start))
                    if [ $cnt -gt 2 ]; then
                        echo -n "${sep}[$start..$((next - 1))]"
                    elif [ $cnt == 2 ]; then
                        echo -n "$sep$start,$(($start + 1))"
                    else    # 0 should not happen.
                        echo -n "$sep$start"
                    fi
                    sep=','
                elif [ "$val" == 'end' ]; then
                    break;
                fi
                start=$num
                next=$((start + 1))
            else
                log_exit "Else should never be reached!"
            fi
        else    # None number (or not full)
            echo -n "$sep$val"
            sep=','
        fi
        IFS=','
    done
    IFS=$def_IFS
}

: <<=cut
=func_frm
Translate a OS release package name int an internal release
So currently we expect:
NMMOS_RHEL6.5-12.0.0_120.02.0-x86_64
          ^ %        ^^^ ^^
Which needs to be translated into (use sed):
RH6_5-120.02 
=output
The translated version or log_exit in case of an error.
=cut
function get_trans_rh_os_release() {
    local file="$1"    # (M) The file to the version from
    local fb_rel="$2"  # (O) The version to use in case file not found.

    if [ ! -r "$file" ]; then
        if [ "$fb_rel" == '' ]; then
            log_exit "Did not find NMM release file '$file', nor fallback rel available."
        fi
        echo -n "$fb_rel"
        return
    fi

    local rel="$(cat $file | tr -d '\n')"
    # first try the current format
    local fnd_rel="$(echo -n "$rel" | sed -r 's/^NMM-?OS_RHEL([0-9]+)\.([0-9]+)-[0-9.]+_([0-9]+)\.([0-9]+).*/RH\1_\2-\3.\4/')"
    if [ "$rel" == "$fnd_rel" ]; then    # Sed did not substitute anything, try older format
        fnd_rel="$(echo -n "$rel" | sed -r 's/^[0-9.]+_([0-9]+)\.([0-9]+)\.[0-9]+-TMMOS_RHEL_([0-9]+)\.([0-9]+).*/RH\3_\4-\1.\2/')"
    fi
    if [ "$rel" == "$fnd_rel" -o "$fnd_rel" == '' ]; then    # Sed did not substitute anything
        log_exit "Failed to analyze rel ($rel), check programmed expectations."
    fi

    echo -n "$fnd_rel"
}

# The pre defined vars names. Please define them when needed.
readonly SVAR_serial_number='system-serial-number'
readonly SVAR_product_name='system-product-name'

: <<=cut
=func_frm
Retrieve a given system variable using a linux dmi name. This becuase the linux
was first. If SunOS is every implemented then a translation mehotd should be
build. This interface is preferred to be leading.
=output
The found setting of the variable or empty if no found or not supported.
=cut
function get_systen_var() {
    local svar="$1" # (M) Use the SVAR_* defines.

    if [ "$SVAR_dmidecode_check" == '' ]; then
        which dmidecode >> /dev/null 2>1
        SVAR_dmidecode_check=$?         # 0 mean available
    fi
    if [ $SVAR_dmidecode_check == 0 ]; then
        # BG24393 - Filter any potential comment lines from wrong dmidecode versions
        dmidecode -s "$svar" | grep -v '^#' | sed 's/[ \t]*$//'
    else
        log_info "No tool to get system var: '$svar'"
    fi
}

