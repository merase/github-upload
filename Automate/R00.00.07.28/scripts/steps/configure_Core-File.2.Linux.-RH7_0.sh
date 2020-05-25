#!/bin/sh

: <<=cut
=script
This step configures the core file settings.
=version    $Id: configure_Core-File.2.Linux.-RH7_0.sh,v 1.1 2017/12/14 13:59:23 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

log_info "Changing the '$OS_cnf_sysctl' file (< RH7.x)."
par='kernel.core_pattern'
if [ "$(cat $OS_cnf_sysctl | grep $par)" == '' ]; then  # not configured yet
    text_add_line $OS_cnf_sysctl "# Set the core dump directory.$nl$par = $GEN_core_dir/$GEN_core_patern" "$par.*"
else
    text_substitute $OS_cnf_sysctl "$par.*" "$par = $GEN_core_dir/$GEN_core_patern"
fi

STR_rebooted=0      # New reboot advised

return $STAT_passed
