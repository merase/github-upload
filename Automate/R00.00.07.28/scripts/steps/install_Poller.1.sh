#!/bin/sh
: <<=cut
=script
Check if a (STV) Poller is needed on this node.
=script_note
It only does somehting if installed on a node without STV and if required.
If the STV is already installed then this step has already been executed. It
will be there for human interest.
=version    $Id: install_Poller.1.sh,v 1.5 2015/07/24 10:01:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

is_poller_needed
if [ $? == 0 ]
    return $STAT_not_applic         # not needed, show it
fi

find_install "$C_STV"
if [ "$install_cur_ver" != '' ]; then
    # it is already installed, so pass it
    return $STAT_passed
fi

# If we come here we have to install the STV, including poller, just execute step
execute_step 0 "install_package $C_STV"
    
return $STAT_passed