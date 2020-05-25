#!/bin/sh

: <<=cut
=script
This step configures the Amount of files handles of the system. 
=version    $Id: configure_File-Handles.1.sh,v 1.3 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

set_default GEN_file_handles '20100'

if [ "$OS_cnf_limits" == '' ]; then     #= No limits-config file defined
    return $STAT_not_applic
fi


# This is not 100% correct but it will be able to replace other nof file handles
# lnxcfg (the source) is only capable of adding and could result in mulptiple
# entries.

log_info "Changing the '$(basename $OS_cnf_limits)' file."
local par='* - nofile'
if [ -f $OS_cnf_limits ] && [ "$(cat $OS_cnf_limits | grep "^\\$par")" == '' ]; then  # not configured yet
    text_add_line $OS_cnf_limits "# Set the number of file handles.$nl$par $GEN_file_handles" "^\\$par"
else
    text_substitute $OS_cnf_limits "^\\$par.*" "$par $GEN_file_handles"
fi

STR_rebooted=0      # New reboot advised

return $STAT_passed
