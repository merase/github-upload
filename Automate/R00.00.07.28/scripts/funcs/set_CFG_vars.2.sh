#!/bin/sh
: <<=cut
=script
This function sets the generic CFG variables which should be used by the scripts.
They are not really related to the OS, but there can be some OS dependent changes.
Moved from 03-config_dynamic since the support of RHEL7 
=script_note
The tmp_os_pkgs has not been moved as that is not reuired at this point and is
used more frequently.
=version    $Id: set_CFG_vars.2.sh,v 1.3 2017/09/11 10:47:27 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

#
# Put in for backward compatibility as older baseline might use the old names.
# Pleas use new names and hopefully the old can be removed some day.
#
readonly    tmp_drivers="$CFG_dir_drivers"
readonly tmp_opensource="$CFG_dir_opensource"
readonly   tmp_software="$CFG_dir_mm_software"

#
# Some external type defines to be used for adding packages
#
readonly      CFG_type_none='none'
readonly CFG_type_component='component'
readonly    CFG_type_helper='helper'
readonly   CFG_type_product='product'
readonly    CFG_type_system='system'        # A system package like an OS.
readonly     CFG_type_alias='alias'
readonly          CFG_types="$CFG_type_none,$CFG_type_component,$CFG_type_helper,$CFG_type_product,$CFG_type_system,$CFG_type_alias"

# CFG_dir_repodata excluded on purpose!
readonly            CFG_dirs="$CFG_dir_root,$CFG_dir_opensource,$CFG_dir_mm_software,$CFG_dir_drivers"

readonly  CFG_install_pkg='install'
readonly CFG_install_cond='conditionally'
readonly CFG_install_skip='skip'
readonly     CFG_installs="'',$CFG_install_pkg,$CFG_install_cond,$CFG_install_skip" # optional

# The option are not checked any can be added. However they should be added here fro referencing
readonly CFG_opt_run_for_backup='run_for_backup'       # Indicates that the backup requires the entity itself to run. Used during upgrade ordering.
readonly CFG_opt_check_yum_sup='check_for_yum_support' # Some might not have yum support. Or partial. If set then an additional function 
                                                       # check_yum_support is called. If function is not there then no support is assumed
readonly CFG_opt_skip_yum_install='skip_yum_install'   # If set then do not replace in install_package <supporting> as yum should take care of it
