#!/bin/sh
: <<=cut
=script
This function set the Linux specific CMD variables.
=version    $Id: set_CMD_vars.2.Linux.sh,v 1.11 2017/06/26 14:25:13 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly CMD_rpm='rpm'               # This should only be used locally (within set_CMD_vars*)
readonly CMD_install_ext='rpm'       # used to identify package extension (just  happen to be the same, it does not represent the same).

# The query part of rpm is allowed to use which give no impact on existing code
# This has also been discussed with Willem and is allowed/supported
# The actual impossibilities we -q and -qp. The others were possible with some
# adaptation. However this is the cheapest and no change/risk :-)
readonly        CMD_install_name="$CMD_rpm -q"   # queries the name of an installed pacakaged: par1 = package name no ver needed.
readonly   CMD_install_name_file="$CMD_rpm -qp"  # queries the name of a specific file package: par1 = package name no ver needed. 
                                                 #  Can be used with --queryformat as well
readonly       CMD_install_query="$CMD_rpm -qi"  # queries a specific package with full info: par1 = exact package name to query
readonly  CMD_install_query_file="$CMD_rpm -qip" # queries a specific file package with full info: par1 = the <path>file name to query
readonly       CMD_ins_query_all="$CMD_rpm -qa"  # queries all packages

# RPM related Install commands, selected via set_install_commands (always available)
readonly             CMD_rpm_install="$CMD_rpm -ivh" # install : Installs an file (in this case an RPM). Expect a file name
readonly         CMD_rpm_ins_freshen="$CMD_rpm -Fv"  # Freshen will only upgrade existing install packages
readonly         CMD_rpm_ins_upgrade="$CMD_rpm -Uv"  # Upgrade will upgrade or install and remove old versions if applicable
readonly           CMD_rpm_uninstall="$CMD_rpm -e"   # uninstall : Uninstall a package (in this case an RPM). Expect named install

# Rest of RPM related instruction in .3 version file, split RH6|RH7

readonly CMD_cpio='cpio'             # Extract cpio archives
readonly CMD_rpm2cpio='rpm2cpio'     # Used to translate rpm into cpio
readonly CMD_pax='pax'               # Alternative to extract cpio archives (work for adax, cpio give premature end).

# HP Array Utility CLI, Due to gen9 support it changed to a newer version 
# hpssacli with seemingly same interface. So lets see if new is found otherwise
# fallback to oodl (and let later require complain when needed). 
# Later hp removed its own hp prefix. Yes this has an extra which, but no indents
CMD_da_cli='ssacli'                         # newest is preferred
`which $CMD_da_cli >>$LOG_file 2>1`
[ $? != 0 ] && CMD_da_cli='hpssacli'        # Then the middle one
`which $CMD_da_cli >>$LOG_file 2>1`
[ $? != 0 ] && CMD_da_cli='hpacucli'        # Default to old
readonly CMD_da_cli
