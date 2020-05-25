#!/bin/sh

: <<=cut
=script
This script contains simple helper functions related to verify functions.
=version    $Id: 20-verify.sh,v 1.2 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

: <<=cut
=func_frm
Differences two files. Fails if any difference is found
=cut
function verify_config_items() {
    local info="$1"     # (O) Additional info on the step itself.
    local new_file="$2" # (M) The new file the diff.
    local exp_file="$3" # (M) The expected file according to the installation file 
    
    difference=`diff $new_file $exp_file`
    res="$?"
    if [ $res != 0 ]; then
        echo "Problems found while verifying: '$info'"
        echo "Please verify the problem below:"
        echo "$difference"
        # TODO make exceptions?
        # TODO make more pleasant outcome
    fi
    check_success "Verify Config items: '$file'" "$res"
}
