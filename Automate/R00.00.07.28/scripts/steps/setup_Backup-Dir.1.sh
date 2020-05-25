#!/bin/sh

: <<=cut
=script
This step will create a new backup dir. The old will be renamed if needed.
Can be configured thorught he data-file:
[backup]
mount_points = ''
link_dir     = ''
dir          = ''
=brief Prepare: Create or mounts a backup dir. Rename old if one existing.
=version    $Id: setup_Backup-Dir.1.sh,v 1.8 2017/02/22 09:05:51 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local what="$1" # (M) what to do create or mount
local for="$2"  # (O) mount for 'add'

check_in_set "$what" 'create,mount'

check_set "$BCK_mount_points" "Please define [$sect_backup]mount_points="
check_set "$BCK_link_dir"     "Please define [$sect_backup]link_dir="
check_set "$BCK_dir"          "Please define [$sect_backup]dir="

STR_backup_mode="$what"      # Will be saved to permanent storage.

#
# Check link existence, if it is not a link then it is a problem
# Always remove linke and create a new one a proper device
#
if [ -e "$BCK_link_dir" ] && [ ! -L "$BCK_link_dir" ]; then
    log_exit "The backup link dir exists ($BCK_link_dir) but it is not a link"
fi
cmd 'Remove backup link' $CMD_rm "$BCK_link_dir"
BCK_sel_mntp=''

#=* Find a suitable mount point
#=- Search in $BCK_mount_points
#=- Select it, if the mount point exists and on a non-bootable device
#=# This assumption is currently made becuase the bootable disk will be whiped
#=skip_control
local nb_devs="$(echo "$OS_nb_devs" | tr ' ' '\n')"
local mnt
for mnt in $BCK_mount_points; do
    local fsys=$(get_filesys_for_mnt "$mnt")
    if [ "$fsys" != '' ]; then
        local nb_dev            # non bootable device do not contain partition so check the first part
        for nb_dev in $OS_nb_devs; do
            if [ "$(echo -n "$fsys" | grep "^$nb_dev")" != '' ]; then
                BCK_sel_mntp="$mnt"
                log_info "selected mount-point: '$BCK_sel_mntp' as backup place."
                break 2 # Break  main loop as well
            fi
        done
    fi
done

if [ "$BCK_sel_mntp" == '' ]; then  #= no mount point found
    log_exit "Did not find any suitable mount point for backup,${nl}tried: $BCK_mount_points"
fi
cmd 'Making generic backup link' $CMD_ln "$BCK_sel_mntp" "$BCK_link_dir"

if [ "$what" == 'mount' ]; then
    if [ ! -d "$BCK_dir" ]; then
        log_exit "No backup dir available in a re-mount request, something went wrong"
    fi
    [ "$for" == 'add' ] && STR_backup_mode='create'      #=! put mode back to create
    return $STAT_passed     # For mount we are finished
fi

#
# The main backup dir may exist and is not copied. However the node
# directory should not exists and is saved if it does. This
# approach allows several nodes to be written in the backup dir/server
#
if [ ! -d "$BCK_dir" ]; then
    cmd 'Create backup dir' $CMD_mkdir $BCK_dir
    cmd 'Allow all users'   $CMD_chmod 777 $BCK_dir
fi

local dir=$(get_bck_dir '' '' '' 'no_create')
#=* Existing backup dir '$dir' will be saved by adding '_<create timestamp>'
#=skip_control
if [ -d "$dir" ]; then
    local old_dir="${dir}_$(stat "$dir/." -c %z | sed 's/ /_/g' | cut -d'.' -f 1)"
    if [ -d "$old_dir" ]; then    # Still exist, failure
        log_exit "Cannot move old backup directory '$dir', please cleanup yourself"
    fi
    cmd 'Backup existing directory' $CMD_mv "$dir" "$old_dir"
fi
cmd "Create backup dir '$dir'" $CMD_mkdir "$dir"
cmd 'Allow all users'          $CMD_chmod 777 "$dir"


return $STAT_passed
