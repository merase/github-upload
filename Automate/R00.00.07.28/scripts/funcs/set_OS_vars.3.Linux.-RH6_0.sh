#!/bin/sh
: <<=cut
=script
This function sets the generic OS variables for < RHEL6
=version    $Id: set_OS_vars.3.Linux.-RH6_0.sh,v 1.8 2017/10/30 13:10:20 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly OS_svc_syslog='syslog'

# Disk parameters
readonly OS_hd_type='cciss'
readonly OS_hd_dev="/dev/$OS_hd_type"
readonly OS_part_pfx='p'
readonly OS_all_hd_dev='c[01]d[0-9]'
readonly OS_all_hd_part="${OS_all_hd_dev}${OS_part_pfx}[0-9]+"
readonly OS_nb_hd_dev='c[01]d[1-9]'                            # non boot
readonly OS_nb_hd_part="${OS_nb_hd_dev}${OS_part_pfx}[0-9]+"
readonly OS_boot_hd_dev='c0d0'

# Make the list with all non-boot devices
OS_nb_devs=''
local slot
local disk
local dev
for slot in {0..1}; do
    for disk in {0..9}; do
        dev="c${slot}d$disk"
        if [ "$dev" == "$OS_boot_hd_dev" ]; then
            continue
        fi
        OS_nb_devs+="$OS_hd_dev/$dev "
    done
done
readonly OS_nb_devs

readonly OS_cd_devs='/dev/cdrom'

