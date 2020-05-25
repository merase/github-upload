#!/bin/sh

: <<=cut
=script
This step verifies the basic components installation. Use sub-step [2..9]
if specific verification is needed. What it does:
=le Look-up the component
=le If managed by tp start then check if at least 2 main processes.
=brief Verify: Check if given component is running (if it is managed by tp tools).
=version    $Id: verify.1.sh,v 1.5 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local comp="$1"  # (M) The component to do verification for

find_component "$comp"
if [ "$comp_idx" == '0' ]; then     #= $comp not found
    # Not defined so not needed allow specific verify to do work
    return $STAT_passed
fi
if [ "$comp_tp_opt" == '' ]; then   #= $comp not managed by tp tools
    # No tp_start option so now process name known as well.
    return $STAT_passed
fi

# The process happens to be the tp_opt. The qcli deamon is an exception
# however qcli is not ac component by itself (and will therefor not be called.
# Always need 2 process wd + process
local proc=${comp_tp_opt:2}
check_running  "$comp" 2 "$proc"

return $STAT_passed


