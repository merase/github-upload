#!/bin/sh
: <<=cut
=script
This function sets the generic CMD variables which are valid for all OS'es
=version    $Id: set_CMD_vars.1.sh,v 1.17 2017/06/08 11:45:10 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# Check the path variable. It may be run from a the boot in which case not
# all required (by scripts out of my control like tp_cci_start) path are defined.
local exp
local add
log_info "Current path: '$PATH'"
for exp in '/usr/bin' '/usr/sbin' '/bin' '/sbin' '/usr/local/bin' '/usr/local/sbin'; do
    if [ "$(echo -n "$PATH" | grep "$exp")" == '' ]; then
        export PATH="$exp:$PATH"
        log_info "Added path: '$exp' new: '$PATH'"
    fi
done

# Short command which can be given to cmd() also prevent alias problems
readonly CMD_awk='awk'                  # awk            : Parameters just like 'awk'
readonly CMD_blkid='/sbin/blkid'        # blkid
readonly CMD_cat='cat'                  # cat
readonly CMD_cd='cd'                    # change dir     : Parameters just like 'cd'
readonly CMD_chgrp='chgrp -R'           # change group   : Parameters just like 'chgrp' always recursively
readonly CMD_chmod='chmod -R'           # change mod     : Parameters just like 'chmod' always recursively
readonly CMD_chown='chown -R'           # change owner   : Parameters just like 'chown' always recursively
readonly CMD_chkcfg='/sbin/chkconfig'   # chkconfig   
readonly CMD_cp='/bin/cp -r'            # copy           : Parameters just like 'cp' always recursively
readonly CMD_e2label='/sbin/e2label'    # e2label        : Change disk label
readonly CMD_egrep='egrep'              # egrep          : For sun dos not support -o, use CMD_ogrep
readonly CMD_expect='expect'            # expect         : External expect program need tcl
readonly CMD_fdisk='/sbin/fdisk'        # fdisk
readonly CMD_fsck='/sbin/fsck'          # fsck
readonly CMD_gawk='/bin/gawk'           # gawk           : Parameters just like 'gawk'
readonly CMD_grep='/bin/grep'           # grep           : Parameters just like 'grep'
readonly CMD_gunzip='gunzip'            # gunzip .gz     : Parameters just like 'gunzip'
readonly CMD_gzip='gzip'                # gzip
readonly CMD_http_get='wget'            # http get       : Parameters just like 'wget'
readonly CMD_ifconfig='/sbin/ifconfig'  # ifconfig       : Parameters just like 'ifconfig'
readonly CMD_ifdown='/sbin/ifdown'      # ifdown         : Parameters just like 'ifdown'
readonly CMD_ifup='/sbin/ifup'          # ifup           : Parameters just like 'ifup'
readonly CMD_ip='/sbin/ip'              # ip             : Parameters just like 'ip'
readonly CMD_kill='kill'
readonly CMD_ln='/bin/ln -s'            # link           : Parameters just like 'ln' always as symbolic
readonly CMD_lsblk='/bin/lsblk'         # lsblk
readonly CMD_ncat='ncat'                # netcat         : Parameters jsut like 'ncat'
readonly CMD_md5='md5sum'
readonly CMD_mkdir='mkdir -p'           # make dir       : Paremeters just like 'mkdir' ignore if parent exists
readonly CMD_mkfs='/sbin/mkfs.ext3'     # mkfs (ext3)
readonly CMD_mkfs4='/sbin/mkfs.ext4'     # mkfs (ext4)
readonly CMD_mv='/bin/mv'               # move           : Parameters just like 'mv'
readonly CMD_mount='mount'              # mount          : Parameters just like 'mount'
readonly CMD_parted='/sbin/parted'      # parted
readonly CMD_ping='/bin/ping'           # ping           : Parameters just like 'ping'
readonly CMD_arping='/sbin/arping'      # arping         : Parameters just like 'arping'
readonly CMD_python='/usr/bin/python2'  # python         : Parameters just like python
readonly CMD_pkill='pkill'
readonly CMD_pgrep='pgrep'
readonly CMD_rm='/bin/rm -rf'           # remove         : Parameters just like 'rm' always recusively and force
readonly CMD_route='/sbin/route'        # route          : Parameters just like 'route'
readonly CMD_runlevel='runlevel'        # runlevel
readonly CMD_scp='scp'                  # scp            : Parameters just like 'scp (not recursive)'
readonly CMD_sed='sed'                  # sed_sed        : Parameters just like 'sed'
readonly CMD_service='service'          # service        : Parameters just like 'service'
readonly CMD_sfdisk='/sbin/sfdisk'      # sfdisk
readonly CMD_ssh='ssh'                  # ssh            : Parameters just like 'ssh'
readonly CMD_sysctl='sysctl'            # sysctl         : Parameters just like 'sysctl'
readonly CMD_touch='touch'              # touch          : Parameters just like 'touch'
readonly CMD_ulimit='ulimit'            # ulimit         : Parameters just like 'ulimit'
readonly CMD_umount='umount'            # umount         : Parameters just like 'umount'
readonly CMD_usermod='usermod'          # usermod        : Parameters just like 'usermod'
readonly CMD_unzip='unzip'              # unzip .zip     : Parameters just like 'unzip'

readonly CMD_tar='tar'                  # tar            : Parameter jsut like 'tar'
readonly CMD_untar="$CMD_tar -xvf"      # unpack .tar    : Expect a file name
readonly CMD_untgz="$CMD_tar -xvzf"     # unpack .tgz    : Expect a file name
readonly CMD_mktar="$CMD_tar -cvf"      # tar create     : tar with create, verbose, file
readonly CMD_mktgz="$CMD_tar -cvzf"     # tar create     : tar with create, verbose, gzip, file
readonly CMD_updtar="$CMD_tar -uvf"     # tar update     : tar with update, verbose, file

# Aliases for some of our own command (just to be inline)
readonly CMD_tp_shell='tp_shell'        # tp_shell       : Parameters just like 'tp_shell'
readonly CMD_tp_auth='tp_auth'          # tp_auth        : Parameters jsut like 'tp_auth'

# There are also OS specific command defined. See OS specific files for more details.
# E.g. CMD_install

if [ "$CMD_ogrep" == '' ]; then
    log_exit "CMD_ogrep should have been defined already"
fi
