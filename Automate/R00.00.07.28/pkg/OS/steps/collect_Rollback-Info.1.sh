#!/bin/sh

: <<=cut
=script
This step will collect the needed data from the OS which is important if a 
rollback is needed.
=brief Collects a list with rpm's, dmesg output and dmidecode output
=version    $Id: collect_Rollback-Info.1.sh,v 1.7 2017/12/06 12:05:40 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

cmd_hybrid '' "$CMD_ins_query_all > $OS_col_pkg"
cmd_hybrid '' "dmesg > $OS_col_dmesg"

which dmidecode >> /dev/null 2>1                                             #=!
if [ $? == 0 ]; then    #= command 'dmidecode' exists
    cmd_hybrid '' "dmidecode > $OS_col_dmidecode"
fi

# Do additional other checks (items as suggested by manual)
# I ignored the fact if soem are alreayd available elsewhere
# The status of textpass in not part of OS and belongs to TextPass
cat << EOF > $OS_col_other_checks
=============Date=====================
$(date)
=============df -kh===================
$(df -kh)
=============hostid===================
$(hostid)
=============hostname=================
$(hostname)
$(hostname -i)
=============ifconfig -a==============
$(ifconfig -a)
=============ntpq -p==================
$(ntpq -p)
=============netstat -nr==============
$(netstat -rn)
=============ps -ef===================
$(ps -ef)
EOF

return $STAT_passed