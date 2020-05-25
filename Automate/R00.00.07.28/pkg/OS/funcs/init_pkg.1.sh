#!/bin/sh
: <<=cut
=script
Initializes the settings needed for this packages:
- Add (optional) package information
- Add (optional) component information
=version    $Id: init_pkg.1.sh,v 1.2 2015/06/30 09:15:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

add_pkg_info 'OS' $CFG_type_system $CFG_dir_root 'OS-Baseline' $CFG_install_skip


