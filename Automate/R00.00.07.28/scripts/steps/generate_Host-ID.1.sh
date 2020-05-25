#!/bin/sh

: <<=cut
=script
This step generates a hostid.
=script_note
Please be aware that pre-created licenses based on host-id will not work
if a host-id is (re)generated. Either used licenses based on system-serial
number or create them when they are verified. In principle force host-ids
can be useful for Virtualized machines which do not have a fixed/shared
system serial number.
=fail
Generate one yourself, see one of last command and skip step.
=version    $Id: generate_Host-ID.1.sh,v 1.4 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=set generated_hostid
The generated host id which can be used for reference.
=cut

generated_hostid=''

if [ -e $OS_etc/hostid ]; then
    log_warning "Host-ID already generated, skipping"
    return $STAT_passed
fi

# Generate or set to a specific value.
select_all_fld_data "$hw_node" "forced_hostid"
local host_id="$($CMD_ogrep '^[a-fA-F0-9]{8}$' <<< "$data_full")"   #= <forced_hostid>

if [ "$full_data" != '' -a "$host_id" == '' ]; then #= No correct Force hostid found
    log_warning "Invalid value for : [$hw_node]forced_hostid='$host_id'"
fi

if [ "$host_id" != '' ]; then    #= Force to an hostid 
    log_screen_info '' "Forcing hostid to requested '$host_id'"
    local a=${host_id:6:2}
    local b=${host_id:4:2}
    local c=${host_id:2:2}
    local d=${host_id:0:2}

    echo -ne \\x$a\\x$b\\x$c\\x$d > /$OS_etc/hostid                          #=!
    check_success "Force hostid to $host_id" "$?"       #= Created hostid
    generated_hostid=`hostid`

    #=* Check if current hostid is the same as the one just generated.
    #=- The current is retrieved using: [root]# hostid
    if [ "$(get_lower $generated_hostid)" != "$(get_lower $host_id)" ]; then  #= Failed to verify hostid
        log_warning "Forcing host_id was not successful. It is '$generated_hostid' iso '$host_id'"
    fi
fi

if [ "$generated_hostid" == '' ]; then    #= No host id yet
    cmd 'Generate a HostID' /sbin/genhostid
    generated_hostid=`hostid`
fi

return $STAT_passed
