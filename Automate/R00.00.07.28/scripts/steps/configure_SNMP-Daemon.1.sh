#!/bin/sh

: <<=cut
=script
This step configure the SNMP-Daemon.
=version    $Id: configure_SNMP-Daemon.1.sh,v 1.7 2017/07/13 13:26:23 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# FKO: I wanted to have the indent level so used a different approach. I rather
#      would have seen different logic.
# Remark since RH7 there is no OpenSource version availebl so that is new behavior as well.
#=* Step is skipped if OpenSource version >= R04.06.00.00 (only STV default port BG2978)
#=* If >= RH7 then new SNMP config approach is taken (different STV port configured)
find_install "$IP_OpenSource" 'optional'                                     #=!
if [ "$install_cur_ver" != '' ] && [[ "$install_cur_ver" < 'R04.06.00.00' ]];then                            #=!

    find_pids 'snmpd'
    if [ $? -gt 0 ]; then
        func service stop snmpd
    fi
    cmd '' $CMD_rm /etc/rc[0-3].d/*snmpd
    
    local svc=$(basename $InitD_SNMP)
    if [ ! -f $InitD_SNMP ]; then 
        cmd '' $CMD_cp "/usr/local/etc/$svc" $OS_initd/
    fi
    
    cmd '' $CMD_ln $InitD_SNMP /etc/rc0.d/K06$svc
    cmd '' $CMD_ln $InitD_SNMP /etc/rc1.d/K06$svc
    cmd '' $CMD_ln $InitD_SNMP /etc/rc2.d/K06$svc
    cmd '' $CMD_ln $InitD_SNMP /etc/rc3.d/K06$svc
    cmd '' $CMD_ln $InitD_SNMP /etc/rc3.d/S92$svc
    
    # It looks like the manual only suggest the -Ln change in case of 
    # STV being installed. Funny thing is the -Ln option is not defined
    # so what the hacks is the change doing. (Besides disabling the -Le (log to stderr)
    # option. I'll take the approach to always change it if and adapt the STV 
    # port if defined.
    text_substitute  $InitD_SNMP "-Le" "-Ln"
    read_config_vars $C_STV
    if [ "$STV_snmp_port" != '' ]; then
        # Question is it right to do it for all nodes, or only for the poller/STV
        # nodes. For now do it for all, the port is most likely not to change
        # I would be nice if this can be recovered as well (not done for now, overkill)
        text_substitute  $InitD_SNMP "udp:[0-9]*" "udp:$STV_snmp_port"
    fi
    
    func service start $svc
    
    check_running 'TextPass SNMP daemon' 1 'snmpd'
elif [ "$OS_cnf_snmpd" != '' ] && [ $OS_prefix == 'RH' ] && [ $OS_ver_numb -ge 70 ]; then
    # Changes were requested using bug 26202, it resulted in not able to change
    # the STV_port, and I always enabled/started it (enable by tools, 
    # but start is not identified)
    # A tools version check was added to as this was only introduce during RHEL7
    find_install "$IP_Tools" 'optional'                                                #=!
    if [ "$install_cur_ver" != '' ] && [[ "$install_cur_ver" < 'R04.09.00.05' ]];then  #= Check Tools version
        log_warning "Your Tools version is too old (need R04.09.00.05 or up), 
SNMP configuration requires attention. Check: '$OS_cnf_snmpd'"
    fi

    read_config_vars $C_STV
    if [ "$STV_snmp_port" != '' ] && [ "$STV_snmp_port" != '11114' ]; then
        log_manual 'Change stv_snmp_port' "
The STV requested a different snmp_port. Please change the default udp port
from udp:11114 to udp:$STV_snmp_port in the file '$OS_cnf_snmpd'"
    fi

    func service enable snmpd
    func service start  snmpd
    func service enable snmptrapd
    func service start  snmptrapd
else                                                                         #=!
    return $STAT_skipped                                                     #=!
fi                                                                           #=1

return $STAT_passed
