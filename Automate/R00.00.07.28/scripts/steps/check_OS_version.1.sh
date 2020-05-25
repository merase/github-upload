#!/bin/sh

: <<=cut
=script
Checks if the version of the OS matches the given version. The definition
os the version is pretty free format. Andy matching the the current OS type has 
to match. E.g. Linux:from:5.0 and Linux:till:6.0 will match anything from 
5.0 (including) and up until 6.0 (excluding). Anything else like SunOs will
be ignore if current type is Linux.
=script_note
If no entries are given for a type then the version will be seen as 'notsup' 
and thus rejected. 'any' for an OS can be used but make sure you do not define 
other types for the same OS.
=fail
This script is for checking if the OS is supported/tested. If it fails then 
it most likely means the tool wants you to say the combination of 
hardware/software is NOT supported.
It is not wise to skip this step, unless a programming error is visible.
=version    $Id: check_OS_version.1.sh,v 1.2 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

#=skip_until_end

local cur_ver="$(get_norm_ver $OS_version)"
local found=0
local err=''
local correct=0
while [ "$1" != '' ]; do
    local os="$(get_field 1 "$1" ':')"
    local type="$(get_field 2 "$1" ':')"
    local ver="$(get_field 3 "$1" ':' | tr '.' '_')"

    check_in_set "$os"   "$OS_linux,$OS_solaris"
    check_in_set "$type" 'from,till,any,notsup'

    shift
    [ "$os" != "$OS" ] && continue      # Ignore not ours

    ((found++))
    local par_ver="$(get_norm_ver $ver)"
    case $type in
        from)   [ $cur_ver -lt $par_ver ] && err+="* Current $OS-$OS_version is too old (< $ver)"; ;;
        till)   [ $cur_ver -ge $par_ver ] && err+="* Current $OS-$OS_version is too recent (>= $ver)"; ;;
        any)    : ;; # Just accept as is. Make sure you have not other type.
        notsup) err+="* Current type '$OS' not supported at all"; ;;
        *) log_exit "Type was checked already, but is incomplete, programming error!"; ;;
    esac
done

[ $found == 0 ] && err+="* Current type '$OS' not supported at all"
if [ "$err" != '' ]; then
    STR_prevent_skip=1          # Prevent that users tries skip on this, there are still ways to skip but then it is intended molesting.
    store_current_state
    log_exit "The current step/file is ${COL_fail}not suitable$COL_def for this OS.
Selected file: '$STR_step_file'
Check which step file should be used and change it before retrying.
Check if the '$OS-$OS_version' matches expectations.
${COL_fail}Do not try to ${COL_bold}bypass/change$COL_def$COL_fail this step as outcome is not guaranteed at all.$COL_def
Reason(s) for rejection:
$err"
fi

unset STR_prevent_skip          # Make sure it is not set.
store_current_state
        
return $STAT_passed

