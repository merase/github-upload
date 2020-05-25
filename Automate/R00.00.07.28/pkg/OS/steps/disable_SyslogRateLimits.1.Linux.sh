#!/bin/sh

: <<=cut
=script
This step disables the Rate Limits within the Syslog facility.
=version    $Id: disable_SyslogRateLimits.1.Linux.sh,v 1.2 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

log_info "Replacing $OS_cnf_syslog with one without rate limiting..."

if [ ! -e "$OS_cnf_syslog.orig" ]; then       # Keep copy if none yet
    cmd '' $CMD_mv "$OS_cnf_syslog" "$OS_cnf_syslog.orig"
fi
cmd '' "$CMD_cp $RCS_app_ins_dir$(basename OS_cnf_syslog)" "$OS_cnf_syslog"

func service restart $OS_svc_syslog

return $STAT_passed
