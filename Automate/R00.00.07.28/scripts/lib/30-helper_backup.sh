#!/bin/sh

: <<=cut
=script
This script is capable of creating backups, by adding files upon request
This shields of how backup are created for (plain .tar, .tgz. remote) and shields
of any additional action like copying it to a backup server.

Backups start from base directory, it is not possible to add file form other
basedirectory. If needed make the base directory / which will allow any dir.
=version    $Id: 30-helper_backup.sh,v 1.19 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut


# Future planned backup types, see init for actually supported.
readonly BCK_type_tar='tar'
readonly BCK_type_tgz='tgz'
readonly BCK_type_remote='remote'
readonly BCK_types="$BCK_type_remote $BCK_type_tgz $BCK_type_tar" # in order of preference for recover

declare -a BACKUP_file     # Use to store requested file names 
declare -a BACKUP_info     # Use to store additional information
declare    BACKUP_f_idx=0
declare    BACLUP_i_idx=0

: <<=cut
=func_int
Check if an file is already added to the backup list.
=func_note
Associative array are easier, unfortunately BASH 4 is not avialble on the 
older system to be backed-up. 
=stdout
1 if already in the list, 0 otherwise.
=cut
function is_backup_file_added() {
    local file="$1"     # (M) the file to check
    
    local num=$BACKUP_f_idx
    local idx=0

    while [ "$idx" -lt "$num" ]; do
        if [ "${BACKUP_file[$idx]}" == "$file" ]; then
            return 1
        fi
        ((idx++))
    done
    return 0
}

: <<=cut
=func_frm
Get the backup dir for a specific component or unknown product.
This to get a uniform and simple interface. Which allows changes at 1 single 
point.
This will create the directory if needed, but only if the comp/post_name is supplied.
=stdout 
=cut
function get_bck_dir() {
    local comp="$1"          # (O) Component or other unique name to do extra defining on.
    local post_name="$2"     # (O) Free part of the post file name, if both empty then only the dir is returned
    local ver="$3"           # (O) A specific version to use, will also skip creation.
    local no_create="$4"     # (O) If set then create check is skipped

    if [ "$BCK_dir" == '' ]; then
        return      # No backup configured
    fi

    local dir="$BCK_dir/${dd_host}"
    local tmpl="$dir"
#    local file=$(get_concat "$comp" "$post_name" '_')
    local file="$post_name" # Currently never add comp name it is already in dirs!
    local skip_ver=0

    #
    # Future implementation: The 'MM' should somehow be related to the product
    # and the components where a product belongs. The whole reason this
    # structure was there is out of the existing manuals procedures. It might
    # as well have been flat (based on components which would have been easier.
    #
    STR_MM_cur_relnum=${STR_MM_cur_release:-$MM_cur_release}      # backwards compatibility
    if [ "$comp" != '' ]; then
        if [ "$comp" == "$IP_TextPass" ]; then
            dir="$dir/MM${STR_MM_cur_release}/$MM_usr"
            tmpl="$tmpl/MM*/$MM_usr"
#            file="$post_name"     # In these cases no component         
            skip_ver=1
        else
            find_component "$comp"
            if [ "$comp_idx" != 0 ]; then
                dir="$dir/MM${STR_MM_cur_release}/$MM_usr/$comp"
                tmpl="$tmpl/MM*/$MM_usr/$comp"
            else    # Use name as dir but change - into /
                dir="$dir/$(echo -n "$comp" | tr '-' '/')"
                tmpl="$dir"
#                file="$post_name"     # In these cases no component         
            fi
        fi
        
        # see if we can add the current version
        if [ $skip_ver == 0 ]; then
            if [ "$ver" != '' ]; then
                dir="$dir/$ver"
                tmpl="$tmpl/$ver"
            else
                find_install "$comp" 'optional'
                if [ "$install_cur_ver" != '' ]; then
                    dir="$dir/$install_cur_ver"
                else
                    dir="$dir/unknown"
                fi
                tmpl="$tmpl/*"
            fi
        fi
    fi
    
    # Best location for auto-check if directory exists. (only if file supplied)
    if [ -L "$BCK_link_dir" ] && [ "$file" != '' ]; then
        if [ -d "$dir" ]; then
            log_debug "Found directory '$dir' (mode-$STR_backup_mode, ver='$ver')"
        elif [ "$STR_backup_mode" == 'create' ] && [ "$no_create" == '' ]; then
            cmd "Create backup dir '$dir'" $CMD_mkdir "$dir"
            cmd 'Allow all users'          $CMD_chmod 777 "$dir"
        elif [ "$STR_backup_mode" == 'mount' -o "$ver" != '' ]; then    # recovery mode, find best match
            local ndir
            local tdir=''
            for ndir in $tmpl; do
                if [ ! -d "$ndir" ]; then continue; fi
                if [ "$tdir" != '' ]; then   # The backup should not create it but lets give an info. No warning inside stdout function
                    log_info "WARNING: Found more then 1 backup version to choose from (ver='$ver'). $ndir , chosen $tdir"
                else
                    tdir="$ndir"
                fi
            done
            [ "$tdir" != '' ] && dir="$tdir"
            [ "$dir" == '' ] && log_exit "Did not find the backup directory '$tmpl'. (ver='$ver')."
        fi
    fi

    echo -n $(get_concat "$dir" "$file" '/')
}

: <<=cut
=func_frm
Cleans the backup information. Should be called when backup finished or aborted.
=cut
function backup_cleanup() {
    [ -z help ] && show_ignore=1    # Not of interest of support.

    # Make sure current backup data is cleaned
    BACKUP_base_name=''
    unset BACKUP_file
    unset BACKUP_info
    BACKUP_f_idx=0
    BACKUP_i_idx=0
}

: <<=cut
=func_frm
Sets a base directory. Which is only possible until the first file is. Setting
it differently after the first file is adde will result is failure.
=cut
function backup_base_dir() {
    local base_dir="$1"     # (O) The base directory, default to '/'

    [ -z help ] && show_short="Backup base dir is: '$base_dir', (relative path for adding files, use e.g. cd)"
    [ -z help ] && show_trans=0

    new_base_dir=${base_dir:-/}
    if [ "$(echo "$new_base_dir" | grep '/$')" == '' ]; then
        new_base_dir="$new_base_dir/"
    fi
    if [ $BACKUP_f_idx != 0 ]; then
        if [ "$new_base_dir" != "$BACKUP_base_dir" ]; then
            log_exit "Change of basedir requested but already files stored ($new_base_dir != $BACKUP_base_dir)"
        fi
        # I could return here but let do the other checks as well
    fi
    if [ ! -d "$new_base_dir" ]; then
        log_exit "Backup base directory '$new_base_dir' does not exist"
    fi
    BACKUP_base_dir="$new_base_dir"
}

: <<=cut
=func_frm
Prepares a new backup file, set base name and base dir.
=func_note
If need make sure set_MM_instnce is already called.
=set BACKUP_base_name
The base name of the backup (no path no extension)
=set BACKUP_base_dir
The base direcotory of the backup location.
=set BACKUP_base_file
The full backup file name (including path and extension)
=set BACKUP_info
Optional backup information about the current backup.
=cut
function backup_init() {
    local type="$1"         # (M) The backup type, see BCK_type_*
    local comp_name="$2"    # (O) The component name
    local base_name="$3"    # (M) The base name
    local base_dir="$4"     # (O) The base directory, default to '/'
    local info="$5"         # (O) Optional backup information (for logging)
    
    [ -z help ] && show_handled_in_lib="Be aware of this!"
    
    check_in_set "$type" "$BCK_type_tar,$BCK_type_tgz"
    base_dir=${base_dir:-/}

    backup_cleanup          # Make sure main data is emtpy
    backup_base_dir "$base_dir"

    BACKUP_type="$type"
    BACKUP_base_name="$base_name"
    BACKUP_info[((BACKUP_i_idx++))]="$info"

    case $BACKUP_type in
        "$BCK_type_tgz" | "$BCK_type_tar" )
            BACKUP_base_file=$(get_bck_dir "$comp_name" "$base_name.$BACKUP_type")
            ;;
        *) log_exit "Backup type '$type' not implemented"
    esac
    backup_inf      # Start with empty group info
}


: <<=cut
=func_frm
Set additional group info (only for reference and keeping thing clear for other
users. It has no function effect at the moment.
=set BACKUP_grp_info
Optional information about the current group.
=cut
function backup_inf() {
    local grp_info="$1"     # (O) Optional additional group info (no :)

    [ -z help ] && show_trans=0 && show_short="Info for backup group: $grp_info"

    if [ "$(echo -n "$grp_info" | $CMD_ogrep ':')" != '' ]; then
        log_warning "Backup group info contains :, not permitted, clearing."
        grp_info=$(get_field 1 "$grp_info" ':')
    fi
    BACKUP_grp_info="$grp_info"
}

: <<=cut
=func_frm
Adds a file or files to the backup request. The file may or may not start with
the BACKUP_base_dir, it contains it then it is stripped of before adding
=cut
function backup_add() {
    local add="$1"  # (M) The file or files (use quoted * expression) to add all in a directory.
    local info="$2" # (O) Additional info overrule the group info (no :)
    local opt="$3"  # (O) If set then the file may be missing (no info given)

    [ -z help ] && show_trans=0 && show_short="Add backup file : '$add'$([ "$info" != '' ] && echo -n " ($info)")"

    check_set "$add" 'File should be given'
    if [ "$(echo -n "$add" | $CMD_ogrep "^$BACKUP_base_dir")"  == '' ]; then
        local full_file="$BACKUP_base_dir$add"
    else
        local full_file="$add"
    fi 

    # Find full wildcards
    local wildcard=0
    if [ "$(basename "$full_file")" == '*' ]; then wildcard=1; fi

    info=${info:-$BACKUP_grp_info}
    if [ "$(echo -n "$info" | $CMD_ogrep ':')" != '' ]; then
        log_warning "Backup file info contains :, not permitted, clearing."
        info=$(get_field 1 "$info" ':')
    fi

    if [ $wildcard == 0 ]; then
        # check readability of all the file (this will do file expansion
        local file
        for file in $full_file; do
            if [ ! -e "$file" ]; then
                if [ "$opt" != '' -o $wildcard != 0 ]; then
                    log_info "No backup file(s) found in/for '$file', skipping."
                else # Only log if no wilcard or ! optional
                    log_warning "Did not find backup file '$file', skipping."
                fi
                continue
            fi
            if [ ! -r "$file" ] || [ ! -e "$file" ]; then
                log_warning "Backup file '$file' can not be read, skipping."
                continue
            fi

            is_backup_file_added "$file"
            if [ $? == 0 ]; then
                BACKUP_file[((BACKUP_f_idx++))]="$file"
                BACKUP_info[((BACKUP_i_idx++))]="$info:$add:$full_file"
                log_debug "backup_add: $file -> $info:$add:$full_file"
            fi
        done
    else        # Let tar find it out, but check directory
        local full_dir="$(dirname "$full_file")"
        if [ ! -d "$full_dir" ]; then
            log_warning "Backup directory '$full_dir' can not be read, skipping."
            continue
        fi
        BACKUP_file[((BACKUP_f_idx++))]="$full_dir"
        BACKUP_info[((BACKUP_i_idx++))]="$info:$add:$full_dir"
        log_debug "backup_add(dir): $full_file -> $info:$add:$full_dir"
    fi  
}

: <<=cut
=func_frm
Check the backup and return the size in megabytes. Currently the size
is calculated in real size (as it is assumed to be packed withouth block
overhead). The result is ceiled to a MB boundary.
=cut
function backup_verify() {
    [ -z help ] && show_ignore=1    # This dos not add info at the moment, it is not complete

    local tot_size=0
    local size

    # Our backup list should only contain single files
    local num=$BACKUP_f_idx
    local idx=0
    while [ "$idx" -lt "$num" ]; do
        local file="${BACKUP_file[$idx]}"
        size=$(stat -c%s "$file")       # The directory itself uses space as well
        tot_size=$((tot_size + size))

        if [ -d "$file" ]; then         # It is a directory so get all sub files. Use du to do it recursively.
            size=$(du --bytes -s "$file" | tr '\t' ' ' | cut -d ' ' -f 1)
            tot_size=$((tot_size + size))
        fi

        ((idx++))
    done
    
    local mb_size=$((tot_size - 1 + MB / MB))
    log_debug "Size of backup: $mb_size MB"

    return $mb_size
}

: <<=cut
=func_frm
Executes the actual backup. This is either local to a file, directly remote
or a automatic remote server as well.
=cut
function backup_execute() {
    local none_warn="$1"    # (O) The warning to give if no files. Defaults to 'Backup requested but nothing to-do.'

    [ -z help ] && show_desc[0]="Execute the requested backup using e.g. tar/zip and added files. e.g.:"
    [ -z help ] && show_desc[1]="- cd <backup_base_dir>"
    [ -z help ] && show_desc[2]="- tar -cvf <base_file> --ignore-failed-read <files added>"
    [ -z help ] && show_trans=0

    check_set "$BACKUP_base_name" "Did not call backup_init?"

    none_warn=${none_warn:-'Backup requested but nothing to-do.'}
    if [ $BACKUP_f_idx == 0 ]; then
        log_warning "$none_warn"
        return
    fi

    IFS=$nl
    local info="${BACKUP_info[*]}"
    IFS=' '
    local files="${BACKUP_file[*]}"
    IFS=$def_IFS

    cmd '' $CMD_cd $BACKUP_base_dir
    case $BACKUP_type in
        "$BCK_type_tar" )
            cmd "$info" $CMD_mktar "$BACKUP_base_file" --ignore-failed-read "$files"
            ;;
        "$BCK_type_tgz" )
            cmd "$info" $CMD_mktgz "$BACKUP_base_file" --ignore-failed-read "$files"
            ;;
        *) log_exit "Execute backup called with unsupported type '$BACKUP_type'" ; ;;
    esac

    # Sending a copy to a remote server can be done using 
    # the 'secure_Backup-Dir' step.
}

