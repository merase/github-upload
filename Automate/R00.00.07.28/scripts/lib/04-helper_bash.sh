#!/bin/sh

: <<=cut
=script
This script contains simple helper functions which are related to direct
bash command.
=version    $Id: 04-helper_bash.sh,v 1.40 2018/06/08 11:39:40 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# Some filter examples. easier to use or learn, e.g to be used in pipes the command still
# need to be added. this due to bash limitations
# usage: sed "$SED_*"
readonly SED_del_spaces='s/ \{1,\}/ /g'             # Will leave 1 space
readonly SED_del_preced_sp='s/^ *//g'
readonly SED_del_trail_sp='s/ *$//g'
readonly SED_del_spaces_tabs='s/[ \t]\{1,\}/ /g'    # Will leave 1 space
readonly SED_del_preced_sptb='s/^[ \t]*//g'
readonly SED_del_trail_sptb='s/[ \t]*$//g'
readonly SED_rep_us_w_sp='s/_/ /g'

# Other usefull but who cannot be defined
# TR
#  - C<tr '\n' ' '> Change all newlins into spaces
#  - C<tr -d '\r'> Delete any carrage return, in this is still in the variable
# CUT
#  - C<cut -d' ' -f1> Get 1st fields sperate by space
#  - C<cut -d' ' -f2> Get 2nd fields sperate by space. Rember if no 2nd field then all is returned!

: <<=cut
=func_ext
Kills a a tree of processes.
=opt2
The signal to use, TERM is used if ommited.
=cut
function killtree() {
    local pid="$1"
    local sig=${2:-TERM}
    
    local child
    log_debug "killtree $*"
    # needed to stop quickly forking parent from producing children between 
    # child killing and parent killing
    $CMD_kill -stop $pid >/dev/null 2>/dev/null 
    for child in $(ps -o pid --no-headers --ppid $pid); do
        killtree $child $sig
    done
    $CMD_kill -$sig $pid >/dev/null 2>/dev/nul
}

: <<=cut
=func_ext
Help function to kill other automate tools in case requested.
Very specific only to be used by main automate program!
=func_note
This function does not use find_pids as it conflicts with sub processes
usd by it (which are seen as automate as well).
=cut
function kill_other_automate_tools() {
    log_screen "$LOG_sep"
    log_screen "== Terminate potential running Automate instance"

    local tmp=$(mktemp)
    local pid
    local cnt=0
    local type
    for type in TERM KILL; do   # First terminate then kill
        ps -ef > $tmp
        local fnd_pids=$(grep "$AUT_start_exec" $tmp | sed "$SED_del_spaces" | cut -d' ' -f2 | tr '\n' ' ')
        for pid in $fnd_pids; do
            if [ $pid == $$ ]; then continue; fi    # Do not kill ourselves
            killtree $pid $type
            log_screen "== Send $type signal to automate tool with pid $pid"
            ((cnt++))
        done
    done
    if [ $cnt == 0 ]; then
        log_screen "== Did not find any running automate tool."
    fi
    log_screen "$LOG_sep"
    remove_temp $tmp 
}

: <<=cut
=func_ext
Make a single command string out of separate parameters
Require I<$strip_args> to be filled with strip_args=("$@")
=optx
The other parameters (which start counting from idx 0)
=set stripped_pars
The stripped paramaters separated with a space.
=cut
function strip_pars() {
    local idx=$1      # (M) Indicates how many pars to skip. 0 = none ,1 = 1st etc

    local num=${#strip_args[@]}

    stripped_pars=''
    while [ "$idx" -lt "$num" ]
    do
        if [ "$stripped_pars" == '' ]; then
            stripped_pars="${strip_args[$idx]}" 
        else
            stripped_pars="$stripped_pars ${strip_args[$idx]}" 
        fi
        ((idx++))
    done
}

: <<=cut
=func_ext
Execute a commando trough a temporary file. This is needed because not all
create commands (passed from one to another) can be properly executed. This
especially involves the usage of | and > operators. The function
gives a generic interface (it was use more an more) allowing for standard 
logging. The file are run in the local bash context.
=cut
function exec_through_file() {
    local info="$1"     # (O) The info belonging to this execution
    local cmd="$2"      # (M) The full command(s) (mulit line allowed.
    local out="$3"      # (O) If set the output is send to stdout as well

    local tmp=$(mktemp)
    echo '#!/bin/sh' > $tmp
    echo "$cmd" >> $tmp

    local full_info="($info) [root]# $cmd"
    if [ "$AUT_cmd_usr" != '' ]; then
        full_info="($info) [$AUT_cmd_usr]\$ $cmd"
    fi
    echo "{$tmp} $full_info" > $LOG_cmds

    log_debug "Executing: $full_info"
    chmod 755 $tmp
    if [ "$out" != '' ]; then
        $tmp  2>> $LOG_cmds | tee -a $LOG_file
    else
        if [ "$AUT_cmd_usr" == '' ]; then      #excute in local context
            $tmp  >> $LOG_cmds 2>&1
        else
            su - $AUT_cmd_usr -c "$tmp" >> $LOG_cmds 2>&1 
        fi
    fi
    AUT_cmd_outcome="$?"
    if [ "$AUT_allow_failure" == '' ]; then
        check_success "$full_info" "$AUT_cmd_outcome" 'one_log'   
    else
        log_info "Outcome (\$? = $AUT_cmd_outcome): $full_info"
    fi

    remove_temp $tmp    
}

: <<=cut
=func_frm
Change the output setting of cmd calls. This can be handy in case the other
options do not need to be changed.
=set AUT_allow_output
If set then output is allowed in subsequent cmd calls.
=cut
function set_allow_output() {
    local allow_output="$1"  # (O) If set then output is returned other wise put into a file

    AUT_allow_output="$allow_output" 

}

: <<=cut
=func_frm
Change the failure setting of cmd calls. This can be handy in case the other
options do not need to be changed.
=set AUT_allow_failure
If set then failure are allowed and to be checked by caller with AUT_cmd_outcome
This feature does not work for cmd_tp_remote.
=cut
function set_allow_failure() {
    local allow_failure="$1" # (O) If set then failure is allowed, empty not allowed anymore

    [ -z help ] && show_ignore=1    # its internal handling

    AUT_allow_failure="$allow_failure"
}

: <<=cut
=func_frm
Sets the current user to execute the command for. The default_cmd_user is root,
use B<default_cmd_usr> to set it back. It command will be executed as su <usr> if
th ethe user is set as none root.
=set AUT_cmd_usr
This contians the currenly set user.
=set AUT_allow_output
If set then output is allowed in subsequent cmd calls.
=set AUT_allow_failure
If set then failure are allowed and to be checked by caller with AUT_cmd_outcome
This feature does not work for cmd_tp_remote.
=cut
function set_cmd_user() {
    local user_name="$1"     # (O) The user name to use for the coming commands. Empty leave as it is.
    local allow_output="$2"  # (O) If set then output is returned other wise put into a file
    local allow_failure="$3" # (O) If set then failure is allowed

    if [ "$user_name" == '' ]; then
        :
    elif [ "$user_name" == 'root' ]; then
        AUT_cmd_usr=''
    else
        AUT_cmd_usr="$user_name"
    fi
    set_allow_output  "$allow_output" 
    set_allow_failure "$allow_failure"
}

: <<=cut
=func_frm
Set the command user to the default.
=set AUT_cmd_usr
Value is set to default which is ''.
=set AUT_allow_output
Value is set to default which is ''.
=set AUT_allow_failure
Value is set to default which is ''.
=cut
function default_cmd_user() {
    AUT_cmd_usr=''
    AUT_allow_output=''
    AUT_allow_failure=''
}


: <<=cut
=func_frm
Executes a command with additional helper information. This function should
be used form any simple bash commands. It will helping documentation, logs
the executed command and checks the outcome. This all keeps the script
uses it easy and readable. The command should be preferably taken from the 
$CMD_* defintions. B<If not available then it should be added>

=optx
Any optional paramaters to the command itself.
=cut
function cmd() {
    local info="$1"         # (O) The additional information related to this command.
    local cmd="$2"          # (M) The command to execute, use $CMD_*

    [ -z help ] && show_handled_in_lib="Be aware of this!"

    # I cannot use strip_pars in this case because the 1st parameter is a string
    local strip_args=("$@")
    
    if [ "$info" == '' ]; then
        info="no-info"
    fi
    strip_pars 1
    local exec_cmd=$stripped_pars
    local full_info="($info) [root]# $exec_cmd"
    if [ "$AUT_cmd_usr" != '' ]; then
        full_info="($info) [$AUT_cmd_usr]\$ $exec_cmd"
    fi

    log_debug "Executing: $full_info"
    echo "$full_info" > $LOG_cmds
    if [ "$AUT_allow_output" == '' ]; then
        if [ "$AUT_cmd_usr" == '' ]; then      #execute in local context
            $exec_cmd >> $LOG_cmds 2>&1
        else
            su - $AUT_cmd_usr -c "$exec_cmd" >> $LOG_cmds 2>&1 
        fi
    else
        if [ "$AUT_cmd_usr" == '' ]; then      #execute in local context
            $exec_cmd | tee -a $LOG_cmds
        else
            su - $AUT_cmd_usr -c "$exec_cmd" 2>&1 | tee -a $LOG_cmds 
        fi
    fi
    AUT_cmd_outcome="$?"
    if [ "$AUT_allow_failure" == '' ]; then
        check_success "$full_info" "$AUT_cmd_outcome" 'one_log'  
    else
        log_info "Outcome (\$? = $AUT_cmd_outcome): $full_info"
    fi
}

: <<=cut
=func_frm
A simplified version of cmd, which always run under proper textpass account
(so no need to use set_cmd_user/default_cmd_user). It is also not allowed to use the output.
=func_note
The TextPass instance is chosen upon the currently set $MM_usr
=optx
Any optional parameters to the command itself.
=cut
function cmd_tp() {
    local info="$1"         # (O) The additional information related to this command.
    local cmd="$2"          # (M) The command to execute, use $CMD_*

    [ -z help ] && show_handled_in_lib="Be aware of this!"

    # I cannot use strip_pars in this case because the 1st parameter is a string
    local strip_args=("$@")
    
    if [ "$info" == '' ]; then
        info="no-info"
    fi
    strip_pars 1
    local exec_cmd=$stripped_pars
    local full_info="($info) [$MM_usr]\$ $exec_cmd"

    log_debug "Executing: $full_info"
    echo "$full_info" > $LOG_cmds
    su - $MM_usr -c "$exec_cmd" >> $LOG_cmds 2>&1 

    AUT_cmd_outcome="$?"
    if [ "$AUT_allow_failure" == '' ]; then
        check_success "$full_info" "$AUT_cmd_outcome" 'one_log'   
    else
        log_info "Outcome (\$? = $AUT_cmd_outcome): $full_info"
    fi
}

: <<=cut
=func_frm
Executes a command with additional helper info information and input.
Using this function can help as a documentation for later on. Why this step
is executed.

=optx
Any optional parameters to the command itself.
=cut
function cmd_input() {
    local info="$1"         # (O) The additional information related to this command.
    local input="$2"        # (M) The input parameters
    local cmd="$3"          # (M) The command to execute, use $CMD_*

    [ -z help ] && show_handled_in_lib="Be aware of this!"

    # I cannot use strip_pars in this case because the 1st parameter is a string
    local strip_args=("$@")

    # write the input into a file which allows it to be use as su
    local tmp="$(mktemp)"
    echo "$input" > $tmp
    chmod 644 $tmp   # All read in case used by other user. local command!
    
    strip_pars 2
    local exec_cmd=$stripped_pars
    # The su approach (string) of cmd can handle input however the local input cannot
    # Therefore those are handle here.
    if [ "$AUT_cmd_usr" == '' ]; then      #execute in local context
        local full_info="($info) [root]# $exec_cmd < $tmp"
        log_debug "Executing: $full_info"
        echo "$full_info" > $LOG_cmds
        if [ "$AUT_allow_output" == '' ]; then
            $exec_cmd < $tmp >> $LOG_cmds 2>&1
        else
            $exec_cmd < $tmp | tee -a $LOG_cmds
        fi
        AUT_cmd_outcome="$?"
        if [ "$AUT_allow_failure" == '' ]; then
            check_success "$full_info" "$AUT_cmd_outcome" 'one_log'   
        else
            log_info "Outcome (\$? = $AUT_cmd_outcome): $full_info"
        fi
    else
        cmd "$info" $exec_cmd < $tmp
    fi

    remove_temp $tmp
}

: <<=cut
=func_frm
Executes a command with using the epxect command which is can handle
more secure inputs then using cmd_input. 
This can only be used as root user. No output is allowed
is executed.

=optx
Multiple expect, send pairs.
=cut
function cmd_expect() {
    local info="$1"         # (O) The additional information related to this command.
    local cmd="$2"          # (M) The command to execute

    if [ "$AUT_cmd_user" != '' ]; then
        log_exit "cmd_expect can only be called as root (at the moment)."
    fi
    if [ "$AUT_allow_output" != '' ]; then
        log_exit "cmd_expect does not allow for output capture."
    fi

    local full_info="($info) [root]# $CMD_expect $cmd ..."
    echo "$full_info" > $LOG_cmds           # Do not fully log exact command

    shift 2
    local exp="${nl}spawn $cmd$nl"
    # Currenlty both expect and send mandatory (this might change)
    while [ "$1" != '' -a "$2" != '' ]; do
        exp+="expect -nocase \"$1\" {send \"$2\r\"; interact}$nl"
        shift 2
    done
    add_cmd_require $CMD_expect         # Check availability
    $CMD_expect -c "$exp" >> $LOG_cmds 2>&1
    AUT_cmd_outcome="$?"
    if [ "$AUT_allow_failure" == '' ]; then
        check_success "$full_info" "$AUT_cmd_outcome" 'one_log'    
    else
        log_info "Outcome (\$? = $AUT_cmd_outcome): $full_info"
    fi
}

: <<=cut
=func_frm
Executes an hybrid command which can contain many pipes and redirects.
The command is given as a string. Stored into an temporary file
and then it wlll be executed. Errors will be logged into the LOG_file
=cut
function cmd_hybrid() {
    local info="$1"         # (O) The additional information related to this command.
    local cmd="$2"          # (M) The full command to execute

    [ -z help ] && show_handled_in_lib="Be aware of this!"

    exec_through_file "$info" "$cmd"        # Simply use internal interface
}

: <<=cut
=func_frm
Executes a simple command on a remote side as user textpass
=func_note
This requires password-less ssh to be configure for the textpass user.
This function does not allow failures (due to the multiplicity nature).
=cut
function cmd_tp_remote() {
    local info="$1"         # (O) The additional information related to this command.
    local node="$2"         # (M) Node or list of nodes to send it to
    local cmd="$3"          # (M) The command to execute
    local allow_failure="$4" # (O) If set then outcome not checked and returnin AUT_cmd_outcome

    local n
    for n in $node; do
        echo "$cmd" | su $MM_usr -c "ssh $n bash -s -l" # >> $LOG_file 2>&1
        if [ "$allow_failure" == '' ]; then
            check_success "($info) [$MM_usr@$n]\$ $cmd" "$?"
        else
            AUT_cmd_outcome=$?
            log_info "Outcome (\$? = $AUT_cmd_outcome): ($info) [$MM_usr@$n]\$ $cmd"
        fi
    done
}

: <<=cut
=func_frm
Special function to indicate a temp file is removed.
If the FLG_keep_tmp is set then files will not be removed.
This removal is nog logged at a lower level and the outcome is ignored.
=cut
function remove_temp() {
    local tmp="$1"      # (M) The (tmp)file to remove

    [ -z help ] && show_ignore=1        # not of interest

    if [ $FLG_keep_tmp == 0 ]; then
        /bin/rm -rf $tmp      # Do not use $CMD_rm ! nor cmd()
        # Output ignore, not use to stop if this fails
    fi
}

: <<=cut
=func_frm
To be use to set host name for now, also change $MM_host_cfg
=set MM_host_cfg
The host specicifc config file referent will be adapted.
=cut
function set_hostname {
    local hostname="$1"    # (M) The new host name

    [ -z help ] && show_short="Sets the actual hostname and adapts $OS_cnf_network"
     
    check_set "$hostname" 'Host is missing'

    # Test if hostnamectl is installed (as of RHE7, if so use that oppiste of hostname
    which hostnamectl >/dev/null 2>&1
    if [ $? == 0 ]; then
        cmd "Set new hostname (using ctl): $hostname" hostnamectl set-hostname $hostname --static
    else
        cmd "Set new hostname: $hostname" hostname $hostname
    fi

    # The old changing in cnf-network is kept. It does not harm.
    cmd "Removed current" $CMD_sed '/HOSTNAME/d' -i $OS_cnf_network
    text_add_line $OS_cnf_network "HOSTNAME=$hostname" 'HOSTNAME=.*'

    MM_host_cfg="$MM_etc/"`hostname`"$MM_host_cfg_postfix"
}

: <<=cut
=func_frm
Disable a specific crontab entry, identified by the full command (make sure it
is unique). If the entry does not exists then nothing is done. (as it is disabled)
=cut
function disable_crontab() {
    local cmd="$1" # (M) The full command as identified in the cron entry (should be unique

    if [ -e $OS_crontab ]; then # Just rplace in a single sed command
        cmd '' $CMD_sed -i "s/\(.*\)$cmd\(.*\)/#\1$cmd\2/" "$OS_crontab"
    fi
}

: <<=cut
=func_frm
Enables a specific crontab entry, identified by the full command (make sure it
is unique). If the entry does not exists then nothing is done, but return is set.
=func_note
This only works if the disable was done with a single # at the front of the line.
Multiple consecutive # are allowed as well but no spaces!
=ret
0 if successful, otherwise 1 if e.g. the entry did not existed.
=cut
function enable_crontab() {
    local cmd="$1" # (M) The full command as identified in the cron entry (should be unique)

    if [ -e $OS_crontab ]; then 
        local fnd=`cat $OS_crontab | grep "$cmd"`
        if [ "$fnd" == '' ]; then   
            return 1    # Did not find it up to caller what to do.
        fi
        # Remove and consecutive # in front og the command (if any)
        cmd '' $CMD_sed -i "s/^#*\(.*\)$cmd\(.*\)/\1$cmd\2/" "$OS_crontab"
    fi
}

: <<=cut
=func_frm
Sets/add a crontab entry (see man crontab -s 5 for more info
=man1 minutes
minutes in the range of (0-59)
=man2 hours
hours in the range (0-23)
=man3 mday
day of month in the range of (1-31)
=man4 month 
month int he range of (1-12) (or names)
=man5 wday
day of week in the range of (0-7) (0 or 7 is Sun, or use names)
=man6 cmd
The full command to execute the output is always redirected to E<gt>/dev/null 2E<gt>&1
=opt7 comment
A single line of (optional) comment. Only added if the job did not exist yet.
=cut
function set_crontab() {
    local cron_entry="$1 $2 $3 $4 $5 $6 >/dev/null"

    if [ -e $OS_crontab ]; then
        local fnd=`cat $OS_crontab | grep -n "$6"`
        if [ "$fnd" != '' ]; then
            local num=$(get_field 1 "$fnd" ':')
            cmd_hybrid 'Update crontab' "$CMD_sed -i '${num}s|.*|$cron_entry 2>\&1|' $OS_crontab"
            return
        fi
    fi
    if [ "$7" != '' ]; then
        echo "" >> $OS_crontab
        echo "#" >> $OS_crontab
        echo "# $7" >> $OS_crontab
        echo "#" >> $OS_crontab
    fi
    echo "$cron_entry 2>&1" >> $OS_crontab
    check_success "Set crontab: $cron_entry" "$?"
}

: <<=cut
=func_frm
Sets/add a crontab entry (see man crontab -s 5 for more info. The crontab will
be executed as a diffent user.
=man1 minutes
minutes in the range of (0-59)
=man2 hours
hours in the range (0-23)
=man3 mday
day of month in the range of (1-31)
=man4 month 
month int he range of (1-12) (or names)
=man5 wday
day of week in the range of (0-7) (0 or 7 is Sun, or use names)
=man6 user
The user to execute the command as.
=man7 cmd
The full command to execute the output is always redirectred to E<gt>/dev/null 2E<gt>&1
=opt8 comment
A single line of (optional) comment
=cut
function set_crontab_as() {
    set_crontab "$1" "$2" "$3" "$4" "$5" "su - $6 -c \"$7\"" "$8"
}

: <<=cut
=func_frm
This function unpack a file if needed. This is done
by looking at the extension. Currently the following is handled:
=le B<.gz>: gzipped file unzip using gzip unzip
=le B<.tar>: packed tarball untar using tar -x
=le B<.cpio>: cpio archive
=le Any of the above (except .gz) can be gzip packed as well. So B<.tar.gz> and B<.cpio.gz>
=le It is assumed that the .gz contains an .tar/.cpio with similar name.                  
=
The unpacked files will be stored in the local directory. The packed file
can be taken from the local directory (leave $2 empty) or from a given
directory (including /).
=set unpacked_file
The file without extension (assumes it was packed like that)
=func_note
tar -zxvf could be used but then an extra .tar step would be needed 
(now it is 2 easy sequential)
=func_note
Functionality could be extended however this is enough for current needs.
=cut
function unpack_file() {
    local file="$1" # (M) The file to check, may contain a * (wildcard)
    local dir="$2"  # (O) An optional path of the file with slash '/'.

    [ -z help ] && show_desc[0]='Unpack file based on extension, following types supported:'
    [ -z help ] && show_desc[1]="- .zip  : $CMD_unzip -o $dir$file"
    [ -z help ] && show_desc[2]="- .gz   : $CMD_gunzip $dir$file"
    [ -z help ] && show_desc[3]="- .tar  : $CMD_untar $dir$file"
    [ -z help ] && show_desc[4]="- .cpio : $CMD_pax -rvf $dir$file"
    [ -z help ] && show_trans=0

    if [ "$(echo "$file" | grep '*')" != '' ]; then
        file=$(echo $dir$file)      # translate the wildcard
        file=$(basename $file)      # Strip optional path again
    fi
  
    unpacked_file=''
    # First check if we have to unzip
    local ext=`echo "$file" | $CMD_ogrep "\.zip$"`
    if [ "$ext" == '.zip' ]; then	# Unpack zipped, always overwrote (as we are interactive)
        cmd '' $CMD_unzip -o $dir$file
        file="${file%.*}"           # Strip the '.zip' extension
    fi

    # Next check if we have to gunzip
    local ext=`echo "$file" | $CMD_ogrep "\.gz$"`
    if [ "$ext" == '.gz' ]; then    # Unpack gzipped
        cmd '' $CMD_gunzip $dir$file
        file="${file%.*}"           # Strip the '.gz' extension
    fi

    # Now check if we need to untar
    ext=`echo "$file" | $CMD_ogrep "\.tar$"`
    if [ "$ext" == '.tar' ]; then	# Unpack tar'ed
        cmd '' $CMD_untar $dir$file
        file="${file%.*}"           # Strip the '.tar' extension
    fi

    # It might be an cpio as well
    ext=`echo "$file" | $CMD_ogrep "\.cpio$"`
    if [ "$ext" == '.cpio' ]; then   # Unpack cpio
        # Do not use CPIO seems to give premature end for adax drivers
        # $CMD_cpio -ivcmd < $dir$file
        cmd '' $CMD_pax -rvf $dir$file
        file="${file%.*}"           # Strip the '.cpio' extension
    fi

    unpacked_file="$file"
}

: <<=cut
=func_frm
Calucukates the md5sum frm a specific file
=set md5_val
The calculated md5 sum.
=cut
function calc_md5() {
    local file="$1"     # (M) The full file path (or relative) to calulate the MD5 over
    local out="$2"      # (O) if set then the output is echo to be use din $(calc_md5 <file> out)
    
    md5_val=`md5sum $file | $CMD_ogrep "^([0-9a-fA-F]+)"`
    check_success "Calc MD for '$file' -> $md5_val" "$?"
    check_set "$md5_val" "No MD5 set for '$file'" 
    
    if [ "$out" != '' ]; then
        echo "$md5_val"
    fi
}

: <<=cut
=func_frm
Retrieve the file-system a mount point is mounted on (if mounted).
=stdout
The full file system reference or empty if not mounted
=cut
function get_filesys_for_mnt() {
    local mnt_point="$1"   # (M) The mount point to search for
    

    local info=$(df |  tr -s ' ' | cut -d' ' -f 1,6 | grep "$mnt_point")
    local check=$(echo -n "$info" | cut -d' ' -f 2 | grep "^$mnt_point\$")
    if [ "$check" != '' ]; then  # Return the file sys (fld 1)
        echo -n "$info" | cut -d' ' -f 1
    fi
}

: <<=cut
=func_frm
Retrieve the mount point for a specific file-system (device)a (if mounted).
=stdout
The full mount point or empty if not mounted
=cut
function get_mnt_for_filesys() {
    local device="$1"   # (M) The full device/file system to search for (so /dev/...)
    
    echo  -n "$(df |  grep "^$device" | tr -s ' ' | cut -d' ' -f 6)"
}

: <<=cut
=func_frm
Check if the given string is a word of the other string.
The word means exact word match delimited by spaces (default).
Or another given delimiter.
=func_note
This version can be used in if's directly. If the outcome is not empty then
it was found. Use the is_substr if $? usage is required. This currently is
a copy on purpose (less overhead)
=stdout
The found substr, whihc can inlcude delimiters (for easy cheap implementation)
or empty in case it was not found.
=cut
function get_substr() {
    local sub="$1"   # (M) The sub string to search for
    local str="$2"   # (O) The string to search in, may be empty
    local delim="$3" # (O) The delimiter (single char)to use defaults to space.
    
    delim=${delim:-' '}
    echo -n "$str" | $CMD_ogrep "(^|$delim)$sub($delim|\$)"
}

: <<=cut
=func_frm
Check is the given string is a word of the other string.
The word means exact word match delimited by spaces (default).
Or another given delimiter.
=func_note
get_substr can be used if [] usages is required.
=ret
1 if it is sub string, otherwise 0
=cut
function is_substr() {
    local sub="$1"   # (M) The sub string to search for
    local str="$2"   # (O) The string to search in, may be empty
    local delim="$3" # (O) The delimiter (single char)to use defaults to space.

    delim=${delim:-' '}

    if [ "$(echo -n "$str" | $CMD_egrep  "(^|$delim)$sub($delim|\$)")" != '' ]; then
        return 1
    fi
    return 0

    [ -z help ] && ret_vals[1]="'$sub' is a word match in [$str], delimiter='$delim'"
    [ -z help ] && ret_vals[0]="'$sub' not found as a word in [$str], delimiter='$delim'"
}

: <<=cut
=func_frm
Makes a constant environment variable out of a prefix, name and a value.
The constant will not be overwritten if it already exits. The bash error will
be prevented and a debug message generated. However it the value is different
then a log_exit will be called (unexpected redefine). This is the current
behavior and could change in the future.
=cut
function make_constant_var() {
    local pfx="$1"  # (M) The prefix to use for the variable name. It will be <pfx>_<name>
    local name="$2" # (M) The variable name. '-' translates into '_'. Other none variable name characters should not be used.
    local val="$3"  # (O) The value to be assigned. If omited then the variable name is used as value (no translation)

    val=${val:-$name}
    local var="${pfx}_$(echo -n "$name" |tr '-' '_')"
    if [ "${!var}" != '' ]; then
        if [ "${!var}" != "$val" ]; then
            log_exit "Constant var with name '$name' changed! ('${!var}' != '$val')"
        else
            log_debug "Constant var with name '$name' already defined."
        fi
    else
        export $var="$val"
        readonly $var
    fi
}

: <<=cut
=func_frm
Changes the run-level to a specific value [1-5]. The old setting will be kept
and commented out so that it can be used in case of restore. If the restore
data already exists and a new set is requested then this will result in a warning
and not overwrite the restore data.
=cut
function set_runlevel_after_reboot() {
    local new_runlevel="$1" # (M) The new run-level [1-5] or 'restore'

    [ -z help ] && show_desc[0]="Set the runlevel for next reboot to $new_runlevel"
    [ -z help ] && show_desc[1]="- This is doen by adapting file $OS_initab"
    [ -z help ] && show_desc[1]="- A restore marker '#automate_restore|*' is created (old value)."
    [ -z help ] && show_trans=0
 
    # This function needs to change depending on the outocme of 26054!
    # It might be wiser to make this a func <name> approach. for dif ver support.
    # For RH7 the runlevels changed in to targets.
    # settign the new target is done by creating a link:
    # ln -sf /usr/lib/systemd/system/<new target>.target /etc/systemd/system/default.target  
    if [ "$OS" != "$OS_linux" ] || [ $OS_ver_numb -ge 70 ]; then    # Safety catch!
        log_exit "This path has not been adapted, see bug 26064"
    fi
    
    check_in_set "$new_runlevel" '1,2,3,4,5,restore'

    local line_marker='^id:[0-6]:.*'
    local restore_marker='#automate_restore|'
    local restore="$(grep "^$restore_marker" $OS_inittab)"
    if [ "$new_runlevel" == 'restore' ]; then
        if [ "$restore" == '' ]; then
            log_warning "Trying to restore run-level, but no previous found, skip restore!"
        else
            cmd '' $CMD_sed -i --follow-symlinks -e "/$line_marker/d" $OS_inittab
            echo "${restore:${#restore_marker}}" >> $OS_inittab
        fi
    else
        local cur_line="$(grep "$line_marker" $OS_inittab)"
        local cur_runlevel="$(get_field 2 "$cur_line" ':')"
        if [ "$cur_runlevel" == "$new_runlevel" ]; then
            log_info "The requested run-level after reboot is already set to $new_runlevel"
        else
            
            cmd '' $CMD_sed -i --follow-symlinks -r -e "s/($line_marker)/$restore_marker\1/" $OS_inittab
            echo "$cur_line" >> $OS_inittab
            cmd '' $CMD_sed -i --follow-symlinks -r -e "s/^id:[0-6]:/id:$new_runlevel:/" $OS_inittab
        fi

    fi

    local set_runlevel="$(grep '^id:' $OS_inittab | $CMD_sed -r -e 's/^id:([0-6]):.*:/\1/')"
    if [ "$set_runlevel" == '' ]; then          # Ouch this is bad
        log_exit "Failed to set or restore run-level, check '$OS_inittab' before rebooting!"
    elif [ "$new_runlevel" != 'restore' -a "$set_runlevel" != "$new_runlevel" ]; then
        log_exit "Failed to set run-level '$set_runlevel' to requested level '$new_runlevel'"
    fi
    
    log_info "Requested to set run-level after reboot to '$new_runlevel', now set to '$set_run_level'"
}

: <<=cut
This will make an permanent environment change int the given script. By default
this will be the $OS_rc_profile.
=func_note
There are some limit on what is being substituted. An existing one liner
export <var>=<val> will cause some problems. Which can be fixed when they occur.
=cut
function make_env_var_permanent() {
    local exp_name="$1" # (M) The variable name to be exported, made permanent
    local value="$2"    # (M) The calue to set
    local script="$3"   # (O) The script file to edit, defaults to $OS_rc_profile

    script=${script:-$OS_rc_profile}

    log_info "Adding or adapting variable $exp_name=$value in '$script'"
    text_add_line $script "${nl}$exp_name=$value${nl}export $exp_name" "$exp_name="
    if [ $? == 0 ]; then
        # Assume that export <exp_name> exists as well
        text_substitute $script "$exp_name=.*" "$exp_name=$value"
    fi
}
