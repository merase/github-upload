#!/bin/sh

: <<=cut
=script
This script will remove some unncessary package from the os. 
Package already removed are ignore.
=script_note
This is a RHEL 7 version of the script. so yum is assumed to be installed.
The list has a default (seed define_vars). 
=version    $Id: remove_Unnecessary-Pkgs.1.Linux.RH7_0-.sh,v 1.1 2017/06/30 06:21:39 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local pkg
for pkg in $OS_unnecessary_pkgs; do
    cmd "Make sure '$pkg' is removed" $CMD_yum_uninstall "$pkg"
done

return $STAT_passed
