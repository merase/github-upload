#!/bin/sh

: <<=cut
=script
This script will update the release file which contains an OS
release indentifier. The file by itself should not have any value. But
it should be maintained to the best of our knowledge.
=version    $Id: update_release_file.1.Linux.sh,v 1.2 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

if [ -e "$OS_NMM_rel_file" ]; then  # Older releases might not have it
    cmd 'Show old contents of OS release file ' $CMD_cat "$OS_NMM_rel_file"
fi
if [ -e "$tmp_os_pkgs/$OS_NMM_rel_base" ]; then     # Not important enough to fail upgrade for
    cmd 'Replace NMM-OS release file'      $CMD_cp  "$tmp_os_pkgs/$OS_NMM_rel_base" "$OS_NMM_rel_file"
else
    # It is unlikely but could happen so lets give an warning
    log_warning "Did not find new NMM-OS release file '$tmp_os_pkgs/$OS_NMM_rel_base', skipping update"
fi
    
return $STAT_passed
