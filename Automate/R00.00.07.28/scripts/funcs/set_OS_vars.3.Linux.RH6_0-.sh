#!/bin/sh
: <<=cut
=script
This function sets the generic OS variables for >= RHEL6
=version    $Id: set_OS_vars.3.Linux.RH6_0-.sh,v 1.9 2017/10/30 13:10:20 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly OS_svc_syslog='rsyslog'

# Disk parameters
readonly OS_hd_type=''
readonly OS_hd_dev='/dev'
readonly OS_part_pfx=''
readonly OS_all_hd_dev='sd[a-z]'
readonly OS_all_hd_part="${OS_all_hd_dev}[0-9]+"
readonly OS_nb_hd_dev='sd[b-z]'                     # non boot
readonly OS_nb_hd_part="${OS_nb_hd_dev}[0-9]+"
readonly OS_boot_hd_dev='sda'

# Make the list with all non-boot devices
OS_nb_devs=''
local dev
local dev
for dev in {a..z}; do       # Make a full list of devices
    if [ "sd$dev" == "$OS_boot_hd_dev" ]; then
        continue
    fi
    OS_nb_devs+="/dev/sd$dev "
done
readonly OS_nb_devs

readonly OS_cd_devs='/dev/sr0 /dev/sr1'

# These parameter changed from RHEL6 and onwards to get a better preformance.
# I do not fully understand the pass change from 2->0 which means no fsck is
# preformend upon system boot (not impacting runtime performance).
# Will be set readonly later on (<script>.4.Linux.sh).
OS_fstab_options='barrier=0,noatime'
OS_fstab_dump='0'
OS_fstab_pass='0'

