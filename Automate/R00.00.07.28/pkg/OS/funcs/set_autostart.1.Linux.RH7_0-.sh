#!/bin/sh
: <<=cut
=script
A script to allow auto start of an entity. This differentiates between 
Linux and Solaris. This is the Linux variant.
From RH7 the use of chkconfig changed into systemctl.
=version    $Id: set_autostart.1.Linux.RH7_0-.sh,v 1.3 2018/01/12 07:53:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local what="$1"     # (M) What to do add/del/on/off for the auto-start
local service="$2"  # (M) The service to changed (.service will be added)

check_set "$service" 'Need service'
service+=".service"

case $what in
    add )
        # In RHEL7 -> it goes via systemd and package installation.
        # It is assume the related package and thus systemd file is already
        # installed. So we can verify that in stead of adding it.
        local outp="$($CMD_systemctl list-unit-files "$service" | tr -s ' ' | grep "^$service")"
        [ "$outp" == '' ] && log_exit "$service should have been installed via package install."
        log_info "Verified if $service has been added via package uninstall."
        ;;
    del )
        # In RHEL7 -> it goes via systemd and package removal.
        # If done in the code then this is most likely before removing the 
        # package. So I cannot check if it is deleted yet.
        # Just report it being requested to be deleted.
        log_info "$service should/will be removed via package uninstall."
        ;;
    on  ) cmd '' $CMD_systemctl enable  "$service"; ;;
    off )
        # Since RHEL7 service changed. or should not be available
        # like chronyd which is removed. However there could be situations
        # where chronyd is still installed and thus disabled. A service which
        # is requested to be disabled and does not exist may not cause a failure
        local outp="$($CMD_systemctl list-unit-files "$service" | tr -s ' ' | grep "^$service")"
        if [ "$outp" == '' ]; then
            log_info "$service is not installed and thus already disabled."
        else
            cmd '' $CMD_systemctl disable "$service";
        fi
        ;;
    *) log_exit "Unimplemeted type '$what' requested"
esac

