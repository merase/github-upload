#!/bin/sh

: <<=cut
=script
This step will backup the Operating System Configuration Files.
=version    $Id: backup_configuration.1.sh,v 1.13 2017/12/06 12:05:40 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# Some pre verification steps
if [ ! -e $OS_etc/hostid ]; then
    log_warning "No '$OS_etc/hostid' available which will result in license invalidation!"
fi

backup_base_dir '/'

backup_inf 'kernel parameter'
backup_add 'etc/profile'                # extra not in UM 
backup_add "${OS_cnf_sysctl:1}"         # extra not in UM

backup_inf 'NTP,Timezone'
backup_add 'etc/ntp.conf'
backup_add 'etc/ntp'                    # extra not in UM
backup_add 'etc/localtime'              # extra not in UM

backup_inf 'Status and Dynamic filesystem tables'
backup_add 'etc/fstab'
backup_add 'etc/mtab'

backup_inf 'Modprobe Configuration'
# backup_add 'etc/modprobe.conf'        # Not found, not in UM, needed?
backup_add 'etc/modprobe.d/*'

backup_inf 'Network Configuration'
backup_add 'etc/sysconfig/network'
backup_add 'etc/sysconfig/network-scripts'

backup_inf 'Crontab'
backup_add 'var/spool/cron'
backup_add 'etc/crontab'
backup_add 'etc/cron.hourly'
backup_add 'etc/cron.daily'
backup_add 'etc/cron.weekly'
backup_add 'etc/cron.monthly'

backup_inf 'Switch config'
# backup_add 'etc/minirc.*'             # Not found, not in UM, needed?
backup_add 'etc/security/limits.conf'   # extra not in UM

backup_inf 'Non-system user, group, password and shadow'
backup_add 'etc/passwd'
backup_add 'etc/group'
backup_add 'etc/shadow'

# Entries without default info
backup_inf ''
backup_add 'etc/host*'                  'Host table, shell setup'
backup_add 'etc/resolv.conf'            'DNS Resolver'
backup_add 'etc/ssh/ssh_host*'          'SSH Configuration'
backup_add 'etc/sudoers'                'Access Control'     'opt' # extra not in UM
backup_add "${OS_sys_syslog:1}"         'System log configuration'
# backup_add 'usr/local/apache/conf/*'    'Apache'                 # Not found, not in UM, needed?

# Entries for logrotate, not in UM requested by ps
backup_inf 'LogRotate'
backup_add 'etc/logrotate.conf'         'LogRotate Configuration' 'opt'
backup_add 'etc/logrotate.d/*'          'LogRotate Files'         'opt'

# Entries added to support better recovery see also BG23137
backup_inf 'UsefullFiles'
backup_add 'etc/init.d/*'

