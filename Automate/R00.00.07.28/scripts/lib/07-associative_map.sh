#!/bin/sh

: <<=cut
=script
This script contains a simple but effective way of preventing the use
of associative array/map which are only supported within BASH 4+. In some
case the array can be prevented or the code is not needed under for the
BASH3 compatible system.
=script_note
* I do not want everything logged (this is internal) so the cmd function is 
not (always used).
* There are limitations on the key names. They should be what is allowed
for files names. A '/' is allowed, which automatically create sub paths
* The file has to be initialized after the generic_vars as it uses $OS_*
* After a normal exit the whole MAP data will be cleaned. This can be
prevent by using the --keep_tmp flag. In case of an error the keep flag
should also be set. This can be handy in investigating the MAPs
* As it was found out later the translation from associate arrays to this
asssociative map gave a side problem. In case the keys used space. This was only
be used by the NDB config and therefor found late (focus shifted to upgrade).
It would have a performance impact (subshell checking) when fixed in this module
just for this exception. Therefore it is decide to fix in the caller code.
Advice to use a '=' for a space characters.
* This code does not allow any spaces fro map, submaps or keys!
=version    $Id: 07-associative_map.sh,v 1.11 2017/03/08 14:01:12 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

MAP_dir="$OS_shm/Automate-Map-Dir"
MAP_initialized=0

: <<=cut
=func_int
Return the keys file. Which is handy for maintenance and potential future change.
=stdout
The full keys file of this map.
=cut
function map_get_key_file {
    local map="$1"  # The name of the map (may include sub maps

    local base=$(basename "$map")
    if [ -h "$MAP_dir/$map" ]; then # It is a link and dest exists.
        # Handle links properly which became visible due to cluster name change Bug 25571
        local real="$(readlink -e "$MAP_dir/$map" 2> /dev/null)"
        if [ "$real" != '' ]; then
            echo -n "$(dirname "$real")/.$(basename "$real")"    # A new name should have been found
            return
        fi
        # It is not good, but not worth a awaring, but it should be recorded
        log_info "Did not resolve link to '$MAP_dir/$map', fallback to default"
    fi

    if [ "$base" == "$map" ]; then # no subdirs
        echo -n "$MAP_dir/.$base"
    else
        echo -n "$(dirname "$MAP_dir/$map")/.$base"
    fi
}

: <<=cut 
=func_frm
Initializes a named map. All current data will be removed. All existing data
will be erased.
=cut
function map_init() {
    local map="$1"          # (M) The name of the map.

    [ -z help ] && show_ignore=1

    check_set "$map" "The map should be defined."
    if [ $MAP_initialized == 0 ]; then      # Real firts time whipe out base dir!
        map_cleanup
        cmd "Creating MAP data directory : $MAP_dir" $CMD_mkdir "$MAP_dir"
        MAP_initialized=1
    fi
        
    log_info "Clearing and Creating MAP data for: $map"
    $CMD_rm "$MAP_dir/$map"
    $CMD_mkdir "$MAP_dir/$map"
    echo -n '' > $(map_get_key_file $map)   # Key file for quick get_keys
}

: <<=cut
=func_frm
Function to cleanup all the stored MAP data.
=cut
function map_cleanup() {
    [ -z help ] && show_ignore=1

    if [ -d "$MAP_dir" ]; then
        cmd "Clearing MAP data directory : $MAP_dir" $CMD_rm "$MAP_dir"
    fi
}

: <<=cut
=func_frm
Put information into the a map entry specified by a key.
=optx
At least 2 optional values are needed. The 2nd last is the key, the last]
is the value to store. Any optional in front of it are part of the map.
=func_note
Either the map may contain '/' or the sub parameters are used. In any case the
sub keys are properly registered in the key file.
This use of / or separate parameters is up to to user.
=cut
function map_put() {
    local map="$1"  # (M) The name of the map. Use slash for sub maps/keys
    local key="$2"  # (M) The key of the entry to store, could also contain a part of sub part.
    local val="$3"  # (O) The value to store, empty will erase the current content

    [ -z help ] && show_ignore=1    # internal admin

    local sdir="$map/$key"      # Filter name to get final key
    map="$(dirname "$sdir")"
    key="$(basename "$sdir")"

    if [ ! -d "$MAP_dir/$map" ]; then   # Quick way to prevent loop on existing key
        local sub
        local smap=''
        for sub in $(echo -n "$map" | tr '/' ' '); do
            if [ ! -d "$MAP_dir/$smap/$sub" ]; then
                log_debug "Adding directory+key for '$MAP_dir/$smap/$sub'"
                $CMD_mkdir "$MAP_dir/$smap/$sub"
                echo "$sub" >> $(map_get_key_file $smap)
            fi
            smap=$(get_concat "$smap" "$sub" '/')
        done
    fi

    if [ "$val" == '' ]; then
        if [ -r "$MAP_dir/$map/$key@" ]; then    # does it exist, if so remove
            $CMD_rm "$MAP_dir/$map/$key@"
            $CMD_sed -i "\|^$key\$|d" "$(map_get_key_file $map)"
        fi
    else
        if [ ! -r "$MAP_dir/$map/$key@" ]; then      # Add to key file if no existed
            echo "$key" >> $(map_get_key_file $map)
        fi
        echo -n "$val" > "$MAP_dir/$map/$key@"
    fi
}

    
: <<=cut
=func_frm
Retrieves information from a specific map entry. If the entry is not found then
empty is returned
=stdout
The information of the selected key.
=cut
function map_get() {
    local map="$1"  # (M) The name of the map.
    local key="$2"  # (M) The key of the entry to retrieve
    local def="$3"  # (O) A default used if not set

    [ -z help ] && show_ignore=1    # internal admin

    if [ -r "$MAP_dir/$map/$key@" ]; then
        cat "$MAP_dir/$map/$key@"
    else
        echo -n "$def"
    fi    
}

: <<=cut
=func_frm
Links a new entry into an existing entry form the same or another map. If
the entries already exists and the link location is different then it will
be silently re linked. Link can only be created on submaps not on physical keys.
Links allow to use map_get/put functions as if it is real data. But also means
that changes in the linked_to data affects the data in the created link.

=cut
function map_link() {
    local src_map="$1"  # (M) The name of the source map to link from
    local src_sub="$2"  # (M) The name of the source sub map (which will be created as key)
    local dst_map="$3"  # (M) The name of the destination map to link to
    local dst_sub="$4"  # (O) The name of the destination sub map, default to src_sub if not given

    dst_sub=${dst_sub:-$src_sub}
    if [ ! -d "$MAP_dir/$src_map" ]; then           # Make sure the src map exists
        $CMD_mkdir "$MAP_dir/$src_map"
    fi
    if [ -d "$MAP_dir/$src_map/$src_sub" ]; then    # The link already exists so remove first
        $CMD_rm "$MAP_dir/$src_map/$src_sub"
    else
        echo "$src_sub" >> $(map_get_key_file "$src_map")
    fi
    if [ ! -d "$MAP_dir/$dst_map/$dst_sub" ]; then   # The destination should exist
        log_exit "map_link, destination '$dst_map/$dst_sub' does not exist."
    fi
    $CMD_ln "$MAP_dir/$dst_map/$dst_sub" "$MAP_dir/$src_map/$src_sub"
    check_success "execute map link '$src_map/$src_sub' -> '$dst_map/$dst_sub'" "$?" 'no_info'
}

: <<=cut
=func_frm
Checks if a specific map/submap exists
=return
1 if entry exists, otherswise 0
=cut
function map_exists() {
    local map="$1"  # (M) The name of the (sub)map.

    [ -d "$MAP_dir/$map" ] && return 1 || return 0
}

: <<=cut
=func_frm
Retrieves the key using a specific index.
=stdout
The  key of the given index or empty if not found.
=cut
function map_get_key() {
    local map="$1"  # (M) The name of the map.
    local idx="$2"  # (M) The index to retrieve the base indicates the start
    local base="$3" # (O) Use a different base/start idx then the default of 1. 

    if [ "$base" != '' ]; then
        idx=$((idx - base + 1))      # internal base 1
    fi

    local kf=$(map_get_key_file $map)
    [ ! -r "$kf" ] && return # no (key)entry so emtpy

    echo -n "$(grep -n '.*' "$kf" | grep "^$idx:" | cut -d':' -f2-)"
}

: <<=cut
=func_frm
Gets all the keys currently available within a MAP.
=stdout
The list with keys separated by a space .
=cut
function map_keys() {
    local map="$1"      # (M) The name of the map.
    local sorted="$2"   # (O) If set then the keys are sorted.

    local kf=$(map_get_key_file $map)
    if [ ! -r "$kf" ]; then  # no (key)entry so empty
        :
    elif [ "$sorted" == '' ]; then
        cat "$kf" | tr '\n' ' '        | $CMD_sed "s/\(.*\)./\1/"       # Strip last space as well
    else
        cat "$kf" | sort | tr '\n' ' ' | $CMD_sed "s/\(.*\)./\1/"       # Strip last space as well
    fi  
}

: <<=cut
=func_frm
Get the amount of entries in within a MAP
=stdout
The amount of entires in the MAP. 0 if none.
=cut
function map_cnt() {
    local map="$1"  # (M) The name of the map.

    local kf=$(map_get_key_file $map)
    if [ ! -r "$kf" ]; then  # no (key)entry so zero
        echo -n '0'
    else
        cat "$kf" | wc -l
    fi
}

: <<=cut
=func_frm
Get the current index of an entry. This is not valid after entries are deleted
from the map./ So make sure you know is has become static/growing!
=stdout
The index of an entry, indexes start counting from 1, unless a different base
is given. Empty if the entry was not found at all.
=cut
function map_idx() {
    local map="$1"  # (M) The name of the map.
    local key="$2"  # (M) The key of the entry to translate into an idx
    local base="$3" # (O) Use a different base/start idx then the default of 1. 

    local kf=$(map_get_key_file $map)

    [ ! -r "$kf" ]   && return     # no (key)entry so empty

    local idx=$(grep -m 1 -n "^$key\$" "$kf" | cut -d':' -f 1)
    [ "$idx" == '' ] && return     # entry not found

    if [ "$base" != '' ]; then
        idx=$((idx - 1 + base))
    fi
    echo -n "$idx"
}

: <<=cut
=func_frm
Find (sub)map entries which have a key with a specific name. It is possible
to match the key against a specific value as well.
=stdout
A list with sub map name having this property. Separated by a comma.
If the key is in the root map then a '.' will be returned.
=cut
function map_find_maps_with_key() {
    local map="$1"   # (M) The name of the map.
    local field="$2" # (M) The field name to search
    local match="$3" # (O) If given then the field has to (exact) match as well

    local dir="$MAP_dir/$map/"
    local dlen=${#dir}
    local found="$(find "$dir" -name "$field\@" -print)"
    if [ "$found" == '' ]; then return; fi

    
    local path
    local ret=''
    IFS=$nl; for path in $found; do IFS=$def_IFS
        local sub="$(dirname "${path:$dlen}")"
        if [ "$match" == '' ]; then     # Accept if exists, no check
            # Substract the leading path and the trailing key
            ret="$(get_concat "$ret" "$sub" ',')"
        else
            local val="$(map_get "$map/$sub" "$field")"
            if [ "$val" == '' ]; then
                log_exit "Could not get just retrieved key '$map/$sub/$field@'"
            fi
            if [ "$val" == "$match" ]; then
                ret="$(get_concat "$ret" "$sub" ',')"
            else
                log_debug "Found a key ($map/$sub/$field@) but not match '$val' != '$match'"
            fi
        fi
    IFS=$nl; done; IFS=$def_IFS

    echo -n "$ret"
}


: <<=cut
=func_frm
Check if the given map entry is a link or a real directory/file
=ret
1 if it is a linl, 0 if not (or not found
=cut
function is_map_linked() {
    local map="$1"   # (M) The name of the (sub)map.

    [ -h "$MAP_dir/$map" ] && return 1 || return 0
}
