#!/bin/sh

: <<=cut
=script
This step configures the core file settings.
=version    $Id: configure_Core-File.2.Linux.RH7_0-.sh,v 1.3 2017/12/15 07:12:01 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

log_info "Configure Core file for >= RH7.x"

local gzf='/usr/local/bin/gzip.sh'
if [ ! -e "$gzf" ]; then
    log_info "Creating gzip file ($gzf)to be use by core packing."
    cat << EOF > $gzf
#!/bin/bash
gzip > "\$1"
EOF
    cmd 'Change gzip file to executable' $CMD_chmod 755 $gzf
else
    log_info "gzip file ($gzf) already exist, not altering, content$nl$(cat $gzf)"
fi

log_info "Changing the '$OS_cnf_sysctl' file (>= RH7.x)."
par='kernel.core_pattern'
if [ "$(cat $OS_cnf_sysctl | grep $par)" == '' ]; then  # not configured yet
    text_add_line $OS_cnf_sysctl "# Configure core dump to be gzipped.$nl$par = |$gzf $GEN_core_dir/$GEN_core_patern.gz" "$par.*"
else
    text_substitute $OS_cnf_sysctl "$par.*" "$par = |$gzf $GEN_core_dir/$GEN_core_patern.gz"
fi

STR_rebooted=0      # New reboot advised

return $STAT_passed
