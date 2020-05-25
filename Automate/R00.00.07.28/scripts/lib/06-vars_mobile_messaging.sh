#!/bin/sh
: <<=cut
=script
This script holds variables, related to Mobile Messaging. This include 
specific functions to get the proper instance variables
=version    $Id: 06-vars_mobile_messaging.sh,v 1.14 2018/08/02 08:10:05 fkok Exp $
=author     Frank.Kok@newnet.com

=fut_feat multi instance prepared
Support of smooth multi instance installation, but also adding a single instance
is in the planning.
=cut

MM_instance='~'    # Not possible name, to make sure it is always set the first time
    
: <<=cut
=func_frm
Set the MM variables. Which can change if a different instance number is given.
=set MM_*
Set many Mobile Messaging varibles
=cut
function set_MM_instance() {
    local instance="$1" # (O) The instance number [1-9],  [<empty>, 0, -, zone name(FFU)] is the main instance

    instance=${instance:-0}
    [ -z help ] && [ "$SHLP_cur_inst" != "$instance" ] && [ "$instance" != '0' ] && show_trans=0 && show_short="${COL_bold}Switching to instance $instance$COL_no_bold" && SHLP_cur_inst="$instance"
    [ -z help ] && [ "$SHLP_cur_inst" != "$instance" ] && [ "$instance" == '0' ] && show_ignore=0

    if [ "$MM_instance" == "$instance" -a "$MM_domains" == "$dd_oam_domains" ]; then
        return      # No need to set again
    fi
    
    MM_shared_dir='TextPass'        # Directory portion of shared directories
    if [ "$(echo "$instance" | grep '[1-9]')" != "$instance" ]; then
        MM_ins_postfix=''
        MM_usr='textpass'
        MM_svc="$MM_usr"
        MM_dir='TextPass'           # Used for identifying generic part of directories
        MM_instance='0'
        MM_ins_name='main'
        if [ "$dd_instanciated" != '0' ]; then
            MM_ins_extra=" instance $MM_instance"
            MM_hw_node="$hw_node#$MM_instance"
        else
            MM_ins_extra=''
            MM_hw_node="$hw_node"
        fi
        instance=0
    else
        # Note:  this reuires to be the same naming as tp_manage_user uses. 
        #        with that tool you cannot specifify the name.
        MM_ins_postfix="$(printf "%02d" "$instance")"
        local pfx='tpuser'
        MM_usr="$pfx$MM_ins_postfix"
        MM_svc="$pfx@$MM_ins_postfix"
        MM_dir="$MM_usr"            # Used for identifying generic part of directories
        MM_instance="$instance"
        MM_ins_name="ins#$MM_instance"
        MM_ins_extra=" instance $MM_instance"
        MM_hw_node="$hw_node#$MM_instance"

        local prev=$instance; ((prev--))
        [ $instance -eq 1 ] && MM_prev_usr='textpass' || MM_prev_usr="$(printf "$pfx%02d" "$prev")"
    fi
      MM_grp='textpass'             # All the same group
      MM_pwd='TextPass'
     MM_home="/usr/$MM_dir"
      MM_bin="/usr/$MM_shared_dir/bin"    # Same dir, binaries are shared!
      MM_ins="/opt/$MM_shared_dir"        # Same dir insatallation is shared!
      MM_etc="$MM_home/etc"
    MM_store="$MM_home/.store"
   MM_grp_id=$((200 + instance))
      MM_var="/var/$MM_dir"

             MM_cfg_ext='txt'
   MM_common_cfg_prefix='common_config'
     MM_common_cfg_file="$MM_common_cfg_prefix.$MM_cfg_ext"
          MM_common_cfg="$MM_etc/$MM_common_cfg_file"
       MM_common_cfg_wc="$MM_etc/${MM_common_cfg_prefix}_*.$MM_cfg_ext"   # Wilcard definition
       MM_host_cfg_file="hostname_config.$MM_cfg_ext"          # This is used for template names only
    MM_host_cfg_postfix="_config.$MM_cfg_ext"
            MM_host_cfg="$MM_etc/"`hostname`"$MM_host_cfg_postfix"   # also set in set_hostname

           MM_ssh_dir="$MM_home/.ssh"
            MM_id_rsa="$MM_ssh_dir/id_rsa"
        MM_id_rsa_pub="$MM_ssh_dir/id_rsa.pub"
       MM_known_hosts="$MM_ssh_dir/known_hosts"
    MM_auth_keys_file="$MM_ssh_dir/authorized_keys"

    # Make a list of all config files. An OAM has really multiple domains
    MM_domains="$dd_oam_domains"
    MM_all_common_cfg="$MM_common_cfg"
    if [ "$dd_is_oam" != '0' ]; then
        local dom
        for dom in $MM_domains; do
            [ "$dom" == 'main' ] && continue    # Skip this is the standard common config
            MM_all_common_cfg+=" $MM_etc/${MM_common_cfg_prefix}_$dom.$MM_cfg_ext"
        done
        MM_all_cfg="$MM_all_common_cfg $MM_host_cfg $MM_common_cfg_wc"
    else
        MM_all_cfg="$MM_common_cfg $MM_host_cfg"
    fi
}

: <<=cut
=func_frm
Retrieve the MM version base on the NMM-OS release file (or given name), 
which currently contains something like this:
NMMOS_RHEL7.3-16.0.0_160.03.0-x86_64
IMHO a wrong name, should be different from OS and only hold NMM info.
=remark
THis function could be changed if we ever see the light.
=stdout
The release (e.g. 16.0.0) or 0 in case not determined
=cut
function get_our_MM_release() {
    local name="$1" # (O) Use a given name rather then the file. The name should match the release string

    if [ "$name" == '' ]; then
        if [ -e "$OS_NMM_rel_file" ]; then
            name="$(cat $OS_NMM_rel_file)"
        else
            log_info "Did not find '$OS_NMM_rel_file; to determine release"
            name="0"
        fi
    fi

    get_field 1 "$(get_field 2 "$name" '-')" '_'
}

: <<=cut
=func_frm
Retrieve the MM version (normalized) based on the NMM-OS release file (or given 
name), which currently contains something like this:
NMMOS_RHEL7.3-16.0.0_160.03.0-x86_64
IMHO a wrong name, should be different from OS and only hold NMM info.
=remark
THis function could be changed if we ever see the light.
=stdout
The release or 0 in case not determined
=cut
function get_our_MM_release_norm() {
    local name="$1" # (O) Use a given name rather then the file. The name should match the release string

    local rel="$(get_our_MM_release "$name").0.0"
    local d1="$(get_field 1 "$rel", '.')"
    local d2="$(get_field 2 "$rel", '.')"
    local d3="$(get_field 3 "$rel", '.')"
    
    printf "%02d%02d%02d" "$d1" "$d2" "$d3"
}

set_MM_instance         # Make sure the default is set
