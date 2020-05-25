#!/bin/sh

: <<=cut
=script
This step will recover the Operating System Configuration Files.
=brief Recovers a specific group (see step) of files of the OS. 
=version    $Id: recover.1.sh,v 1.18 2017/12/06 12:05:40 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local what="$1" # (O) What to recover. Empty will default to Others

: <<=cut
=func_int
Add or replace a lines matching on the first column
=cut
function replace_or_add_lines() {
    local dst="$1"      # (M) The destination file
    local lines="$2"    # (O) The lines the replace or add. first column separates by :

    IFS=''
    local line
    while read line; do
        IFS=$def_IFS
        local key="^$(get_field 1 "$line" ':'):.*\$" 
        text_replace_or_add_line "$dst" "$line" "$key"
        IFS=''
    done <<< "$lines"
    IFS=$def_IFS
}

: <<=cut
=func_int
Will restore the group and password files. This is done by taking the
migrated data and overwriting or add the new lines.
=cut
function restore_group_and_passwd_file() {
    [ -z help ] && show_desc[0]="Restore the group and password files, by migrating them".
    [ -z help ] && show_desc[1]="If failing then migrate users [200, 500/1000..65534] from previous backup."
    [ -z help ] && show_desc[2]="The files changed are: [/etc/passwd /etc/group /etc/shadow]"

    local awk_inf
    if [ "$OS" != "$OS_linux" ] || [ $OS_ver_numb -ge 70 ]; then
        awk_inf='(($3==200) || ($3>=1000) && ($3<65534))'
    else
        awk_inf='(($3==200) || ($3>=500) && ($3<65534))'
    fi

    local type
    for type in passwd group shadow; do
        recover_files $IP_OS 'backup' "etc/$type" /tmp

        # Get data which should be migrated 2 versions
        if [ "$type" == 'shadow' ]; then
            local mig="$(exec_through_file "Migrate $type" "$CMD_awk -F: '$awk_inf {print \$1}' /tmp/etc/passwd | tee - | egrep -f - /tmp/etc/$type" output)"
        else
            local mig="$(exec_through_file "Migrate $type" "$CMD_awk -F: '$awk_inf' /tmp/etc/$type" output)"
        fi
    
        replace_or_add_lines "/etc/$type" "$mig"
        cmd '' $CMD_rm "/tmp/etc/$type"
    done
}

local ret=$STAT_passed
case "$what" in
    'Cron-Tabs')
        if [ "$STR_cron_tabs_recovered" == '0' ]; then  #= not yet recovered
            recover_files $IP_OS 'backup' etc/crontab      /
            recover_files $IP_OS 'backup' etc/cron.hourly  /
            recover_files $IP_OS 'backup' etc/cron.daily   /
            recover_files $IP_OS 'backup' etc/cron.weekly  /
            recover_files $IP_OS 'backup' etc/cron.monthly /
            recover_files $IP_OS 'backup' var/spool/cron   /
            # Not the best place but it is need right after recovery. The STV screws up a normal place, make it possibe to overrule if ever needed.
            local svc=${STR_svc_rhsmd:-disable}
            execute_step 0 "configure_Subscription $svc"
            STR_cron_tabs_recovered=1
        else
            return $STAT_done
        fi
        ;;
    'DNS-Files')
        recover_files $IP_OS 'backup' etc/resolv.conf  /
        ;;
    'Host-Files')
        recover_files $IP_OS 'backup' etc/hostid / '' 'optional'        # Some systems do not had an hostid and would fail on it.
        recover_files $IP_OS 'backup' etc/hosts  /
        ;;
    'NTP-Files')
        recover_files $IP_OS 'backup' 'etc/ntp.conf'   /
        recover_files $IP_OS 'backup' 'etc/ntp'        /
        func $IP_OS set_autostart on ntpd                               # Make sure started after reboot.
        func service restart ntpd
        ;;
    'SSH-Files')
        recover_files $IP_OS 'backup' 'etc/ssh/ssh_host*' /
        # Properties change on RHEL7
        if [ "$OS" == "$OS_linux" ] && [ $OS_ver_numb -ge 70 ]; then
            cmd '' $CMD_chmod 0640 /etc/ssh/*_key
            cmd '' $CMD_chown root:ssh_keys /etc/ssh/*_key
        fi
        ;;
    ''|'Others')
        log_warning 'Strangely enough nothing seem to be needed.'
        ;;
    'GrpAndPwd-Files')
        restore_group_and_passwd_file
        ;;
    'LogRotate-Files')
        recover_files $IP_OS 'backup' 'etc/logrotate.conf'   /
        # The logratate.d is not recovered upon request (nor in manual)
        ;;
    'SysCtl-Files')
        # For an upgrade to RH7 (from RH6) recover the old, verify for the link
        # Please note that I copy and do no add as suggested in the manual.
        if [ "$RT_type" == "$RT_upgrade" ] && [ "$OS" == "$OS_linux" ] && [ $OS_ver_numb -ge 70 ]; then  
            recover_files $IP_OS 'backup' 'etc/sysctl.conf'   /
            if [ "$(ls -l "$OS_cnf_sysctl" 2> /dev/null | grep '\.\./sysctl.conf')" == '' ]; then
                log_warning "The link from $OS_cnf_sysctl to '../sysctl.conf' is incorrect, please fix and investigate."
            fi
            cmd 'Make new system pars effective' $CMD_sysctl -p $OS_cnf_sysctl
        else
            log_info "Recovery of sysctl not applicable for '$RT_type; or '$OS:$OS_ver_numb'"
            ret=$STAT_not_applic
        fi
        ;;
    'IpTables-Files')
        local svc
        local var
        for svc in iptables ip6tables; do
            var="OS_col_$svc"
            if [ -f "${!var}" ]; then
                cmd "Restore $OS_sysconfig/$svc" $CMD_cp "${!var}" "$OS_sysconfig/$svc"
                func service enable $svc
                func service start  $svc
            fi
        done
        ;;
    *)  log_exit "'$what' is unsupported, fixed steps configuration file?"
        ;;
esac

return $ret
