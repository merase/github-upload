#!/bin/sh

: <<=cut
=script
This step configures the RHEL Subscription to prevent the message in the syslog
=version    $Id: configure_Subscription.1.Linux.sh,v 1.2 2015/10/08 12:00:39 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local what="$1" # (M) What to do disable or enable

check_in_set "$what" 'disable,enable'

#
# The rhsmd file is not relay know (though propably daily). Lets just
# find all potential locations (future proof).
#
local file
for file in $(find /etc/cron* -name 'rhsmd' -print); do
    text_change_comment "$what" '/usr/libexec/rhsmd' "$file"
done

return $STAT_passed
