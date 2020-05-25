#!/bin/sh

: <<=cut
=script
This step verifies the port usage. Actually there is nothing to verify
it against so it only logs current usage.
=brief Verify: Actually stores the output of netstat -a into the logfile for reference
=version    $Id: verify_Port-Usage.1.sh,v 1.2 2015/07/15 11:07:17 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# Store information fro later reference, the manual does not subscribe what
# to verify it against. This might be added later.
cmd 'Show Port-Usage' netstat -a

return $STAT_passed
