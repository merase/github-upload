#!/bin/sh

: <<=cut
=script
This script contains simple helper functions whihc are related to finding stuff.
=version    $Id: 10-helper_find.sh,v 1.26 2018/09/25 06:41:11 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

: <<=cut
=func_frm
Find the last installed version useing package module.
If no package is found then this is seen as an error and will terminate.
Unless the optional flag is given.
the run.
=set installed_version
Will hold the installed version like Rxx.yy.zz.bb
=cut
function find_last_installed_version() {
    local name="$1"     # (M) Installed package name E.g. ${pfx_mm_pkg}MGR
    local opt="$2"      # (O) Set if it is allowed to be not found
    
    if [ "${name:0:1}" == '*' ]; then   # Strip wildcard sign if any
        name="${name:1}"
    fi
    installed_version=$($CMD_ins_query_all | grep $name | $CMD_ogrep "\-R.*(\-|$)" | cut -d'-' -f2 | uniq)
    check_success "Get package info: $name -> $installed_version" "$?"
    if [ "$installed_version$opt" == '' ]; then
        log_exit "Package '$name' does not seem to be installed (it should)"
    fi
}

: <<=cut
=func_frm
Finds a package version based on the real pakcage verison and the file name. 
This function allows for empty versions.
=set found_version
Will hold the file version like Rxx.yy.zz.bb
=set real_version
will hold the real version as based on the package.
=cut
regex_match_version='\-(R|d|0|1|2|3|4|5|6|7|8|9)[0-9a-zA-Z._]+(\-|$|\.)'
function find_file_version() {
    local file="$1"     # (M) The file or or full file name e.g. TextPassRTR-R04.04.04.17-RHEL5-x86_64.rpm

    found_real_version=''
    # See if it s with has OS pacakge installer. and if it exists/accesible.
    if [ "${file##*.}" == "$OS_install_ext" ] ; then     # Tyre to find real version some package like jre screwed up names!
        local out="$($CMD_install_name_file "$file" 2>/dev/null)"       # remove error from output
        if [ "$out" != '' ]; then
            found_real_version=$(echo -n "$out" | $CMD_ogrep "$regex_match_version" |  cut -d'-' -f2 | head -n1)
        fi
    fi

    found_version=$(echo -n "$file" | $CMD_ogrep "$regex_match_version" |  cut -d'-' -f2 | head -n1)

    if [ "$found_version" != '' ]; then  # strip a potential ending .
        local len=$((${#found_version}-1))
        if [ "${found_version:$len:1}" == '.' ]; then
            found_version="${found_version:0:$len}"
        fi
    fi
    [ "$found_real_version" == '' ] && found_real_version="$found_version"
    # This is kind of dirty because tomcat does not use naming convention, filter .tar and .tgz
    local ext="${found_real_version##*.}"
    if [ "$ext" == 'tar' -o "$ext" == 'tgz' -o "$ext" == 'gz' ]; then
        found_real_version="${found_real_version%.*}"   # Strip the extension
    fi
}

: <<=cut
=func_frm
Finds a package version based on the package to be installed. This is done
by searching the given directory for example to C<${pfx_mm_pkg}RTR>
If no package is found then this is seen as an error and will terminate
=set found_version
Will hold the version like Rxx.yy.zz.bb
=cut
function find_pkg_version() {
    local dir="$1"      # (M) The directory to search in.
    local file="$2"     # (M) The package file to search for. E.g. ${pfx_mm_pkg}RTR or a full file.
    local optional="$3" # (O) If given then finding is optional

    log_debug "enter: $*"
    found_version=''
    local f
    for f in $dir/*$file*; do
        if [ -f $f ] || [ -d $f ]; then
            f=`echo "$f" | grep "$file"`
            if [ "$f" != '' ]; then
                found_version=`echo "$f" | $CMD_ogrep "$regex_match_version" | cut -d'-' -f2`
                if [ "$found_version" == '' ]; then
                    log_exit "Package '$file' does not have a package file associated (it should)"
                fi
                log_debug "Get package version: $dir/$file -> $found_version"
                return
            fi
        fi
    done
    if [ "$optional$found_version" == '' ]; then
        log_exit "Package '$file' does not have a package file associated (it should)"
    fi
}

: <<=cut
=func_frm
This searches current directory and finds matching file. Currently
exactly 1 file package version should be found and will terminate.
=set found_file
The found file holding the whole matching file
=cut
function find_file() {
    local file="$1"      # (M) main package name e.g. TextPassOpenSource  for TextPassOpenSource-R04.00.06.00-RHEL5.x86_64
    local src_dir="$2"   # (O) If set the directory will temporary be changed, otherwise current dir will be used
    local opt="$3"       # (O) If set the file is optional so no error if not found
    local allow_dir="$4" # (O) If a directory is aloa allowed.

    found_file=''

    # Wild-cards are indicated with a 1st * and allow anything behind the given name
    # The 1st character is much easier to check/strip!
    if [ "${file:0:1}" == '*' ]; then
        file="${file:1}"
        local wildcard='Y'
    fi

    # Change directoru if needed.
    local cur_dir=''
    if [ "$src_dir" != '' ]; then 
        if [ ! -d "$src_dir" ]; then
            log_info "Did not found file '$file', dir '$src_dir' does not exist."
            return   # No dir so empty
        fi
        cur_dir=$(pwd)
        if [ "$cur_dir" != "$src_dir" ]; then
            cmd '' $CMD_cd "$src_dir"
        else
            cur_dir=''
        fi
    fi

    local f
    local tmp
    for f in $(ls -d ${file}* 2>/dev/null); do
        if [ -d "$f" -a "$allow_dir" == '' ]; then continue; fi   # Skip if it is an sub dir.

        if [ "$wildcard" == '' ]; then
            tmp="$(echo -n "$f" | $CMD_ogrep "^$file$regex_match_version")"
        else
            tmp="$(echo -n "$f" | grep "^$file" | $CMD_ogrep "$regex_match_version")"
        fi

        if [ "$tmp" != '' ]; then
            if [ "$found_file" != '' ]; then
                log_exit "Found more then one file with name '$file'"
            fi
            found_file="$f"
        fi
    done

    if [ "$cur_dir" != '' ]; then cmd '' $CMD_cd "$cur_dir"; fi

    if [ "$found_file" == '' -a "$opt" == '' ]; then
        log_exit "Did not find package with name '$file'"
    fi

    log_info "Found file: '$found_file', search for: '$file'"
}

: <<=cut
=func_frm
Return a list with pids of processes belonging to given match.
=set found_ps
The full output of the ps command which matches the request
=set found_pids
A list (space separated) with process ids which matches the request.
=cut
function find_pids() {
    local match="$1"    # (M) the string to match (not case sensitive)
    local match2="$2"   # (O) A secondary string to match (not case sensitive)
    local excl="$3"     # (O) A string to exclude
    local excl2="$4"    # (O) A secondary string to exclude

    [ -z help ] && show_short="Find all PIDs matching '$match'"
    [ -z help ] && [ "$match2" != '' ] && show_short+=" or '$match2'"
    [ -z help ] && show_pars[1]='' && show_pars[2]=''

    local found

    check_set "$match" 'Need a search criteria for ps'
    found_ps="$(ps -ef | grep -v grep | grep -i -e "$match" | grep -i -e "$match2")"
    if [ "$excl"  != '' ]; then found_ps="$(echo -n "$found_ps" | grep -v -e "$excl")" ; fi
    if [ "$excl2" != '' ]; then found_ps="$(echo -n "$found_ps" | grep -v -e "$excl2")"; fi
    if [ "$found_ps" != '' ]; then
        found_pids=`echo "$found_ps" | sed "$SED_del_spaces" | cut -d' ' -f2 | tr '\n' ' '`
        found=$(get_word_count "$found_pids")
        log_debug "found $found pids for '$match'&'$match2': $found_pids"
    else
        found_pids=''
        found=0
        log_debug 'Did not find any matching processes'
    fi

    return $found
}

: <<=cut
=func_frm
Retrieves the useful information from a given package file.
Names should follow this: name-version-release.architecture.rpm
See also: http://www.rpm.org/max-rpm/ch-rpm-file-format.html
=func_note
This functions uses the package tool to find most of the fields
as the names are defined but still inconsistent. (e.g. os release has another .
in it). The also resolved problem in our naming conventions.
=set found_path
The path of the file relative to given (basically dirname).
=set found_file
The full base file name excluding the path.
=set found_name
The package name as it should be registered within the package tool.
=set found_version
The package version of the file.
=set found_release
The (release of the file.
=set found_arch
The architecture of the file.
=set found_ext
The extension of the file.
=set found_installed
The full name (no ext) of the installed packages if any. This requires the
chk_ins option to bet set. It will be <empty> if not found or not queried.
=set found_differ
Will only be calculated and if found_installed is set. If 0 then the package in
the file has the same version as then installed one. If the version differs then
this var will be set to 1. If not calculated then it will be empty.
=set found_comp
The name used to compare the installed to (which is deduced out of other data).
Only set if found_installed is set.
=set found_cur_verrel
The current installed version+release which is a substract of the 
found_installed. Will be set to NA if not found.
=return
0 if the file is correct or error given below
1 = file not found
2 = Wrong extension
3 = failed to analyze file 
4 = No name found
5 = No version found
6 = Wrong architecture (not in $OS_sup_arch list)
=cut
function find_file_pkg_info() {
    local file="$1"     # (M) A package path may be included
    local chk_ins="$2"  # (O) If set then the installed version is checked.
    
    log_debug "Find file pkg info: '$file'"
    
    if [ ! -r "$file" ]; then
        log_info "find_file_pkg_info: '$file' not found."
        return 1
    fi

    found_path=$(dirname  "$file")
    found_file=$(basename "$file")
    found_ext=${found_file##*.}
    found_arch=''
    found_version=''
    found_release=''
    found_name=''
    found_installed=''
    found_differ=''
    found_comp=''
    found_cur_verrel='NA'
        
    if [ "$found_ext" != "$OS_install_ext" ]; then
        log_info "find_file_pkg_info: '$found_file' wrong extension ($found_ext)."
        return 2
    fi

    # To prevent problem in naming we use most of the real package information.
    local info="$($CMD_install_name_file  --queryformat '%{NAME}:%{VERSION}:%{RELEASE}:%{ARCH}' "$file" 2>/dev/null)"
    if [ "$info" == '' ]; then
        log_info "find_file_pkg_info: Could not analyze file '$file'"
        return 3
    fi 

    found_name="$(get_field 1 "$info" ':')"
    if [ "$found_name" == '' ]; then
        log_info "find_file_pkg_info: '$found_file' did not find name."
        return 4
    fi

    found_version="$(get_field 2 "$info" ':')"
    if [ "$found_version" == '' ]; then
        log_info "find_file_pkg_info:: '$found_file' did not find version."
        return 5
    fi

    found_release="$(get_field 3 "$info" ':')"
    # No check allowed empty

    found_arch="$(get_field 4 "$info" ':')"
    is_substr "$found_arch" "$OS_sup_arch" ','
    if [ $? == 0 ]; then
        log_info "find_file_pkg_info: '$found_file' wrong architecture ($found_arch !in '$OS_sup_arch')."
        return 6
    fi

    if [ "$chk_ins" != '' ]; then
        found_installed=$($CMD_install_name $found_name | grep "$found_arch\$") # filter on found architecture
        if [ $? != 0 ]; then
            log_debug "find_file_pkg_info: '$found_name' does not seem to be installed."
            found_installed=''
        else
            # Ignore the architecture, some files have multiple rop, with same version but differen architecture )questionable)
            found_comp="$found_name-$found_version-$found_release"
            if [ "$found_comp" != "${found_installed%.*}" ]; then
                found_differ=1
            else
                found_differ=0
            fi
            found_cur_verrel=$(echo -n "$found_installed" | sed -r "s/$found_name-(.*)-(.*)\..*/\1-\2/")
        fi
    else
        found_installed=''
    fi

    log_debug "Success: '$found_file' -> p:$found_path, n:$found_name, v:$found_version, r:$found_release, a:$found_arch, e:$found_ext, i:$found_installed, d:$found_differ"

    return 0
}
