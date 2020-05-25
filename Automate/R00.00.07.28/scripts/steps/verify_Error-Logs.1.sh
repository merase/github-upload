#!/bin/sh

: <<=cut
=script
This step verifies the error logs. It currently does that in a very rudimentary
way. It looks at 'fail' or 'error' texts. The script will only create a warning 
so it will always continue.
=brief Verify: Generic check of message logs, could show up old not relevant errors as well.
=version    $Id: verify_Error-Logs.1.sh,v 1.4 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local show=20       # Amount of lines to show

if [ ! -r "$OS_messages" ]; then
    log_warning "Cannot open the '$OS_messages' file."
else
    #=# Use last 25000 lines to speed up in case of long existing files.
    local lines="$(tail -25000 "$OS_messages" | grep -i -e 'fail' -e 'error' )"
    if [ "$lines" != '' ]; then
        local cnt="$(echo -n "$lines" | wc -l)"
        log_warning "Found suspected lines, please investigate '$OS_messages' ($cnt/$show):$nl$(echo -n "$lines" | tail -$show)"
    fi
fi

return $STAT_passed
