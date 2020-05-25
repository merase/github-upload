#!/bin/sh

: <<=cut
=script
This step to execute tp_tools on several components.

=script_note
DISCLAIMER you can most likely break it with a wrong config. Don't do it is
expected to be created/correct. This makes the code so much easier!

=script_note
If all is given then all known installed components are executed one by one
If you want something like restart use tp_start (which does that. Or 2 steps
first stop then start.

=version    $Id: 15-helper_tp_tools.sh,v 1.9 2017/06/29 06:29:17 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

: <<=cut
=func_frm
=opt2 component
- multiple component name (not --tp_ams but AMS) separated by space
- all for all installed components
- <empty> for configured ones
=cut
SNMPD_cnf='/etc/snmp/snmpd.conf'
SNMPD_script='/etc/init.d/textpass_snmpd'

function tp() {
    local tool="$1"          # (M) The tp tool to execute. set=tp_set
    local component="$2"     # (M) The component or all for all   
    local pars="$3"          # (O) Parameter to be given to the tool
    local out_file="$4"      # (O) If this is defined then output is appended to given file
    local allow_failure="$5" # (O) If set then failures will be allowed    

    [ -z help ] &&   show_short="Execute: tp_$tool"
    [ -z help ] && [ "$component" != "all" -a "$component" != '' ] &&  show_short+=" for $component"
    [ -z help ] && [ "$pars" != '' ] && show_short+=", pars[$pars]"
    [ -z help ] && show_trans=0

    log_debug "tp: $tool <$component> '$pars' >> '$out_file' ($allow_failure)"

    add_cmd_require 'perl' '' 'ret'     # Just some safety also handy during strange testing
    if [ $? != 0 ]; then
        log_warning "Perl is not installed (anymore), cannot execute tp_<cmd>"
        return
    fi

    local tp_tool="$MM_bin/tp_$tool"
    [ ! -x $tp_tool ] && log_exit "Unknown tp_tool($tp_tool) given"

    local install="$component"
    [ "$install" ==  "all" ] && install=$dd_components

    local cur_usr=$AUT_cmd_usr
    set_cmd_user $MM_usr '' "$allow_failure"
    if [ "$install" == '' ]; then
        if [ "$out_file" == '' ]; then
            cmd '' $tp_tool $pars
        else
            cmd_hybrid '' "$tp_tool $pars >> $out_file"
        fi
    else
        for i in $install
        do
            find_component "$i"
            if [ "$comp_tp_opt" != "" ]; then
                if [ "$out_file" == '' ]; then
                    cmd '' $tp_tool $comp_tp_opt $pars
                else
                    cmd_hybrid '' "$tp_tool $comp_tp_opt $pars >> $out_file"
                fi
            fi
        done
    fi
    [ "$cur_usr" != '' ] && set_cmd_user $cur_usr || default_cmd_user
}

: <<=cut
=func_frm
Translates a given base SNMP port into a instantiated port number.

=func_note
This is in preparation of, the use of instance will currently cause a failure.
Parts of this might need reading from file, pre-created from gen_config.c
=stdout
=cut
function get_instance_port() {
    local base_port="$1"     # (O) The base port, not need for all type (e.g. cm_port)
    local base_type="$2"     # (M) The base type of the port (add type if needed)
    local instance_nr="$3"   # (M) The instance number use 0 as first instance
    local offs_port="$4"     # (O) The ofsset for to use for some instancinc types (snmp) instancing.

    # The main instance is handled differently then the instances
    # In this case (to make it it easy I calculate the needed ports based
    # on the actual contents of .textpass (or tp_manage_user). This because
    # that is on a remote site. This will work if standard config is used.
    # It was much cheaper and easier to implement. Can be enhanced in this
    # single function if needed. Only a limited number of port are needed at
    # this point.
    local port
    if [ "$instance_nr" == '0' ]; then
        case "$base_type" in
            cm_port)  port=9600      ; ;;
            eci_port) port=9500      ; ;;
            lgp_port) port=30003     ; ;;
            snmp)     port=$base_port; ;;  # Keep same base port
            *) log_exit "Unsupported base type($base_type), usage error?"; ;;
        esac
    else    # It is an instance
        [ "$INS_vars_defined" == '' ] && func $IP_TextPass define_instance_vars
        local base_port_name="$(printf "INS_base_port_%02d" "$instance_nr")"
        base_port="${!base_port_name}"
        case "$base_type" in
            cm_port)  port=$((base_port + 19)); ;;
            eci_port) port=$((base_port + 1)) ; ;;
            lgp_port) port=$((base_port + 34)) ; ;;
            snmp)     port=$((base_port + offs_port)); ;;
            *) log_exit "Unsupported base type($base_type#$instance_nr), usage error?"; ;;
        esac
    fi


    echo -n "$port"
}
