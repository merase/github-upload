#!/bin/sh
: <<=cut
=script
This function sets the generic OS variables which are valid for all OS'es
=version    $Id: set_OS_vars.1.sh,v 1.21 2017/10/30 13:10:20 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly OS_usr='/usr'
readonly OS_tmp="$OS_usr/tmp"

readonly OS_etc='/etc'
readonly OS_local_etc="$OS_usr/local$OS_etc"
readonly OS_initd="$OS_etc/init.d"
readonly OS_logrotated="$OS_etc/logrotate.d"
readonly OS_hosts="$OS_etc/hosts"
readonly OS_profile="$OS_etc/profile.d"
readonly OS_rcd="$OS_etc/rc.d"
readonly OS_modprobe="$OS_etc/modprobe.d"
readonly OS_security="$OS_etc/security"
readonly OS_sysconfig="$OS_etc/sysconfig"
readonly OS_fstab="$OS_etc/fstab"
readonly OS_httpd="$OS_etc/httpd"
readonly OS_inittab="$OS_etc/inittab"
readonly OS_sysctld="$OS_etc/sysctl.d"
readonly OS_systemd="$OS_etc/systemd"

readonly OS_httpd_conf="$OS_httpd/conf"
readonly OS_httpd_confd="$OS_httpd/conf.d"


readonly OS_var='/var'
readonly OS_log="$OS_var/log"

readonly OS_spool="$OS_var/spool"
readonly OS_cron="$OS_spool/cron"
readonly OS_crontab="$OS_cron/root"

readonly OS_mnt='/mnt'

readonly OS_shm='/dev/shm'

readonly OS_adax='/usr/net/Adax'

readonly OS_cnf_logrotate="$OS_logrotated/syslog"
readonly OS_cnf_prelink="$OS_etc/prelink.conf"
readonly OS_cnf_network="$OS_sysconfig/network"
readonly OS_cnf_ntp="$OS_etc/ntp.conf"
readonly OS_cnf_limits="$OS_security/limits.conf"

readonly OS_ntp="$OS_etc/ntp"
readonly OS_ntp_step_tickers="$OS_ntp/step-tickers"

readonly OS_rc_profile="$OS_etc/profile"
readonly OS_rc_bash="$OS_etc/bashrc"
readonly OS_rc_startup="$OS_rcd/rc.local"

readonly OS_sys_umask='033'

readonly OS_NMM_rel_base='NMM-OS-release'
readonly OS_NMM_rel_file="$OS_local_etc/$OS_NMM_rel_base"

readonly OS_arch_x86_64='x86_64'
readonly OS_arch_i686='i686'
readonly OS_arch_noarch='noarch'

readonly OS_lib='/lib'
readonly OS_lib64='/lib64'

# Defaults can be overuled in different OS/versions
OS_cnf_modp_bonding="$OS_modprobe/bonding.conf"

# There are also OS specific OSvars  defined. See OS specific files for more details.
# E.g. OS_install_ext
