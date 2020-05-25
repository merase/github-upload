#!/bin/sh

: <<=cut
=script
This script is part of autmatic installation/upgrade script and contains
the own data storage routine. This hold the data need to continue processing.
=version    $Id: 03-config_store.sh,v 1.39 2018/03/05 14:47:35 fkok Exp $
=author     Frank.Kok@newnet.com

=feat storage of process data
The current processing data is stored after each step. This make it 
possible to known where to continue. It also makes it possible to predfine
boot locations. 
=cut

readonly RT_install='install'
readonly RT_recover='recover'
readonly RT_upgrade='upgrade'
readonly   RT_types="$RT_install,$RT_recover,$RT_upgrade"  # Please adapt if needed!

# The product are need to identify some generic stuff. Perhaps this should
# become dynamic as well. For now this is cheaper (1 active product 'textpass')
readonly PRD_TextPass='TextPass'
readonly  PRD_Krypton='Krypton'
readonly  PRD_Mercury='Mercury'
readonly PRD_products="$PRD_TextPass,$PRD_Krypton,$PRD_Mercury,none" # Please adapt if needed!

readonly AUT_def_sw_iso='NMM-SW'

# Standard STR parameter which have default and can be read/overruled from 
# the configuration file [automate]. These are just defaults
STR_run_type="$RT_install"   # See RT_* e.g. install, upgrade, recover
STR_products="$PRD_TextPass" # See PRD_* e.g. TextPass
STR_wait_overlay=1           # Enable(1) or disable(0) the overlaying of wait information.

STR_cons_retry_time=30      # Maximizes retry time if console is enabled
STR_cons_max_retries=2      # Maximizes retries if console is enabled
STR_dwnl_retry_time=30      # Time before retrying manual download availability
STR_dwnl_max_retries=10     # amount of times to try man download
STR_fxf_retry_time=15       # Time before retrying fxfer updates availability
STR_fxf_max_retries=250     # amount of times to try fxfer updates
STR_lic_retry_time=30       # Time before retrying license checks
STR_lic_max_retries=30      # amount of times to try manual license
STR_ndb_retry_time=30       # Time before retrying ndb checks
STR_ndb_max_retries=120     # amount of times to try, so 30 * 120 is wait 1 hour
STR_run_retry_time=30       # Time before retrying verify run components
STR_run_max_retries=30      # amount of times to try verify run components
STR_ssh_retry_time=60       # Time before retrying SSH peers
STR_ssh_max_retries=60      # amount of times to try, so 60 * 60 is wait 1 hour
STR_syn_retry_time=10       # Time before retrying SYN peers
STR_syn_max_retries=360     # amount of times to try, so 10 * 360 is wait 1 hour
STR_tnd_retry_time=15       # Time before retrying TND nodes
STR_tnd_max_retries=10      # amount of times to try
STR_chk_retry_time=30       # Time before retrying check services
STR_chk_max_retries=960     # amount of times to try, so 30 * 960 is wait 8 hours
STR_dsk_retry_time=30       # Time before retrying check disks
STR_dsk_max_retries=480     # amount of times to try, so 30 * 960 is wait 4 hours
STR_mgr_s_retry_time=10     # Time before retry the mgr start finished
STR_mgr_s_max_retries=360   # amount of times to try so 10 * 360 is wait 1 hour  
STR_tpshell_retry_time=5    # Time to wait before retrying a tp_shell in sync
STR_tpshell_max_retries=3   # Amount of times a tp_shell is retried


# Variable which will be store for continuation of the process, not wise to set in data file!
STR_step_file=''
STR_data_file=''
STR_exec_steps=''
STR_instances='*'
STR_upg_plan_file=''
STR_sel_sw_iso=''           # Refers to a SW ISO [iso/name] in the data file.
STR_sel_os_iso=''           # Refers to a OS ISO [iso/name] in the data file.

# Some variablles to skip functionality. Only for testing! Set to 1 to skip.
STR_skip_reboot=''          # Skip the requested boot phase
STR_skip_run_check=''       # Skip the check for all TextPass processes running before the upgrade
STR_skip_split_disk=''      # Skip the spilt disk message, to be used with skip_shutdown if wanted.
STR_skip_shutdown=''        # List with extra's of shutdown_machine: store_state, for_kernel_update
STR_skip_ams_db_upgrade='1' # By default skip the AMS upgrade.
STR_skip_sep_upgrades=''    # Skip separate upgrade calls from the upgrade plan. Allow to continue if these not needed
STR_allow_fsck_fix='1'      # By default allow fixing file systems after a run without fixing.
#STR_prevent_skip           # Can be used by check_OS_version to prevent skipping, defaul not set.
STR_reboot_aft_upgrade=0    # If set then a reboot after upgrade is requested
#Skipping any name step set STR_skip_step_<name> to 1, was introduced for:
#STR_skip_step_update_devices=''

# Variable for directing special steps: 
STR_create_usb_rh_iso=''    # Ref to iso/ with RHEL OS which will allow to create a RHEL OS USB for upgrading the full OS. Empty disable

# Vrables which could be overulle, not shown by defualt
#STR_svc_rhsmd='disable'    # disable/enable the subscription daemon

# State variables, set default and leave them in th storage files as is!
# See also reset_state_data() for initializing them
declare -a STR_step_queue   # Will hold the todo-queue with sub steps
declare -a STR_step_arr     # The array with the current steps numbers on each depth
declare -a STR_step_cmd     # The array with the current command on each depth
declare STR_step_depth

: <<=cut
=func_ext
Reset the non-volatile state variables. This will prevent any problems with
previous steps interruptions.
=note
The function will not yet store it one disk only change it memory for the next
storage request!
=cut
function reset_state_data() {
    unset STR_shutdown_info

    unset STR_step_queue_busy     # The current busy step from the queue
    unset STR_step_queue
    unset STR_step_queue_proc
    unset STR_step_arr
    unset STR_step_cmd     # The array with the current command on each depth
    STR_step_depth=0    # The current depth of steps 0=none, 1=1st etc
    STR_step_arr[0]=0
    STR_step_cmd[0]=''

    STR_cron_tabs_recovered=0
}
reset_state_data

: <<=cut
=func_ext
Restore any default value to be set at the (re)start run.
This will not reset all value as some need to be kept, but only then
values holding inter step information.
=cut
function reset_store_vars() {
    STR_rebooted=0              # A reboot counter set to 0 if a a new reboot is wanted.
    STR_cron_tabs_recovered=0   # Crontabs not yet recovered.
    unset STR_sel_sw_iso        # No SW-ISO selected.
    unset STR_sel_os_iso        # No OS-ISO selected.
    unset STR_shutdown_info
    unset STR_prevent_skip      # Prevent left over for restart/new file.
}
reset_store_vars                # Call it once as well.
        
: <<=cut
=func_ext
Selects a file to write the automating data in.
This either is an existing one or one where the preferred directory exists.
=need AUT_store_script
=need AUT_store_dirs
=set AUT_store_file
The location of the selected store file.
=cut
function select_store_file() {
    local pref_file="$1"    # (O) Preferred store file.
    local d
    local f="$pref_file"
    
    AUT_store_file=''
    if [ "$f" != '' ]; then
        AUT_store_file=$f
        if [ -e $f -a -x $f ]; then
            return
        fi
        # test if it can be created
        echo -n '' > $f
        check_success "create given ($f) store file." "$?"
        cmd '' $CMD_rm $f           # Remove it again
        return
    fi
    
    # First try to find the file
    for d in $AUT_store_dirs; do
        f="$d/$AUT_store_script"
        if [ -e $f -a -x $f ]; then
            AUT_store_file=$f
            return
        fi
    done
    
    # if we come here then no existing file is found, find a directory
    for d in $AUT_store_dirs; do
        if [ -d $d ]; then
            AUT_store_file="$d/$AUT_store_script"
            return
        fi
    done
    
    log_exit "Could not find any location for store file.\nTried: '$AUT_store_dirs'"
}

: <<=cut
=func_ext
Reads the current state from the storage file
=cut
function read_current_state() {
    local store_file="$1"   # (O) Store to use or default selected

    select_store_file $store_file 

    if [ "$AUT_store_file" != '' -a -e $AUT_store_file ]; then
        if [ ! -x $AUT_store_file ]; then
            log_exit "Store file ($AUT_store_file) cannot be executed"
        fi
        log_info "Using store information from $AUT_store_file"
        . $AUT_store_file       # Simply executes the store/script file
        check_success 'read information from store file' "$?"
    fi

    # Validate some (important) settings.
    check_in_set "$STR_run_type" "$RT_types"     '(Data file: [automate]run_type=)'
    check_in_set "$STR_products" "$PRD_products" '(Data file: [automate]products=)'
}

: <<=cut
=func_ext
Store the current processing variables into the store file.
It automatically stores all variable starting with STR_
The store file is selected and created if needed.
=cut
function store_current_state() {
    [ -z help ] && show_ignore=1    # Internal no need to bother.

    if [ "$AUT_store_file" == '' ]; then
        select_store_file
    fi
    local f=$AUT_store_file
    
    local str_vars=`set | grep '^STR_'`
    
    # The storing is done by creating a new file which is a bash script
    echo "#!/bin/sh" > $f
    check_success 'Write new store file' "$?" 'no_info'
    echo "$str_vars" >> $f
    check_success 'Append data to store file' "$?" 'no_info'
    if [ ! -x $f ]; then
        cmd '' $CMD_chmod +x $f
    fi
}

: <<=cut
=func_ext
Extract continuation data out of the stored information. After that it will
clear necessary steps data. This because not all step can handle an auto continue
and the state in which the main steps are being restarted cannot be generally
saved. Even if line number would be stored then still it is difficult to automate
own temporary variable. It therefore needs to request the step it self.
So that the programmer can decide what is possible and what is not.

This function will merely copy the data needed.
=cut
function extract_continue_state() {
    if [ "$STR_step_depth" != '' ] && [ "$STR_step_depth" -ge '1' ]; then  # Need depth and later on queued
        if [ "$STR_step_queue_busy" != '' ]; then
            AUT_cont_step_queue=("$STR_step_queue_busy" "${STR_step_queue[@]}")
            STR_step_queue_busy=''
        else
            AUT_cont_step_queue=("${STR_step_queue[@]}")
        fi
        if [ "${#AUT_cont_step_queue[@]}" != '0' ]; then
            AUT_cont_step_queue_proc=("${STR_step_queue_proc[@]}")
            AUT_cont_step_arr=("${STR_step_arr[@]}")
            AUT_cont_step_cmd=("${STR_step_cmd[@]}") 
            AUT_cont_step_depth=$STR_step_depth
        fi
    fi
    reset_state_data        # Always reset the store state data
}

: <<=cut
=func_frm
Checks if a product is currently enabled. This is simple wrapper to make the 
code readable and add safety checks.
=func_note
the return value is different then is_substr as it is planned to be used
directory in an if product_enabled <prod>; then.
=return
0 on success meanign it is enabled. otherwise it is not enabled.
0 if not enabled, 1 if it is available in $STR_products
=cut
function product_enabled() {
    local product="$1"  # (M) The product to look up, Use $PRD_*

    check_set    "$product" 'No product given to verify'
    check_in_set "$product" "$PRD_products"

    is_substr "$product" "$STR_products" ','
    [ $? == 0 ] && return 1 || return 0         # Invert
}
