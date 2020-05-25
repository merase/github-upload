#!/bin/sh

: <<=cut
=script
This function get the version of a specific package.
=set func_return
Will hold the collected version or empty if package not found or no version could be collected.
=version    $Id: get_pkg_version.1.sh,v 1.13 2017/07/04 12:52:01 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local ent="$1"      # (M) The internal entity identifier (primary key of install table)
local dir="$2"      # (M) The directory where the package resides
local pkg="$3"      # (M) The package name to verify

local s_pkg=''
local version=''
local add_str=''        # <str> to add as prefix
local add_rel=0         # 1 means to add relase field (for old STV)
local correct_rel=0     # 1 means to check for a correct release (starting with R and len 12)
func_return=''          # Reset func_return to empty

# There s is a special exception for the STV which does not use a single package
# It also uses a wrong naming convention (causing it to loose 4th digit).
# Other exeptions added as well. I'm not happy with it but it works
local field='Version'
case "$pkg" in
    TextPassSTV)        pkg="${pkg}util"     ; correct_rel=1  ; add_str='R'; add_rel=1; ;;
    TextPassOpenSource) pkg='TextPassLibxml2'; field='Release'; add_str='R'; ;; # ouch ugly but so be it.
    LiS)                                    # Use streams command
        which streams >> /dev/null 2>1
        if [ "$?" == '0' ]; then
            version=$(streams status | cut -d' ' -f4 | cut -d':' -f 1 | cut -d'-' -f 2)
        fi
        s_pkg=$pkg
        ;;
    atmii|hdc|qcx|sscf|sscop)           # Look for copyright file
        local file="$OS_adax/$pkg/Copyright"
        if [ -e "$file" ]; then
            version="$($CMD_cat "$file" | grep Version | grep delta | cut -d' ' -f 4)"
        fi
        s_pkg="$pkg"    # Indicate package is processed (single exit checking)
        ;;
    apache-tomcat)   # this is not so nice, as it is a tarball and is supposed to be installed in a directory, use TC_henv (only one version) to find it
        if [ "$TC_henv" == '' ]; then
            func $IP_Tomcat define_vars
        fi
        if [ "$TC_henv" != '' ]; then
            local path="$(get_field 2 "$(grep "^ *${TC_henv} *=" $OS_rc_profile)" '=')"
            if [ -d "$path" ]; then     # Only valid if path exists
                version="${path##*-}"    # currently the version is the end after last -, so let use that easy approach (until it is screwed up)
                s_pkg="$pkg"    # Indicate package is processed (single exit checking)
            else
                log_info "The $TC_henv points to '$path, but that does not exists. Not installed?"
            fi
        fi
        ;;
    OS-Baseline)
        version=$OS_version     # Already collected before
        s_pkg="$pkg"    # Indicate package is processed (single exit checking)
        ;;
    '') log_exit "Missing pkg name." 
        ;; 
esac

if [ "$s_pkg" == '' ]; then     # Not yet processed
    if [ "${pkg:0:1}" == '*' ]; then    # A wild search on generic query first
        local fpkg="$($CMD_ins_query_all | grep -m 1 ${pkg:1})"
        if [ "$?" != '0' -o "$fpkg" == '' ]; then
            log_info "Did not find package for $ent:$pkg"
            return
        fi
        pkg=$fpkg
    fi

    # This works for linux and might need to change (move to Linux script) if Solaris is introduced
    local output        # Do not put the local in fron of next line it influences $?
    output="$($CMD_install_query $pkg)"
    if [ $? == 0 -a "$output" != '' ]; then    # okay to continue
        version=`echo "$output" | grep $field | sed "$SED_del_spaces" | cut -d' ' -f3`
        if [ "$version" != '' ]; then
            if [ $correct_rel == 1 -a "${version:0:1}" == 'R' -a ${#version} == 12 ]; then
                add_str=''
                add_rel=0
            fi
            if [ "$field" == 'Release' ]; then # get 1st 4 digit pairs
                version=$(echo -n "$version" | cut -d '.' -f1-4)
            elif [ $add_rel == 1 ]; then
                local add_dig=`echo "$output" | grep 'Release' | sed "$SED_del_spaces" | cut -d' ' -f3`
                if [ "$add_dig" != '' ]; then version="$version.$add_dig"; fi
            fi
            version="$add_str$version"
            s_pkg=$pkg
        else
            log_info "Found package but could not retrieve version info for $ent:$pkg"
        fi
    else
       log_debug "Package $ent:$pkg is not installed"
    fi 
fi

if [ "$s_pkg" != '' ]; then
    if [ "$version" != '' ]; then
        log_debug "Found package $ent:$s_pkg, it has version: $version"
    else
        log_debug "Package $ent:$s_pkg is not installed"
        return
    fi
fi

func_return="$version"

return 0
