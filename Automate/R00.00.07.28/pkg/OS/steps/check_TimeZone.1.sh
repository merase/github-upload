#!/bin/sh

: <<=cut
=script
Checks if the current timezoen matches the intended configured one 
[generic]os_tz=''. This is done using /etc/localtime link.
=version    $Id: check_TimeZone.1.sh,v 1.1 2017/09/06 11:40:28 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local cur_tz='unknown'
if [ -h /etc/localtime ]; then
  cur_tz="$(readlink /etc/localtime | sed "s/\/usr\/share\/zoneinfo\///")"
fi

if [ "$cur_tz" != "$GEN_os_tz" ] || [ "$GEN_os_tz" == '' ]; then
    log_exit "Your current timezone ($cur_tz) does not match configured [generic]os_tz='$GEN_os_tz'
or it is empty. Please fix data file before continuing the upgrade!"
fi

return $STAT_passed
