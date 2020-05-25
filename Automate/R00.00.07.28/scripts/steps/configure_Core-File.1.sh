#!/bin/sh

: <<=cut
=script
This step configures the core file settings.
=version    $Id: configure_Core-File.1.sh,v 1.6 2017/12/14 13:59:23 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

set_default GEN_core_dir     '/var/TKLC/core'   # Future proof, overrule capability
set_default GEN_core_patern  'core.%e.%p'
set_default GEN_core_limit   'infinity'

log_info 'Configuring core dumps.'
text_remove_line $OS_etc/profile 'ulimit'
text_add_line $OS_etc/profile 'ulimit -S -c unlimited > /dev/null 2>&1'

cmd 'Creating core dir' $CMD_mkdir -m 777 "$GEN_core_dir"

local par

if [ "$OS_cnf_system" != '' ]; then
    log_info "Setting core limit to infinity '$OS_cnf_system' file."

    par='DefaultLimitCORE'
    text_remove_line $OS_cnf_system "$par"
    text_add_line $OS_cnf_system "$par=$GEN_core_limit"
fi

# a part 2 will coninue

return $STAT_passed
