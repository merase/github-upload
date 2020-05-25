#!/bin/sh

: <<=cut
=script
This script contains functions to show/create help from the original
scripts. How to do this with limited changes in the files and
limited copied (and thus faulty) information.
=remark
MAJOR REMARK. THIS CODE IS NOT THE NICEST IN REGARDS TO GLOBAL VARIABLES
BUT IT DOES DO THE TRICK AND ALLOWS LOCALIZIGN THE FILES WHERE THE EXPLANATION
BELONGS. dO NOT CONSIDER THIS WAY OF WORKING AS A BEST PRACTICE FOR GENENERIC
BASH PROGRAMMING.

THIS IS NOT SYNTAX CHECKER, IN SOME PLACES IT ASSUMES THE BASH CODE IS CORRECT!
=version    $Id: 85-show_help.sh,v 1.3 2017/06/08 11:45:10 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

SHLP_inited=0               # Record if SHLP module is initialized before
SHLP_cur_user='unk'         # Attempt to identify cur user.
SHLP_cur_node="@$hw_node"   # The current nod, currenlty not changed
SHLP_cur_node=''            # As the current node does not work set it to empty, remove when implemented
SHLP_cur_inst=''            # The current instance, for removing double reports, but allow changes

         SHLP_no_func_yet='' # Remove when func support fully build
         SHLP_dbgind=0
readonly SHLP_ind='                               '


readonly SHLP_w_dbg='dbg'   # Silent parameter
readonly SHLP_w_dev='dev'
readonly SHLP_w_sup='sup'
readonly SHLP_what="$SHLP_w_sup,$SHLP_w_dev"    # List with supported types.
readonly SHLP_nc=$'\266' # An alternative  newline character (overcomming $() problems

readonly SHLP_regex_bashvar='[a-zA-Z_][a-zA-Z0-9_]*'
readonly SHLP_func_marker='\[ -z help \] && '     # the exact marker to be used in functions. DO NOT CHANGED.
readonly SHLP_stdout='/dev/stdout'

readonly map_shlp="SHLP_tags"
# fields used in the above map
readonly  shlp_name='name'
readonly  shlp_type='type'
readonly shlp_short='short'
readonly  shlp_what='what'
readonly  shlp_help='help'

readonly map_var='SHLP_var'
# map_var/<name>/
readonly var_name='name'               
readonly var_type='type'     # p=function parameter (always local), l=local var, g=global var
readonly var_init='initial'  # The Initial value
readonly var_cur='current'   # The current value
readonly var_def='default'   # The default value (may be set multiple times)
readonly var_pidx='pidx'     # Index referring to parameter $[1-9] (number only)

readonly map_var_expr='SHLP_var_expr'
# map_var_expt/<expr_nr>
# fields used in the above map
readonly vare_var='var'      # links to a map_var/<name>
readonly vare_expr='expr'    # the variable expression
readonly vare_lno='lno'      # The original line no

readonly map_steps='SHLP_steps' # Used for prefixing deifferent types, also build internally
readonly map_steps_now="${map_steps}_now"
readonly map_steps_later="${map_steps}_later"
readonly map_funcs='SHLP_funcs'
readonly map_links='SHLP_links' # To quickly refer back
readonly map_calls='SHLP_call_expr' # A link from a call expr_no to func/step
readonly scr_type='type'        # FOr easy reference
readonly scr_name='name'
readonly scr_comp='comp'        # Optional comp for func/step
readonly scr_step='step'        # the full step info (including parameters)
readonly scr_pars='pars'        # Additional parameters for func [number 1-9 added]
readonly scr_refs='refs'        # The amount of references to this func/step
readonly scr_tags='main_tags'
readonly scr_files='files'
readonly scr_file='file'
readonly scr_link='link'        # A link to a script entity
readonly scr_pr_ref='last_pr_ref'
readonly scr_docu='documented'
readonly scr_expr_ref='expr_ref'

readonly file_task="$OS_shm/.Help-Task-Num.dat"
readonly file_numb="$OS_shm/.Help-Numb-Num.dat" # ind depth will be added

readonly TAG_id='='             # The tag identifier, single char!!
readonly TAG_indent='  '
readonly TAG_dev='D '
readonly TAG_indent_len=${#TAG_indent}

: <<=cut
=func_int
Adds a tag with proper info to be stored in the map.. This will create the following 
TAG_<name>=<tag>
TINF_<name>=<info>
T
=cut
function add_tag() {
    local tag="$1"      # (M) The tag to add
    local name="$2"     # (M) The name, if epty tag is used
    local type="$3"     # (M) Identifies the type of the tage S=singel, M=multi, I=ignore
    local short="$4"    # (O) The short description use in the show otuput
    local what="$5"     # (O) If set then this tag is only valid for sepicfi levels (multiple separated by ,)
    local help="$6"     # (O) Any additonal help, just nice for recording.
    
    local map="$map_shlp/$tag"
    [ "$what" != '' ] && what="$what,$SHLP_w_dbg"       # Add if debug if any
    map_put $map "$shlp_name"  "${name:-$tag}"
    map_put $map "$shlp_type"  "$type"
    map_put $map "$shlp_short" "$short"
    map_put $map "$shlp_what"  "$what"
    map_put $map "$shlp_help"  "$help"
}

: <<=cut
=func_int
WIll read a specific tag and puts them into the tag_* vars
=set tag_tag
The real tag. If empty then the tag was not found
=set tag_name 
The name of the current tag
=set tag_type
Identifies the current type of tag (see add_tag)
=set tag_short
The short discription to use in show output
=set tag_what
Indetifies for what it applies. Empty means all
=cut
function read_tag() {
    local tag="$1"      # (O) The tag to read

    local map="$map_shlp/$tag"
    map_exists "$map"
    if [ $? != 0 ]; then
        tag_tag="$tag"
        tag_name="$( map_get "$map" "$shlp_name")"
        tag_type="$( map_get "$map" "$shlp_type")"
        tag_short="$(map_get "$map" "$shlp_short")"
        tag_what="$( map_get "$map" "$shlp_what")"
        # tag_help currently not read
    else
        tag_tag=''
    fi
}

: <<=cut
=func_int
Initialise the show help configuration
=cut
function init_show_help() {
    [ $SHLP_inited != 0 ] && return

    map_init $map_shlp
    
    add_tag author      ''        S 'Author: '                       'dev' 'Identifying the author'
    add_tag brief       ''        I ''                               ''    'An oneliner brief description. Mainly used by the automate tool.'
    add_tag cut         ''        S ''                               ''    'End tag of full pod section.'
    add_tag example     ''        I ''                               ''    'An example text.'
    add_tag fail        ''        M "What to-do if step fails:$nl"   ''    'What could be done to continue.'
    add_tag feat        ''        I ''                               ''    'A feature description.'
    add_tag fut_feat    ''        I ''                               ''    'A future feature description (not yet build).'
    add_tag func_ext    ''        I ''                               ''    'External function.'
    add_tag func_frm    ''        I ''                               ''    'Framework function.'
    add_tag func_int    ''        I ''                               ''    'Internal function.'
    add_tag help_todo   ''        S "File not checked for help, skipping: " '' 'This will stop processing the file, until it is approved.'
    add_tag le          ''        L '- '                             ''    'Identifies a listed item.'
    add_tag need        ''        I ''                               ''    'Define a global variable which is needed.'
    add_tag ret         'return'  I ''                               ''    'A return value.'
    add_tag script      ''        M "Step Information:$nl"           ''    'A script defintion.'
    add_tag script_note ''        M "Please note:$nl"                ''    'An additional srip note.'
    add_tag set         ''        I ''                               ''    'Identifies a variable to be set.'
    add_tag stdout      ''        I ''                               ''    'Instruct the ouput of function it through stdout.'
    add_tag version     ''        S 'Version: '                      'dev' 'Include a CVS like version.'
    
    local i
    for i in 1 2 3 4 5 6 7 8 9; do
        add_tag "man$i" "par_man$i" M "Mandatory Parameter-$i: "        ''    "Mandatory parameter$i."
        add_tag "opt$i" "par_opt$i" M "Optional Parameter-$i: "         ''    "Optional paramater$i."
    done
    add_tag     "optx"  "par_optx"  M 'Other Parameters: '           ''    'Any other Optional paramaters.'
    
    
    SHLP_inited=1
}

function dbg_msg() {
    if [ "$cur_what" == "$SHLP_w_dbg" ]; then
        if [ "$SHLP_dbgind" -lt 0 ]; then
            echo -ne "D $1 (${COL_todo}Warning ind($SHLP_dbgind) < 0 $COL_def" 1>&2
        fi
        echo "D ${SHLP_ind:0:$SHLP_dbgind}$1" 1>&2
    fi
}

function dev_msg() {
    [ "$cur_what" == "$SHLP_w_dev" -o "$cur_what" == "$SHLP_w_dbg" ] && echo "$1" 1>&2
}

: <<=cut
=func_int
Simple but uniform function to get a link to func/step. Just in case something
might change. 
=cut
function get_link_map() {
    local type="$1" # (M) [func|step]
    local name="$2" # (M) Name of th func or step
    local comp="$3" # (O) The component if known

    echo "$map_links/$type:$name:$comp"
}

: <<=cut
=func_int
Simple but uniform function to get a call to func/step. Just in case something
might change. 
=cut
function get_call_map() {
    local expr_no="$1" # (O) The xepression no, default to $cur_expr_no
 
    expr_no=${expr_no:-$cur_expr_no}
    printf "$map_calls/%05d" "$expr_no"
}

function add_step_todo() {
    local info="$1"     # (M) Full step info
    local when="$2"     # (O) [now|later] defualt is now
    local docu="$3"     # (O) Sets the already documented data

    when="${when:-now}"

    check_in_set "$when" 'now,later'

    local name="$(get_field 1 "$info")"
    local comp="$(get_field 2 "$info")"
    if [ "$comp" != '' ]; then
        find_install "$comp" 'optional'
        [ "$install_idx" == '0' -o "$install_aut" == '' ] && comp=''
    fi

    local ref="$(printf "%03d" $(map_cnt "${map_steps}_$when"))-$name"
    local map="${map_steps}_$when/$ref"
    local lmap="$(get_link_map step "$name" "$comp")"
    local cmap="$(get_call_map)"

    map_exists "$lmap"
    if [ $? == 0 ]; then
        map_put "$map" "$scr_type" 'step'
        map_put "$map" "$scr_name" "$name"
        map_put "$map" "$scr_comp" "$comp"
        map_put "$map" "$scr_step" "$info"
        [ "$docu" != '' ] && map_put "$map" "$scr_docu" "$docu" # only set not clear

        map_link "$map_links" "$(basename "$lmap")"  "${map_steps}_$when" "$ref"

        # Collect and store the step files
        local files="$(find_step_files "$info")"
        local file
        local idx=0
        for file in $files; do
            local fmap="$map/$scr_files/$(printf "%02d" $idx)"
            map_put "$fmap" "$scr_file" "$file"
            store_main_tag_into_map "$fmap/$scr_tags" "$file"
            ((idx++))
        done 
    else
        local refs="$(map_get "$lmap" "$scr_refs")"
        ((refs++))
        map_put "$lmap" "$scr_refs" "$refs"
        [ "$docu" != '' ] && map_put "$lmap" "$scr_docu" "$docu" # only set not clear
    fi

    # Parameters not stored yet (so far not needed, see add_func_todo)    
    map_link "$cmap" "$scr_link" "$map_links" "$(basename "$lmap")" 
}

function add_func_todo() {
    local func="$1"     # (M) The function to add
    local comp="$2"     # (O) The component for this func, empty if generic (no need to validated]
    local pidx="$3"     # (O) The parameter index to add parameters from the show_pars array

    local ref="$(printf "%03d" $(map_cnt "$map_funcs"))-$func"
    local map="$map_funcs/$ref"
    local lmap="$(get_link_map func "$func" "$comp")"
    local cmap="$(get_call_map)"

    map_exists "$lmap"
    if [ $? == 0 ]; then
        map_put "$map" "$scr_type" 'func'
        map_put "$map" "$scr_name" "$func"
        map_put "$map" "$scr_comp" "$comp"
        map_put "$map" "$scr_refs" "1"
 
        map_link "$map_links" "$(basename "$lmap")"  "$map_funcs" "$ref"

        # Collect and store the func files (ccp code yes sometimes I get tired)
        local files="$(find_func_files "$func" "$comp")"
        local file
        local idx=0
        for file in $files; do
            local fmap="$map/$scr_files/$(printf "%02d" $idx)"
            map_put "$fmap" "$scr_file" "$file"
            store_main_tag_into_map "$fmap/$scr_tags" "$file"
            ((idx++))
        done
    else
        local refs="$(map_get "$lmap" "$scr_refs")"
        ((refs++))
        map_put "$lmap" "$scr_refs" "$refs"
    fi

    # Store parameters in generic call map
    local idx=$pidx; local cnt=1
    while [ "${show_pars[$idx]}" != '' ]; do
        map_put "$cmap/$scr_pars" "par$cnt" "${show_pars[$idx]}"
        ((idx++)); ((cnt++))
    done
    map_link "$cmap" "$scr_link" "$map_links" "$(basename "$lmap")" 
}

: <<=cut
=func_int
Stores a specific tag. Some tags are using sequential sub maps
=cut
function store_tag() {
    local map="$1"  # (M) The  main map to store in
    local tag="$2"  # (M) The tag to store
    local info="$3"  # (M) the full info

    local dst_map="$map"
    case "$tag" in
        'set'|'need') 
            dst_map+="/$tag"
            tag="$(printf "%02d" $(map_cnt "$dst_map"))"
            ;;
        *)  : ;;
    esac

    map_put "$dst_map" "$tag" "$info"
}

: <<=cut
=func_int
Will store all the main tags (first cut section) into a given map.
This funciton does not care about the tags at all is written
=cut
function store_main_tag_into_map() {
    local map="$1"  # (M) The map to create it in, a submap $tag will be create
    local file="$2" # (M) The file to parse

    if [ ! -r "$file" ]; then
        map_put "$map" 'short_help' "File '$file' not found, not further described"
        return
    fi

    local info=''
    local line
    local state=0     # 0=finding 1st marker, 1 found id, 9=done
    local ctag=''
    local sep=''
    IFS=''; while read line; do IFS=$def_IFS
        line="$(echo -n "$line" | sed -e "$SED_del_preced_sptb" -e "$SED_del_trail_sptb")"
        case $state in
            0) [ "$(echo -n "$line" | grep '^ *: *<<=cut')" != '' ] & state=1; ;;
            1) if [ "${line:0:1}" == "$TAG_id" ]; then
                    [ "$info" != '' ] && store_tag "$map" "$ctag" "$info"
                    ctag="$(get_field 1 "${line:1}")"      # strip the tag (remove id and get full tag
                    info="$(get_field 2- "${line}")"      # get the rest
                    [ "$info" == '' ] && sep='' || sep="$nl"
               elif [ "${line:0:4}" == '=cut' ]; then
                    state=9             # Just for processing last data
               else
                    info+="$sep$line"
                    sep="$nl"
               fi
               ;;
            9) [ "$info" != '' ] && store_tag "$map" "$ctag" "$info"
               break; ;;                # Done with the file
        esac
    IFS=''; done < $file;  IFS=$def_IFS
}

: <<=cut
=func_int
Unquotes a string and removes the earlier created <[sect]var='val'>
Only call this if you known not more then 1 parama is availble
=cut
function unconfig() {
    local string="$1"       # (O) The string to unquoute

    dbg_msg "unconfig : [$string]"

    # The sed regex filters all <[sect]var='val' into val
    unquote "$string" | $CMD_sed "s/<\[[^]]*\][^=]*='\([^']*\)'>/\1/g"
}

: <<=cut
=func_int
Removes the "'" and '"' from the string.
=cut
function unquote() {
    local string="$1"   # (O) The string to unquoute
    local indent="$2"   # (O) Add an extra indent after every new_line

    dbg_msg "unquote : [$string][$indent]"
    
    case "${string:0:1}" in
        "'"|'"') string="${string:1}"; ;;
    esac
    local len=${#string}
    if [ $len -gt 0 ]; then
        ((len--))
        case "${string:$len:1}" in
            "'"|'"') string="${string:0:$len}"; ;;
        esac
    fi

    if [ "$indent" == '' ]; then        # Separated for speed, coudl have been 1
        echo -n "$string" | tr "$SHLP_nc" "$nl"
    else
        echo -n "$string" | tr "$SHLP_nc" "$nl" | $CMD_sed "1 ! s/^/$indent/"
    fi

}

function escape() {
    local string="$1"   # (O) The string to escape
    
    echo -n "$string" | $CMD_sed 's/"/\\"/g'
}

function inc_indent() {
    ((cur_ind_lvl++))
}

function dec_indent() {
    [ $cur_ind_lvl -gt 0 ] && ((cur_ind_lvl--))
}

function get_indent() {
    local text="$1"     # (O) The text to print, normaly a single character as defined by p_* funcs
    local tmp_diff="$2" # (O) use - or + to indicate one temporary diff to cur_ind_lvl

    local lvl=$cur_ind_lvl
    case "$tmp_diff" in
        '-') [ $lvl -gt 0 ] && ((lvl--)); ;;
        '+')                   ((lvl++)); ;;
        '++')       ((lvl++)); ((lvl++)); ;;    # Added for special case
        *)   :                            ;;
    esac

    if [ "$text" == 'T' ]; then # Translate the task symbol
        if [ $lvl == 0 ]; then
            text="$cur_task."
            ((cur_task++))
            echo -n "$cur_task" > "$file_task"     # Update new task number
        else
            text='*'
        fi
    fi
    if [ $lvl == 0 ]; then
        printf "%-4s" "$text"
    else
        local len=$(((lvl-1)*3+4))
        printf "%-${len}s" ''
        [ "$text" != '' ] && printf "%-3s" "$text"
    fi
}

function p_none() {
    local tmp_diff="$1" # (O) use - or + to indicate one temporary diff to cur_ind_lvl

    get_indent '' "$tmp_diff"
}

function p_task() {
    local tmp_diff="$1" # (O) use - or + to indicate one temporary diff to cur_ind_lvl

    get_indent 'T' "$tmp_diff"
}

function p_info() {
    local tmp_diff="$1" # (O) use - or + to indicate one temporary diff to cur_ind_lvl

    get_indent '#' "$tmp_diff"
}

function p_extra() {
    local tmp_diff="$1" # (O) use - or + to indicate one temporary diff to cur_ind_lvl

    get_indent '*' "$tmp_diff"
}

function p_list() {
    local tmp_diff="$1" # (O) use - or + to indicate one temporary diff to cur_ind_lvl

    get_indent '-' "$tmp_diff"
}

function p_fail() {
    local tmp_diff="$1" # (O) use - or + to indicate one temporary diff to cur_ind_lvl

    get_indent '!' "$tmp_diff"
}

function p_numb() {
    local tmp_diff="$1" # (O) use - or + to indicate one temporary diff to cur_ind_lvl

    local file="$file_num$cur_ind_lvl"
    [ ! -r "$file" ] && reset_numb
    
    local numb="$(cat "$file")"
    numb=${numb:-1}
    get_indent "$numb)" "$tmp_diff"
    ((numb++))
    echo "$numb" > "$file"
}

: <<=cut
=func_int
Reset the number for the current depth
=cut
function reset_numb() {
    echo "1" > "$file_num$cur_ind_lvl"
}

        
function trans_vars() {
    local var="$1"      # (M) The var to Translate, empty is in fact erre, but returns <empty>
    local no_sect="$2"  # (O) If set no section translation is needed

    dbg_msg "trans_vars : [$var][$no_sect]"

    local check_var=0
    local trans_var=0
    local ins
    local par   
    local len
    local def=''
    local sect=''

    if [ "$var" == '' ]; then
        echo "<empty>" 
    elif [ "${var:0:1}" == '{' ]; then
        var="${var:1}"; var="${var%?}"
        par="$(echo -n "$var" | $CMD_ogrep "^$SHLP_regex_bashvar")"  # All until next control char
        local idx="${#par}"
        if [ $idx -gt 0 ]; then
            case "${var:$idx:1}" in
                '}') var="$par"; trans_var=1; ;;   # It is a simple {<var>}n no complex stuff
                ':') ((idx++))                     # Don' support all
                     local nc="${var:$idx:1}"
                     case "$nc" in
                        '-') ((idx++))             # Default value
                             def="$(parse_string "${var:$idx}" $no_sect)" 
                             var="$par"
                             check_var=1
                             ;;
                        [0-9])                  # Single digit start index
                             case "$par" in     # ouch soem conflicting naems, which are hard to resolve so make excetption
                                'file') echo -n "<\$$par strip of first $nc digits>"; ;;
                                *)      echo -n "${!par:$nc}"; ;;
                             esac
                             ;;
                     esac
                     ;;
            esac
        else
            echo "\${$var}"           # Current complex not further handled, show as is
        fi
    elif [ "${var:0:1}" == '(' ]; then      # assume ending) as well
        if [ "${var:1:1}" == '(' ]; then    # A double (( is a expression to evaluate
            :   # todo ?
        else
            var="${var:1}"; var="${var%?}"
            ins="$(get_field 1 "$var")"
            case "$ins" in
                'basename'|'dirname'|'get_mount_point'|'get_short_hash'|'get_state')       # Should have 1 par!
                    par="$(parse_string "$(get_field 2- "$var")" $no_sect)"; 
                    echo -n "$($ins "$par")"
                    ;;
                'get_field')
                    parse_pars "$var"
                    if [ "$(echo -n "${prs_pars[1]}" | $CMD_ogrep '^[0-9-]*$')" != '' ]; then
                        echo -n "$(get_field "${prs_pars[1]}" "${prs_pars[2]}" "${prs_pars[3]}")"
                    fi  # else don't print anything is the safest
                    ;;
                'get_bck_dir')
                    parse_pars "$var"
                    echo -n "$(get_bck_dir "${prs_pars[1]}" "${prs_pars[2]}" "${prs_pars[3]}" 'no_create')"
                    ;;
                'get_best_file'|'get_matching_files')
                    parse_pars "$var"
                    echo -n "$($ins "${prs_pars[1]}" "${prs_pars[2]}" "${prs_pars[3]}" "${prs_pars[4]}" "${prs_pars[5]}" "${prs_pars[6]}" "${prs_pars[7]}")"
                    ;;
                'get_trans_rh_os_release')
                    parse_pars "$var"
                    echo -n "$($ins "${prs_pars[1]}" "$OS_version")"    # Falback to our OS version (prevents stop)
                    ;;
                'cmd')
                    parse_pars "$var"
                    echo -n "Output of [${prs_pars[1]}] : "
                    local pidx=2
                    while [ "${prs_pars[$pidx]}" != '' ]; do echo -n "${prs_pars[$pidx]}"; ((pidx++)); done
                    ;;
                'mktemp') echo -n '/tmp/tmp.<XXXXXXXXXX>' ; ;;
                'date')   echo -n '<date>'                ; ;;
                *)        echo -n "\`$var\`"              ; ;;
            esac
        fi
    elif [ "$var" == '$' ]; then    # $$
        echo -n "<cur pid>"
    elif [ "$var" == '?' ]; then    # $?
        echo -n "<last result>"
    elif [ "$var" == '*' ]; then    # $*
        local par; local sep=''
        for par in $(map_keys "$map_var"); do
            case "$par" in
                [1-9]) 
                    if [ $par -gt $cur_shift ]; then
                        echo -n "$sep$(map_get "$map_var/$par" "$var_cur")"
                        sep=' '
                    fi
                    ;;
            esac
        done
    else
        trans_var=1
    fi
    
    if [ $trans_var != 0 ]; then
        if [ "${!var}" != '' ]; then
            case "$var" in      # Yes some of the vars should have been capitalized (don't fix now)
                'STAT_'*)     echo -n "${STAT_stats[${!var}]}" ; ;; # Use STAT translate name iso actual value
                'dd_'*)       echo -n "${!var}"                ; ;; # Our internal data dictionary
                'hw_'*)       echo -n "${!var}"                ; ;; # Our internal hardware data
                'sect_'*)     echo -n "${!var}"                ; ;; # Our internal section data
                'tmp_'*)      echo -n "${!var}"                ; ;; # Our internal temp directoroes
                'map_'*)      echo -n "${!var}"                ; ;; # Our internal known maps
                'comp_'*)     echo -n "${!var}"                ; ;; # Our internal comp var from find_component
                'install_'*)  echo -n "${!var}"                ; ;; # Our internal install var from find_install
                'upg_act_'*)  echo -n "${!var}"                ; ;; # Our internal upgrade actions
                'upg_ref_'*)  echo -n "${!var}"                ; ;; # Our internal upgrade references
                'upg_typ_'*)  echo -n "${!var}"                ; ;; # Our internal upgrade types
                'exe_state_'*)echo -n "${!var}"                ; ;; # Our internal upgrade states
                'mnt_iso')    echo -n "${!var}"                ; ;; # Our internal mnt_iso var
                'nl')         echo -n "$SHLP_nc"               ; ;; # End newlne ar dificult.
                'tb')         echo -n "${!var}"                ; ;;

                'STR_sel'*)   echo -n "${!var}"                ; ;; # Predef stored selection
                'BCK_type_'*) echo -n "${!var}"                ; ;; # Predef BCK_types
                'GEN_'*)      sect='generic'                   ; ;; # a var from the generic section      
                'STR_'*)      sect='automate'                  ; ;; # a var from the automate section   
                'BCK_'*)      sect='backup'                    ; ;; # a var from the backup section
                [a-z]*'dir')  echo -n "${!var}"                ; ;; # Dirs from init_lib
                [a-z]*'fld')  echo -n "${!var}"                ; ;; # Flds from init_lib
                *)
                    if [ "$(echo -n "$var" | grep '^[A-Z_]')" != '' ]; then
                        echo -n "${!var}"       # Translate all start with capital or _ 
                    else
                        check_var=1
                    fi
                    ;;
            esac
            if [ "$sect" != '' ]; then
                [ "$no_sect" == '' ] && echo -n "<[$sect]${var:4}='${!var}'>" || echo -n "${!var}"
            fi
        else
            case "$var" in      # Try translate some we know!
                'MM_usr') [ "$dd_istanciated" != '0' ] echo -n '<textpass|tpuser0[1-9]>' || echo 'textpass'; ;;
                'C_'*)    echo -n "${var:2}" ; ;; # For testing assume standard generation
                'IP_'*)   echo -n "${var:3}" ; ;; # For testing assume standard generation
                'BACKUP_base_file') echo -n "$BCK_dir/$dd_host/..."; ;; # as close as I can get if unknown
                *)        check_var=1     ; ;; 
            esac
        fi
    fi

    if [ $check_var != 0 ]; then
        # What to do could be conflicting other locals. Check with var table
        map_exists "$map_var/$var"
        if [ $? != 0 ]; then
            [ "$def" == '' ] && def="$(map_get "$map_var/$var" "$var_def")"
            local val="$(map_get "$map_var/$var" "$var_cur")"
            if [ "$val" != '' ]; then
                echo -n "$val"
            elif [ "$def" != '' ];then
                echo -n "$def"
            else
                echo -n "\$$var"
            fi
        elif [ "$def" != '' ]; then
            echo -n "$def"
        else
            echo -n "\$$var"
        fi
    fi
}


function parse_string() {
    local line="$1"     # (M) The line with the var including ' or "
    local no_sect="$2"  # (O) If set no section translation is needed
    local is_cond="$3"  # (O) If set this is a condition parse $? is left alone

    dbg_msg "parse_string : [$line][$no_sect][$is_cond]"

    local len="${#line}"
    local idx=0

    local fc="${line:0:1}"
    local out=''
    case $fc in
        "'") echo "$line"; return  ; ;;    # do not process, return as is
        '"') out+="$fc"; ((idx++)) ; ;;    # A process-able string
        '-') out+=' '              ; ;;    # Not nicest but cannot echo '-e', so add space to trick nested echo's
        *)                         : ;;    # Anything else also process-able
    esac

    local var=''
    local nc
    local tc
    local acc; local fnd; local oth; local paran
    while [ $idx -lt $len ]; do
        nc="${line:$idx:1}"; ((idx++))
        case "$nc" in
            '$')                    # Should be a processed string. Problem some could be complex!
                if [ "${line:$idx:1}" == '{' ]; then # Might be a complex var, for now print as is
                    ((idx++))
                    var=''
                    acc=1; fnd=0; oth=0       # Need 1 } before finished
                    while [ $idx -lt $len -a $acc != 0 ]; do
                        tc="${line:$idx:1}"; ((idx++))
                        case "$tc" in
                            '{')             ((acc++))            ;;
                            '}')             ((acc--)); ((fnd++)) ;;
                            '['|'('|':'|'$') ((oth++))            ;;
                        esac
                        [ $acc -gt 0 ] && var+="$tc"
                    done
                    [ $fnd -gt 1 -o $oth -gt 0 ] && var="{$var}"   # Keep it complex
                elif [ "${line:$idx:1}" == '(' ]; then  # might be a complex sub command
                    ((idx++))
                    var='('
                    paran=1
                    while [ $idx -lt $len -a $paran != 0 ]; do
                        tc="${line:$idx:1}"; ((idx++))
                        case "$tc" in       # Check incomplete ) with string make it not work, for now enough
                            '(')             ((paran++))            ;;
                            ')')             ((paran--)); ((fnd++)) ;;
                        esac
                        var+="$tc"
                    done
                elif [ "${line:$idx:1}" == '*' ]; then 
                    var='*'; ((idx++))
                elif [ "${line:$idx:1}" == '?' ] && [ "$is_cond" == '' ] ; then 
                    var='?'; ((idx++))
                else 
                    # Head -1 removes multi line which are handled when line passed.
                    var="$(echo -n "${line:$idx}" | head -1 | $CMD_ogrep "^$SHLP_regex_bashvar")"
                    local l=${#var}
                    idx=$((idx + l))
                fi
                if [ "$var" != '' ]; then  
#                    out+="$(escape "$(trans_vars "$var" $no_sect)")"   # escape now handled by read -r
                    out+="$(trans_vars "$var" $no_sect)"
                else
                    out+="\$${line:$idx:1}"; ((idx++))  # Should have found something, just ad next char
                fi
                ;;
            *)  out+="$nc"; ;;
        esac
    done
    
    echo "$out"
}

: <<=cut
=func_int
Will analyse an existing fucntion. Will store variables
in show_* vars. Yes this si kind of dirty but it works and make
the code somewhat separated.
This funciton uses af_ prefix for local to prevent potential clashes.
=cut
function analyze_func() {
    local af_func_name="$1"    # (M) The funciton to analyze_func
    
    if [ "$(echo -n "$af_func_name" | $CMD_ogrep "^$SHLP_regex_bashvar")" != "$af_func_name" ] ; then
        echo -e "$(p_fail)${COL_todo}Parse error, not a function: [$af_func_name]$COL_def"
        return
    fi

    # Try to find the function and the SHLP_func_marker
    local af_func="$(declare -f  "$af_func_name")"
    if [ "$af_func" == '' ]; then
        echo "$(p_task)Call to non resident/unknown function."
        show_idx=0  # For now print all as is
        return      # Only to cut down in indenting level!
    fi
    
    # Pre get the help instrucions
    local af_help="$(echo -n "$af_func" |  grep "$SHLP_func_marker" | sed "s/^.*$SHLP_func_marker//")"
    if [ "$af_help" == '' ]; then
        echo "$(p_task)Call to non further described function (hlp)."
        show_idx=0      # Show as is
        return      # Only to cut down in indenting level!
    fi
    dbg_msg "help tags:$nl$af_help"

    # Alwasy translate vars as it is yet unknown if needed.
    local -a af_real_vars=()
    local af_vars="$(echo -n "$af_func" |  $CMD_ogrep "^[ ]*local[ ]+$SHLP_regex_bashvar=(\"|)\\\$[1-9](\"|)")"
    local var
    IFS=$nl; for var in $af_vars; do IFS=$def_IFS
        local i="$(echo -n "$var" | $CMD_ogrep '\$[1-9]' | $CMD_ogrep '[1-9]')"
        if [ "$i" != '' ]; then
            af_real_vars[$i]="$(echo -n "$var" | $CMD_sed 's/local//' | tr -d ' ' | cut -d '=' -f 1)"
            [ "${show_vars[$i]}" == '' ] && show_vars[$i]="${af_real_vars[$i]}"
        fi
    IFS=$nl; done; IFS=$def_IFS
    dbg_msg "func vars:$nl$af_vars"
    
    # See if we need to set soem default pars only simple support <var>
    # Complex would need overrule code soemthing ling [ "${show_pars[#]" == '' ] && show_pars[#]='default'
    # I want to prevent that as it is double can and thus double maintaining/fault sensitive.
    local af_defaults="$(echo -n "$af_func" | $CMD_ogrep "^[ ]*$SHLP_regex_bashvar=(\"|)\\\${$SHLP_regex_bashvar:-.*}(\"|)")"
    dbg_msg "func defa:$nl$af_defaults"
    
    # Make and execute the evalution_function. Done in separeta fucntion to 
    # parse local varm shield of local clashes and to be able to use standad evaluation
    # rules whcih allows complex defintion.
    local i
    local af_add=''
    for i in "${!af_real_vars[@]}"; do
        local var="${af_real_vars[$i]}"
        af_add+="[ \"\$$var\" != '' ] && show_pars[$i]=\"\$$var\"$nl"
    done
    local af_eval="shlp_eval_function() {
    $af_vars
    $af_defaults
    $af_add
    $af_help
}
"
    dbg_msg "eval: $af_eval"
    dbg_msg "pars: 1[${show_pars[1]}], 2[${show_pars[2]}], 3[${show_pars[3]}], 4[${show_pars[4]}], 5[${show_pars[5]}], 6[${show_pars[6]}], 7[${show_pars[7]}], 8[${show_pars[8]}], 9[${show_pars[9]}]"
    eval "$af_eval" 
    shlp_eval_function "$(unconfig "${show_pars[1]}")" "$(unconfig "${show_pars[2]}")" "$(unconfig "${show_pars[3]}")" "$(unconfig  "${show_pars[4]}" "${show_pars[5]}")" "$(unconfig  "${show_pars[6]}")" "$(unconfig  "${show_pars[7]}")" "$(unconfig  "${show_pars[8]}")" "$(unconfig  "${show_pars[9]}")"
        
    # Now look at potnetially set values
    if [ "$show_ignore" != 0 ]; then
        show_idx=-1     # overule if set otherwise by accident
    elif [ "$show_conditional" != 0 ]; then
        local par="$(unquote "${show_pars[$show_conditional]}")"
        local var="${af_real_vars[$show_conditional]}"
        if [ "$par" == '' ]; then
            show_idx=0
            if [ "$var" == '' ]; then
                echo "$(p_task)Call to non further described function (var)."
            else
                echo "$(p_task)Call to non further described function (par)."
            fi
        else
            local short="${show_cond["$par"]}"
            if [ "$short" == '' ]; then
                show_idx=0
                echo "$(p_task)Call to non further described function ($var=$par)."
            else
                echo "$(p_task)$short"
                [ $show_trans -lt 0 ] && show_trans=1   # Enable if not set.
            fi
        fi
    elif [ "$show_short" ]; then
        echo -e "$(p_task)$show_short"
        [ $show_trans -lt 0 ] && show_trans=1   # Enable if not set.
    elif [ "${#show_desc[@]}" != 0 ]; then
        echo "$(p_task)Call function ${show_pars[0]}, doing:"
        local desc
        for desc in "${show_desc[@]}"; do
            echo -e "$(p_none +)$desc"
        done
        [ $show_trans -lt 0 ] && show_trans=1   # Enable if not set.
    fi
    
}

: <<=cut
=func_int
Parses the condition and will give a translation if possibel.
This the central point to add more logic for confitions
=need show_pars
Will be used to acces this potential other parts of the condition
=set fnd_condition
Will be overuled with potential given codition e.g. via ret_vals
=cut
function parse_condition() {
    local idx="$1"    # (M) The start idx of the conditions
    local sep="$2"    # (O) Optional seprateor between conditions (e.g in case of for
 
    if [ "$fnd_hlp_comment" ]; then     # An help comment overrules any logic, don't sue #= if you don't want that
        fnd_condition="[ $fnd_hlp_comment ]"
        fnd_hlp_comment=''                      # Use only once
        return
    fi
    fnd_condition=''
    
    local actual_cond='';
    local transl_cond='';
    local compl_cond=''
    local complex=''
    local text_cond=0
    local num_transl=0
    local add_sep=''
    local negate=0
    local fld; local tst; local par
    # Currently we only support 1 condition, there is some preparation for multo condtions
    while [ "${org_pars[$idx]}" != '' ]; do
        actual_cond="$(parse_string "${org_pars[$idx]}" no_sect is_cond)"
        transl_cond=''
        compl_cond=''
        case "${org_pars[$idx]}" in     # First try realy fixed names (could be improved?) write as is
            '[ $dd_instanciated == 0 ]'  ) transl_cond='no instances configured'   ; ;;
            '[ $dd_instanciated != 0 ]'  ) transl_cond='instances are configured'  ; ;;
            '[ $YUM_supported == 0 ]'    ) transl_cond='yum usage is not supported'; ;;
            '[ $YUM_supported != 0 ]'    ) transl_cond='yum usage is supported'    ; ;;
            '[ "$'*'" == '"'0' ]"        ) transl_cond="${ret_vals[0]}"            ; ;;
            '[ "$'*'" != '"'0' ]"        ) transl_cond="${ret_vals[1]}"            ; ;;
            *) case "$actual_cond" in
            '[ $? == 0 ]'  | '[ $? -eq 0 ]') transl_cond="${ret_vals[0]}"    ; ;;
            '[ $? == 1 ]'  | '[ $? != 0 ]' ) transl_cond="${ret_vals[1]}"    ; ;;
            '[ $? -gt 0 ]' | '[ $? -ge 1 ]') transl_cond="${ret_vals[1]}"    ; ;;
            '[ "0" == '"'0' ]"             ) transl_cond="${ret_vals[0]}"    ; ;;   # Needs to be made more generic!
            '&&'|'||')                       complex+=" $actual_cond "       ; ;;
            '[ '*' ]')                # A test, not all handled, this an attempt
                fld=2
                tst="$(get_field $fld "$actual_cond")"
                while [ "$tst" != ']' ]; do
                    par="$(unquote "$(get_field $((fld+1)) "$actual_cond")")"
                    case "$tst" in      # Not all done, see e.g. http://tldp.org/LDP/Bash-Beginners-Guide/html/sect_07_01.html
                        '!') negate=1; ;;       # Assume we use one
                        '-o') compl_cond+=" or "; ;;
                        '-a') compl_cond+=" and "; ;;
                        '-b') 
                              [ $negate == 0 ] && compl_cond+="[ File '$par' exists and is a block-special file ]" || \
                                                  compl_cond+="[ File '$par' does not exists or not block-special file ]"
                              ((fld++))
                              ;;
                        '-c') 
                              [ $negate == 0 ] && compl_cond+="[ File '$par' exists and is a character-special file ]" || \
                                                  compl_cond+="[ File '$par' does not exists or not character-special file ]"
                              ((fld++))
                              ;;
                        '-d') [ $negate == 0 ] && compl_cond+="[ Directory '$par' exists ]" || \
                                                  compl_cond+="[ Directory '$par' does not exists ]"
                              ((fld++))
                              ;;
                        '-e') [ $negate == 0 ] && compl_cond+="[ File '$par' exists ]" || \
                                                  compl_cond+="[ File '$par' does not exists ]"
                              ((fld++))
                              ;;
                        '-f') 
                              [ $negate == 0 ] && compl_cond+="[ File '$par' exists and is regular file ]" || \
                                                  compl_cond+="[ File '$par' does not exists or not regular file ]"
                              ((fld++))
                              ;;
                        '-g') 
                              [ $negate == 0 ] && compl_cond+="[ File '$par' exists and its SGID bit is set ]" || \
                                                  compl_cond+="[ File '$par' does not exists or SGID bit is not set ]"
                              ((fld++))
                              ;;
                        '-h'|'-L') 
                              [ $negate == 0 ] && compl_cond+="[ File '$par' exists and is symbolic link ]" || \
                                                  compl_cond+="[ File '$par' does not exists or not symbolic link ]"
                              ((fld++))
                              ;;
                        '-k') 
                              [ $negate == 0 ] && compl_cond+="[ File '$par' exists and its sticky bit is set ]" || \
                                                  compl_cond+="[ File '$par' does not exists or sticky bit not set ]"
                              ((fld++))
                              ;;
                        '-p') 
                              [ $negate == 0 ] && compl_cond+="[ File '$par' exists and is a named pipe (FIFO) ]" || \
                                                  compl_cond+="[ File '$par' does not exists or not a named pipe (FIFO) ]"
                              ((fld++))
                              ;;
                        '-r') [ $negate == 0 ] && compl_cond+="[ File '$par' exists and is readable ]" || \
                                                  compl_cond+="[ File '$par' does not exists or not readable ]"
                              ((fld++))
                              ;;
                        '-s') [ $negate == 0 ] && compl_cond+="[ File '$par' exists and has a size greater than zero ]" || \
                                                  compl_cond+="[ File '$par' does not exists or a size of zero ]"
                              ((fld++))
                              ;;
                        '-u') 
                              [ $negate == 0 ] && compl_cond+="[ File '$par' exists and its SUID bit is set ]" || \
                                                  compl_cond+="[ File '$par' does not exists or SUID bit is not set ]"
                              ((fld++))
                              ;;
                        '-w') [ $negate == 0 ] && compl_cond+="[ File '$par' exists and is writeable ]" || \
                                                  compl_cond+="[ File '$par' does not exists or not writeable ]"
                              ((fld++))
                              ;;
                        '-x') [ $negate == 0 ] && compl_cond+="[ File '$par' exists and is executable ]" || \
                                                  compl_cond+="[ File '$par' does not exists or not executable ]"
                              ((fld++))
                              ;;
                        *) compl_cond="$actual_cond"; break ;;    # Not handled yet add in full as is
                    esac
                    ((fld++))
                    tst="$(get_field $fld "$actual_cond")"
                done
                ;;
            *) compl_cond="$actual_cond"       ; ;;  # for now add as is
            esac; ;;
        esac
        
        ((idx++))

        complex+="$add_sep"; add_sep="$sep"
        [ "$transl_cond" != '' ] && complex+="[ $transl_cond ]"
        [ "$compl_cond"  != '' ] && complex+="$compl_cond"
        [ "$transl_cond" != '' ] && ((num_transl++))
    done
    
    [ $num_transl -gt 1 ] && complex="$(echo -n "$complex" | $CMD_sed -e 's/\&\&/and/g' -e 's/||/or/g')"

    ret_vals=()     # not needed/invalid.

    fnd_condition="$complex"
}

: <<=cut
=func_int
Siple helper to stor a pasr uses fnd_ vars.
This to make code more readable.
=cut
function store_par() {
    local set_par="$1"  # (O) If set then appended to fnd_par 
    
    [ "$set_par" != '' ] && fnd_par="$fnd_par$set_par"  # Append after fnd_par
    if [ "$fnd_par" != '' ]; then
        if [ "$fnd_par" == '$*' ]; then     # Unquoted $*, expand into multiple
            local par
            for par in $(parse_string "$fnd_par"); do
                fnd_pars[$fnd_idx]="$par"
                dbg_msg "mpar added:[$fnd_idx][${fnd_pars[$fnd_idx]}]"
                ((fnd_idx++))
            done
        else
            fnd_pars[$fnd_idx]="$fnd_par"
            dbg_msg "par added:[$fnd_idx][${fnd_pars[$fnd_idx]}]"
            ((fnd_idx++))
        fi
        fnd_par=''
    fi
}

function get_cur_line() {
    local as_is="$1"    # (O) If set then the line is returned as is, otherwise cleaned(remove head/trail spaces

    if [ $cur_idx -lt $max_idx ]; then
        if [ "$as_is" != ''  ]; then
            echo -n "${cur_lines[$cur_idx]}"
        else
            echo -n "${cur_lines[$cur_idx]}" | sed -e "$SED_del_preced_sptb" -e "$SED_del_trail_sptb"
        fi
    fi
}
    
function parse_next_line() {
    local dont_prefix_nl="$1"   # (O) If set then no initla new is prefixed.
    local as_is="$2"            # (O) If set then the line is returned as is, otherwise cleaned(remove head/trail spaces
    
    [ "$dont_prefix_nl" == '' ] && fnd_par+="$nl"
    # The cur_idx was already increase, so start here.
    while [ $cur_idx -lt $max_idx ]; do
        prs_line="$(get_cur_line $as_is)"
        ((cur_idx++))
        if [ "$prs_line" != '' ]; then
            prs_len=${#prs_line}
            line_idx=0
            break   # found a new line
        fi
        fnd_par+="$nl"
    done
    dbg_msg "parse_next_line : todo='${prs_line:$line_idx}'"
}

function parse_expr_squote() {
    [ $line_idx -ge $prs_len ] && parse_next_line
    dbg_msg "expr ' : todo=${prs_line:$line_idx}#" ; ((SHLP_dbgind++))
    while [ $line_idx -lt $prs_len ]; do
        local nc="${prs_line:$line_idx:1}"   # First/find char
        ((line_idx++))
        fnd_par+="$nc"
        case "$nc" in
            "'") ((SHLP_dbgind--)); dbg_msg "expr ' : ret 1"; return 1; ;;
            *)   : ;;
        esac
        [ $line_idx -ge $prs_len ] && parse_next_line
    done
    fnd_par+="[' incomplete]"
    ((SHLP_dbgind--)); dbg_msg "expr ' : incomplete!"
    return 1    # Process incomplete for now
}

function parse_expr_dquote() {
    [ $line_idx -ge $prs_len ] && parse_next_line
    dbg_msg "expr \" : todo=${prs_line:$line_idx}#"; ((SHLP_dbgind++))
    while [ $line_idx -lt $prs_len ]; do
        local nc="${prs_line:$line_idx:1}"   # First/find char
        ((line_idx++))
        fnd_par+="$nc"
        case "$nc" in
            '"') ((SHLP_dbgind--)); dbg_msg 'expr " : ret 1'; return 1; ;;
            '$') parse_expr_dolar                                          ; ;;
            '\') fnd_par+="${prs_line:$line_idx:1}"; ((line_idx++))        ; ;; # escape char
            *)   : ;;
        esac
        [ $line_idx -ge $prs_len ] && parse_next_line
    done
    fnd_par+='[" incomplete]'
    ((SHLP_dbgind--)); dbg_msg 'expr " : incomplete!'
    return 1    # Process incomplete for now
}

function parse_expr_btick() {
    [ $line_idx -ge $prs_len ] && parse_next_line
    dbg_msg "expr \` : todo=${prs_line:$line_idx}#"; ((SHLP_dbgind++))
    while [ $line_idx -lt $prs_len ]; do
        local nc="${prs_line:$line_idx:1}"   # First/find char
        ((line_idx++))
        fnd_par+="$nc"
        case "$nc" in
            '`') ((SHLP_dbgind--)); dbg_msg 'expr ` : ret 1'; return 1; ;;
            '"') parse_expr_dquote                                       ; ;;
            '$') parse_expr_dolar                                        ; ;;
            *)   : ;;
        esac
        [ $line_idx -ge $prs_len ] && parse_next_line
    done
    fnd_par+='[` incomplete]'
    ((SHLP_dbgind--)); dbg_msg 'expr ` : incomplete!'
    return 1    # Process incomplete for now
}

function parse_expr_brack() {
    [ $line_idx -ge $prs_len ] && parse_next_line
    dbg_msg "expr [ : todo=${prs_line:$line_idx}#"; ((SHLP_dbgind++))
    while [ $line_idx -lt $prs_len ]; do
        local nc="${prs_line:$line_idx:1}"   # First/find char
        ((line_idx++))
        fnd_par+="$nc"
        case "$nc" in
            ']') ((SHLP_dbgind--)); dbg_msg 'expr ] : ret 1'; return 1; ;;
            '[') parse_expr_brack                                         ; ;;
            '$') parse_expr_dolar                                         ; ;;
            *)   : ;;
        esac
        [ $line_idx -ge $prs_len ] && parse_next_line
    done
    fnd_par+='[[ incomplete]'
    ((SHLP_dbgind--)); dbg_msg 'expr ] : incomplete!'
    return 1    # Process incomplete for now
}

function parse_expr_paran() {
    [ $line_idx -ge $prs_len ] && parse_next_line
    dbg_msg "expr ( : todo=${prs_line:$line_idx}#"; ((SHLP_dbgind++))
    while [ $line_idx -lt $prs_len ]; do
        local nc="${prs_line:$line_idx:1}"   # First/find char
        ((line_idx++))
        fnd_par+="$nc"
        case "$nc" in
            ')') ((SHLP_dbgind--)); dbg_msg 'expr ) : ret 1'; return 1; ;;
            '(') parse_expr_paran                                     ; ;;
            "'") parse_expr_squote                                    ; ;;
            '"') parse_expr_dquote                                    ; ;;
            '$') parse_expr_dolar                                     ; ;;
            *)   : ;;
        esac
        [ $line_idx -ge $prs_len ] && parse_next_line
    done
    fnd_par+='[( incomplete]'
    ((SHLP_dbgind--)); dbg_msg 'expr ) : incomplete!'
    return 1    # Process incomplete for now
}
            
function parse_expr_accol() {
    [ $line_idx -ge $prs_len ] && parse_next_line
    dbg_msg "expr { : todo=${prs_line:$line_idx}#"; ((SHLP_dbgind++))
    while [ $line_idx -lt $prs_len ]; do
        local nc="${prs_line:$line_idx:1}"   # First/find char
        ((line_idx++))
        fnd_par+="$nc"
        case "$nc" in
            '}') ((SHLP_dbgind--)); dbg_msg 'expr } : ret 1"'; return 1; ;;
            '{') parse_expr_accol                                         ; ;;
            "'") parse_expr_squote                                        ; ;;
            '"') parse_expr_dquote                                        ; ;;
            '$') parse_expr_dolar                                         ; ;;
            *)   : ;;
        esac
        [ $line_idx -ge $prs_len ] && parse_next_line
    done
    fnd_par+='[{ incomplete]'
    ((SHLP_dbgind--)); dbg_msg "expr } : incomplete!"
    return 1    # Proces incomplete for now
}

function parse_expr_dolar() {
    [ $line_idx -ge $prs_len ] && parse_next_line
    dbg_msg "expr \$ : todo=${prs_line:$line_idx}#"; ((SHLP_dbgind++))

    local ret=1
    local fc="${prs_line:$line_idx:1}"   # First/find char
    ((line_idx++))
    fnd_par+="$fc"
    case "$fc" in
        '{') parse_expr_accol;  ret=$?; ;;
        '(') parse_expr_paran;  ret=$?; ;;
        "'") parse_expr_squote; ret=$?; ;;
        '"') parse_expr_dquote; ret=$?; ;;
        '$') ((SHLP_dbgind--)); dbg_msg 'expr $ : ret: 1 $$'; 
             return 1
             ;; # Special case $$ is pid
        *)
            while [ $line_idx -lt $prs_len ]; do
                local nc="${prs_line:$line_idx:1}"   # next char
                case "$nc" in
                    "'"|'"'|'}'|']'|')'|' '|'$'|';'|'`'|'\')
                        ((SHLP_dbgind--)); dbg_msg "expr \$ : ret $ret:'$nc'"
                        return $ret
                        ;;
                    *) 
                        fnd_par+="$nc"
                        ((line_idx++))
                        ;;
                esac
            done
            ;;
    esac
    ((SHLP_dbgind--)); dbg_msg "expr \$ : ret $ret (done/eol)"
    return $ret     #reached end of line no continuation (for now)
}

: <<=cut
=func_int
Retrieve the first found expression:
- starts with ' " ( [ {
- ends with ' " ) ] }
- Nothing returned if 1st characters is not within set
- Parses anything between start/end including multiple depth
- For none end diffs (like ' ") a double '' or "" is allowed but does not end it
This function is part of the parses and use some vars to effectively pass data.
If start_idx is given then the store_par will also be called!
=need prs_line
=need prs_len
=need line_idx  
The current index in the prs_line
=set fnd_par
Add the foudn charaters.
=set line_idx
The line_idx is adapted if start_idx is given.
=return
0 if no expression found, otherwise 1
=cut
function parse_expr() {
    local expind="$1"   #(O) the expexcterd debug level for allowing multi expressions

    local fc="${prs_line:$line_idx:1}"   # First/find char

    expind=${expind:-0}
    if [ $SHLP_dbgind != $expind ]; then
        echo -e "${COL_todo}Unexpected ind lvl($expind != $SHLP_dbgind), please report, continuing$COL_def"
        SHLP_dbgind=$expind
    fi
    dbg_msg "expr : todo=${prs_line:$line_idx}# fc='$fc'"; ((SHLP_dbgind++))
    
    ((line_idx++))      # assume it is a expression (simplyfies code)
    
    case "$fc" in
        "'") fnd_par+="$fc"; parse_expr_squote; ;;
        '"') fnd_par+="$fc"; parse_expr_dquote; ;;
        '[') fnd_par+="$fc"; parse_expr_brack ; ;;
        '(') fnd_par+="$fc"; parse_expr_paran ; ;;
        '{') fnd_par+="$fc"; parse_expr_accol ; ;;
        '$') fnd_par+="$fc"; parse_expr_dolar ; ;;
        '`') fnd_par+="$fc"; parse_expr_btick ; ;;
        *) ((line_idx--));
            ((SHLP_dbgind--)); dbg_msg "expr : not expression"
            return 0; ;; # Oops not expression correct it
    esac
    local ret=$?
        
    local nc="${prs_line:$line_idx:1}"
    if [ $ret == 1 ] && [ "$nc" != '' ] && [ "$nc" != ' ' ] && [ "$nc" != '=' ]; then
        # expression is concatenated so continue parsing
        parse_expr $SHLP_dbgind
        ret=$?
    fi
    
    ((SHLP_dbgind--)); dbg_msg "expr : ret $ret"
    
    return $ret
}

function parse_pars() {
    local line="$1" # (M) the line to parse
 
    dbg_msg "parse_pars : [$line]"

    local idx=0
    local len=${#line}
    local par=''
    local pidx=0
    local in_spec=''
    
    prs_pars=()
    
    while [ $idx -lt $len ];do
        local ch="${line:$idx:1}"
        ((idx++))
        if [ "$in_spec" == '' ] && [ "$ch" == ' ' ]; then
            if [ "$par" != '' ]; then
                prs_pars[$((pidx++))]="$(unquote "$(parse_string "$par" no_sect)")"
                par=''
            fi
            continue
        elif [ "$in_spec" != '' ] && [ "$ch" == "$in_spec" ]; then
            in_spec=''
        elif [ "$in_spec" == '' ]; then
            if [ "$ch" == "'" ] || [ "$ch" == '"' ]; then
                in_spec="$ch"
            fi
        fi
        par+="$ch"
    done
    [ "$par" != '' ] && prs_pars[$pidx]="$(unquote "$(parse_string "$par" no_sect)")"
}

function print_bck_file() {
    local comp_name="$1"    # (O) The component name
    local base_name="$2"    # (M) The base name
    local head="$3"         # (M) The heading, make sure it is properly spaced to fit others.
    local type="$4"         # (O) The backup type, see BCK_type_*, emnpty for wildcard
    
    type="${type:-"[tar|tgz]"}"
    echo -n "$(p_none +)$head : "
    if [ "$BCK_dir" != '' ]; then
        echo "$(get_bck_dir "$comp_name" "$base_name.$type" '' 'no_create')"
    else
        echo -e "${COL_bold}[backup] section not configured propely, no full file name${COL_no_bold}"
        echo    "$(p_none +)comp : $comp_name"
        echo    "$(p_none +)part : $base_name.$type"
    fi
}

function show_execute_cmd() {
    local user="$1"     # (M) The user to execute it under
    local i_idx="$2"    # (O) The info index
    local c_idx="$3"    # (O) The command index (to pass stuff) -> show_idx

    local info=''

    [ "$i_idx" != '' ] && info="$(unquote "${show_pars[$i_idx]}")"
    if [ "$info" != '' ]; then  # Use the long version
#        echo "$(p_task)Execute command, info: $info"   # More generic
        echo "$(p_task)$info, with:"     # Trusting info
        echo -n "$(p_none +)[$user$SHLP_cur_node]"
    else
        echo -n "$(p_task)[$user$SHLP_cur_node]"
    fi
    [ "$user" == 'root' ] && echo -n "# " || echo -n "$ "

    show_no_sect='req-cmd'  # request no_sect
    show_idx=${c_idx:-$show_idx}
}

: <<=cut
=func_int
Will print the show _pars as indicated by either show_trans or show_idx.
Those item are reset to -1 to prevent a secondary print action.
=cut
function print_pars() {
    local no_sect="$1"  # (O) If set no section translation is needed (only for show_pars,show_no_sect can be used as well)
    
    no_sect=${no_sect:-"$show_no_sect"}

    local idx
    local add_nl=0

    if [ $show_trans -gt 0 ]; then
        local max=0
        for idx in "${!show_pars[@]}"; do   # fist find the max width
            local var="${show_vars[$idx]}"
            [ $idx == 0 -o $idx == $show_conditional -o "$var" == '' ] && continue  # Skip these
            [ ${#var} -gt $max ] && max=${#var}
        done
        for idx in "${!show_pars[@]}"; do  # Skip command task should have been printed as short/desc
            local par="${show_pars[$idx]}"
            [ $idx == 0 -o $idx == $show_conditional -o "$par" == '' ] && continue
            echo -n "$(p_none +)"
            local var="${show_vars[$idx]:-"<unknown>"}"
            printf "%-${max}s : $(unquote "$par")\n" "$var"
        done
    elif [ $show_idx -ge 0 ]; then
        [ $show_idx == 0 ] && echo -n "$(p_none)"
        idx=$show_idx; sep=''
        while [ $idx -lt $pars_idx ]; do
            if [ "$no_sect" == '' ]; then
                echo -n "$sep${show_pars[$idx]}"
            else
                echo -n "$sep$(parse_string "${org_pars[$idx]}" $no_sect)"
            fi
            [ $add_nl -gt 0 ] && echo -n "$nl" && ((add_nl--)) || sep=' ' 
            [ "${show_pars[$idx]}" == '<<' ] && add_nl=2 && sep='' && echo -n ' '  #inline doc + 2 *nl
            ((idx++))
        done
        [ $idx -ne 0 ] && echo ''
    fi
    show_trans=-1
    show_idx=-1
}

: <<=cut
=func_int
Prints the help comment if not skipped and still set.
=cut
function print_hlp_comment() {
    local tmp_diff="$1" # (O) use - or + to indicate one temporary diff to cur_ind_lvl

    if [ $fnd_skip_hlp_comment == 0 ]; then
        # Do we need to add some given help comment using #=[ =] direction.
        case "$fnd_hlp_comment" in
            "$nl") echo '' ; ;;
            '')    :       ; ;; # do nothing
            *)     echo "$(p_info $tmp_diff)$fnd_hlp_comment"; ;;   # Print indented as info
        esac
        fnd_hlp_comment=''  # Only print once per line.
    fi
}

: <<=cut
=func_int
Print the short help for a script. The intro and no_hlp text will
be written after current text. A newline will always be added.
=cut
function print_script_help() {
    local type="$1"      # (M) [func|step]
    local name="$2"      # (M) Name of the func or step. In case call expr_no
    local comp="$3"      # (O) The component if known
    local head="$4"      # (O) If set then (all) header is printed
    local dir="$5"       # (O) The directory
    local expr_ref="$6"  # (O) The expr no to use for parameter or emtpy fro $cur_expr_no
    local pr_ref="$7"    # (O) A print ref to match, defaults. Use to lower output in all/1file

    local intro=", see $type for info, short help:"
    local no_hlp=", nothing described, see $type '$dir'"
    local all_pr="$COL_dim, already described earlier$COL_no_dim"

    expr_ref=${expr_ref:-$cur_expr_no}
    pr_ref=${pr_ref:-0}
    
    local main_map="$(get_link_map "$type" "$name" "$comp")"
    local map="$main_map/$scr_files"
    local pmap="$(get_call_map "$expr_ref")/$scr_pars"
    [ "$type" == 'func' ] && otype='function' || otype="$type"
   
    local cur_ref="$(map_get "$main_map" "$scr_pr_ref")"
    if [ "$head" != '' ] ; then
        if [ "$comp" != '' ]; then
            echo -ne "$(p_task)Calling entity $otype [$COL_bold$comp:$name$COL_no_bold"
        else
            echo -ne  "$(p_task)Calling $otype [$COL_bold$name$COL_no_bold"
        fi
        # Add the parameter (if any)
        local par; local val
        for par in $(map_keys "$pmap" | sort); do
            if [ "${par:0:3}" == 'par' ]; then
                val="$(map_get "$pmap" "$par")"
                [ "$val" != '' ] && echo -n " $(unconfig "$val")" || echo -n " ''"    # Empty not really possible
            fi
        done
        echo -n ']'
        map_exists "$main_map"; [ $? == 0 ] && echo -e "$no_hlp" && return
        map_exists "$map"     ; [ $? == 0 ] && echo -e "$no_hlp" && return
        [ "$cur_ref" == "$pr_ref" ]         && echo -e "$all_pr" && return
    else
        [ "$cur_ref" == "$pr_ref" ] && return
    fi
        
    local hlp; local fnr
    for fnr in $(map_keys "$map"); do
        # First get the short_help text. Its preference is to use =short_help
        # however it can fallback to =script. Which is good enough for some
        # default scripts. Use -short_help if that need overuling 
        # (e.g too complex/incomplete).
        hlp="$(map_get "$map/$fnr/$scr_tags" 'short_help')"
        [ "$hlp" == '' ] && hlp="$(map_get "$map/$fnr/$scr_tags" 'script')"
        [ "$hlp" == '' ] && continue    # No help then don't show other pars.

        # Try to collect the set statement as those might be important
        local smap="$map/$fnr/$scr_tags/set"
        local snr; local set; local add=0
        for snr in $(map_keys "$smap"); do
            hlp+="$nl"
            set="$(map_get "$smap" "$snr")"   # The 1st line should be the var
            hlp+="$(echo -n "$set" | $CMD_sed -e '1 s/^\(.*\)$/- Uses $\1 to pass following info:/' -e '1 ! s/^/  /')"
            ((add++))
        done

        # Now see if we can translate any pars from this help, <'a var'>
        local var; local par; local val
        for var in $(echo -n "$hlp" | $CMD_ogrep '<[^>]*>' | sort | uniq); do
            par=${var:1}; par=${par%?}
            val="$(map_get "$pmap" "$par")"
            [ "$val" != '' ] && hlp="$(echo -n "$hlp" | sed "s/$var/$val/g")"
        done

        break   # Only process the first found with info at this moment.
    done
    map_put "$main_map" "$scr_pr_ref" "$pr_ref"    # Printed for this ref once.
    if [ "$hlp" != '' ]; then
        inc_indent
        echo -e "$intro$nl$(echo -ne "$hlp" | $CMD_sed "s/^/$(p_none +)/g")"
        dec_indent
    else
        echo -e "$no_hlp"
    fi
}

: <<=cut
=func_int
Show found commands. Used variables from parse_line
=cut
function show_commands() {
    
    # The following can be set in the library funciton using the 
    # SHLP_func_marker. e.g. [ -z help ] && show_short="Short to print"
    # BE VERY CRAFEULL CHANGING NAMES, THEY CAN BE USED IN THE FILES
    local show_idx=-1        # -1 means add no part other start at pars. May be overuled by function.
    local show_ignore=0      # Set to 1 if function is to be ignored in displaying
    local show_conditional=0 # Show a short based on a the given conditional parameter [1-9]
    local show_short=''      # A sort line wiht help todo, like: execute command
    local show_trans=-1      # Parse function vars to given pars (cannot parse comments, just names), -1 not define, 0 do not trans, 1 force to trans.
    unset show_cond; 
    declare -A show_cond     # used for conditional definitions.
    local -a show_vars=()    # Auto trans array pr optionally overrule by function.
    local -a show_desc=()    # A multi line longer description with complex explanation 
                             # (function are not parsed) Only useful if no short given.
    local tmp_user=''

    [ $cur_script_pars != 0 ] && cur_script_pars=0 && echo ""   # Add a newline once to separate pars

    [ "$fnd_comment" != '' ] && dev_msg "##$fnd_comment" && fnd_comment=''
    if [ $ctrl_start_skip != 0 ]; then
        # First need to find the first
        case "${show_pars[0]}" in
            'if'|'for'|'while'|'until'|'case') ctrl_start_skip=0; ctrl_in_skip=1; ;;
        esac
    fi
    if [ $ctrl_in_skip != 0 ] && [ $ctrl_start_skip == 0 ]; then
        case "${show_pars[0]}" in
            'if'|'for'|'while'|'until'|'case')                                 ((ctrl_skip_control++)); ;;
            'fi'|'done'|'esac')                [ $ctrl_skip_control -ge 1 ] && ((ctrl_skip_control--)); ;;
        esac
        if [ $ctrl_skip_control -gt 0 ]; then
            dev_msg "ctrl_skip: ${show_pars[*]}"
        else
            ctrl_in_skip=0
        fi
        return
    fi
    [ $ctrl_skip_line -ge 1 ] && return
    
    local pidx

    fnd_proc=1      # Assume it will be processesd as main command.
    case "${show_pars[0]}" in
        #
        # Command ralated calls
        #
        'set_cmd_user')
            local user="$(unquote "${show_pars[1]}")"
            local old="$SHLP_cur_user"
            [ "$user" != '' ] && SHLP_cur_user="$user"
            [ "$old" != "$SHLP_cur_user" ] && echo "$(p_task)Login is as '$user'"
            ;;
        'default_cmd_user') 
            [ "$SHLP_cur_user" != 'root' ] && echo "$(p_task)Logout '$SHLP_cur_user' and make sure 'root' is active user"
            SHLP_cur_user='root'
            ;;
        
        'cmd')       show_execute_cmd "$SHLP_cur_user" 1 2         ; ;;
        'cmd_tp')    show_execute_cmd "$(trans_vars MM_usr)" 1 2   ; ;;
        'cmd_input') 
            show_execute_cmd "$SHLP_cur_user" 1 3
            print_pars                  # Print them now, not later
            local inp="$(unquote "${show_pars[2]}")"
            if [ "$inp" != '' ]; then
                echo "$(p_info +)The following auto [input] is used:"
                echo -n "$inp" | tr "$SHLP_nc" "$nl" | $CMD_sed -e "s/^\(.*\)\$/$(p_none +)[\1]/" -e "s/\$/<ENTER>/"
            fi
            echo ''
            ;;
        'cmd_hybrid')       # The 2nd par is the whole command, just unquote it
            show_execute_cmd "$SHLP_cur_user" 1
            echo "${unqo_pars[2]}"
            ;;

        # $CMD_* are handled in default case, yes some could have been cmd * (prevent code change_            
        'chmod'|'echo'|'which'|'.'|'cat')          
            show_execute_cmd "$SHLP_cur_user" '' 1;
            echo -n "${show_pars[0]} "  # print our-self to prevent extra indent
            print_pars no_sect          # Print them now, not later, no sect translation
            ret_vals[0]="Last command executed successfully"
            ret_vals[1]="Last command failed"
            ;;

        #
        # special interst functions, hard to solve with geneirc [ -z help ]
        #
        'backup_init')      # Overule parameters, make less complex and add info
            echo    "$(p_task)Prepare a new backup request (files will be added)"
            echo    "$(p_none +)type : ${show_pars[1]}"
            print_bck_file "${unqo_pars[2]}" "${unqo_pars[3]}" "file" "${unqo_pars[1]}"
            show_idx=-1
            ;;
        'recover_files')
            echo    "$(p_task)Recover file(s) from a previous backup into a specific directory"
            if [ $cur_recovers == 0 ]; then
                echo "$(p_list +)Examples command for extracting files (shown once):"
                echo "$(p_list +)tar : tar -xvf  <bck file> -C <dest dir> \"<get files>\""
                echo "$(p_list +)tgz : tar -xvzf <bck file> -C <dest dir> \"<get files>\""
            fi
            print_bck_file "${unqo_pars[1]}" "${unqo_pars[2]}" "bck file "
                                           echo    "$(p_none +)get files : ${unqo_pars[3]}"
                                           echo -n "$(p_none +)dest dir  : "
            [ "${unqo_pars[4]}" != '' ] && echo                            "${unqo_pars[4]}" || \
                                           echo                            "<current dir>"
            [ "${unqo_pars[5]}" != '' ] && echo    "$(p_none +)chown to  : ${unqo_pars[5]}"
            [ "${unqo_pars[6]}" != '' ] && echo    "$(p_none +)optional  : [ non-found files ] or [ no archive ] is allowed"
            ret_vals[0]="Recovery was succesfull"
            ret_vals[1]="files or archive not found"
            ((cur_recovers++))
            show_idx=-1
            ;;

        # Step handling
        'execute_step')
            if [ "${show_pars[1]}" == '0' -a "${show_pars[2]}" != '' ]; then    # Show only direct steps.
                local info="$(unquote "${show_pars[2]}")"
                add_step_todo "$info" 'now'
                echo "$(p_task)Now execute sub-step '$info'"
            fi
            ;;
        'execute_queued_steps')
            local map="$map_steps_later"
            local num="$(map_cnt "$map")"
            if [ $num == 0 ]; then
                echo "$(p_task)Request to execute all queued sub-steps, none seems queued."
            else
                echo "$(p_task)Execute all queued sub-steps, estimated list (not accurate):"
                local ref
                for ref in $(map_keys "$map"); do
                    echo "$(p_list +)$(map_get "$map/$ref" $scr_step)"
                done
            fi
            ret_vals[0]="No queued steps found"
            ret_vals[1]="One or more queued steps found"
            ;;
            
        'queue_step')
            if [ "${show_pars[1]}" != '' ]; then 
                local info="$(unquote "${show_pars[1]}")"
                add_step_todo "$info" 'later'
                echo "$(p_task)Potential queued step: '$info'"
            fi
            ;;

        # Function script handling
        'func')
            local comp_or_func="$(unquote "${show_pars[1]}")"
            local func="$(unquote "${show_pars[2]}")"
            local comp=''
            local fdir
            find_install $comp_or_func 'optional'
            if [ "$install_ent" != '' ]; then      # The first name is a package 
                comp="$comp_or_func"
                add_func_todo "$func" "$comp" 3
                fdir="$install_aut/funcs"
            else
                func="$comp_or_func"
                add_func_todo "$func" '' 2
                fdir="$fncdir"
            fi
            print_script_help func "$func" "$comp" head "$fdir"
            if [ "$fnd_ins_comment" == 'execute' ]; then    # Use with great care
                func "${unqo_pars[1]}" "${unqo_pars[2]}" "${unqo_pars[3]}" "${unqo_pars[4]}"        # 4 should be enough for now
                fnd_ins_comment=''
            fi
            ;;

        'wait_until_passed')    # Need to redo things to show nice functio
            local fnc="$(unquote "${show_pars[3]}")"                 # (M) The function name to call)
            if [ "$fnc" != '' ]; then
                local slp="$(unconfig "${show_pars[1]}")"; slp=${slp:-30} # (O) The time to wait, default is 30
                local max="$(unconfig "${show_pars[2]}")"; max=${max:0}   # (O) The maximum times to wait., 0 or empty = unlimited
                local sec="$([ $max == 0 ] && echo -n "forever" || echo -n "max $((slp * max)) sec")"
                echo "$(p_task)Wait $sec until:"
                inc_indent; analyze_func "$fnc"; dec_indent
                ret_vals[0]="All attempts failed (stopped trying)"
                ret_vals[1]="An attempt passed"
                show_idx=-1     # Overule if set by analyze
            else
                show_idx=0
            fi
            ;;

        'find_install')
            local ent="$(unquote "${show_pars[1]}")"
            echo -e "$(p_info)Finding installation information for $ent"  
            find_install "$ent" optional        # Do not exit when not found
            ret_vals[0]="install package '$ent' not found"
            ret_vals[1]="install package '$ent' found"
            ;;
        'find_component')
            local name="$(unquote "${show_pars[1]}")"
            echo -e "$(p_info)Finding component information for $name"  
            find_component "$name"              # The default is optin do not exit
            ret_vals[0]="component '$name' not found"
            ret_vals[1]="component '$name' found"
            ;;

        #
        # Some use a width layout to make it more clear and redable (this assumes a width terminal whtih we nowadys have!
        #
        
        #
        # logging related calls for getting shorter output
        #
        'log_info'|'log_screen')    echo -e "$(p_info)$(unquote "${show_pars[1]}" "$(p_none +)")"                                        ; ;;
        'log_screen_info')          echo -e "$(p_info)$(unquote "${show_pars[2]}" "$(p_none +)")"                                        ; ;;
        'log_exit')                 echo -e "$(p_info)Exit with : $(unquote "${show_pars[1]}" "$(p_none +)            ")"                ; ;;
        'log_warning')              echo -e "$(p_info)Warning : $(unquote "${show_pars[1]}" "$(p_none +)          ")"                    ; ;;
        'log_wait')                 echo -e "$(p_info)$(unquote "${show_pars[1]}" "$(p_none +)")"
                                    local wait="${show_pars[2]}"; wait="${wait:-10}"    # default is 10
                                    echo -e "$(p_task +)Waiting for $wait sec before continuing."
                                    ;;
        'log_manual')               if [ "${unqo_pars[1]}" != '' ]; then
                                        echo -e "$(p_task  )Manual task logged for later execution, info:"
                                        echo -e "$(p_none +)$COL_bold$(unquote "${show_pars[1]}")$COL_no_bold"
                                        reset_numb
                                    fi
                                    
                                    echo -e "$(p_numb +)$(unquote "${show_pars[2]}" "$(p_none ++)")"
                                    ;;
        'log_debug')                dev_msg "$(p_info)$(unquote "${show_pars[1]}" "$(p_none +)")" ; ;;
        'manual_step')              echo -e "$(p_task  )Manual step : $(unquote "${show_pars[2]}")"
                                    echo -e "$(p_none +)$(unquote "${show_pars[1]}" "$(p_none +)")"
                                    ;;
        
        #
        # Structured logic 
        #
        'exit')                     echo "$(p_info)Exit with return code ${show_pars[1]}" ; ;;
        'return')                   echo "$(p_task)$cur_type done with result: $(unquote "${show_pars[1]}")"                    ; ;;
        'if')    parse_condition 1; echo "$(p_task)Whenever $fnd_condition"                                         ; inc_indent; ;;
        'elif')  parse_condition 1; echo "$(p_task -)Or whenever $fnd_condition"                                                ; ;;
        'then')  : ;;  # a single then can be ignore (normaly it is ); then
        'else')                     echo "$(p_task -)Otherwise"                                                                 ; ;;
        'fi')                                                                                                         dec_indent; ;;
        'do')    : ;;  # a single do can be ignore (normaly it is ]; do
        'done')                                                                                                       dec_indent; ;;
        'while') parse_condition 1; echo "$(p_task)As long as $fnd_condition"                                       ; inc_indent; ;;
        'until') parse_condition 1; echo "$(p_task)Until $fnd_condition"                                            ; inc_indent; ;;
        'case')  ((cur_case_depth++)); local cd=$cur_case_depth
                 local case_var="$(unquote "${org_pars[1]}")"
                 local case_val="$(unquote "${show_pars[1]}")"
                 [ "${case_val[$cd]}" == '' ] && case_val[$cd]='<??>'
                 if [ "$case_var" == "$case_val" ]; then
                     echo "$(p_task)Choice the option which matches <$case_var>"
                 else
                     echo "$(p_task)Choice the option which matches $case_var='$case_val'"
                 fi
                 inc_indent
                 ;;
        'esac')  [ $cur_case_depth -gt 0 ] && ((cur_case_depth--))
                 dec_indent
                 ;;
        ';;')    dec_indent; ;;
        'for')   parse_condition 3 ' '
                 local forset="$fnd_condition"
                 [ "${forset:0:1}" != '[' ] && forset="[$(echo -n "$forset" | $CMD_sed -e 's/ *$//' -e 's/ /, /g')]"
                 echo "$(p_task)For iterator ${show_pars[1]} in set $forset"
                 inc_indent
                 ;;
        'break') local up="${show_pars[1]}"; [ "$up" == ';' ] && up=''
                 echo -n "$(p_task)Stop with current control loop"
                 [ "$up" != '' -a "$up" != '1' ] && echo " ($up levels up)" || echo''
                 ;;
        'continue')
                 echo "$(p_task)Continue with next iteration, skip rest"
                 ;;
        #
        # sub functionality, please use function so far! (easier to recognize)
        #
        'function')
            local func="${show_pars[1]}"
            local dparan="${show_pars[2]}"
            local content="${org_pars[3]}"
            if [ "$func" != '' ] && [ "$dparan" == '()' ] && [ "$(declare -F "$func")" == '' ]; then
                # Function not defined, define it ourself, for future use
                eval "$func() $content"
            fi
            ;;
        
        #
        # Other bash specific functions
        #
        'source') : ;;  # Happily ignore from now

        #
        # Other items
        #
        ':') echo "$(p_task)Don't do anything (control filler)"; ;;
        '[ '*)                      # inline compound statement [ ] && expr, format to be improved
            parse_condition 0
            echo "$(p_task)$fnd_condition"
            ;;
        '')         return     ; ;; # Nothing extra todo
        ';'|'&')    return     ; ;; # Assumed new command, do nothing extra
        *)
            # Could be in a case statement if so look at any ')'
            local analyze=1
            if [ $cur_case_depth -gt 0 ]; then
                local idx=0
                local labels=''     # Build up while investigating
                while [ $idx -lt $pars_idx ]; do
                    if [ "${show_pars[$idx]}" == ')' ]; then
                        analyze=0
                        break
                    elif [ "${show_pars[$idx]}" == '|' ]; then
                        labels+=' or '
                    else
                        labels+="[${show_pars[$idx]}]"
                    fi
                    ((idx++))
                done
                if [ $analyze == 0 ]; then
                    if [ "$labels" == '[*]' ]; then
                        echo "$(p_task)If no option matched do"
                    else
                        echo "$(p_task)Whenever option matches $labels do"
                    fi
                    inc_indent
                    fnd_skip_hlp_comment=1
                fi
            elif [ "${org_pars[0]:0:5}" == '$CMD_' ] && [ "${org_pars[0]}" != "${show_pars[0]}" ]; then
                # This takes care of any $CMD_* as first parameter.
                show_execute_cmd "$SHLP_cur_user" '' 1;
                echo -n "${show_pars[0]} "  # print our-self to prevent extra indent
                print_pars no_sect          # Print them now, not later, no sect translation
                ret_vals[0]="Last command executed successfully"
                ret_vals[1]="Last command failed"
                analyze=0
            fi


            [ $analyze == 1 ] &&  analyze_func "${show_pars[0]}"
            ;;
    esac

    print_pars
    print_hlp_comment '+'
}



: <<=cut
=func_int
Pre-aalyzes the paramete =, by looking at the variables (if possible)
after that passing it on to the generic command processsing.
=cut
function proc_show_pars() {
    local name=''  # The nam of the variable
    local expr     # The full expression
    local oper     # The operator
    local type=''  # The type [bplg<emoty>]
    local init=''
    local par
    local sidx=-1
    local skip_cmd=0
    local extra=''
    local show_no_sect=''   # Could be used to addapt no_sect behavior


    ((cur_expr_no++))
    dbg_msg "proc_show_pars: $cur_line_no:$cur_expr_no [${show_pars[0]}][${show_pars[1]}][${show_pars[2]}]"

    case "${show_pars[0]}" in
        'local')   type='l'; sidx=1; ;;
        'declare') type='g'; sidx=1; ;;
        'unset')   type='u'; sidx=1; ;;
        'export')  type='e'; sidx=1; ;;
        'shift')
            local shift="${show_pars[1]}"
            [ "$shift" != '' ] && cur_shift=$((cur_shift + shift)) || ((cur_shift++))
            skip_cmd=1
            ;;
                 
            # We should only used simple ((<var>++)) and ((<var>--)), other may be added
        '(('*'))') 
            name="$(echo -n "${show_pars[0]}" | $CMD_ogrep "$SHLP_regex_bashvar")"
            case "${show_pars[0]}" in
                *'++))') extra='++'; ;;
                *'--))') extra='--'; ;;
            esac
            skip_cmd=1  # Always skip also the very complex ones
            ;;
        *)  case "${show_pars[1]}" in
                '='|'+=') type='?'; sidx=0; ;;
            esac
            ;;
    esac
    
    if [ $sidx -lt 0 ] && [ "$name" != '' ] && [ "$extra" != '' ]; then
        local map="$map_var/$name"
        map_exists "$map"
        if [ $? == 0 ]; then
            map_put "$map" "$var_name"  "$name"
            map_put "$map" "$var_type"  'g'
            map_put "$map" "$var_cur"   '0'
        fi
        local cur="$(map_get "$map" "$var_cur")"
        if [ "$(echo -n "$cur" | $CMD_ogrep '^[0-9]*')" == "$cur" ]; then   #is it a number
            case "$extra" in
                '++') ((cur++)); ;;
                '--') ((cur--)); ;;
            esac
            map_put "$map" "$var_cur"   "$cur"
        fi
        skip_cmd=1
    elif [ $sidx -ge 0 ]; then
        if [ "${show_pars[1]:0:1}" == '-' ]  || [ "${show_pars[1]:0:2}" == ' -' ]; then # Space might be added due to echo problem
            ((sidx++))
        fi
        name="${show_pars[$sidx]}"
        oper="${show_pars[$((sidx + 1))]}"
        expr="${org_pars[$((sidx + 2))]}"
        case "$oper" in
            '=') init="$fnd_hlp_comment"    # Allow to overrule with inline #= !
                 [ "$init" == '' ] && init="$(unquote "$(parse_string "$expr" no_sect)")" || fnd_hlp_comment=''
                 ;;
            *) : ;; # All other not supported for now
        esac
        if [ "$type"  == 'l' ]; then
            # Fix your code if not local var="[1-9]"  # () Do not  skip the '"'
            par="$(echo -n "$expr" | grep '^"$[1-9]"' | $CMD_ogrep "[1-9]")"
            if [ "$par" != '' ]; then
                type='p'
                map_exists "$map_var/$par"
                if [ $? != 0 ]; then
                            map_put "$map_var/$par" "$var_pidx" "$par"
                    init="$(map_get "$map_var/$par" "$var_cur")"
                else
                    init=''
                fi
            fi
        fi

        local map="$map_var/$name"
        local emap="$map_var_expr/$(printf "%05d" "$cur_expr_no")"

        [ "$type" == 'u' ] && map_init "$map"

        # check for variable existence
        map_exists "$map"
        if [ $? == 0 ] || [ "$type" == 'u' ]; then
            map_put "$map" "$var_name"  "$name"
            map_put "$map" "$var_type"  "$type"
            map_put "$map" "$var_init"  "$init"
            map_put "$map" "$var_cur"   "$init"    # not a mistake also $init

            # Only show 'p' the others are dev only (no need to bother with too much logic)
            local add; local hlp
            [ "$init" != '' ] && add="=\"$init\"" || add=' <empty|not set>'
            [ "$fnd_comment" != '' ] && hlp="$nl$(p_info +)$fnd_comment" || hlp=''
            case "$type" in
                'p')
                     local ptype='Script'   # Basically means not defined
                     local pcom=''
                     if [ "$fnd_comment" != '' ]; then
                        local t="$(echo -n "$fnd_comment" | $CMD_ogrep '^ *\([oOmM]\)'| $CMD_ogrep '[oOmM]')"
                        case "$t" in
                            'o'|'O') ptype='Optional'; ;;
                            'm'|'M') ptype='Mandatory'
                                     [ "$init" == '' ] && add="${COL_bold}$add${COL_no_bold}"   # Not set not really good
                                     ;;  
                        esac
                        hlp="$nl$(p_info +)$(echo -n "$fnd_comment" | $CMD_sed 's/^ *(\([oOmM]\)) *//')"
                     fi
                     echo -e "$(p_extra)$ptype Parameter : $name$add$hlp"
                     ((cur_script_pars++))
                     ;;
                'l') dev_msg "$(p_none +)local    $name$add$hlp"       ; ;;
                'g') dev_msg "$(p_none +)global   $name$add$hlp"       ; ;;
                'e') dev_msg "$(p_none +)export   $name$add$hlp"       ; ;;
                *)   dev_msg "$(p_none +)unsup($type) $name$add$hlp"   ; ;;
            esac
            skip_cmd=1
        elif [ "$oper" == '=' ]; then
            [ $ctrl_skip_line == 0 ] && map_put "$map" "$var_cur" "$init"    # Only update the current, if not in skip
            skip_cmd=1
        elif [ "$type" != '?' -a "$type" != '' ]; then  # Double define vars, skip cmd
            skip_cmd=1
        fi
        
        map_link "$emap" "$vare_var"  "$map_var" "$name"
        map_put  "$emap" "$vare_expr" "$expr"
        map_put  "$emap" "$vare_lno"  "$cur_line_no"

        skip_cmd=1
    fi
    
    if [ $ctrl_skip_code == 0 ]; then
        [ $skip_cmd == 0 ] && show_commands || print_hlp_comment
    fi
    fnd_ins_comment=''
}

: <<=cut
=func_int
Translates an inline documented string a single string.
These are string e.g. << EOF  <lines EOF
The current character is right after the >> There could be
space between de << and idndicator.
=ret
0 successful proes, 1 failure. fnd_par set to failure reason.
=cut
function parse_indoc_string() {
    # first we need to find the indirecotor but read out all spaces frist
    while [ $line_idx -lt $prs_len ]; do
        [ "${prs_line:$line_idx:1}" != ' ' ] && break
        ((line_idx++))
    done
    # The indicator is on some line until eol (space should no be allowed. 
    # Not aware other things are allowed at this moment.
    local ind="${prs_line:$line_idx}"
    store_par "$ind"
    [ "$ind" == '' ] && fnd_par="[ no << indicator found ]" && return 1  # no ind ignore, but warning
    parse_next_line no_nl as_is
    while [ $cur_idx -lt $max_idx ] && [ "$prs_line" != "$ind" ]; do     # Should be exact match!
        fnd_par+="$prs_line"
        parse_next_line '' as_is
    done
    [ "$prs_line" != "$ind" ] && fnd_par="[ Ending indicator '$ind' not found ]" && return 1
    store_par
    store_par "$ind"
    line_idx=$prs_len   # Read away the indicator
    return 0
}
        

: <<=cut
=func_int
Translates an existing line into separare parameters
=cut
function parse_line() {
    local prs_line="$1" # (M) The line to parse (minimum 1 char
    
    local prs_len="${#prs_line}"
    local    line_idx=0
    local    fnd_par
    local -a fnd_pars   # Found on this line
    local -a fnd_expr
    local    fnd_comment=''
    local    fnd_hlp_comment=''
    local    fnd_ins_comment=''
    local    fnd_skip_hlp_comment=0
    local    fnd_condition=''
    local    fnd_idx=0

    while [ $line_idx -lt $prs_len ]; do
 #       echo "D:$line_idx[${prs_line:$line_idx:1}][$fnd_par]"
        if [ "$fnd_par" == '' ]; then   # Only check expr if not busy something else
            parse_expr 
            [ $? != 0  ] && continue    # Found one, store and continue (could be expr expr)
        fi

        # We coem her if none expresiion in progress or none found.
        local ch="${prs_line:$line_idx:1}"
        local dbl="${prs_line:$line_idx:2}"
        local trp="${prs_line:$line_idx:3}"
        ((line_idx++))
 
        case "$trp" in
            '<<<')      # input redirection from string, currnelty not further procsesing (FFU)
                store_par
                store_par "$trp"
                ;;
            # Remark not indenting on purpose
            *) case "$dbl" in
            '()'|'&&'|'||'|';;') 
                store_par           # The optional function name
                store_par "$dbl"    # The function/and/or indication
                ((line_idx++))
                ;;
            '\"')
                fnd_par+="$dbl"
                ((line_idx++))
                ;;
            '<<')       # input redirection from inline file, todo
                store_par
                store_par "$dbl"
                ((line_idx++))
                parse_indoc_string  # Will store addiotnal parameters
                [ $? != 0 ] && echo -e "${COL_todo}Indoc string failed: $fnd_par"
                ;;
            '>>')    # output redirect append to file, todo
                store_par
                store_par "$ch"
                ;;
            # Remark not indenting on purpose, no '?' pr '*' needed.
            *) case "$ch" in
            "'"|'"'|'{'|'(')        # Do not throw exception this is already error handling, try to continue
                echo -e "${COL_todo}'$ch' should have been handled by parse_expr${COL_def_bg}";
                line_idx=$prs_len
                break
                ;; 
            '[')        # This looks like an <array>[idx]
                fnd_par+="$ch"
                parse_expr
                ;; 
            '#')
                store_par   # Store any pending par       
                fnd_comment="$(echo -n "${prs_line:$line_idx}" | $CMD_sed -e "$SED_del_preced_sptb")"; 
                line_idx=$prs_len;
                case "${fnd_comment:0:2}" in
                    '= ') fnd_hlp_comment="$(parse_string "${fnd_comment:2}")"; ;;
                    '=&') fnd_ins_comment="$(parse_string "${fnd_comment:2}")"; ;;
                    '=#') fnd_hlp_comment="$nl"                               ; ;;    # #=# is newline rest ignored
                    '=!') ((ctrl_skip_line++))                                ; ;;    # SKip this line
                esac
                ;;
            '$')
                store_par   # Store any pending par so far
                fnd_par+="$ch"
                parse_expr
                ;;
            ')'|':')    # Case item or filler within case (all fillers).
                store_par           # Store the left hand
                store_par "$ch"
                store_par ';'       # This will allow the next expr if on same line
                ;;
            '='|';'|'&'|'|')
                store_par           # Store the left hand
                store_par "$ch"     # Store this operator
                ;;
            '<')    # input redirection from a file todo
                store_par
                store_par "$ch"
                ;;
            '>')    # output redirect to new file, todo
                store_par
                store_par "$ch"
                ;;
            ' ') store_par  ; ;; # Store pending par, ignore space 
            *) fnd_par+="$ch"; ;;
        esac; ;;esac; ;;esac
    done
    store_par   # Store any last pending par
    
    ((cur_line_no++))
    
    # split the line into multiple commands. This is a simple approach us the
    # palin ';' and '&' as sepeartor. Add a ';' to have an easier handlign in
    # the loop )signle show.
    local -a show_pars  # DO NOT CHANGE THIS NAME IT IMPACTS OTHER HELP DEFINITION IN OTHER FILES!!
    local -a org_pars   # SAME MAY APPLY IF NEEDED TO OVERULLE
    local -a unqo_pars  # SAME MAY APPLY IF NEEDED TO OVERULLE
    local pars_idx=0
    local idx=0
    fnd_pars[$fnd_idx]=';'; ((fnd_idx++))
    while [ $idx -lt $fnd_idx ]; do
        dbg_msg "par:[$idx]${fnd_pars[$idx]}"
        if [ "${fnd_pars[$idx]}" == ';' ] || [ "${fnd_pars[$idx]}" == '&' ]; then
            proc_show_pars
            show_pars=(); org_pars=(); unqo_pars=()
            pars_idx=0
            fnd_skip_hlp_comment=0
        else
            org_pars[$pars_idx]="${fnd_pars[$idx]}"
            show_pars[$pars_idx]="$(parse_string "${fnd_pars[$idx]}")"
            unqo_pars[$pars_idx]="$(unquote "${show_pars[$pars_idx]}")"
            ((pars_idx++))
        fi
        ((idx++))
    done

    if [ $ctrl_skip_line -ge 1 ]; then
        ((ctrl_skip_line--))
    fi
}

: <<=cut
=func_int
Identify the lines and an extra paramaters.

The way it is being parsed might require in some cases style changes
* As it won't be able to handle multi liners (use of ; in some cases).
* It is pretty much white space oriented tabs might cause troubles.
=set line_short
A short comment which can be used to print
=set line_comment
A longer comment depending on the type of the liner
=stdout
The processed lines
=cut
function proc_line() {
  
    # Chomp spaces and tabs (front/back)
    local line="$(get_cur_line)"
    dbg_msg "$cur_idx:$line"
    ((cur_idx++))       # This line will always be processed
    if [ "$cur_proc" != '' ]; then
        if [ $cur_idx -lt $cur_proc ]; then
            echo -en "$COL_ok"
        elif [ $cur_idx -gt $cur_proc ]; then
            echo -en "$COL_def"
        else
            echo -en "$COL_fail"
        fi
    fi
    
    [ "$line" == '' ] && return

    local line_no="$cur_idx"    # Only set to the beginning of the line.

    case "$line" in
        ': <<=cut'*) ctrl_in_pod=1; ((ctrl_pod_cnt++))  ; ;; # Our pod marker (remember and ignore)
        '=cut'*)                                             # Special mark don't do default parsing
            [ $ctrl_pod_cnt == 1 ] && echo ''                # 1st Creates an empty line
            ctrl_in_pod=0
            ;;
        "$TAG_id")  : ;;                                     # Empty skip as is
        "$TAG_id"*)
            [ "$cur_proc" != '' ] && echo -en "$COL_def"
            local pot_tag="$(get_field 1 "${line:1}")"      # strip the tag (remove id and get full tag
            read_tag "$pot_tag"
            if [ "$tag_tag" != '' ]; then
                [ "$tag_what" != '' -a "$(get_substr "$what" "$tag_what" ',')" == '' ] && tag_type='I'  # Force ignore
                case "$tag_type" in
                    'M')
                        echo "$(p_extra)$tag_short$(get_field 2- "$line")"
                        while [ $cur_idx -lt $max_idx ]; do
                            line="$(get_cur_line as_is)"
                            if [ "${line:0:1}" != "$TAG_id" ]; then 
                                echo "$(p_none +)$line"
                                ((cur_idx++))
                            else
                                break;
                            fi
                        done
                        [ $cur_idx -eq $max_idx ] && echo "Warning: Reached end of file but no end marker yet."
                        ;;
                    'S') echo "$(p_extra)$tag_short$(get_field 2- "$line")"
                         [ "$tag_tag" == 'help_todo' ] && ctrl_skip_file=1
                         ;;
                    'L') echo "$(p_none)$tag_short$(get_field 2- "$line")"; ;;
                    'I') :                                          ;;
                    *)   prg_err "Unsupported tag type '$type'"  ; ;;
                esac 
            else                   
                echo "Unrecognized tag [$TAG_id$pot_tag] on line $line_no"
            fi
            ;;
        '#=#')   echo ''                             ; ;;
        '#=# '*) echo -e "$(p_info  )$(parse_string "${line:4}" $cur_no_sect)"  ; ;; # Yes process the comment with #
        '#= '*)  echo -e "$(p_none  )$(parse_string "${line:3}" $cur_no_sect)"  ; ;; # Yes process the comment with <>
        '#=* '*) echo -e "$(p_task  )$(parse_string "${line:4}" $cur_no_sect)"  ; ;; # Yes process the first as a task
        '#=- '*) echo -e "$(p_list +)$(parse_string "${line:4}" $cur_no_sect)"  ; ;; # Yes process the additional task (indent)
        '#=inc_indent') inc_indent; ;;
        '#=dec_indent') dec_indent; ;; 
        '#=trans_sect_enable')  cur_no_sect=''        ; ;; 
        '#=trans_sect_disable') cur_no_sect='no_sect' ; ;; 
        '#=include_hlp'*)
            local file="$hlpdir/$(get_field 2 "$line")"
            if [ -r "$file" ]; then
                echo "$(p_extra)Additional information:"
                echo -e "$(cat "$file" | grep -v '^=' | $CMD_sed "s/^/$(p_none +)/")$nl"
            else
                echo "$(p_info_)Did not find help file: $file"
            fi
            ;;            
        '#=search_func'*)   # For now only dislplay, perhaps later collect? 
            echo "$(p_list +)Function to search for: $(get_field 2- "$line")"
            ;;
        '#=skip_control'*)      
            if [ $ctrl_start_skip == 0 ] && [ $ctrl_in_skip == 0 ]; then
                ctrl_start_skip=1
                ctrl_skip_control=0
            else
                dbg_msg "WARN : Found nested '$fnd_comment', ignored"
            fi
            ;;
        '#=skip_until_marker'*)                              ((ctrl_skip_code++)); ;;
        '#=skip_until_here'*)   [ $ctrl_skip_code -ge 1 ] && ((ctrl_skip_code--)); ;;
        '#=skip_until_end'*)    ctrl_skip_code=10000                             ; ;; # Yes x here's would undo skip
        '#=warning '*) echo -e "${COL_warn}$LOG_wsep$nl$(get_field 2- "$line")$nl$LOG_wsep" ; ;;
        '#=queue_step '*) 
            local info="$(unquote "$(get_field 2- "${line}")")"
            add_step_todo "$info" 'later'
            echo "$(p_task +)Sub-step '$info' could be queued/executed for later execution."
            ;;
        '#=execute_step '*)     # Do not enter the step index as parameter!
            local info="$(unquote "$(parse_string "$(get_field 2- "${line}")" no_sect)")"
            add_step_todo "$info" 'now'
            echo "$(p_task +)Sub-step '$info' might be executed in given tasks."
            ;;
        '#=return '* | '#=cmd '* | '#=cmd_input '* | '#=unpack_file '* | '#=func '*)            # Some allow to define as comment.
            line="$(get_field 2- "$line" '=')"
            parse_line "$line"
            ;;
        '#=cat '* | '#=grep '*)      # a simple cat or grep, grp pars switched file first!
            parse_pars "$(parse_string "$line" no_sect)"    # Get parse, never sect
            local ins="${prs_pars[0]:2}"
            local file="${prs_pars[1]}"
            local output=''
            if [ "$file" != '' ] && [ -r "$file" ]; then
                case "$ins" in
                    'cat')  output="$($ins "$file")"                   ; ;;
                    'grep') output="$($ins "${prs_pars[2]}" "$file")"  ; ;;
                esac
                [ "$output" == '' ] && echo "$(p_none)<no contents>" || echo "$output" | $CMD_sed "s/^/$(p_none)/"
            else
                dev_msg "Ignore cat (no file '$file'): $line"
            fi
            ;; 
        '#=set_var_cur '* | '#=set_var_def '*)         # Will overwrite current/default val, no existence check just add/clean
            parse_pars "$line"
            local fld="var_$(get_field 3 "${prs_pars[0]}" '_')"; fld="${!fld}"
            if [ "$fld" != '' ] && [ "${prs_pars[1]}" != '' ]; then
                map_put "$map_var/${prs_pars[1]}" "$fld" "${prs_pars[2]}"
                dev_msg "Setting ${prs_pars[1]}[$fld]='${prs_pars[2]}'"
            fi
            ;;
        '#'*) dev_msg "$line"                                                    ; ;; 
        *) [ $ctrl_in_pod == 0 ] && parse_line "$line" || dev_msg "$line"; ;;
    esac
}

: <<=cut
=func_int
Will show the help of a specific file.
=stdout
The output generated for the specifed file.
=cut
function show_help_for_file() {
    local info="$1"    # (M) The step info belong to this file
    local file="$2"    # (M) The existing step file to process
    local type="$3"    # (M) What is the type of the file represent
    local what="$4"    # (M) What to show (see below)
    local proc="$5"    # (O) Optional line to which data has been processed
    
    # Will be accessed and changed by subroutines
    local -a ret_vals
    local -a cur_lines
    local -a prs_pars  
    local    cur_proc="$proc"
    local    cur_idx=0     
    local    cur_ind_lvl=0
    local    cur_type="$type"
    local    cur_what="$what"
    local    cur_line_no=0
    local    cur_expr_no=0
    local    cur_script_pars=0
    local    cur_task=1
    local    cur_case_depth=0
    local    cur_shift=0
    local    cur_recovers=0
    local    cur_no_sect='no_sect'   # The by #= statement as default
    local    max_idx=0       

    # Some control states used by parse_line (stateful)
    local ctrl_in_pod=0
    local ctrl_pod_cnt=0
    local ctrl_start_skip=0
    local ctrl_in_skip=0
    local ctrl_skip_code=0
    local ctrl_skip_control=0
    local ctrl_skip_line=0
    local ctrl_skip_file=0

    check_in_set "$type" 'Step'

    map_init $map_var
    map_init $map_var_expr
    echo "$cur_task" > "$file_task"
    
    SHLP_cur_user='root'

    # Decide if entity or automate file and store the parameters (space separated!)
    local fnr=3         # Default assume from entity
    [ "$(echo -n "$file" | grep '/scripts/steps')" != '' ] && fnr=2    # From automate not ent
    local par; local pidx=1
    for par in $(get_field ${fnr}- "$info"); do
        local map="$map_var/$pidx"
        map_put "$map" "$var_name"  "$pidx"
        map_put "$map" "$var_type"  'b'     # bash variable
        map_put "$map" "$var_init"  "$par"
        map_put "$map" "$var_cur"   "$par"
        ((pidx++))
    done
    if [ $fnr == 3 ]; then  # It is an entity
        local comp="$(get_field 2 "$info")"
        func "$comp" define_vars   # Define the vars in attempt for proper variables.
        find_install "$comp" optional
        if [ "$install_aut" != "" ] && [ -d "$install_aut/etc" ]; then
            STP_etc_dir="${install_aut}/etc"
        fi
        local SCR_whoami="$comp"; readonly SCR_whoami
    fi

    # First we read all the lines, which is handier in forward processing
    local line
    IFS=''; while read -r line; do IFS=$def_IFS
        cur_lines[$max_idx]="$line"
        ((max_idx++))
    IFS=''; done < $file;  IFS=$def_IFS

    echo "$LOG_sep"
    echo "Help for: $type '$info'"
    echo "$LOG_isep"
    echo "file: '$file'"
    echo "node: $hw_node, Default Bash-User: root"
    echo "$LOG_isep"

    SHLP_cur_inst=$(echo -n "$info" | $CMD_ogrep ' instance [0-9]' | $CMD_ogrep '[0-9]')
    [ "$SHLP_cur_inst" != '' ] && echo -e "${COL_bold}inst: $SHLP_cur_inst, This script currently run for instance $SHLP_cur_inst$COL_no_bold"
    local SCR_instance="${instance:-0}"; readonly SCR_instance
    
    if [ "$(echo -n "$file" | grep 'Baseline')" != '' ]; then
        # Seem like a baseline file, check fully documented version
        local full_doc_intro="$GEN_our_pkg_baseline-NMM15.7.0.1"
        compare_pkg_version  "$GEN_our_pkg_baseline" "$full_doc_intro"
        [ $? == 0 ] && echo -e "${COL_warn}warn: Be aware you baseline does not have all additional documentation.
      Documentation might be incomplete or too complex. Full annotated doc
      supported started in $full_doc_intro.$COL_def"
    fi
    
    [ $max_idx == 0 ] && echo "Warning: The file is empty!"
    while [ $cur_idx -lt $max_idx ]; do
        proc_line  # Will increase cur_idx upto needs
        cur_task="$(cat "$file_task")"      # update with current value
        [ $ctrl_skip_file != 0 ] && break
    done
    echo "$LOG_sep$nl"
}

: <<=cut
=func_int
Check for other scritps and prints them if not printed yet
=cut
function print_other_scripts() {
    local out_file="$1"    # (O) Used to indicate output file (additional info written)

    out_file="${out_file:-$SHLP_stdout}"
    
    local add=0; local icnt
    local map
    local key; local fkey
    local file

    # Adding the now and later funcs which are not yet printed
    for map in $map_steps_now $map_steps_later; do
        for key in $(map_keys "$map"); do
            if [ "$(map_get "$map/$key" "$scr_docu")" != '' ]; then
                dev_msg "Skipping $map/$key, already documented"
                continue
            fi
            local step="$(map_get "$map/$key" "$scr_step")"
            dev_msg "Adding step ($map/$key): $step"
            map_put "$map/$key" "$scr_docu" 'sub-done'
            ((add++))
            [ "$out_file" != "$SHLP_stdout" ] && log_screen "Processing extra : $step"
            if [ "$step" == '' ]; then
                log_screen "Failed to get info for: [$map]/[$key], skipping!"
            else
                help_on_step "$step" '' '' '' 'cont' >> $out_file
            fi
        done
    done
 
    
    # Funcs are not yet supported. only show a list
    map="$map_funcs": 
    if [ "$(map_cnt "$map")" != 0 ]; then
        SHLP_no_func_yet=''         # Print another header
        for key in $(map_keys "$map"); do
            local name="$(map_get "$map/$key" "$scr_name")"
            local comp="$(map_get "$map/$key" "$scr_comp")"
            local fmap="$map/$key/$scr_files"
            local files="$(map_cnt "$fmap")"
            for fkey in $(map_keys "$fmap"); do
                file="$(map_get "$fmap/$fkey" "$scr_file")"
                [ "$out_file" != "$SHLP_stdout" ] && log_screen "Processing func : [$comp]$func : $(basename "$file")"
                help_on_func "$func" "$comp" "$file" '' 'cont'  >> $out_file
            done
        done
    fi
    
    return $add
}

: <<=cut
=func_frm
The start point for printing help for a step file
=cut
function help_on_step() {
    local step_info="$1"    # (M) The full step info to search for. The 1st par could identify an entity
    local what="$2"         # (O) What to show (sup/dev) defaults to sup
    local upto_line="$3"    # (O) Processing went upto a specific line
    local upto_file="$4"    # (O) Processing went upto a specific file
    local cont="$5"         # (O) Indicates continuation (do reinit some maps)

    if [ "$cont" == '' ] || [ $SHLP_inited == 0 ]; then
        # Initialize  the scripts maps
        map_init $map_steps_now
        map_init $map_steps_later
        map_init $map_funcs
        map_init $map_links
        map_init $map_calls
    fi
    
    [ $SHLP_inited == 0 ] && init_show_help

    add_step_todo "$step_info" 'now' 'done'

    step_par="${step_par:-"$(get_field 2- "$step_info")"}"
    what="${what:-sup}"
    [ "$what" != "$SHLP_w_dbg" ] && check_in_set "$what" "$SHLP_what"   # Silently accept dbg

    SHLP_cur_user='root'    # Lets assume a new steps start under root (this does not have to be valid)

    local files="$(find_step_files "$step_info")"
    if [ "$files" != '' ]; then
        local file
        for file in $files; do
            local proc="$upto_line"
            [ "$upto_file" != '' -a "$upto_file" != "$file" ] && proc=''
            [ -r "$file" ] && show_help_for_file "$step_info" "$file" Step "$what" "$proc"
            [ "$file" == "$upto_file" ] && break
        done
    else
        echo "Did not find any step files related with '$step_info'"
    fi
    
    if [ "$cont" == '' ]; then
        print_other_scripts
        while [ $? == 1 ]; do   # found perhaps more triggered
            print_other_scripts
        done
    fi
        
}

: <<=cut
=func_frm
The start point for printing help for a func file
=cut
function help_on_func() {
    local func="$1"         # (M) The function to show
    local comp="$2"         # (O) The optional component for this func
    local file="$3"         # (O) The actual file to process
    local what="$4"         # (O) What to show (sup/dev) defaults to sup
    local cont="$5"         # (O) Indicates continuation (do reinit some maps)

    if [ "$SHLP_no_func_yet" == '' ]; then
        echo "$(p_none)Functions cannot be fully generated (there was no time to annotate)."
        echo "$(p_list +)Use given inline help or read function file."
        echo "$(p_list +)If required then make sure future time is allocated for this."
        echo "$(p_none)The list with (additional) found functions:"
        SHLP_no_func_yet='printed'
    fi

    echo "$(p_list +)[$comp]$func : $(basename "$file")"

    return
        

    if [ "$cont" == '' ] || [ $SHLP_inited == 0 ]; then
        # Initialize  the scripts maps
        map_init $map_steps_now
        map_init $map_steps_later
        map_init $map_funcs
        map_init $map_links
        map_init $map_calls
    fi
    
    [ $SHLP_inited == 0 ] && init_show_help

    # TODO actually print it
}

: <<=cut
=func_frm
Write all documentation to an file. And give intermediate information.
=need AUT_step
The steps need to be defined ofcourse.
=cut
function write_doc_for_step_to_execute() {
    local from_step="$1"    # (O) The start step, if empty then all (from 1)
    local out_file="$2"     # (O) The output file or stdout if not given (not via log_screen)

    local num=${#AUT_step[@]}
    local idx=${from_step:-1}

    if [ "$out_file" == '' ]; then
        out_file="$autodocdir/$(basename "$STR_step_file")"
        out_file="${out_file%.*}"
        out_file+=".gen.txt"
    fi
    cmd_hybrid "Test if documentation file '$file' can be written" "echo '' > $out_file"

    [ "$out_file" != "$SHLP_stdout" ] && log_screen "${LOG_sep}
Generating documentation for steps to execute [$idx..$((num-1))]
$LOG_isep
This can take some while, progress shown per step.
Output: $out_file
Hint  : Follow proces with : tail -f <file>
$LOG_isep" 

    while [ "$idx" -lt "$num" ]; do
        local step="${AUT_step[$idx]}"
        [ "$out_file" != "$SHLP_stdout" ] && log_screen "Processing[$idx] : $step"
        help_on_step "$step" '' '' '' 'cont' >> $out_file
        ((idx++))
    done

    [ "$out_file" != "$SHLP_stdout" ] && log_screen "${LOG_isep}${nl}Checking for sub steps, function calls$nl$LOG_isep"
    
    print_other_scripts "$out_file"
    while [ $? == 1 ]; do
        print_other_scripts "$out_file"
    done

    [ "$out_file" != "$SHLP_stdout" ] && log_screen "${LOG_isep}
Done, All output written to '$out_file'
$LOG_isep
${COL_bold}Thank you for using the auto document feature of Automate!$COL_def
Any suggestions to improve the auto generated documentation. Please share
your thoughts with the author (currently 'Frank.Kok@newnet.com') and let us
see if it can be easily improved.
$LOG_sep"
}

