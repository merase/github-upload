#!/bin/sh

: <<=cut
=script
This step will collect the needed data from the OS which is important if a 
rollback is needed.
=brief Collects a list with rpm's, dmesg output and dmidecode output
=version    $Id: collect_Rollback-Info.2.Linux.RH7_0-.sh,v 1.1 2017/12/06 12:05:40 fkok Exp $
=author     Frank.Kok@newnet.com
=cut


# Do additional other checks (items as suggested by manual)
# I ignored the fact if soem are alreayd available elsewhere
cat << EOF > $OS_col_other_checks
==========user.target info============
$(ls /etc/systemd/system/multi-user.target.wants/)
EOF

return $STAT_passed