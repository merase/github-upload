#!/bin/sh
#
# This script will Initialize the libraries (bash scripts) used by the Automation tool.
# This scripts bases it path on the current run location. No need to give it
#
# Parameters:

if [ "$HOME" == '' ]; then  # No home if start-up by system (needed by e.g. MySQL ? 5.6.6)
    export HOME='/root'     # Slightly dirty workaround as it is runnin under root
fi
    
readonly    scriptdir="$1"  # (M) The script base directory

# Global in library can be set/changed by user app
 FLG_log_enabled=${FLG_log_enabled:-1}    # Enables or disables logging 
 FLG_dbg_enabled=${FLG_dbg_enabled:-0}    # Enables or disables debugging
FLG_cons_enabled=${FLG_cons_enabled:-0}  # Enables the console output (iso screen)
FLG_call_enabled=${FLG_call_enabled:-0}  # Enables the script calling output

readonly    stepfld='steps'
readonly     fncfld='funcs'

readonly     libdir="$scriptdir/lib"        # Descendants of the script dir 
readonly    stepdir="$scriptdir/$stepfld"
readonly     fncdir="$scriptdir/$fncfld"

readonly  installdir=`dirname $scriptdir`   # Is one higher than scriptdir
readonly      bindir="$installdir/bin"      # Descendants of the install dir
readonly      hlpdir="$installdir/hlp"
readonly   verifydir="$installdir/verify"
readonly templatedir="$installdir/template"

readonly      vardir='/var/Automate'
readonly      etcdir="$vardir/etc"
readonly      logdir="$vardir/log"
readonly      pkgdir="$vardir/pkg"           # All package should be collected (linked into this pkg directory) pkg/<ent>/<ver>/
readonly      upgdir="$vardir/upg"           # Created plans ares stored here
readonly  autodocdir="$vardir/auto_doc"
readonly boot_copied="$etcdir/.boot_data_copied"
readonly  update_chk="$etcdir/.update_checked"    

readonly decl_script='declare_vars.sh'      # Special script to declare vars (not OS dependent)

readonly hlp_auto_doc="$hlpdir/feature_auto_document.txt"   # Yes currently hard defined

# There is one check done here before continue and that is to see if this is the right OS
readonly OS=`uname`
readonly OS_any='Any'       # Special indication in case other version need to be referred (within connecting to OS)
readonly OS_linux='Linux'
readonly OS_solaris='SunOS'

CMD_ogrep='egrep -o'    # Defined here as something used before actually define by set_CMD_vars, different for Solaris

if [ "$OS" == $OS_linux ]; then
    if [ -f /etc/redhat-release ] ; then
        OS_prefix="RH"
        OS_version="$OS_prefix"`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*// | sed s/[.]/_/`
    else
        echo "Linux distribution not recognized/supported, check manual"
        exit 4
    fi
elif [ "$OS" == $OS_solaris ]; then
    if [ -f /etc/release ]; then
        OS_prefix="Sol"
        OS_version="$OS_prefix"`cat /etc/release | grep "Solaris" | sed s/.*Solaris\ // | sed s/\ .*// | sed s/[.]/_/`
    else
        echo "Solaris distribution not recognized/supported, check manual"
        exit 4
    fi
    # Exception: Default command not yet defined need egrep -o, solaris different see set_CMD_vars
    CMD_ogrep='/usr/sfw/bin/gegrep -o'
else
    echo "This script can only run on $OS_linux or $OS_solaris not on $OS, check manual"
    exit 4
fi
readonly CMD_ogrep
readonly OS_prefix
readonly OS_version
readonly OS_ver_numb=`echo -n "$OS_version" | sed 's/_//' | $CMD_ogrep '[0-9]+'` 

# 
# Verify the bash version due to associative array we need at lease version 4
# Which is a bummer as Solaris 10 only seems to have version 3. This was found
# out later. There might be away to use a newer bash version (available 11) or
# we can work it out.
# Currently it should be worked around using own map implementation, moved
# minimal from 4 to 3 again.
#
readonly BASH_min_ver=3
readonly BASH_ver="${BASH_VERSINFO[0]}"
if [ "$BASH_ver" -lt "$BASH_min_ver" ]; then
    echo "This script currently requires at least version $BASH_min_ver, you bash version is $BASH_ver"
    exit 5
fi

: <<=cut
=func_int
Read all shell scripts in a lib directory if they start with NN- and not 00-
The NN defines the priority of read because some library files need to
be initialized first. Everything else is skipped.
=func_note
This function can be used for automate library files and component specific
library files. It should be first called for automate library files where
priority 01 should contain the logging which allows for calling log_debug!
=cut
function read_library_files() {
    local dir="$1"  # (M) The library directory to read

    for i in `ls $dir/*.sh | sort -d`; do
        priority=`basename "$i" | $CMD_ogrep "^[0-9][0-9]-.*" | $CMD_ogrep '[0-9][0-9]'`
        if [ "$priority" == '' ] || [ "$priority" == '00' ]; then
            continue
        fi
        if [ "$priority" -gt "01" ]; then
            log_debug "Reading library file: $i"
        fi
        . $i        # Read it in.
        if [ "$?" != 0 ]; then
            if [ "$priority" -gt "01" ]; then
                log_exit "Failed reading library file: $i"
            else
                echo "Failed reading library file: $i"
                exit 5
            fi
        fi
    done
}

read_library_files "$libdir"    # Initialize our own library files


# All initial declare scripts, they will be picked-up at the proper place.
AUT_new_declares="$(find -L "$pkgdir" -name "$decl_script" -print)"

log_debug "Done reading all found library files"

#
# Find some hardware related log_info
#
HW_prd_name="$(get_systen_var $SVAR_product_name)"
HW_prd_name=${HW_prd_name:-Unknown}
HW_srv_type='Dedicated'             # Zoned could be added in the future for SunOS. 
HW_skip_raid_cfg=0          
# Catch the known/supported virtual types. Not all are tested!
if [ "$(echo "$HW_prd_name" | grep -i -e 'vmware' -e 'KVM' -e 'Oracle' -e 'OpenStack' -e 'docker' -e 'systemd-nspawn')" != '' ]; then
    HW_srv_type='Virtual'
    HW_skip_raid_cfg=1      # A virtual system can no do the raid config.
fi
readonly HW_prd_name
readonly HW_srv_type
readonly HW_skip_raid_cfg

log_info "Found OS: $OS, version: $OS_version, number: $OS_ver_numb"

# Update or current OS version (just to make it complete 
update_install_ent_field $IP_OS "$INS_col_cur_version" "$OS_version"

NCAT_start_listener $NCAT_log_idx "tail -f -n+0 $LOG_screen_cpy"

trap library_cleanup EXIT

function library_cleanup() {
    IFS=$def_IFS                # Back to normal in case it was interupted with strange IFS
    default_cmd_user
    stop_inprogress_ind
    NCAT_stop_listener $NCAT_log_idx
    NCAT_stop_listener $NCAT_ssh_idx
    NCAT_stop_listener $NCAT_fxf_idx
    NCAT_stop_listener $NCAT_syn_idx
    NCAT_stop_listener $NCAT_chk_idx

    # Cleanup the MAP directory,only if not instructed to keep.
    [ $FLG_keep_tmp == 0 ] && map_cleanup
}

#
# Enable automatic debugging of entry and exit messages. This sis done without
# introducing code in the file it self. So no extra work. It will only work for 
# the currently defined functions (so do this after the library is initialized)
# Some functions are excluded to prevent overflowing the output
# Yes there is slight bug in finding the name, name should not start with [0-9]
# This is only done when debug is enabled!
# 
if [ $FLG_dbg_enabled != 0 -a "$(get_substr 'entry' "$FLG_dbg_mod" ',')" != '' ]; then
    added_mod=''; sep=''
    dbg_excep='^(log_|map_|check_'      # Full prefixes
    dbg_excep+='|get_concat|get_field|get_lower|get_norm_ver|get_upper|get_which_ents_requires'
    dbg_excep+='|is_substr|get_substr'
    dbg_excep+='|select_line'
    dbg_excep+='|set_log_date'
    dbg_excep+=')'
    IFS=$nl; for func_name in $(declare -F | cut -d' ' -f 3 | $CMD_egrep -v "$dbg_excep"); do IFS=$def_IFS
        func="$(declare -f ${func_name} | tail -n +3)"
        pars="$(echo -n "$func" | $CMD_sed -r 's/^[ \t]*local[ \t]*([a-zA-Z_0-9]*)=["]{0,1}(\$[1-9])["]{0,1}.*/!\1!\2!/' | grep '^!')"
        body="log_debug \"Entry: $func_name("; sep=''
        IFS=$nl; for var_info in $pars; do IFS=$def_IFS
            body+="$sep$(get_field 2 "$var_info" '!')='$(get_field 3 "$var_info" '!')'"
            sep=', '
        IFS=$nl; done; IFS=$def_IFS
        body+=")\""

        eval "$(echo "${func_name}(){"; echo "${body}"; declare -f ${func_name} | tail -n +3)"
        added_mod+="$sep$func_name"; sep=', '
    IFS=$nl; done; IFS=$def_IFS    

    log_debug "Added automatic entry debug for: '$added_mod'"
fi

log_debug "Libraries initialized, installation path: $installdir"