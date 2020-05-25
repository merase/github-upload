#!/bin/sh
: <<=cut
=script
Defines variables used by OS scripts.
=version    $Id: define_vars.1.sh,v 1.7 2017/09/07 11:07:09 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

if [ "$OS_vars_defined" != "$SCR_whoami" ]; then    # static to ver/node, only if needed  
    OS_vars_defined="$SCR_whoami"

    process_section_vars "$hw_node" "OS_"

    set_default OS_exp_dsk_slot    '0'
    set_default OS_exp_dsk_log_drv '1'
    set_default OS_exp_dsk_phy_drv '1 2'

    # Currently the list (space spearated) with packages which are to be removed
    # from the system. It has a defualt, but this would allow it to overrule 
    # using the data file. Please use with care. Advanatge no code change needed
    # if more/less needed. For now this is OS independent (might change)
    set_default OS_unnecessary_pkgs 'firewalld chrony'
fi

# Backup definitions (also used for recover)

# Collect definitions
OS_col_pkg=$(           get_bck_dir 'OS' 'packages_installed.txt')
OS_col_dmesg=$(         get_bck_dir 'OS' 'dmesg_output.txt')
OS_col_dmidecode=$(     get_bck_dir 'OS' 'dmidecode_output.txt')
OS_col_other_checks=$(  get_bck_dir 'OS' 'other_checks.txt')
OS_col_iptables=$(      get_bck_dir 'OS' 'iptables')
OS_col_iptables_stat=$( get_bck_dir 'OS' 'iptables_status.txt')
OS_col_ip6tables=$(     get_bck_dir 'OS' 'ip6tables')
OS_col_ip6tables_stat=$(get_bck_dir 'OS' 'ip6tables_status.txt')

