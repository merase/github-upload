#!/bin/sh

: <<=cut
=script
This step check if the core file setting is correct. In this case if it
is set using gzip. If not gizpped then it will be reconfigured like a standard
installation.
=version    $Id: reasure_Core-File.1.sh,v 1.1 2017/12/14 13:59:23 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

log_info "Reassuring if core file is zipped."

local par='kernel.core_pattern'
if [ "$(cat $OS_cnf_sysctl | grep $par | grep gzip)" != '' ]; then
    return $STAT_skipped    # nothing needed 
elif [ "$(cat $OS_cnf_sysctl | grep $par)" == '' ]; then  
    # not configured yet, which is unexpected
    log_warning "Core files did not seem configured at all, doing it now!"
else
    log_info "Updating core file setting to latest standard."
fi

execute_step 0 'configure_Core-File'

return $STAT_passed
