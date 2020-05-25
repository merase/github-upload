#!/bin/sh

: <<=cut
=script
This analyzies the current max/device assignment compared to the pre upgrade
settup. Differences are fixed changing the udev definition. This is needed
becuase it was discovered that RH5.x had different assignement than RH6.x in
case mulitple cards where available (or better could change). This would
cause the ifcfg and route files but also cable labels to become invalid.
=script_note
It has been seen that upgrades with an OS (e.g. 5.7 to 6.5) changed
the order of the Ethernet devices. This is caused by a changed behavior
of the udev default (RH6.5 makes default for all, RH5.7 does not have
specific assignments). This could be solved by applying udev differently
however that would require another reboot (and an actual change in the
newest version). 
=version    $Id: analyze_and_fix_network_config.1.Linux.RH6_0-.sh,v 1.1 2015/11/11 10:03:06 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

#
# First get the current mapping which is stored in a mpa for easy acces
# then get the old mapping. The files are restored in a temporary dir to prevent
# overwriting data which is still needed. The route files if any might require
# changing as well.
#
local map_eth="NTW_eth"
map_init $map_eth


local rule_file="$OS_etc/udev/rules.d/70-persistent-net.rules"
if [ ! -e "$rule_file" ]; then
    log_warning "Did not find udev rules ($rule_file) to analyze, skipping"
    return 0    # Bailout
fi

local eth_dev='eth[0-9]+'
local mac_adr='[0-9a-fA-F:]{17}'
local all_inf="$(cat $rule_file | grep 'SUBSYSTEM' | cut -d ',' -f 4,7 | sed -e 's/.*address}=="//' -e 's/", NAME="/ /' -e 's/"$//')"
local all_mac="$(echo -n "$all_inf" | $CMD_ogrep "$mac_adr" | cut -d ' ' -f 1 | tr '\n' ' ')"
local all_eth="$(echo -n "$all_inf" | $CMD_ogrep "$eth_dev" | cut -d ' ' -f 2 | tr '\n' ' ')"

local dev
local i=1
for dev in $all_eth; do
    local mac="$(get_field $i "$all_mac")"; ((i++))
    mac="$(get_upper "$mac")"
    map_put "$map_eth/cur/$dev" DEVICE "$dev"       # eth reference table
    map_put "$map_eth/cur/$dev" HWADDR "$mac"
    map_put "$map_eth/mac/$mac" HWADDR "$mac"       # mac reference table
    map_put "$map_eth/mac/$mac" C_DEVICE "$dev"
done

# Now we have to look into the old ifcfg scirpt to find old macs (tmp_dir)
local ns_dir='/etc/sysconfig/network-scripts'
local tmp_dir='/tmp/netw_bck'
recover_files $IP_OS 'backup' "${ns_dir:1}/ifcfg-*" "$tmp_dir"

local cwd=$(pwd)
local file
local old_dev
local not_found=''
cmd '' $CMD_cd $tmp_dir$ns_dir/
for file in ifcfg-*; do
    [ ! -f $file ] && continue
    dev="$(echo -n "$file" | $CMD_ogrep "^ifcfg-$eth_dev" | $CMD_ogrep "$eth_dev")"
    if [ "$dev" != '' ]; then       # An eth file
        map_put "$map_eth/old/$dev" DEVICE "$dev"       # old reference table
        local mac="$(grep HWADDR $file | cut -d '=' -f2 | sed "$SED_del_preced_sp" | sed "$SED_del_trail_sp")"
        mac="$(get_upper "$mac")"
        if [ "$mac" != '' ]; then
            local old_mac="$(map_get "$map_eth/old/$dev" HWADDR)"
            if [ "$old_mac" != '' -a "$old_mac" != "$mac" ]; then  # If set then is should be same
                log_warning "Found double mac for '$file' ($old_mac & $mac)${nl}for same device '$dev' forcing the 1st found."
            else
                map_put "$map_eth/old/$dev" HWADDR   "$mac"
                map_put "$map_eth/mac/$mac" O_DEVICE "$dev"
            fi
        else
            log_info "Did not find a HWADDR in '$file', check later using old dmesg."
            not_found+="$dev "
        fi
    fi
done    

# Did we not find some (e.g. due to bonding), tyr to get them from old dmesg info
if [ "$not_found" != '' ]; then
    func OS define_vars     # Make sure defiend, main step is not part of OS (yet).
    if [ ! -e $OS_col_dmesg ]; then
        log_warning "Could not find old dmesg output to recover missed ethernet interfaces,
missing HWADDR for: $not_found, manual verification needed."
    else
        for dev in $not_found; do
            local mac="$(cat $OS_col_dmesg | $CMD_egrep "$eth_dev.*$mac_adr\$" | $CMD_grep "$dev:" | $CMD_ogrep "$mac_adr")"
            if [ "$mac" == '' ]; then
                log_warning "Did not find MAC belonging to $dev, manual verification needed."
            fi
            mac="$(get_upper "$mac")"
            map_put "$map_eth/old/$dev" HWADDR   "$mac"
            map_put "$map_eth/mac/$mac" O_DEVICE "$dev"
        done
    fi
fi

# Now see if changed or not by walking through old
local tfile="$tmp_dir/$(basename $rule_file)"
cmd '' $CMD_cp $rule_file $tfile        # Use tfile to prepare 
local fixed=0
for mac in $(map_keys "$map_eth/mac"); do
    local old_dev="$(map_get "$map_eth/mac/$mac" O_DEVICE)"
    local cur_dev="$(map_get "$map_eth/mac/$mac" C_DEVICE)"
    local cur_mac="$(map_get "$map_eth/mac/$mac" HWADDR)"

    if [ "$cur_mac" == '' ]; then
        log_warning "The MAC $mac is currently not defined, leaving it as is."
    elif [ "$old_dev" == '' ]; then
        log_warning "Did not find an old device for MAC $mac, leaving it as is."
    elif [ "$cur_dev" = '' ]; then
        log_warning "Did not find a new device for MAX $mac and $old_dev, leaving it as is."
    elif [ "$old_dev" != "$cur_dev" ]; then
        # Made is start-step to show what we are doing (not for time wise).
        start_step "Fixing $cur_dev->$old_dev to match MAC $mac"
        local line="$(cat $tfile | $CMD_grep 'SUBSYSTEM' | $CMD_ogrep -i "$mac.*" | $CMD_sed 's/\*/\\*/')"
        if [ "$line" == '' ]; then
            log_warning "Failed to locate MAC $mac for $old_dev in udev config, skipping."
            finish_step $STAT_warning
            continue
        fi
        local rep="$(echo -n "$line" | sed -r "s/$eth_dev/$old_dev/")"
        cmd_hybrid '' "$CMD_sed -i 's/$line/$rep/' $tfile" 
        ((fixed++))
        map_put "$map_eth/cur/mac" A_DEVICE $old_dev
        finish_step $STAT_passed
    fi
done

# Now restart udev in a proper way so that we don;t need a reboot. 
# we are stopping the nework service, but notrestarting is (done in caller step)
if [ $fixed != 0 ]; then
    start_step "Reconfigure udev to accept new changes"
    cmd '' service network stop
    [ ! -e $rule_file.bck ] && cmd '' $CMD_cp $rule_file $rule_file.bck  # Only one safety backup
    cmd '' $CMD_cp $tfile $rule_file
    cmd '' udevadm control --reload-rules
    cmd '' udevadm trigger --attr-match=subsystem=net
    finish_step $STAT_passed
else
    log_info "Network is correct, nothing to fix."
fi

return 0

