#!/bin/sh
: <<=cut
=script
Simply implements the service functions, But also allows for regular
component to be started in a service way.
=short_help
Execute given command:<par1> for service:<par2>. Depending on the service it
is done in difference ways:
- A TextPass component will use tp_start/stop --<tp_opt> (under current tp user)
- Any other service will use:
--- service <par2> <par1>                              (OS <= RH6.x)
--- systemctl <par1> <par2>.service                    (OS >= RH7.x)
- Theoretical it is possible services have specific start/stop steps.
=version    $Id: service.1.sh,v 1.9 2017/06/08 11:45:10 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local cmd="$1"  # (M) the command e.g. start/stop, see list (case) below
local svc="$2"  # (M) the service to act upon , bu may be a defined component as well

check_set "$svc" 'No service given to act upon, check command.'

#
# ! first we have to see if there are aliases. If so call all subs with the
# given service command.
#
find_install $svc 'opt'
if [ "$install_aliases" != '' ]; then   # found and aliases
    local aliases="$install_aliases"    # It might change
    local alias
    for alias in $aliases; do
        func $alias service $cmd
    done
    return 0    # Finished the main package does not have a service associated.
fi

find_component $svc
if [ "$comp_idx" != 0 ]; then
    if [ "$comp_tp_opt" != '' ]; then
        add_cmd_require 'perl' '' 'ret'     # Just some safety also handy during strange testing
        if [ $? != 0 ]; then
            log_warning "Perl is not installed (anymore), cannot execute tp_<cmd>"
            return 0
        fi

        set_cmd_user $MM_usr
        case "$1" in
            'start'|'restart')      # Start will do as sop first if needed
                cmd '' tp_start $comp_tp_opt
                ;;
            'stop')
                # It could be the system is not configure (yet) if a stop fails
                # with: ERROR: System is not configured to run <> process
                # then it is still assumed to be stopped
                set_cmd_user $MM_usr 'output' 'allow_failure'
                local out="$(cmd '' tp_stop  $comp_tp_opt)"
                if [ "$AUT_cmd_outcome" != '0' ] &&
                   [ "$(echo -n "$out" | grep 'System is not configured to run')" == '' ]; then
                        set_cmd_user $MM_usr 
                        cmd '' tp_stop  $comp_tp_opt        # Rerun agian but now most likely fail
                fi
                ;;
            'enable')  func $IP_OS set_autostart on  "$(get_lower "$svc")"; ;;
            'disable') func $IP_OS set_autostart off "$(get_lower "$svc")"; ;;
            *) 
                log_exit "Service <component> command $cmd not recognized, check command"
                ;;
        esac
        default_cmd_user
    fi
elif [ "$install_ent" != '' ]; then
    # Not a component but it is a package. We did not find a package specific
    # service either. But we don't want to fail the caller. so just return
    log_debug "Generic service $cmd for $svc but no specific file, ignoring."
else
    case "$cmd" in
        'start'|'restart'|'stop')
            if [ "$CMD_use_systemctl" == '1' ]; then
                cmd '' $CMD_systemctl $cmd "$svc.service"
            else
                cmd '' $CMD_service $svc $cmd
            fi
            ;;
        'enable')  func $IP_OS set_autostart on  "$svc"; ;;
        'disable') func $IP_OS set_autostart off "$svc"; ;;
        *) 
            log_exit "Service command $cmd not recognized, check command"
            ;;
    esac
fi

return 0