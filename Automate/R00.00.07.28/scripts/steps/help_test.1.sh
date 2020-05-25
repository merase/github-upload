#!/bin/sh

: <<=cut
=script
This is a test script to test the generation of help text out of the bash
command. The step itself cannot be executed.
=script_note
This is additonal script information
=version    $Id: help_test.1.sh,v 1.1 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local var="$1"
local fixed=0    
local os="$(get_field 1 "$1" ':')"
local skip=$((unalloc + free))

cat << EOF
Read input form inine script
  over multiple libes and a var fixed=$fixed
EOF

cat > /usr/t.txt << EOF
A cat to fle with input
EOF

is_component_selected $hw_node $C_MGR 
if [ $? == 1 ]; then    # ignored
    log_info 'Yes it is a manager'; log_info "Multiple commands"
elif [ $? == 2 ]; then #= unexpected error
    log_exit "Failure case, automate halted."
else
    log_info "Double quoted no it is not a amanager"
fi

# Regular development comment is ignored (but shown in 'dev' mode.
#=# Inline comment for help text, show as is. '#=# ' space is required!
#=# Inline comment with var translation, works for main parameters only: $var
#=#

has_managable_device $hw_node
if [ $? -gt 0 ]; then
    # Test some commands with var substitution
    log_info "Configuring File Transfer on combined node"
    cmd '' $CMD_cd $MM_etc
    cmd 'Remove none gzipped version' $CMD_rm MGRdata.xml
    cmd 'Remove potential link file' $CMD_rm MGRdata.xml.gz
    cmd 'Make new link for MGRdata file' $CMD_ln $MM_etc/MGRdata.xml.$dd_oam_ip.gz $MM_etc/MGRdata.xml.gz
else
    log_info "Skipping File Transfer. MGR without manageable devices"
fi #=#

# This basically overules all defaults in bashrc
text_add_line $OS_rc_bash 'export PROMPT_COMMAND=''RETRN_VAL=$?;logger -p local6.debug "$(whoami) [$$]: $(history 1 | sed "s/^[ ]*[0-9]\+[ ]*//" ) [$RETRN_VAL]"'''
text_add_line $OS_cnf_syslog '# Log all user comands'
text_add_line $OS_cnf_syslog "local6.* $OS_commands"

# For now it realy assumes no messing with the defualt
text_add_line_after $OS_cnf_logrotate "$OS_commands" "/var/log/spooler"

text_change_comment 'enable'  'some text to enable'  '/tmp/a_file.txt'
text_change_comment 'disable' 'some text to disable' '/tmp/a_file.txt'

# Test some loop controls
while [ $idx -lt $end ]; do
    # do something, not named
done
while [ $idx -lt $end ]; do #= there are entries
    # do with named condition
done

for i in $list; do
    # do semething, not named
done
for i in $list; do  #= the list of entiries
    # do with named condition
done

until [ $idx == $end ]; do
    # do something, not named
done
until [ $idx == $end ]; do  #= end is reached
    # do with named condition
done

#=skip_control
until [ $idx == $end ]; do  #= NO SHOW
    log_info "This should not show up!"
done

#=skip_control
until [ $idx == $end ]; do  #= NO SHOW MULTI
    for i in $id; do
        log_info "This should not show up! (multi)"
    done
done

until [ $idx == $end ]; do  #= should show
    log_info "However this should show up!"
done

until [ $idx == $end ]; do  #= should show multi
    for i in $id; do
        log_info "This mult should show up."
        break 2;
    done
    break;
done

local var='one'
case "$var" in
    'one'|'three') log_info "show one"; log_into "and another three"; ;;
    'two'*)
        log_info "show two"
        ((i++))
        ;;
    "$RT_install" | "$RT_recover" ) log_info "test"; ;;
    *) log_info "wildcard"; ;;
esac

#=warning Test a warning message

# some return value translatios
return $STAT_passed
return $STAT_failed
return $STAT_not_applic

#=# Now we are skipping code until end
#=skip_until_end

log_info "This code is never shown"
return $STAT_passed

