#!/bin/sh

: <<=cut
=script
This step re-configures the OS TimeZone settings after OS packages
update. glibc and glibc-common packages are overwriting the 
/etc/localtime file.
=version    $Id: reasure_local-time_setting.1.sh,v 1.3 2017/02/15 13:35:29 fkok Exp $
=author     sanjeev.krishan@newnet.com
=cut

local dst="$OS_etc/localtime"
if [ ! -L "$dst" ]; then

    # Execute the time-zone configuration step. This step will be executed if the soft link is not present
    log_info "Soft link for $dst was removed by glibc , re-creating the soft link again."
    check_mandatory_genvar GEN_os_tz

    local file="/usr/share/zoneinfo/$GEN_os_tz"
    if [ -e "$file" ]; then
        if [ -e "$dst" ]; then
            log_info "$dst already exists, so taking backup on same path"
            cmd 'Backup old localtime' $CMD_mv "$dst" "$dst.org"
        fi
        cmd "Set OS TZ to '$GEN_os_tz'" $CMD_ln $file $dst
    else
        log_warning "Did not find time zone file: $file, skipping set"
    fi

fi


return $STAT_passed
