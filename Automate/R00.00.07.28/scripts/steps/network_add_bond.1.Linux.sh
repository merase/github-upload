#!/bin/sh

: <<=cut
=script
This function adds a bonded interface to the system. Its original source
was taken from the lnxcfg, but has been adapted for the automate usage.
The VLAN tagging is optional.
=fail
In case of fialure, check the configuration and try to understand the error.
This script shows the commands to add bond, which should be similar to the old
lnxcfg, one could also try other wrapper tools like that to add the bond
as given by the parameters. If this is the OAM/main interface to use then
it is not advised to skipp this step until it is fixed.
=optx
The interfaces to add
=version    $Id: network_add_bond.1.Linux.sh,v 1.3 2017/10/27 12:22:50 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local bond="$1"     # (M) The bond name to ad, e.g. bond0 or bond0.1129 including VLAN tag
local ipaddr="$2"   # (M) The IP address to assign to this bond. currently IPv4 only
local netmask="$3"  # (M) The Network mask to use
shift 3             # Get the interfaces
local interfaces="$*"

# Some simple sanity checks
check_set "$bond"           'bond name not given'
vlan_id=$(get_field 2 "$bond" '_')  # Get vlan if any
bond=$(get_field    1 "$bond" '_')     # Always make sure single bond name
check_set "$ipaddr"         'ipaddr not given'
check_set "$netmask"        'netmask not given'
check_set "$interfaces"     'No interface given at all'

local b_ifcfg=$OS_nwconfig_path/ifcfg-$bond

local add_ip=''
if [ "$vlan_id" != '' ]; then   #= Bond is vlan tagged
    func netw_mod_vlan del $bond $vlan_id
else
    #=# Not vlan tagged, later IPADDR=$ipaddr and NETMASK=$netmask will be added
    add_ip="IPADDR=$ipaddr${nl}NETMASK=$netmask$nl"
fi

if [ -f $b_ifcfg ]; then
    log_warning "Bonded interface '$bond' already exists, will be removed first"
    cmd '' $CMD_ifdown $bond
    log_info "Old contents of '$b_ifcfg':$nl$(cat $b_ifcfg)"
    cmd '' $CMD_rm $b_ifcfg
fi

log_info "Configuring $bond ..."
echo "DEVICE=$bond
BOOTPROTO=none
ONBOOT=yes
$add_ip
USERCTRL=no
BONDING_OPTS=\"mode=active-backup miimon=100\"
TYPE=Bonding" > $b_ifcfg
                
local intf
for intf in $interfaces; do
    log_info "Configuring $intf"
    local ifcfg=$OS_nwconfig_path/ifcfg-$intf
    # Defining a MAC while bonding give conflicts (use netw_get_maccaddrin case needed), see also:
    # https://www.kernel.org/pub/linux/kernel/people/marcelo/linux-2.4/Documentation/networking/bonding.txt
    echo "DEVICE=$intf
ONBOOT=yes
BOOTPROTO=none
MASTER=$bond
SLAVE=yes
USERCTL=no
TYPE=Ethernet" > $ifcfg

done

if [ "$OS_cnf_modp_bonding" != '' ]; then   #! Use of bonding.conf requested
    # RHEL specific code, which is inline, would prefer a specific file but not always the best.
    if [ $OS_ver_numb -lt 60 ]; then    #= RHEL release older then RH6.0
        if [[ ! $($CMD_grep $bond $OS_cnf_modp_bonding) ]]; then    #= $bond not defined in $OS_cnf_modp_bonding
            echo -e "alias $bond bonding\noptions $bond mode=1 miimon=100" >> $OS_cnf_modp_bonding
        fi
    else
        cmd '' touch $OS_cnf_modp_bonding
        if [[ ! $($CMD_grep $bond $OS_cnf_modp_bonding) ]]; then    #= $bond not defined in $OS_cnf_modp_bonding
            echo "alias $bond bonding" >> $OS_cnf_modp_bonding
        fi
    fi
else
    log_info "Bonding config file not needed on this OS version, skipping."
fi

cmd "Configured $bond ..." $CMD_ifup $bond

func netw_vfy_intf $bond 'D'        # Should now exist


if [ "$vlan_id" != '' ]; then   #= Bond is vlan tagged
    func netw_mod_vlan add $bond $vlan_id "$ipaddr" "$netmask"
fi

return $STAT_passed
