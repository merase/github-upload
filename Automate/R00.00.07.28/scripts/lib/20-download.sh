#!/bin/sh

: <<=cut
=script
This script contains functions related to file download.
=version    $Id: 20-download.sh,v 1.7 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com

=feat download from mounted folder
ISO downloads could be supplied through the mounted folder.

=feat download from HTTP server
ISO could be downloaded from a reachable HTTP server.

=feat wait on supplied file
If not ISO found then the file could be pushed onto the system at the
given location. This will be discovered and the the process will continue if 
possible.
=cut

: <<=cut
=func_int
Verifies if the download file is available. If not the manual request starts
or continues. This will be called by wait_until_passed.
=set WAIT_pass_request
Will be set to a sting if the file has not been found yet.
=cut
function verify_dowload_available() {
    local dir="$1"  # (M_ The directory where the download is expected
    local file="$2" # (M) The base file to check download availability for

    local src_file="$dir/$file"
    if [ -e $src_file ]; then  # It exist but is it complete (not growing anymore) ?
        local psize=0
        local size=$(stat -c%s $src_file)
        while [ "$psize" != "$size" ]; do
            sleep 2     # Ok we are screwed if it does not grow for x sec
            psize=$size
            size=$(stat -c%s $src_file)
        done    # After this the file should not grow anymore, so continue
        WAIT_pass_request=''    # Indicate finished
    else
        # Not found finished request a next pass
        WAIT_pass_request="The automatic retrieval of '$file' is not configured.
Please copy the '$file' to '$dir' 
on this host '$dd_host/$dd_oam_ip, e.g from OAM node:
# scp $file root@$dd_oam_ip:$src_file
Availability will be re-tried in a short while."
    fi
}

: <<=cut
=func_frm
Downloads a file.
=func_note
For now it copies it from another fixed location or using a download server.
=cut
function download_file() {
    local loc_path="$1"     # (M) local path of the destination.
    local file="$2"         # (M) The file to download.
    local check_sum="$3"    # (O) md5sum to check the downloaded file against

    local src_file="$tmp_download/$file"
    local dst_file="$loc_path/$file"

    # I currnetly  (safety parsing) cannot use the local variables in help, but can use the parameters!
    [ -z help ] && show_desc[0]="* Try to copy from $tmp_download/$file to $loc_path/$file" 
    [ -z help ] && show_desc[1]="* Whenever [ $tmp_download/$file not found ] and [ $STR_download_srv set ]"
    [ -z help ] && show_desc[2]="  * Fail if server type is not 'http'" 
    [ -z help ] && show_desc[3]="  * [root]# $CMD_http_get $STR_download_srv/$file -O $loc_path/$file" 
    [ -z help ] && show_desc[4]="* Whenever [ failed to download ] or [ not configured ]"
    [ -z help ] && show_desc[5]="  * Request to manually copy $file to $loc_path"
    [ -z help ] && [ "$check_sum" != '' ] && show_desc[6]="* MD5sum is verified against : $check_sum"
    [ -z help ] && show_trans=0
    
    #
    # First check if there is a already a copy available in the tmp_download directory
    # and not already as destination.
    #
    if [ ! -e $dst_file ] && [ -e $src_file ]; then
        cmd 'Copy from download dir' $CMD_cp $src_file $dst_file
    fi
    
    #
    # Next can we download via a server. Prepared support for multiple ways
    #
    if [ ! -e $dst_file -a "$STR_download_srv" != '' ]; then 
        local type=$(get_field 1 "$STR_download_srv" ':')
        case "$type" in
            http )
                cmd 'Download using http' "$CMD_http_get $STR_download_srv/$file -O $dst_file"
                ;;
            *) "Unsupported type '$type' of download server requested, verify [$sect_automate]download_srv."
        esac            
    fi

    #
    # Not found with an automatic way, start a manual action
    #
    if [ ! -e $dst_file ]; then
        wait_until_passed "$STR_dwnl_retry_time" "$STR_dwnl_max_retries" verify_dowload_available "$tmp_download" "$file"
        if [ $? != 0 ]; then
            # It should exits now so copy it to its current destination 
            cmd 'Copy from manual download dir' $CMD_cp $src_file $dst_file
        fi
    fi
    
    #
    # Do the md5 verification if configuration, still no file means failure
    #
    if [ -e $dst_file ]; then
        if [ "$check_sum" != "" ]; then
            calc_md5 "$dst_file"
            if [ "$check_sum" != "$md5_val" ]; then
                cmd 'Remove faulty file' $CMD_rm $dst_file
                log_exit "MD5 checksum of file '$file' did not match ($check_sum != $md5_val)"
            fi
        fi
    else
        log_exit "Could not download file '$file' from any source"
    fi
}
