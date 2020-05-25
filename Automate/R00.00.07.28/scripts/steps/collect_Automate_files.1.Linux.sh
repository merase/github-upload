#!/bin/sh

: <<=cut
=script
This functions gathers information about a package before it is actually installed.
The automation data is stored in the package itself. In some case this could
lead to a chicken and an egg. Examples are:
* Upgrades where require info is needed
* Install package which need pre_install scripts
* ...
This step will extract pkg info from all installed components (needed e.g.
for common config creation) and some standard packages
=script_note
This functionality is a preperation to future ideas. It will not realy extract
data as there is no data available yet. 
=fail
This step can be skipped if it would cause failure.
=version    $Id: collect_Automate_files.1.Linux.sh,v 1.5 2017/03/08 14:01:12 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

#=# Future internal automate coding.
#=skip_until_end

# 
# Question how to do 
# * MySQL-Server  (currently always fallback)
# * MySQL-Cluster (currently always fallback)
# * Opensource    (tarball with separate RPM's)
# * STV           (tarball no RPM's)
#
local ip
for ip in $dd_all_comps $IP_MySQL_Server $IP_MySQL_Cluster $IP_OpenSource; do
    # For Linux we have to use rpm2cpio to extract the file
    find_install $ip
    cmd '' $CMD_cd $install_dir
    find_file $install_pkg '' 'opt' # Optional for future changes in packages with old automate software
    local ext=`echo "$found_file" | $CMD_ogrep "\.$OS_install_ext$"`
    if [ "$ext" == ".$OS_install_ext" ]; then
        # Extract everything belonging to Automate by using the correct names
        # like automate-pkg directory and the /var/Automate directory
        # we will install the files including the links in /var
        # This will be overwritten with the same info once the rpm is installed
        # Which results in a seamless cut-over from temp to real data.
        cmd_hybrid "Try to extract pkg file for $ip" "cd / ; $CMD_rpm2cpio $install_dir/$found_file | cpio -idm '*[Aa]utomate*'"
    else
        log_info "Could not check for pkg files no rpm ($found_file)"
    fi
done

return $STAT_passed
