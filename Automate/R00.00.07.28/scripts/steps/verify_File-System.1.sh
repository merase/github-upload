#!/bin/sh

: <<=cut
=script
This verifies if the file system is correct before starting the upgrade.
To be correct the label names need to match the mount points, which is the 
default but it could be off.

It is also checked (using configure Partition step) if the actual labels
matches the expectations. As unknown will cause the recover to fail (as it
does not know what to do with it (how to mount).
=brief Validation: Make sure labels matches the mount points. Warn and fix if possible.
=version    $Id: verify_File-System.1.sh,v 1.4 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com

=cut

#=* Find all mounted ext3 file system skip the boot disk.
#=- See if their labels match the mount points.
#=- If not the label is changed/fixed and a warning given, example:
#=inc_indent
#=cmd "Changing disklabel to mount-point '$lab' -> '$mnt'" $CMD_e2label "$dev" "$mnt"
#=dec_indent
#=skip_control
local nb_devs="$(echo -n "$OS_nb_devs" | tr ' ' '\n')"
local line
IFS=$nl
for line in $(cat /proc/mounts | grep 'ext3' | tr -s ' ' | grep "$nb_devs" ); do
    IFS=$def_IFS
    local dev=$(get_field 1 "$line")
    local mnt=$(get_field 2 "$line")
    local lab=$($CMD_blkid "$dev" | tr ' ' '\n' | grep "^LABEL=" | cut -d'"' -f 2)
    if [ "$lab" == '' ]; then
        :  # Skip not formatted at all
    elif [ "${#mnt}" -gt 16 ]; then
        log_warning "Length mount-point $mnt for $dev > 16, skipping"
    elif [ "$mnt" != "$lab" ]; then
        # Changing the label is no harmfull so just do it
        cmd "Changing disklabel to mount-point '$lab' -> '$mnt'" $CMD_e2label "$dev" "$mnt"
        log_warning "Disk label ($lab) for $dev was not same as mount-point ($mnt), fixed!"
    fi
    IFS=$nl
done
IFS=$def_IFS

execute_step 0 'configure_Partitions upgrade check'

return $STAT_passed
