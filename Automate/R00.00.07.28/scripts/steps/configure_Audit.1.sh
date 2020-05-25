#!/bin/sh

: <<=cut
=script
This step configures the Audit logging facility.
=version    $Id: configure_Audit.1.sh,v 1.3 2015/05/21 10:54:31 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# This basially overules all defaults in bashrc
text_add_line $OS_rc_bash 'export PROMPT_COMMAND=''RETRN_VAL=$?;logger -p local6.debug "$(whoami) [$$]: $(history 1 | sed "s/^[ ]*[0-9]\+[ ]*//" ) [$RETRN_VAL]"'''

text_add_line $OS_cnf_syslog '# Log all user comands'
text_add_line $OS_cnf_syslog "local6.* $OS_commands"

# For now it realy assumes no messing with the defualt
text_add_line_after $OS_cnf_logrotate "$OS_commands" "/var/log/spooler"

return $STAT_passed
