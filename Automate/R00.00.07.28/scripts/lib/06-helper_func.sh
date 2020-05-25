#!/bin/sh

: <<=cut
=script
This script contains simple helper functions related to the function
mechanism
=version    $Id: 06-helper_func.sh,v 1.12 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

: <<=cut
=func_int
This functions shields variables clashes from the local function and the called
function (as it cannot be controlled what user functions are doing.
=set SCR_whoami
This will hold the entity + optional version (separated by a :) of the
being called function. This can be used by a function to store info about
himself. This is accessible for its children. May be empty if unknown.
=set SCR_alias
This will hold the original alias name or entity (if no alias, without a version).
This is accessible for its children. May be empty if unknown.
=set SCR_instance
This hold the instance number can be useful if entity needs to know. One could
use MM_instance but that would require overruling in e.g. func. This is more
localized in the SCRIPT function. Do not add to whoami, which would cause
unwanted side effect. Now the pkg can decide what it wants.
=func_note
Believe me it happened with funny behavior.
=cut
function call_func_in_func() {
    local whoami="$1"          # (O) Identifies who this step belong to may be empty
    local alias="$2"           # (O) Identifies the original alias, may be empty
    local func_script="$3"     # (M) the function script to call
    local parameters="$4"      # (O) The additional parameter to pass

    # Store the whoami as local but with a 'global'prefix as it can be used by 
    # this functions children. Not using a global allows correct handling of
    # nested calls.
    local SCR_whoami="$whoami"; readonly SCR_whoami
    local  SCR_alias="$alias" ; readonly SCR_alias

    # Copy the instance from current level or set to 0. It is currently
    # not possible nor advised that a funciton can change the instance
    local instance="$SCR_instance"
    local SCR_instance="${instance:-0}"; readonly SCR_instance

    log_screen_info "$func_script" $parameters
    . $func_script $parameters ""
    check_success "func: called: $func_script $parameters" "$?"
}

: <<=cut
=func_ext
Find func file belonging to the given funcs. This does not support the versions
but allows for the order and the OS specific selection. Once the step order is
broke so it will stop. The order is 1,2,3,4,..9. So 1,2,4 will show only 1 and 2
=func_note
It is currently not yet used by func (risk of breaking stuff) but it
might be possible/useful to adapt it and use it.
=stdout 
The file (full paths which are related to this func. They are ordered in sequence.
The files are separated by spaces (so no spaces in files names!).
=cut
function find_func_files() {
    local func="$1"      # (M) The internal function to process
    local comp="$2"      # (O) The optional component

    local dir="$fncdir"
    local pars=''
    local whoami=''
    local cur_ver=''

    # No madatory, optional check though we have to strip it. Could be in both
    [ "${func:0:1}" == '!' ] && func="${func:1}"
    [ "${func:0:1}" == '*' ] && func="${func:1}"
    [ "${comp:0:1}" == '!' ] && comp="${comp:1}"
    [ "${comp:0:1}" == '*' ] && comp="${comp:1}"
    
    if [ "$(basename $func)" != "$func" ]; then    # Look like a directory
        dir="$func"
    elif [ "$comp" != '' ]; then          # See if there is a component specific of func specific dir
        find_install "$comp" 'optional'
        if [ "$install_ent" != '' ]; then      # The first name is a package 
            cur_ver=$install_cur_ver
            [ "$install_aut" != '' ] && [ -d "$install_aut/funcs" ] && dir="$install_aut/funcs $fncdir"
        fi
    fi
    [ "$func" == '' ] && return     # No function no files
    
    local i
    local d
    local f
    local sep=''
    IFS=$def_IFS
    for i in {1..9}; do
        for d in $dir; do
            f=$(get_best_file "$d/$func.$i" '' '' '' "$cur_ver")
            if [ "$f" != '' ]; then
                echo -n "$sep$f"
                sep=' '
                break 1     # This sequence has been done
            fi
        done
        [ "$f" == '' ] && break  # Stop if none found in this sequence
    done
}

: <<=cut
=func_frm
Execute a function stored in a file, these are stored in:
=le <component_dir>/<func>.sh
=le $fncdir/<func>.sh or
Function files can be OS and Os version independent.
The function files should have sequence number like <sub>.n.sh
Where n = [1..9]
Only one file of a sequence number is executed. This is the file with the
closest match of OS.version.
This approach allow 2 approaches:
=le sequential 1 generic for all os, then linux then linux.rhel6-5. Use n=1..3
=le signle match. All uses n=1.
=
=func_note
The called function itself is responsible for checking error codes!
=man1
The component to access. A component can be extended with a version like:
C<comp:ver> if so then this component version has to exists (failure if not).
If omitted then the most recent (which happens to be the version to be installed)
will be selected.
The comp_or_func may also contain a directory in which case that directory
is search. This should include the funcs subdir as well.
If the first character is an '!' then the function has to be found.
If the first character is an '*' then the function is optional.
=optx 
Additional parameter given to func. In case of a component the first optional
parameter will be the func. 
=ret
The amount of functions called. 0 if no match was found.
=example
C<func service start mysql>  # Generic way to start MySQL using service.sh
C<func MGR service start>    # Start MGR using component specific service.sh
=cut
function func() {
    local comp_or_func="$1"  # (M) The internal function or component (see func) to call
    local func="$2"          # (O) The function to execute (needed if component)
    local strip_args=("$@")

    log_debug "func trying: func $*"

    local chk_dir=''
    local dir
    local pars=''
    local whoami=''
    local alias=''
    local cur_ver=''

    # Decide on default mandatory base on given name
    local mandatory=0
    if [ "${comp_or_func:0:1}" == '!' ]; then
        mandatory=1
        comp_or_func="${comp_or_func:1}"
    fi
    # Function can also be forced optional
    local optional=0
    if [ "${comp_or_func:0:1}" == '*' ]; then
        optional=1
        comp_or_func="${comp_or_func:1}"
    fi
    check_set "$comp_or_func" "No function given to execute."
    
    # There is a small chicken and an egg. Which is not really a problem becuase
    # the init vars are always local and not part of any install package. 
    # Therefor just quickly check if the function exists. In this case map_get
    # which is used by find_install
    declare -f map_get > /dev/null
    local map_inited=$?
    if [ "$(basename $comp_or_func)" != "$comp_or_func" ]; then    # Look like a directory
        dir=$comp_or_func
        chk_dir=$dir
        strip_pars 2
        pars=$stripped_pars     # just in case of nested calls
    elif [ $map_inited == 0 ]; then
        # See if there is a component specific of func specific dir
        find_install $comp_or_func 'optional'
        if [ "$install_ent" != '' ]; then      # The first name is a package 
            cur_ver=$install_cur_ver
            whoami=$(get_concat "$install_ent" "$cur_ver" ':')
            alias="${install_alias:-$install_ent}"
            strip_pars 2
            pars=$stripped_pars     # just in case of nested calls
            if [ "$install_aut" != '' ] && [ -d "$install_aut/funcs" ]; then
                dir="$install_aut/funcs $fncdir"
            fi
            chk_dir="$fncdir"
        fi
    fi
    if [ "$chk_dir" == '' ]; then           # It is a regular func
        mandatory=1                         # These are mandatory
        func=$comp_or_func
        strip_pars 1
        pars=$stripped_pars     # just in case of nested calls
        dir="$fncdir"
    fi
    if [ "$func" == '' ]; then
        log_exit "Missing function definition"
    fi
    
    local i
    local d
    local f
    local cnt=0
    local pars
    IFS=$def_IFS
    for i in {1..9}; do
        for d in $dir; do
            f=$(get_best_file "$d/$func.$i" '' '' '' "$cur_ver")
            if [ "$f" != '' ]; then
                if [ ! -x $f ]; then
                    log_exit "Func file '$f' cannot be executed."
                fi
                if [ "$d" == "$chk_dir" ]; then   # comp but fallkack add compontent as parameter
                    call_func_in_func "$whoami" "$alias" "$f" "$pars $comp_or_func"
                else
                    call_func_in_func "$whoami" "$alias" "$f" "$pars"
                fi
                ((cnt++))
                break 1     # This sequence has been done
            fi
        done
        if [ "$f" == '' ]; then
            break;      # Stop if none found in this sequence
        fi
    done
    
    if [ "$mandatory" == '1' -a "$optional" == '0' -a "$cnt" == '0' ]; then
        log_exit "No function was found for: func $*"
    fi

    return $cnt

    [ -z help ] && ret_vals[0]="No function found for '$comp_or_func $func'"
    [ -z help ] && ret_vals[1]="At least 1 function found for '$comp_or_func $func'"
}

: <<=cut
Prints a list with all functions.
=cut
function show_funcs() {
    local func
    local dir
    
    log_screen "All main functions (not related to package:"
    for func in `ls $fncdir/*.sh | sort -d | sed 's|/.*/||' | cut -d'.' -f1 | uniq`; do
        log_screen "- $func"
    done
    log_screen ''

# TODO finsih if wanted, how todo all the different versions    
#     for dir in $pkgdir/*; do
#         if [[ ! -d $dir ]] || [[ ! -d $dir/funcs ]]; then
#             continue
#         fi
#         
#         log_screen "Functions belonging to package $dir:"
#         for func in `ls $dir/funcs*.sh | sort -d | sed 's|/.*/||' | cut -d'.' -f1 | uniq`; do
#             log_screen "- $func"
#         done
#         log_screen ''   
}