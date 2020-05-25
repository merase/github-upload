#!/bin/sh

: <<=cut
=script
This script checks if the current automate tool is running on a specific node.
If not then the automation run is stopped.
=script_note
The type of nodes to be checked can/will be extended in the future.
=fail
Do not skip this step unless there is a coding error. Failure should
be intended and continuation of steps are not meant for this type of node.
=version    $Id: run_only_on.1.sh,v 1.4 2017/02/22 09:05:51 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local comps="$1"    # (M) The components to be available (sep ,), use 'All' to always pass, or 'SubProvPlat for all related to SPP

check_set "$comps" 'Components to sync with are mandatory'

#=# Assume not passed, pass=0
local pass=0
case $comps in
    All|all)
        #=# All always passes, pass=1
        pass=1
        ;;
        
    SubProvPlat|subprovplat)
        # This negative logic is to be removed one official to be tested
        if [ "$STR_allow_subprovplat" == '' ] then #= SubProvPlatform not allowed
            log_exit "SubProvPlatform was made dormant, enable it on you own risk (if you know how :-)"
        fi
        is_substr "$hw_node" "$dd_prov_plat_nodes"
        [ $? == 1 ] && pass=1
        ;;

    *)
        local comp
        for comp in $(echo -n "$comps" | tr ',' ' '); do #= $comps
            is_substr "$comp" "$dd_components"
            if [ $? == 1 ]; then
                #=# Found component, pass=1
                pass=1
                break       # Need only one match
            fi
        done
        ;;
esac

if [ $pass == 0 ]; then #= not passed (pass == 0)
    STR_prevent_skip=1          # Prevent that users tries skip on this, there are still ways to skip but then it is intended molesting.
    store_current_state
    log_exit "This node '$hw_node' or its components do not belong to '$comps',
which means this step file '$STR_step_file'
${COL_fail}should not be executed on this node$COL_def. Please check intended use."
fi

return $STAT_passed

