#!/bin/sh

: <<=cut
=script
This script is capable of recovering backups. If need then the recover 
functionality will be smart enough to extract only once. However this is not
done by defult in cas eof bigger files (in other words to be added).
=version    $Id: 31-helper_recover.sh,v 1.10 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

: <<=cut
=func_frm
Recover files from a backup into a specific directory. The type of then backup 
is discovered automatically.
=ret
0 if successful recover, 1 if optional was allowed and not found.
=cut
function recover_files() {
    local comp_name="$1"    # (O) The component name, could include <name>:<ver>
    local base_name="$2"    # (M) The base name
    local files="$3"        # (M) The backup file(s) to recover, use '*' for wildcard
    local dst_dir="$4"      # (O) The destination directory to store the file(s) in., empty for local
    local new_usrgrp="$5"   # (O) New user:group of the file(s)
    local optional="$6"     # (O) If set then not found in (or no) archive is allowed.

    [ -z help ] && show_handled_in_lib="Be aware of this!"

    check_set "$files"   'No files given to recover'
    check_set "$dst_dir" 'No destination directory given to recover in'

    # Get version in case given
    local comp_ver="$(get_field 2 "$comp_name" ':')"
    comp_name="$(get_field 1 "$comp_name" ':')"

    # Find out which base type is preferred (remote, tgz, tar.
    local type
    local bck_file=''
    for type in $BCK_types; do
        if [ "$type" == "$BCK_type_remote" ]; then
            # TODO retrieve file from remote server, now only local
            continue
        fi
        bck_file=$(get_bck_dir "$comp_name" "$base_name.$type" "$comp_ver")
        if [ -f "$bck_file" ]; then
            break;
        fi
    done

    if [ "$bck_file" == '' ] || [ ! -f $bck_file ]; then
        if [ "$optional" == '' ]; then
            log_exit "Did not find backup file '$bck_file'"
        fi
        log_info "Did not find backup file '$bck_file', which is allowed."
        return 1
    fi

    set_allow_failure "$optional"       # Allow failure if optional
    dst_dir=${dst_dir:-$(pwd)}
    local info="Recover '$files' from $bck_file into $dst_dir"
    case $type in
        "$BCK_type_tar" )
            cmd_hybrid "$info" "$CMD_untar $bck_file -C $dst_dir \"$files\""
            ;;
        "$BCK_type_tgz" )
            cmd_hybrid "$info" "$CMD_untgz $bck_file -C $dst_dir \"$files\"" 
            ;;
        *) log_exit "Recovered files called with unsupported type '$type'"; ;;
    esac
    set_allow_failure

    if [ "$optional" != '' -a  $AUT_cmd_outcome != 0 ]; then
        if [ "$(grep -i 'Not found in archive'  "$LOG_cmds")" != '' ]; then 
            # Seems to be not fund, accept this
            return 1
        fi
        log_exit "Failed to extract '$files', extra info:$nl$(cat $LOG_cmds)"
    fi

    if [ "$new_usrgrp" != '' ]; then
        if [ "$(basename "$dst_dir/$files")" == '*' ]; then # Wildcard do whole dire recursively
            local dir="$(dirname "$dst_dir/$files")"
            if [ "$dir" == '/' ]; then
                log_exit "Requested to change grp/own on '/', this cannot be good!"
            fi
            cmd '' $CMD_chown "$new_usrgrp" "$dir"
        else
            cmd '' $CMD_chown "$new_usrgrp" "$dst_dir/$files"
        fi
    fi

    return 0
}

