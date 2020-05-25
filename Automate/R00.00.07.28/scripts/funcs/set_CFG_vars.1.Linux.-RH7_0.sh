#!/bin/sh
: <<=cut
=script
This function sets the generic CFG variables which should be used by the scripts.
They are not really related to the OS, but there can be some OS dependent changes.
Moved from 03-config_dynamic since the support of RHEL7 
=version    $Id: set_CFG_vars.1.Linux.-RH7_0.sh,v 1.3 2017/07/03 09:59:07 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly CFG_pkg_tmp_dir='/usr/tmp'  # This was the old described behavior

readonly        CFG_dir_root='/'
readonly  CFG_dir_opensource="$CFG_pkg_tmp_dir/opensource"
readonly CFG_dir_mm_software="$CFG_pkg_tmp_dir/textpass"
readonly     CFG_dir_drivers="$CFG_pkg_tmp_dir/drivers"
