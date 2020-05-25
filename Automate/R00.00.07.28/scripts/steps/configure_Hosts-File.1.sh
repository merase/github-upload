#!/bin/sh

: <<=cut
=script
This step configure the Hosts file. 
=version    $Id: configure_Hosts-File.1.sh,v 1.3 2014/11/24 07:43:19 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

#
# We will keep the old hosts file just in case
#$OS_hosts
if [ -e $OS_hosts ]; then
    cmd 'Backup hosts' $CMD_mv $OS_hosts $OS_hosts.bak
fi

echo "# Localhost definitions
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6

# TextPass nodes (OAM-IPs)" > $OS_hosts
check_success 'Hosts: Write localhost info' "$?"

translate_nodes_into_arrays "$dd_all_sects"
local num=$?
local idx=1
local fsrv
local fcnt=1

while [ $idx -le $num ]; do
    fsrv=''
    is_substr "${TMP_node[$idx]}" "$dd_oam_nodes"     # Decide if this is an fserver as well
    if [ $? != 0 ]; then                            # The main fserver shoudl
        fsrv=" fserver$fcnt"
        ((fcnt++))
    fi
    printf "%-15s ${TMP_host[$idx]} ${TMP_node[$idx]}$fsrv\n" "${TMP_oam_ip[$idx]}" >> $OS_hosts
    check_success "Hosts: Write ${TMP_node[$idx]}" "$?"
    ((idx++))              
done

return $STAT_passed
