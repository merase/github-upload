#!/bin/sh

: <<=cut
=script
This script will update all actions in the upgrade plan to the given value.
This is needed for example if the OS is overwritten. The overwrite will then
take care of the other entities being installed. However some parts will
still need to know the upgraded versions. Which will be kept in the original
plan.
=version    $Id: update_upg_plan.1.sh,v 1.2 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local act="$1"      # (M) The new action to set, not all values are allowed.

check_in_set "$act" "$upg_act_preinstall"

local plan_file=$STR_upg_plan_file
if [ "$plan_file" == '' ]; then
    return $STAT_not_applic
elif [ ! -r "$plan_file" ]; then
    log_exit "Upgrade plan '$plan_file' is not accessible."
elif [ ! -f "$plan_file.org" ]; then
    cmd '' $CMD_mv "$plan_file" "$plan_file.org"
    plan_file+='.org'
else
    log_info "Upgrade plan backup exists, skipping backup."
fi

#=* Update all actions, manually it could be done in the following way:
#=- Open the file '$STR_upg_plan_file'
#=- For all lines replace the first word with '$act'
#=- Save the file
#=skip_until_marker

local input=$(cat "$plan_file")
if [ $? != 0 -o "$line" == '' ]; then
    log_exit "Failed to read upgrade information from '$plan_file'"
fi
cmd '' $CMD_rm "$STR_upg_plan_file"     # Remove it, now use the real name form now on.

local line
IFS=''
while read line; do
    echo "$act $(echo "$line" | cut -d' ' -f 2-)" >> "$STR_upg_plan_file"
done <<< "$input"
IFS=$def_IFS
#=skip_until_here


return $STAT_passed
