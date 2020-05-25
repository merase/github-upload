#!/bin/sh

: <<=cut
=script
This step create repositories for the OS.
This step assumes creatrepo is installed, which is checked in precheck_impact,
no further checks are done.
=version    $Id: create_Repository.1.sh,v 1.5 2018/09/05 12:17:17 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

if [ "$OS" != "$OS_linux" ] || [ $OS_ver_numb -lt 70 ]; then
    return $STAT_not_applic
fi

# if we have an os_upgrade dir then we will create the repo
os_rel="$(get_our_OS_release "$dd_os_iso_file")"  # From 7.5 the repositories changed
if [ "$os_rel" -ge 75 ]; then
    # Make sure old os-upgrade repo is gone (just in case)
    cmd 'Remove repos in case exists' $CMD_rm $OS_yum_repos/lithium-os-upgrade_local.repo $OS_yum_repos/lithium-SupportPkgs_*.repo
    if [ -d "$CFG_pkg_OS_dir" ]; then
        cmd 'Create Repo for OS' createrepo $CFG_pkg_OS_dir

        # I verified with Divya and it is assumed there already a .repo
        # file form previous installation pointing towards /var/Packages/OS
        # therfore no new repo file is required.
    fi
elif [ -d "$CFG_pkg_OS_upg_dir" ]; then
    cmd "Create Repo for os_upgrade" createrepo $CFG_pkg_OS_upg_dir

    # Create the repo file for, just overwrite 
    cat > $OS_yum_repos/lithium-os-upgrade_local.repo << EOF
[lithium-OS-upgrade-repo-Local]
name = Local repository for OS upgrade
baseurl=file:///var/Packages/os_upgrade/
gpgcheck=0
enabled=1
EOF
fi

# this is executed after retrieve the new ISO so we clean it here
cmd 'Cleanup yum cache' $CMD_yum clean all

return $STAT_passed
