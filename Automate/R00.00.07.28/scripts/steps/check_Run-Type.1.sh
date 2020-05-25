#!/bin/sh

: <<=cut
=script
Checks if the run_type as defined in [automate]run_type='' is configured as
expected. This because the run_type is important for some steps. It was not
decided to aut set this to prevent an unaware configuration error.
=version    $Id: check_Run-Type.1.sh,v 1.3 2017/09/08 07:42:51 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local run_type="$1" # (M) The run  type to verify

check_in_set "$run_type" "$RT_types"
if [ "$STR_run_type" != "$run_type" ]; then
    log_exit "The configured [automate]run_type='$STR_run_type' does not match required [$run_type]
Check data file or use different step file."
fi

# one additional check in case upgrade and source i RH6 and target RH7
# The baseline need to support at least the porper target release
# If not done that way then the backup routines will have incomplete data!
if [ "$STR_run_type" == "$RT_upgrade" ] && [ "$OS" == "$OS_linux" ] && [ $OS_ver_numb -ge 60 ] && [ "$(echo -n "$dd_os_iso_file" | $CMD_ogrep 'RHEL7\.')" == 'RHEL7.' ]; then
    check_min_version "$GEN_our_pkg_baseline" "R16.0.0.3" "This Upgrade from RHEL6.x to RHEL7.x requires target Baseline:$nl"
fi

return $STAT_passed
