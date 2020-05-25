#!/bin/sh
: <<=cut
=script
This function sets the generic CFG variables which should be used by the scripts.
They are not really related to the OS, but there can be some OS dependent changes.
Moved from 03-config_dynamic since the support of RHEL7 
=version    $Id: set_CFG_vars.1.Linux.RH7_0-.sh,v 1.4 2018/08/23 09:34:45 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly        CFG_pkg_dir="$OS_var/Packages" 
readonly     CFG_pkg_OS_dir="$CFG_pkg_dir/OS"                    
readonly     CFG_pkg_SW_dir="$CFG_pkg_dir/SW"                    
readonly CFG_pkg_OS_upg_dir="$CFG_pkg_dir/os_upgrade"            
readonly CFG_pkg_OS_sup_dir="$CFG_pkg_dir/support-packages"      # On OS-ISO

readonly   CFG_pkg_tmp_dir="$CFG_pkg_SW_dir"  # Old reference to SW

# Since NMM 17.0, which should be unrelated to RH75 (so left it at RH70). 
# the software paths changed (which is actually stupid and was not really needed to 
# create a single repo) so the 17.0 should only be used with retriev_ISO of a
# 17.0. This check is done within the retrieve_ISO function.
readonly        CFG_dir_root='/'
readonly  CFG_dir_opensource="$CFG_pkg_SW_dir"
readonly CFG_dir_mm_software="$CFG_pkg_SW_dir"
readonly     CFG_dir_drivers="$CFG_pkg_SW_dir"
readonly    CFG_dir_repodata="$CFG_pkg_SW_dir/repodata"    # Excluded from CFG_dirs
