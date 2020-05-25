#!/bin/sh

: <<=cut
=script
This step configure the Time-Zone.
=version    $Id: configure_Time-Zone.1.sh,v 1.5 2017/06/08 11:45:11 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

if [ "$GEN_os_tz" != '' ]; then
    if [ -e $SH_tz ]; then
        log_info "Skip Time-Zone setup, '$SH_tz' already exists, not changing it."
    else
        # This assumes the file is none existing, no additional check just overwrite
        echo "export TZ=$GEN_os_tz" > $SH_tz
        cmd '' $CMD_chmod "+x" $SH_tz 
    fi
else
    log_info "Skip Time-Zone setup, as [$sect_generic]os_tz='' is not defined."
fi

return $STAT_passed
