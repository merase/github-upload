#!/bin/sh
: <<=cut
=script
This script holds generic variables
=version    $Id: 06-vars_generic.sh,v 1.22 2018/08/02 08:10:05 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# Some generically used keywords
readonly KW_instance='instance'

# The following var group are defined using a function as they have also os differences.
func set_GEN_vars   # Definition of all preset $GEN_* variables, which can be overruled by [generic] section
func set_OS_vars	# Definition of all $OS_* variables
func set_CMD_vars 	# Definition of all $CMD_* variables
func set_AUT_vars   # Definition of automation related vars like $AUT_* variables
func set_CFG_vars   # Definition of $CFG_* variables

InitD_SNMP="$OS_initd/textpass_snmpd"

SH_tz="$OS_profile/tz.sh"

# Some color definitions, see e.g. http://misc.flogisoft.com/bash/tip_colors_and_formatting
readonly COL_def='\e[0m'         # The default all attributes off
readonly COL_def_fg='\e[39m'     # Default foreground color
readonly COL_def_bg='\e[49m'     # Default background color
readonly COL_ok='\e[32m'         # Green
readonly COL_fail='\e[31m'       # Red
readonly COL_info='\e[35m'       # Magenta
readonly COL_todo='\e[43m'       # BG Yellow
readonly COL_warn='\e[33m'       # Yellow
readonly COL_blink='\e[5m'       # Only blink (Does not work for all terminals)
readonly COL_bold='\e[1m'        # Bold
readonly COL_undl='\e[4m'        # Underline
readonly COL_dim='\e[2m'         # Dim text
readonly COL_rev='\e[7m'         # Reverse
readonly COL_hide='\e[8m'        # Hidden (Could be usefull for passwords)
readonly COL_no_blink='\e[25m'   # Reset blink
readonly COL_no_bold='\e[21m'    # Reset bold
readonly COL_no_undl='\e[24m'    # Reset underline
readonly COL_no_dim='\e[22m'     # Reset dim
readonly COL_no_rev='\e[27m'     # Reset reverse
readonly COL_no_hide='\e[28m'    # Reset hidden


# There is some logic in the number 0x = busy, 1x = ok, 2x = failed
readonly STAT_grp_busy=9
readonly STAT_grp_ok=19
readonly STAT_grp_failed=29

# Do not use value 0!
readonly STAT_todo=1                    # Still to-do, internal 
readonly STAT_substeps=2                # The step has sub steps to execute
readonly STAT_wait=3                    # Wait for the user or timeout before continue
readonly STAT_partial=4                 # The implementation is partially finished (internal)
readonly STAT_manual=5                  # A manual step is requested
readonly STAT_info=6                    # Additional info will be given, before the final result
readonly STAT_usr_skipped=7             # User skipped upon request
readonly STAT_implicit=9                # Step will be done implicitly due to other dependencies
readonly STAT_passed=10                 # The step has passed
readonly STAT_not_applic=11             # A step is available but it was not applied
readonly STAT_skipped=12                # The step is skipped (upon request / cofniguration)
readonly STAT_warning=13                # A warning was given which should be noticed [WARNING x]
readonly STAT_sum_warn=14               # The summarize of the warnings [x WARNING(S) ]
readonly STAT_shutdown=15               # A shutdown was requested
readonly STAT_reboot=16                 # A reboot was requested
readonly STAT_done=17                   # Step seems to be done already, not redone
readonly STAT_s_reboot=18               # A reboot but stay in current step
readonly STAT_later=19                  # Some manual action should be done later
readonly STAT_failed=20                 # The step failed
readonly STAT_not_found=21              # The step was not found (only for interactive mode!)

# Textual translate from STAT_ to string
       STAT_stats[$STAT_todo]='TODO'
   STAT_stats[$STAT_substeps]='SUBSTEPS'
       STAT_stats[$STAT_wait]='WAIT'
    STAT_stats[$STAT_partial]='PARTIAL'
     STAT_stats[$STAT_manual]='MANUAL'
       STAT_stats[$STAT_info]='INFO'
STAT_stats[$STAT_usr_skipped]='SKIPPED'
   STAT_stats[$STAT_implicit]='IMPLICIT'
     STAT_stats[$STAT_passed]='PASSED'
 STAT_stats[$STAT_not_applic]='NOT APPLIC'
    STAT_stats[$STAT_skipped]='NOT NEEDED'
    STAT_stats[$STAT_warning]='WARNING'
   STAT_stats[$STAT_sum_warn]='WARNING'
   STAT_stats[$STAT_shutdown]='SHUTDOWN'
     STAT_stats[$STAT_reboot]='REBOOT'
       STAT_stats[$STAT_done]='DONE'
   STAT_stats[$STAT_s_reboot]='REBOOT'
      STAT_stats[$STAT_later]='LATER'
     STAT_stats[$STAT_failed]='FAILED'
  STAT_stats[$STAT_not_found]='NOT_FOUND'
readonly  STAT_min_space=12              # Minimum space reserver + use max_lengt larged state + 2 for []

# List of predefined element names, the contents is still defined by the
# config. However the type is important to make certain decission
readonly EL_OAM='OAM'   # An OAM element normally has the manager on it
readonly EL_TE='TE'     # A Traffcie Element, most of the time has a router
readonly EL_SE='SE'     # A subsctriber Element
readonly EL_LE='LE'     # A logging Element
readonly EL_COMB='COMB' # A combined element which can have all combinations

readonly nl=$'\n'   # A simple newline variable
readonly tb=$'\t'   # A simple tabulator variable

# Some predifined calculation units
readonly kB=1024
readonly MB=$(( kB * kB ))
readonly GB=$(( MB * kB ))
readonly TB=$(( GB * kB ))

readonly map_var_def='VAR_cur_default'
         map_var_inited=0

: <<=cut
=func_frm
Set a default value for a variable in case it is not set. If no default
value is given then it is checked if the value is actually set. If not set
then the execution stops.
=cut
function set_default() {
    local var="$1"      # (M) The variable to check and or set, cannot hold spaces.
    local def_val="$2"  # (O) The default value, if empty then it is check if var set

    [ -z help ] && [ "$def_val" == '' ] && show_short="Fail if '\$$var' has not value assigned"
    [ -z help ] && [ "$def_val" != '' ] && show_short="Set default for '\$$var' to '$def_val' (so if not set)"
    [ -z help ] && show_trans=0 

    if [ $map_var_inited == 0 ]; then       # One time init
        map_init $map_var_def
        map_var_inited=1
    fi

    local cur_val="${!var}"
    if [ "$cur_val" == '' ]; then
        check_set "$def_val" "Variable '$var' should be set, it is not."
        export $var="$def_val"      # Need to be like this in case of spaces
        cur_val="${!var}"
    fi

    local comp="$(get_field 1 "$var" '_')"
    map_put "$map_var_def/$comp" "$var" "$cur_val"

}

: <<=cut
=func_frm
Selects and assign a default variable out of the primary and a secondary choice.
A warning will be given if both variable are set and not the same. If none
set then the resulting variable will not be set.
Remember the parameters are names of variables, not content!
=cut
function select_default() {
    local result="$1"   # (M) The name of the result var. Cannot hold spaces.
    local prim="$2"     # (M) The primary variable name to choice from
    local sec="$3"      # (M) The secondary variable name to choice from.

    if [ "${!prim}" != '' ]; then
        if [ "${!sec}" != '' -a "${!prim}" != "${!sec}" ]; then
            # Made info because it is hard to auto select source. Variables
            # eitehr check [cfg/XXX]nnnnn or [sect#n]nnnn
            log_info "Both $prim='${!prim}' and $sec='${!sec}' but not same, chosen primary."
        fi
        export $result="${!prim}"      # Need to be like this in case of spaces
    elif [ "${!sec}" != '' ]; then
        export $result="${!sec}"      # Need to be like this in case of spaces
    fi
    
    if [ "${!result}" != '' ]; then
        local comp="$(get_field 1 "$result" '_')"
        map_put "$map_var_def/$comp" "$result" "${!result}"
    fi
}

: <<=cut
=func_frm
Cleans all default values for a epecific component. This to allow proper
instancing as some entities need this. Only the variable check by default 
as a specifci compmenent prefix will be cleaned.
=cut
function clean_default_vars() {
    local comp="$1"     # (M) The component prefix to be cleaned

    local map="$map_var_def/$comp"
    local var
    for var in $(map_keys "$map"); do
        unset $var
        map_put "$map" "$var"       # And eras from the map as well
    done
}

: <<=cut
=func_frm
Add a field into a global variable. The fields are separated by a space. 
Additional a value can be assigned with an = operator. If the given
operator is = then the value is always overruled. If it is + then the value
is only set if not defined yet.
=cut
function add_field() {
    local var="$1"  # (M) The variable to check and/or add fields to
    local fld="$2"  # (M) The field to adapt or add
    local op="$3"   # (O) Empty or The operand either = (always assign) or + optional assign
    local val="$4"  # (O) The value to assign to the field (no spaces allowed)

    local new_str=''
    local set
    local fnd=0
    for set in ${!var}; do
        local cfld=$(get_field 1 "$set" '=')
        if [ "$cfld" == "$fld" ]; then
            fnd=1
            if [ "$op" == '=' ] && [ "$val" != '' ]; then
                new_str+=" $fld=$val"
            elif [ "$op" == '+' ]; then
                log_debug "Found '$set' & '$fld', no overrule, skipping"
                new_str+=" $set"
            else
                new_str+=" $set"
            fi
        else
            new_str+=" $set"
        fi
    done

    if [ $fnd == 0 ]; then
        if [ "$val" != '' ]; then
            new_str+=" $fld=$val"
        else
            new_str+=" $fld"
        fi
    fi

    export $var="${new_str:1}"  # Strip 1st space (easy algorithm)
}

: <<=cut
=func_frm
Retrieve the OS version base on the OS release file (or given namE), 
which currently contains something like this:
NMMOS_RHEL7.3-16.0.0_160.03.0-x86_64
IMHO a wrong name, should only hold SO info.
=stdout
The release so 73 for RHEL7.3 or 0 in case not determined
=cut
function get_our_OS_release() {
    local name="$1" # (O) Use a given name rather then th file. The name should match the release string

    if [ "$name"  == '' ]; then
        if [ -e "$OS_NMM_rel_file" ]; then
            name="$(cat $OS_NMM_rel_file)"
        else
            log_info "Did not find '$OS_NMM_rel_file; to determine release"
            name="0"
        fi
    fi

    get_field 1 "$name" '-' | tr -d '.' | $CMD_ogrep '[0-9]+'
}
