#!/bin/sh

: <<=cut
=script
If called with upgrade then it will verify if there or no ext2 filesystems
as they can not be upgrade from RH6 to RH7.
=version    $Id: verify_File-System.2.Linux.RH6_0-.sh,v 1.1 2017/09/05 09:46:51 fkok Exp $
=author     Frank.Kok@newnet.com

=cut

# Not an upgrade, no check
[ "$STR_run_type" != "$RT_upgrade" ] && return $STAT_not_applic

# No OS select do so cannto move to 7.x
[ "$STR_sel_os_iso" == '' ] || [ "$dd_os_iso_file" == '' ] && return $STAT_not_applic

# This is assuming as specific file verison format, but so be it!
[ "$(echo -n "$dd_os_iso_file" | $CMD_ogrep 'RHEL7\.')" != 'RHEL7.' ] && return $STAT_not_applic

local ext2="$(cat /proc/mounts | grep 'ext2' | tr -s ' ' )"
if [ "$ext2" != '' ]; then
    log_exit "Found file-system with type ext2, cannot continue upgrade to RH7.
Either unmount or fix it in case it is a disk required by our product.
List of wrong mount points:
$ext2"
fi

return $STAT_passed
