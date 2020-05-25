#!/bin/sh

: <<=cut
=script
This step verifies the Network Time Protocol (NTP).
=brief Verify check if NPT runs and seem to have peers. Peers itself are not checked.
=version    $Id: verify_NTP.1.sh,v 1.3 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

if [ "$GEN_ntp_server" == '' ]; then
    log_info "Skip NTP verification, as [$sect_generic]ntp_server='' is not defined"
else
    #=cmd 'Check NPT status with' ntpq -p
    if [ `ntpq -p | wc -l` -lt 3 ]; then    #= not enough peers (< 3 lines )
        log_warning 'NTP does not seem to have peers'
    fi
    log_info 'NTP verification passed'
fi

return $STAT_passed
