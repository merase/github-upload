#!/bin/sh

: <<=cut
=script
This step will collect all versions from all packages. This is needed 
since Automate does not install all packages directly.
So it is safer to ask rpm for the installed versions again.
=version    $Id: collect_Versions.1.Linux.RH7_0-.sh,v 1.2 2017/06/08 11:45:11 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local ver_column="$1" # (O) The version column to retrieve and update, default to ver_current ($INS_col_cur_version)

ver_column="${ver_column:-$INS_col_cur_version}"

check_in_set "$ver_column" "$INS_col_cur_version,$INS_col_ins_version"

update_install_info get_pkg_version "$ver_column"
refresh_mysql_version
[ "$IP_TextPass" != '' ] && func TextPass identify_mm_release

return $STAT_passed

