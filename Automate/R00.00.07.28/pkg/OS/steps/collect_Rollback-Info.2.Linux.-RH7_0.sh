#!/bin/sh

: <<=cut
=script
This step will collect the needed data from the OS which is important if a 
rollback is needed.
=brief Collects a list with rpm's, dmesg output and dmidecode output
=version    $Id: collect_Rollback-Info.2.Linux.-RH7_0.sh,v 1.2 2018/07/13 06:01:15 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# Do additional other checks (items as suggested by manual)
# I ignored the fact if soem are alreayd available elsewhere
cat << EOF > $OS_col_other_checks
=============chkconfig --list=========
$(chkconfig --list)
EOF

return $STAT_passed