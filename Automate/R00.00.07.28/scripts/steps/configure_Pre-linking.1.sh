#!/bin/sh

: <<=cut
=script
This step configures the Pre-linking of shared libraries. 
Soem OS versions do not have this by default anymore.
=version    $Id: configure_Pre-linking.1.sh,v 1.4 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

if [ "$OS_cnf_prelink" == '' ]; then    #= No prelink-config file defined
    return $STAT_not_applic
fi

# Make sure the following pre-link command is always available
text_add_line "$OS_cnf_prelink" '-l /usr/local/lib64'

return $STAT_passed
