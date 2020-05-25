#!/bin/sh

: <<=cut
=script
This script contains simple helper functions for mysql execution.
Which are not bound to the  main automation script
=version    $Id: 10-helper_mysql.sh,v 1.15 2017/06/29 06:30:47 fkok Exp $
=author     Frank.Kok@newnet.com

=feat shield of mysql 
MySQL call are shielded of as much as possible, which gives an more cleaner
interface and generic error checking.
=cut

# Remark a lot of MySQL and all different in meaning and potential use !
SQL_usr='mysql'
SQL_grp='mysql'
SQL_svc='mysql'
SQL_root='root'
SQL_pwd="lokal\$"
SQL_db='mysql'
SQL_exe='/usr/local/bin/mysql'
SQL_cnf='my.cnf'
SQL_cfg="$OS_etc/$SQL_cnf"
SQL_ppar="-p$SQL_pwd"                       # Only password parameter (or login-path)
SQL_par="-u$SQL_root $SQL_ppar"             # Default parameters for < 5.6.6
SQL_cmd="$SQL_exe $SQL_par -D$SQL_db"
SQL_port=3306
SQL_login_path='mysql_root'
SQL_local_host='localhost.localdomain';
SQL_upgr_marker='/var/lib/mysql/RPM_UPGRADE_MARKER'

STR_SQL_sup_login_path=0                        # Support from 5.6.6 and up 0 = no, 1 = yes

readonly sql_ver_login_path='5.6.6'         # Support as of version, lee

: <<=cut
=func_ext
Refreshes the current MySQL settings base on the version
=cut
function refresh_mysql_version() {
    local checked=0
    STR_SQL_sup_login_path=0                    # Assume not
    # Since yum automate is not in fully in control of version and therefore the
    # Cheapest way out was to set the support o on if RH7 is used.
    if [ "$OS" != "$OS_linux" ] || [ $OS_ver_numb -ge 70 ]; then  
        STR_SQL_sup_login_path=1        # It is always assumed
        checked=1                       # Skip further checks
    fi

    # We have one problem the MySQL-Cluster contains a server as well and would
    # not show as an installed MySQL-Server so check the cluster first.
    if [ "$checked" == '0' -a "$(get_substr "$hw_node" "$dd_ndb_mysql_nodes")" != '' ]; then
        find_install $IP_MySQL_Cluster 'opt'
        if [ "$install_ent" == '' ]; then
            log_info "Refresh_MySQL_version: Did not find MySQL-Cluster, continue search"
        elif [ "$install_cur_ver" == '' ]; then
            log_info "Refresh_MySQL_version: No current MySQL-Cluster, continue search"
        else
            local maj=$(get_field 1 "$install_cur_ver" '.')
            local min=$(get_field 2 "$install_cur_ver" '.')
            local sub=$(get_field 3 "$install_cur_ver" '.')
            if [ "$maj" -gt '7' ] ||
                [ "$maj" -eq '7' -a "$min" -gt '3' ] ||
                [ "$maj" -eq '7' -a "$min" -eq '3' -a "$sub" -ge '6' ]; then
                log_info "Refresh_MySQL_version: Current MySQL-Cluster version ($install_cur_ver) contains MySQl-Server version >= $sql_ver_login_path"
                STR_SQL_sup_login_path=1
            else
                log_info "Refresh_MySQL_version: Current MySQL-Cluster version ($install_cur_ver) has MySQL-Server version < $sql_ver_login_path"
            fi
            checked=1
        fi
    fi

    if [ "$checked" == '0' ]; then
        find_install "$IP_MySQL_Server" 'opt'
        if [ "$install_ent" == '' ]; then
            log_info "Refresh_MySQL_version: Did not find MySQL-Server, assuming < $sql_ver_login_path"
        elif [ "$install_cur_ver" == '' ]; then
            log_info "Refresh_MySQL_version: No current MySQL-Server identified, assuming < $sql_ver_login_path"
        else
            local maj=$(get_field 1 "$install_cur_ver" '.')
            local min=$(get_field 2 "$install_cur_ver" '.')
            local sub=$(get_field 3 "$install_cur_ver" '.')
            if [ "$maj" -gt '5' ] ||
            [ "$maj" -eq '5' -a "$min" -gt '6' ] ||
            [ "$maj" -eq '5' -a "$min" -eq '6' -a "$sub" -ge '6' ]; then
                log_info "Refresh_MySQL_version: Current MySQL version ($install_cur_ver) is >= $sql_ver_login_path"
                STR_SQL_sup_login_path=1
            else
                log_info "Refresh_MySQL_version: Current MySQL version ($install_cur_ver) is < $sql_ver_login_path"
            fi
        fi
    fi

    if [ $STR_SQL_sup_login_path == 1 ]; then
        # >= 5.6 use the --login-path 
        SQL_par="--login-path=$SQL_login_path"
        SQL_ppar="$SQL_par"
    else
        # <= 5.5 uses the standard -u -p paramaters
        SQL_ppar="-p$SQL_pwd"
        SQL_par="-u$SQL_root $SQL_ppar"
    fi
    SQL_cmd="$SQL_exe $SQL_par -D$SQL_db"
}

: <<=cut
=func_frm
Test if the MySQL connection for root is working
=ret
1 is succesfully connected otherwise 0
=cut
function test_mysql_connection() {
    local host="$1" # (O) The host to connect to, default to <empty>
    
    [ -z help ] && local show_host="${host:-"localhost"}"
    [ -z help ] && show_trans=0 && show_short="Test if MySQL connection to 'root@$show_host' works."

    if [ "$host" != '' ]; then
        host="-h$host"
    fi
    local out=$(echo "show variables like 'version';" | $SQL_exe $SQL_par $host 2>&1 | grep 'version')
    if [ "$out" != '' ]; then
        return 1
    fi
    return 0

    [ -z help ] && ret_vals[0]="Failed to test MySQL connection to 'root@$show_host'"
    [ -z help ] && ret_vals[1]="Succesfull tested MySQL connection to 'root@$show_host'"
}

: <<=cut
=func_frm
Executes an MySQL command as root user in the given database
=set sql_outut
Holds the output of the MySQL command.
=cut
function execute_mysql() {
    local cmd="$1"      # (M) The mysql command to execute.
    local use_db="$2"   # (O) The database to use if not set then 'mysql' is used.
    
    use_db="${use_db:-"$SQL_db"}"

    [ -z help ] && show_trans=0 && show_short="[db=$use_db]mysql> $cmd"

    sql_output=`echo "$cmd" | $SQL_exe $SQL_par -D$use_db`
    check_success "Execute MySQL command: '$cmd' on db '$use_db' as root" "$?"
}

: <<=cut
=func_frm
Executes an MySQL but give a plains output. No headers and a single TAB as field
seperator. This one might be handier in direct queries.
This funciton is putting the outptu to stdout it is therefore intended to be
used like: var=\$(plain_mysql "cmd" "db")
=func_note
This function was added later and might be useful for existing execute_mysql
calls. However that could mean adapting the functionality.
=cut
function plain_mysql() {
    local sql_cmd="$1"  # (M) The mysql command to execute.
    local use_db="$2"   # (O) The database to use if not set then 'mysql' is used.

    use_db=${use_db:-$SQL_db}
    local exec="$SQL_exe $SQL_par -D$use_db -N -B -e \"$sql_cmd\""
    exec_through_file "Plain MySQL" "$exec" output
}

: <<=cut 
=func_frm
Grant all priveleges to a specific user. As a feature of MySQL it will indirectly
create a user if needed. Personally I don't know why mysql_create_user is needed,
but left it in for exact step compatibility
=cut
function mysql_grant() {
    local grant="$1"    # (O) Which privelege, defaults to 'ALL PRIVILEGES'
    local on="$2"       # (O) The db.tab to grant on, defaults to '*.*'
    local usr="$3"      # (M) The user to create.
    local pwd="$4"      # (O) The password to use, if empty no identified with grant option is added
    local domain="$5"   # (O) The domain/ip, % if not given.

    grant=${grant:-ALL PRIVILEGES}
    on=${on:-'*.*'}
    domain=${domain:-%}
    if [ "$pwd" != '' ]; then
        execute_mysql "GRANT $grant ON $on TO '$usr'@'$domain' IDENTIFIED BY '$pwd' WITH GRANT OPTION;"
    else
        execute_mysql "GRANT $grant ON $on TO '$usr'@'$domain';"
    fi
}

: <<=cut
=func_frm
Create an MySQL user if it does not exist yet.
It will also grant all priveleges.
=func_note
The grant priveleges might need to move to a seperate function
in the future.
=cut
function mysql_create_user() {
    local usr="$1"      # (M) The user to create.
    local pwd="$2"      # (M) The password to use
    local domain="$3"   # (O) The domain/ip, localhost if not given.
    local nowarn="$4"   # (O) If given then no warning is given but an info msg

    domain=${domain:-localhost}

    [ -z help ] && show_desc[0]="Create an MySQL (if not existing), for example:"
    [ -z help ] && show_desc[1]="- check,  mysql> SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$usr') AS user_exists \G;"
    [ -z help ] && show_desc[2]="- create, mysql> CREATE USER '$usr'@'$domain' IDENTIFIED BY '$pwd';"
    [ -z help ] && show_desc[3]="- grant,  mysql> GRANT ALL PRIVILEGES ON $on TO '$usr'@'$domain' IDENTIFIED BY '$pwd' WITH GRANT OPTION;"
    [ -z help ] && show_trans=0

    # Check if user already exists
    execute_mysql "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = '$usr') AS user_exists \G;"
    local exists=`echo "$sql_output" | grep user_exists | cut -d' ' -f2`
    if [ "$exists" == '1' ]; then
        if [ "$nowarn" != '' ]; then
            log_info "The $usr already existing, not need to create it."
        else
            log_warning "The $usr already exists, will not create it."
        fi
    else
        execute_mysql "CREATE USER '$usr'@'$domain' IDENTIFIED BY '$pwd';"
        mysql_grant '' '' "$usr" "$pwd" "$domain"
    fi
}

: <<=cut
Checks if an database exists
=ret
1 means it exist, 0 otherwise
=cut
function mysql_database_exists() {
    local dbname="$1"   # (M) The database to query

    [ -z help ] && show_trans=0 && show_short="Check if database '$dbname' exists within MySQL."

    execute_mysql "SHOW DATABASES \G;"
    local exists=`echo "$sql_output" | grep "$dbname"`
    if [ "$exists" != '' ]; then
        log_debug "Database with name '$dbname' exists."
        return 1
    fi
    log_debug "Database with name '$dbname' does not exist."
    return 0

    [ -z help ] && ret_vals[0]="database with name '$dbname' does not exists'"
    [ -z help ] && ret_vals[1]="database with name '$dbname' exists'"
}

: <<=cut
=func_frm
Makes a backup of a MySQL database (or databases) into a given file.
This is current being done using mysqldmp tool (in an ASCII format.
Backup are done useing the root MySQL user.
=cut
function make_mysql_backup() {
    local databases="$1"    # (M) The database or database to backup (space separated)
    local file="$2"         # (M) The file to write the data in.
    local options="$3"      # (O) Additional options (space separated), please add --

    [ -z help ] && show_short="Make a backup of MySQL database(es) into a given file"

    # First check existence of database and make it a warning if not (this will allow the process to continue
    local db
    local dbs=''
    local skipped''
    local sep=''
    for db in $databases; do
        mysql_database_exists $db
        if [ $? != 0 ]; then
            dbs+="$sep$db"
            sep=' '
        else
            log_warning "MySQL database '$db' does not exist, backup will be skipped." 15
        fi
    done

    if [ "$dbs" != '' ]; then
        cmd_hybrid "Make DB backup of '$databases'" "mysqldump $SQL_par $options --databases $dbs > $file"
    else
        log_info "No available database left over from original request '$databases', skipped backup."
    fi
}

: <<=cut
=func_frm
=stdout
Will return the size of the database in GB
=cut
function get_mysql_database_size() {
    local db="$1"   # (M) The database to query

    `mysql_plain "SELECT round(sum( data_length + index_length ) / 1024 / 1024 /1024,6) FROM information_schema.TABLES WHERE table_schema like '$db'"`
}

: <<=cut
=func_frm
Retrieves a paremeter from   the MySQL configuration file. 
=func_note
The section is currently ignored to make it easier, but this can be implemented
when needed.
=stdout
The retrieve parameter or empty in case not found or not set.
=cut
function get_mysql_parameter() {
    local sect="$1"     # (M) The section to read from currently ignored
    local item="$2"     # (M) The item to retrievverify

    if [ ! -r $SQL_cfg ]; then
        log_exit "MySQL configuration ($SQL_cfg) not readable, improper MySQL installation?"
    fi

    local output="$(grep "^ *$item *= *" $SQL_cfg)"
    [ "$output" == '' ] && return

    local val="$(get_field 2 "$output" '=')"
    val="$(get_field 1 "$val" '#')"
    val="$(echo -n "$val" | sed "$SED_del_preced_sp" | sed "$SED_del_trail_sp")"

    log_info "Retreived MySQL cfg paramater: [$sect]$item it is '$val'"

    echo -n "$val"
}

: <<=cut
=func_frm
Checks if a specific value is configured in the MySQL configuration file. 
log_exit will be called in case of mismatches (just like most check functions).
The function ca also be used to check existence only (not a particular value).
=func_note
The section is currently ignored to make it easier, but this can be implemented
when needed.
=cut
function check_mysql_parameter() {
    local sect="$1"     # (M) The section to read from currently ignored
    local item="$2"     # (M) The item to verify
    local exp="$3"      # (O) The value which should match. If empty then only existence is checked

    [ -z help ] && show_trans=0 && show_short="Checking MySQL cfg par: [$sect]$item is '$exp' or fail"

    log_info "Checking MySQL cfg paramater: [$sect]$item=$exp"

    local val="$(get_mysql_parameter "$sect" "$item")"
    [ "$val" == '' ] && log_exit "Did not find configuration item '$item'"

    if [ "$exp" != '' -a "$val" != "$exp" ]; then
        log_exit "The value of '$item' is not '$exp', but '$val', please verify"
    fi
}


: <<=cut
=func_frm
Sets (add, change or delete) a parameter if needed in the MySQL configuration file. 
=func_note
For adding the section is used, for chnage it is not an is assumed the
parameter was unique. This to make code easier, but this can be implemented
when needed.
The changes will be don in my.cnf it will NOT RESTART mysql that has to be 
arranged on a different level e.g. by using the return values after all is done.
=return
0 - if no change was executed
1 - for change in the value
2 - for adding as it did not exist before
3 - for delete in case it existed
=cut
function set_mysql_parameter() {
    local sect="$1"     # (M) The section to read from currently ignored
    local item="$2"     # (M) The item to set
    local val="$3"      # (O) The value to set, if empty then it will be remove

    if [ ! -r $SQL_cfg ]; then
        log_exit "MySQL configuration ($SQL_cfg) not readable, improper MySQL installation?"
    fi

    cur_val="$(get_mysql_parameter "$sect" "$item")"

    local ret=0
    if [ "$cur_val" != "$val" ]; then       # Do we need to change anything?
        if [ "$cur_val" == '' ]; then       # And thus val is set so do an add
            cmd_hybrid "Adding '$item' to $SQL_cfg:" "$CMD_sed -i --follow-symlinks -r 's/^ *\[$sect\] *$/\[$sect\]\n$item=$val/' $SQL_cfg"
            ret=2
        elif [ "$val" == '' ]; then         # exists but wanted to be delete
            cmd_hybrid "Delete '$item' from  $SQL_cfg:" "$CMD_sed -i --follow-symlinks -r 's/^ *$item/# upgrade deleted : $item/' $SQL_cfg"
            ret=3
        else
            cmd_hybrid "Changing '$item=$cur_val into '$val' in $SQL_cfg" "$CMD_sed -i --follow-symlinks -r 's/^ *$item *=.*/$item=$val/' $SQL_cfg"
            ret=1
        fi
    fi

    return $ret
}

: <<=cut
=func_frm
Remove the upgrade marker before an install/upgrade. The user can
interrupt the process.
=cut
function pre_check_remove_marker()
{
    local info="$1" # (O) Additional info to be written with command.

    if [ -e "$SQL_upgr_marker" ]; then
        log_wait "Found a MySQL upgrade marker: $SQL_upgr_marker.
This basically means a previous installation/upgrade did not finish.
File will be removed and process continues, unless interrupted." 30
        cmd "Removing upgrade marker ($info)" $CMD_rm "$SQL_upgr_marker"
        log_warning "Removed MySQL upgrade marker!"
    fi
}

: <<=cut
=func_frm
Remove the upgrade marker after an install/upgrade. It should have been
gone and this is jsut an extra check.
=cut
function post_check_marker_removed()
{
    local info="$1" # (O) Additional info to be written with command.

    if [ -e "$SQL_upgr_marker" ]; then
        log_warning "MySQL upgrade marker still exists, removing it."
        cmd 'Removing upgrade marker' $CMD_rm "$SQL_upgr_marker"
    fi
}
