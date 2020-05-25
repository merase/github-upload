#!/bin/sh

: <<=cut
=script
This script contains simple helper functions related to package versions functions.
The package versions will be collected and stored in a file (for later usage 
after a continue/restart). This fill will be written, accessed and maintaned by
this small library.
=version    $Id: 25-versions.sh,v 1.4 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

: <<=cut
=func_frm
This function will return the from (current) and the to (final) version to 
upgrade to. Unexpected setting will be logged and the proper status will be 
returned. In some case the log_exit can be used.
=le A log_exit will be used in case the versions file has not yet be created
=le A log_exit will be used in case seem to be downgrading (not supported at the moment)
=le STAT_warning and a warning will be given if either version is not found.
=le STAT_not_applic and an info will be given if the versions are the same
=func_note
It will either get its information from the upgrade plan or fallback to
the already stored information. The already stored information can
however be to new in case an OS install is doen (and therefor it can skip
specific steps.
=set pkg_full_from_ver
Will contain (if passed) the version (full textual) of the current package.
=set pkg_full_to_ver
Will contain (if passed) the version (full textual) of the final package
=set pkg_from_version
Will contain (if passed) the version (full numeric) of the current package.
=set pkg_to_version
Will contain (if passed) the version (full numeric) of the final package
=ret status
$STAT_passed if ok to continue, otherwise the error status.
=cut
function retrieve_versions() {
    local pkg="$1"  # (M) The package to retrieve information for.

    [ -z help ] && show_desc[0]="Retrieves the versions for '$pkg', if passed, then:"
    [ -z help ] && show_desc[1]="- <pkg_full_from_ver> : contains textual ver current pkg"
    [ -z help ] && show_desc[2]="- <pkg_full_to_ver>   : contains textual ver final pkg"
    [ -z help ] && show_desc[3]="- <pkg_from_ver>      : contains numeric ver current pkg"
    [ -z help ] && show_desc[4]="- <pkg_to_ver>        : contians numeric ver final pkg"
    [ -z help ] && show_desc[5]="This function requires a valid upgrade plan, current is:"
    [ -z help ] && show_desc[6]="- $STR_upg_plan_file"
    [ -z help ] && show_trans=0

    # Get default from the current data set first
    local from_ver=$(map_get "$map_cfg_ins/$pkg" "$INS_col_cur_version")
    local to_ver=$(  map_get "$map_cfg_ins/$pkg" "$INS_col_ins_version")
    if [ "$STR_upg_plan_file" != '' ] && [ -f "$STR_upg_plan_file" ]; then
        local line="$(grep " $pkg " "$STR_upg_plan_file")"
        if [ "$line" != '' ]; then      # Line set so expect both versions
            from_ver=$(get_field 4 "$line")
            to_ver=$(  get_field 5 "$line")
        fi
    fi

    pkg_full_from_ver="$from_ver"
    pkg_full_to_ver="$to_ver"
    pkg_from_version=$(get_norm_ver "$from_ver")
    pkg_to_version=$(  get_norm_ver "$to_ver")

    local status=$STAT_passed
    if [ "$pkg_from_version" == '' -o "$pkg_to_version" == '' ]; then
        pkg_from_version=${pkg_from_version:-not set}
        pkg_to_version=${pkg_to_version:-not set}
        log_warning "Do not know what to upgrade: $pkg | '$pkg_from_version' -> '$pkg_to_version'"
        status=$STAT_warning
    elif [ "$pkg_from_version" == "$pkg_to_version" ]; then
        log_info "$pkg : Same version ($pkg_from_version), no upgrade needed."
        status=$STAT_not_applic
    elif [ "$pkg_to_version" -lt "$pkg_from_version" ]; then
        log_exit "$pkg : Seem to be downgrading '$pkg_from_version' > '$pkg_to_version', not supported!"     
    fi

    return $status
}

