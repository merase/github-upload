#!/bin/sh

: <<=cut
=script
This is the generic backup script will will call additional backup_configuration
functions from the components given.
Theoretically the entity can overrule the full backup by having its own
<backup.1.sh> defined. But if <backup.2.sh> tgeb the backup_configuration will
be called first.
=brief Backup Configuration Files specific to the component.
=version    $Id: backup.1.sh,v 1.9 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local pkg="$1"      # (M) The short-name of a pakage to do backup for
local type="$2"     # (O) The type of prepare currently instance/zone/<empty>
local extra="$3"    # (O) Extra information (e.g. instance number or zone name)

check_in_set "$type" "$C_TYPE_SET"
set_MM_instance "$extra"        # Set proper user, etc.

#=# Only proceed if the $pkg is valid or if it is is 'needed' by others.
#=skip_until_marker
find_install "$pkg"
if [ "$install_idx" == '0' ]; then
    # Not defined so no backup not (not applicable)
    return $STAT_not_applic
fi

#
# Check if the component is actually requires, this safe checking in the called
# function and allows for proper status reported (nice not applicable)
# This is only need for none components (so the generic packages)
#
find_component "$pkg"           # See if it is an internal component
if [ "$comp_idx" == '0' ]; then # No so need to check if required
    local who=$(get_who_requires "$pkg" "$dd_components $dd_supporting")
    if [ "$who" == '' ]; then
        return $STAT_not_applic
    fi
fi
#=skip_until_here

#
# Prepare the backup
#
backup_init $BCK_type_tar "$pkg" "backup" '' "Backup for $pkg"

#
#=# Each entity can have it own 'backup_configuration' function.
#=# See if $pkg has one and execute additional backup.
# The backup is is cleaned if no func, no harm done.
func "$pkg" backup_configuration 
if [ $? == 0 ]; then
    backup_cleanup
    return $STAT_not_applic
fi

#
# Now do the actual backup, first do verify
#
backup_verify
backup_execute
backup_cleanup

return $STAT_passed

