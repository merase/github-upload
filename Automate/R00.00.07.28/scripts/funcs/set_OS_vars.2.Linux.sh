#!/bin/sh
: <<=cut
=script
This function sets the generic OS variables which are valid for all Linux versions
=version    $Id: set_OS_vars.2.Linux.sh,v 1.14 2017/10/30 13:10:20 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly OS_yum_repos="$OS_etc/yum.repos.d" # linux generic: yum by itself is not limited to RH7
readonly OS_yum_repomd='repodata/repomd.xml'         # The file holding main repo data, relative to baseurl

readonly OS_install_ext='rpm'               # used to identify package extension
readonly OS_sup_arch="$OS_arch_x86_64,$OS_arch_i686,$OS_arch_noarch"    # Ordered most likely 1st

readonly OS_messages="$OS_log/messages"
readonly OS_commands="$OS_log/commands.log"

readonly OS_nwconfig_path="$OS_sysconfig/network-scripts"

readonly OS_system_mem_MB=$(awk '/MemTotal/{print  int(($2+1023)/1024)}' /proc/meminfo)
readonly OS_system_mem_GB=$(((OS_system_mem_MB + 1023) / 1024))

readonly OS_physical_cpus=$(grep "^physical id" /proc/cpuinfo | sort -u | wc -l)
readonly OS_cpus_per_core=$(grep "^core id" /proc/cpuinfo | sort -u | wc -l)
readonly OS_total_cpus=$((OS_physical_cpus * OS_cpus_per_core))                     # Excluding hyper-threading
readonly OS_total_ht_cpus=$(grep -i "processor" /proc/cpuinfo | sort -u | wc -l)    # Including hyper-threading

readonly OS_kernel_inst='kernel'        # The main kernel packages require install
readonly OS_kernel_pkgs="$OS_kernel_inst kernel-devel kernel-firmware bfa-firmware dracut-kernel dracut"    # Packages requiring a kernel update (if changed).

# Make the list with all image device (the device mountable as image through ILO/USB)
OS_img_devs=''
local dev
for dev in {a..z}; do       # Make a full list of devices
    OS_img_devs+="/dev/sd$dev "
done
readonly OS_img_devs

# Will be set readonly later on (<script>.4.Linux.sh).
OS_fstab_options='defaults'
OS_fstab_dump='1'
OS_fstab_pass='2'
