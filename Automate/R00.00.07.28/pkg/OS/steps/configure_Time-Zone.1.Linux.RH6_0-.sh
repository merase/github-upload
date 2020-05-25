#!/bin/sh

: <<=cut
=script
This step configure the OS TimeZone settings.
=version    $Id: configure_Time-Zone.1.Linux.RH6_0-.sh,v 1.2 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut


check_mandatory_genvar GEN_os_tz

local file="/usr/share/zoneinfo/$GEN_os_tz"
local dst="$OS_etc/localtime"
if [ -e "$file" ]; then
    if [ -e "$dst" ]; then
        cmd 'Backup old localtime' $CMD_mv "$dst" "$dst.org"
    fi
    cmd "Set OS TZ to '$GEN_os_tz'" $CMD_ln $file $dst
else
    log_warning "Did not find time zone file: $file, skipping set"
fi
