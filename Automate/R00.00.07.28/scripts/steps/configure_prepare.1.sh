#!/bin/sh

: <<=cut
=script
This step configures the preparation of any components
=version    $Id: configure_prepare.1.sh,v 1.3 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local type="$1"     # (O) The type of prepare currently instance/zone/<empty>
local extra="$2"    # (O) Extra information (e.g. instance number or zone name)

check_in_set "$type" "$C_TYPE_SET"
    
#=* Currently nothing to do only for showing the user

return $STAT_passed
