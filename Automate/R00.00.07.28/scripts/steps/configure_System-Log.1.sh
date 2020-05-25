#!/bin/sh

: <<=cut
=script
This step configure the System Logging facility.
=version    $Id: configure_System-Log.1.sh,v 1.5 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# change the syslog umask
SRC_FILE=/etc/sysconfig/rsyslog
TMP_FILE=/tmp/rsyslog.$$

set_default GEN_syslog_umask '033'
log_info "Changing the syslog umask to '$GEN_syslog_umask'."
if [ "$(cat $OS_sys_syslog | grep SYSLOG_UMASK)" == '' ]; then  #= SYSLOG_UMASK not yet configured
    text_add_line $OS_sys_syslog "#$nl# set this to a umask value to use for all log files as in umask(1).${nl}SYSLOG_UMASK=$GEN_syslog_umask" 'SYSLOG_UMASK'
else
    text_substitute $OS_sys_syslog 'SYSLOG_UMASK=.*' "SYSLOG_UMASK=$GEN_syslog_umask"
fi

log_info "Disable escape control characters."                                #=!
local par='EscapeControlCharactersOnReceive'
if [ "$(cat $OS_cnf_syslog | grep $par)" == '' ]; then  #= Disable escape control characters not yet configured
    text_add_line $OS_cnf_syslog "#$nl# Disable escape control characters (do not replace tab with #011).${nl}\$$par off" "$par"
else
    text_substitute $OS_cnf_syslog "\$$par .*" "\$$par off"
fi

log_info "Setting read access to log file(s) for other users."               #=!
cmd 'Setting read access to log file(s) for other users.' $CMD_chmod a+r $OS_messages*

log_info 'Make sure the message file is preceded by a -'
text_substitute $OS_cnf_syslog "[ \t]$OS_messages" "\t-$OS_messages"

func service restart $OS_svc_syslog  # if needed lets do it always removes an if!

return $STAT_passed
