#!/bin/sh

: <<=cut
=script
This script is part of automatic installation/upgrade script and contains
the dynamic configuration functions. Currently packages, components and 
interfaces can be configured. The modules themselves are responsible for 
registering them the proper way. 
=script_note
This approach give a more object oriented approach which allows for multiple
version but also multiple product (like textpass/krypton). It might need 
extending in the future but it is a long way of becoming independent of 
static configuration items. The main goal: The entity and thus their programmers
know how it works and not the tool!
The actual adding of object is only allowed after the set_CFG_vars is called,
which is normally done as part of all the library initialization.
=version    $Id: 03-config_dynamic.sh,v 1.22 2017/09/12 07:22:22 fkok Exp $
=author     Frank.Kok@newnet.com
=cut


# Some standard dir definitions. Currently they do not allow for spaces!
readonly        mnt_iso='/mnt/iso'
readonly          tmp_d='/usr/tmp'
readonly   tmp_download="$tmp_d/download"
readonly        tmp_lic="$tmp_download/lic"
readonly        tmp_etc="$tmp_download/etc"
readonly        tmp_iso="$tmp_d/iso"
readonly    tmp_os_pkgs="$tmp_d/os_updates"
readonly     pfx_mm_pkg="TextPass"

readonly    map_cfg_ins='CFG_install'
readonly     map_cfg_if='CFG_interface'
readonly    map_cfg_mod='CFG_modules'
readonly    map_cfg_iso='CFG_iso'

#
# Internal Field names used in the map_cfg_ins map. Both the install packages
# as well as the components are stored in the same tree.
#
readonly        ins_name='name_ins'
readonly        ins_type='type'
readonly   ins_decl_type='type_decl'    # The declared type (by the main product)
readonly     ins_any_old='any_old'      # Set if any old pkg names
readonly         ins_dir='dir'
readonly         ins_pkg='pkg'
readonly     ins_install='install'
readonly       ins_alias='alias'
readonly     ins_aliases='aliases'
readonly       ins_order='order'
readonly      ins_prefix='prefix'
readonly     ins_require='require'
readonly     ins_aut_ver='ver_automate'
readonly     ins_cur_ver='ver_current'
readonly     ins_ins_ver='ver_installable'
readonly     ins_ins_nam='name_installable'
readonly   ins_skip_show='skip_show'
readonly      ins_childs='childs'
readonly     ins_parents='parents'
readonly     ins_options='options'

readonly        cmp_name='name_comp'
readonly      cmp_device='device'
readonly         cmp_lic='lic'
readonly   cmp_snmp_base='snmp_base'
readonly   cmp_snmp_offs='snmp_offs'
readonly   cmp_start_opt='start_option'
readonly cmp_cfg_run_par='cfg_run_par'
readonly     cmp_high_tp='high_tp'
readonly    cmp_internal='internal_comp'

readonly       intf_name='name_intf'
readonly       intf_prot='protocol'

# may be used for (ext) references
readonly INS_col_cur_version="$ins_cur_ver" 
readonly INS_col_ins_version="$ins_ins_ver"
readonly    INS_col_ins_name="$ins_ins_nam"
readonly     INS_col_high_tp="$cmp_high_tp"
readonly     INS_col_require="$ins_require"
readonly   INS_col_skip_show="$ins_skip_show"
readonly        INS_col_type="$ins_type"
readonly      INS_col_childs="$ins_childs"
readonly     INS_col_options="$ins_options"

readonly C_TYPE_SET="'',instance,zone"  # Use multiple time for checking parameters


: <<=cut
=func_int
Helper to set the install fields, see find_install for the fields.
=cut
function set_install_fields() {
    local key="$1"          # (M) The index to set, use <empty> to clear otherwise it has to exists!
    local org_alias="$2"    # (O) If set then this is the original key, only 1 depth aliasing is supported!

    local map_entry="$map_cfg_ins/$key"
    install_ent=$(map_get $map_entry $ins_name)
    if [ "$install_ent" == '' ]; then
        install_idx=0
        install_ent=''
        install_dir=''
        install_alias=''
        install_aliases=''
        install_type=''
        install_pkgs=''
        install_any_old=''
        install_act_vld=0
        install_act_pkgs=''
        install_old_pkgs=''
        install_pkg=''
        install_ins=''
        install_files=''
        install_aut_ver=''
        install_cur_ver=''
        install_ins_ver=''
        install_ins_name=''
        install_options=''
        return      # keep indent depth low
    fi

    install_idx=$(map_idx $map_cfg_ins $key)
    [ "$install_idx" == '' ] && log_exit "Install entry ($name) found but no index." # safety check
    install_dir=$(map_get $map_entry $ins_dir)
    local alias=$(map_get "$map_entry/$ins_alias" $ins_name)
    install_alias="$org_alias"
    if [ "$alias" != '' ]; then # Its an alias
        if [ "$org_alias" != '' ]; then         # multi depth aliases not supported config error
            log_exit "Multi depth aliases not supported, configuration error for: $install_ent, $org_alias"
        fi
        set_install_fields "$alias" "$key"
        install_aliases=''
        return
    else
        install_aliases=$(map_keys "$map_entry/$ins_aliases")
    fi
    install_type=$(map_get $map_entry $ins_type)
    install_pkgs=$(map_keys "$map_entry/$ins_pkg")

    install_any_old=$(map_get $map_entry $ins_any_old)
    if [ "$install_any_old" != '' ]; then
        # Separate the actual and old packages
        install_act_vld=0
        install_act_pkgs=''; local sep1=''
        install_old_pkgs=''; local sep2=''
        local pkg
        for pkg in $install_pkgs; do
            is_map_linked "$map_entry/$ins_pkg/$pkg"
            if [ $? == 1 ]; then
                install_old_pkgs+="$sep2$pkg"; sep2=' '
            else
                local act=$(map_get "$map_entry/$ins_pkg/$pkg" $ins_ins_nam)
                # Not set yet fallback to most recent, otherswiese the one set (could be an old in case old ISO)
                if [ "$act" == '' ]; then
                    install_act_pkgs+="$sep1$pkg"
                else
                    install_act_pkgs+="$sep1$act"
                    install_act_vld=1
                fi
                sep1=' '
            fi
        done
    else
        install_act_vld=1
        install_act_pkgs="$install_pkgs"
        install_old_pkgs=''
    fi
    install_pkg=$(get_field 1 "$install_act_pkgs")

    # For now translate the name into old letter mapping, to be change in the future
    install_ins=$(map_get $map_entry $ins_install)
    case $install_ins in
        $CFG_install_cond) install_files='y'; ;;
        $CFG_install_pkg ) install_files='Y'; ;;
        $CFG_install_skip) install_files='N'; ;;
        *)                 install_files='' ; ;;
    esac
    install_aut_ver=$(map_get $map_entry $ins_aut_ver)
    install_cur_ver=$(map_get $map_entry $ins_cur_ver)
    install_ins_ver=$(map_get $map_entry $ins_ins_ver)
    install_ins_nam=$(map_get $map_entry $ins_ins_nam)
    install_options=$(map_get $map_entry $ins_options)
}


: <<=cut
=func_ext
Initializes a packages. This is done by calling the init_pkg function.
=set init_ver
The version which was initialized.
=ret
0 pkg initialized (init_ver set)
1 if not found
2 already intialized (nothing changed)
=cut
function init_package() {
    local pkg="$1"      # (M) The package to initialize
    local ver="$2"      # (O) If given then this version has to be matched

    check_set "$pkg" "No package name given"
    local dir="$pkgdir/$pkg"
    if [ ! -d "$dir" ]; then
        log_debug "Ignore init, did not found package dir: '$dir'"
        return 1
    fi

    local sel_ver=''
    if [ "$ver" != '' ]; then
        if [ ! -d "$dir/$ver" ]; then
            log_debug "Ignore init, given version '$ver' not found in: '$dir'"
            return 1
        elif [ ! -d "$dir/$ver/funcs" ]; then
            log_debug "Ignore init, given version '$ver' has no funcs dir: '$dir'"
            return 1
        fi
        sel_ver=$ver
    fi

    if [ "$sel_ver" == '' ]; then
        #
        # Next find the best fitting version (highest) (assume alphabetic highest as well)
        # Skip some specials
        #
        local sdir
        local fallback=''
        for sdir in $dir/*; do
            ver=$(basename $sdir)
            [ ! -d $sdir          ] && continue
            [ "${ver:0:1}" == '.' ] && continue
            [ ! -d "$sdir/funcs"  ] && continue
            case $ver in
                'any'     ) fallback=$ver                                   ; ;; # Any preferred over fallback
                'fallback') if [ "$fallback" == '' ]; then fallback=$ver; fi; ;; # fallback if not set
                *)          if [ "$sel_ver" == '' ] && [[ "$ver" > "$sel_ver" ]]; then 
                                sel_ver="$ver"
                            fi
                            ;;
            esac
            if [ "$sel_ver" == '' ]; then sel_ver=$fallback; fi                 # Assign fallback if needed
        done
    fi

    if [ "$sel_ver" != '' ]; then
        local cur_ver="$(map_get $map_cfg_mod $pkg)"
        if [ "$cur_ver" != '' ]; then
            if [ "$cur_ver" == "$sel_ver" ]; then
                return 2
            else
                log_info "Found package '$pkg' with different ver '$cur_ver' != '$sel_ver', updating"
            fi
        fi

        func "$dir/$sel_ver/funcs" init_pkg
        ret=$?
        if [ $ret != 0 ]; then # A function was found as well.
            update_install_ent_field $pkg $ins_aut_ver $sel_ver
        fi

        # Read package specific library files
        [ -d "$dir/$sel_ver/lib" ] && read_library_files "$dir/$sel_ver/lib"

        map_put $map_cfg_mod $pkg "$sel_ver"
        init_ver=$sel_ver
        return 0
    fi
    return 1
}

: <<=cut
=func_ext
Initializes the config module. It closely depends on the require package 
so that will be initialized as well.
=cut
function init_config() {
    map_init $map_cfg_ins
    map_init $map_cfg_if
    map_init $map_cfg_iso
    map_init $map_cfg_mod

    #
    # Now walk through the package directory and initialize all current packages
    #
    log_screen_bs init 'Initialization  : '
    log_screen_bs bs 'starting'

    # Make sure the product are initialized first
    local prd
    local prd_pkgs=''
    local sep=''
    for prd in $(echo -n "$STR_products" | tr ',' ' '); do
        prd_pkgs+="$sep$pkgdir/$prd"
        sep=' '
    done

    local dir
    for dir in $prd_pkgs $pkgdir/*; do
        [ ! -d $dir ]           && continue
        local pkg=$(basename $dir)
        [ "${pkg:0:1}" == '.' ] && continue
        log_screen_bs bs "$pkg"
        init_package $pkg
        case "$?" in        # Report status for info only.
            0) log_screen_bs add " ($init_ver)"; ;;
            1) log_screen_bs add " (skipped)"  ; ;;
            2) log_screen_bs add " (done)"     ; ;;
            *) log_screen_bs add " (unknown)"  ; ;;
        esac
#        sleep 0.05   # Slightly slow down the output (disabled).
    done
    
    # Get our versions ans show the after the done
    local vers="$OS_version"
    local pkg
    local var
    local add="Functionality cannot be guaranteed, install versions as before.${nl}Or use --restart, but only if current run can be stopped!"
    for pkg in $GEN_our_pkgs_sp; do
        local ver="$($CMD_install_query $pkg | grep 'Version' | sed "$SED_del_spaces" | cut -d' ' -f3)"
        if [ "$ver" != '' ]; then
            vers="$(get_concat "$vers" "$ver" ', ')"
            var="STR_ver_$pkg"
            if [ "${!var}" != '' ]; then    # already stored, compare it
                compare_ver "$ver" "${!var}"
                if [ $? == $REQ_cmp_less ]; then
                    log_exit "Current version of $pkg is less then previously used ($ver < ${!var})$nl$add"
                fi
            fi
            export $var="$ver"      # Just store new, even if same
        else
            if [ "${!var}" != '' ]; then
                log_exit "Previous installation had version $ver for $pkg, now none.$nl$add"
            fi
        fi
    done
    log_screen_bs end "done                       ($vers)"
}

: <<=cut
=func_ext
Shows all install-able packages, which is more for debugging purpose
=cut
function show_installable_pkg() {
    local len_ent=4
    local len_aver=8
    local len_cver=7
    local len_iver=7
    local ent
    for ent in $(map_keys $map_cfg_ins sort); do
        set_install_fields $ent
        if [ "${#install_ent}" -gt "$len_ent" ]; then
            len_ent=${#install_ent}
        fi
        if [ "${#install_aut_ver}" -gt "$len_aver" ]; then
            len_aver=${#install_aut_ver}
        fi
        if [ "${#install_cur_ver}" -gt "$len_cver" ]; then
            len_cver=${#install_cur_ver}
        fi
        if [ "${#install_ins_ver}" -gt "$len_iver" ]; then
            len_iver=${#install_ins_ver}
        fi
    done

    log_screen "$nl$LOG_sep"
    log_screen "Installable packages:"
    log_screen "$LOG_isep"
    local row="%-${len_ent}s  %-${len_aver}s  %-${len_cver}s  %-${len_iver}s %-s"
    local log=`printf "$row" "Name" "Automate" "Curent" "in ISO" "PkgName"`
    log_screen "$log"

    for ent in $(map_keys $map_cfg_ins sort); do
        set_install_fields $ent
        [ "$install_ent" == '' -o "$install_alias" != '' ] && continue
        log_screen "$(printf "$row" "$install_ent" "$install_aut_ver" "$install_cur_ver" "$install_ins_ver" "$install_ins_nam")"

        # See if we have sub packages with a different version than the main/1st
        local pkg
        for pkg in $(map_keys "$map_cfg_ins/$ent/$ins_pkg"); do
            local ins=$(map_get "$map_cfg_ins/$ent/$ins_pkg/$pkg" $ins_ins_ver)
            # only show if installable version differs and showable
            if [ "$install_ins_ver" != "$ins" ] &&    
               [ "$(map_get "$map_cfg_ins/$ent/$ins_pkg/$pkg" $ins_skip_show)" == '' ]; then 
                local cur=$(map_get "$map_cfg_ins/$ent/$ins_pkg/$pkg" $ins_cur_ver)
                local p_pkg="$pkg"
                if [ "$ent" == "${pkg:0:${#ent}}" ]; then p_pkg="${pkg:${#ent}}"; fi  # strip similar prefix
                log_screen "$(printf "$row" "-$p_pkg" '' "$cur" "$ins")"
            fi
        done
    done
    log_screen "$LOG_sep$nl"
}

: <<=cut
=func_ext
Updates an install identified by entity name using field identifier.
=cut
function update_install_ent_field() {
    local ent="$1"      # (M) The ent name to update
    local field="$2"    # (M) The full field to update INS_**
    local value="$3"    # (M) The value to set
    local always="$4"   # (O) If set the the value is always put in (even if the ent does not exist yet)

    if [ "$always" == '' -a "$(map_get "$map_cfg_ins/$ent" $ins_name)" == '' ]; then
        log_debug "Did not find requesting installation ent name: $ent"
        return      # Nothing to do silently ignore
    fi
    map_put "$map_cfg_ins/$ent" $field "$value"

    # In cache cached re-update all fields
    if [ "$ent" == "$install_ent" ]; then
        set_install_fields $ent
    fi
}

: <<=cut
=func_frm
Updates an field within a package identified by package/component name using 
field identifier.
=set updated_ent
Will hold the (main)entity which has been updated, or empty if none
=cut
function update_install_pkg_field() {
    local ent="$1"      # (O) The entity name if known, left empty if not. Use to speed up searches!
    local pkg="$2"      # (M) The pkg name to update
    local field="$3"    # (M) The full field to update INS_**
    local value="$4"    # (M) The value to set

    updated_ent=''
    # Optimization try if it starts with pfx_mm_pkg
    if [ "$ent" == '' ] && [ "${pkg:0:${#pfx_mm_pkg}}" == "$pfx_mm_pkg" ]; then
        ent="$(get_field 1 "${pkg:${#pfx_mm_pkg}}" '-')"
        if [ "$(map_get "$map_cfg_ins/$ent" $ins_name)" == '' ]; then
            # Try a second level 
            ent="$(get_field 1,2 "${pkg:${#pfx_mm_pkg}}" '-')"
            if [ "$(map_get "$map_cfg_ins/$ent" $ins_name)" == '' ]; then
                ent=''      # Not found lets trigger the long search below
            fi
        fi
        [ "$ent" != '' ] && log_debug "Found optimized pkg: $pkg -> $ent"
    fi

    if [ "$ent" == '' ]; then       # First we need to find the first matching package
        local found=0
        for ent in $(map_keys $map_cfg_ins); do
            local spkg
            for spkg in $(map_keys "$map_cfg_ins/$ent/$ins_pkg"); do
                if [ "$spkg" == "$pkg" ]; then
                    log_debug "Found install pkg: $pkg -> $ent/$spkg"
                    found=1
                    break 2
                fi
                if [ "$(map_get "$map_cfg_ins/$ent/$ins_pkg/$spkg" $ins_prefix)" != '' ] &&
                   [ "$spkg" == "${pkg:0:${#spkg}}" ] ; then
                    pkg=$spkg
                    log_debug "Found install prefixed pkg: $pkg -> $ent/$spkg"
                    found=1
                    break 2
                fi
            done
        done
        if [ "$found" == 0 ]; then
            log_debug "Did not find requesting install pkg name: $pkg"
            return      # Nothing to do silently ignore
        fi
    elif [ "$(map_get "$map_cfg_ins/$ent" $ins_name)" == '' ]; then
        log_debug "Did not find requesting installation ent name: $ent"
        return      # Nothing to do silently ignore
    fi

    # Check if the selected package is actualy present
    if [ "$(map_get "$map_cfg_ins/$ent/$ins_pkg/$pkg" $ins_name)" == '' ]; then
        log_debug "Did not find requesting install ent/pkg name: $ent/$pkg"
        return      # Nothing to do silently ignore
    fi

    map_put "$map_cfg_ins/$ent/$ins_pkg/$pkg" $field "$value" 
    # Ssee if we can update the main reference, which is package with index 1
    # Or if it is currently not (set (in case the main package is not giving a value).
    # Only do this is value set. clearing the main has to be done otherwise at the moment (= not needed).
    if [ "$value" != '' ]; then
        if [ "$(map_get_key "$map_cfg_ins/$ent/$ins_pkg" 1)" == "$pkg" ] ||
           [ "$(map_get "$map_cfg_ins/$ent" $field)" == '' ]; then
            map_put "$map_cfg_ins/$ent" $field "$value"
            updated_ent=$ent
        fi
    fi
}

: <<=cut
=func_frm
Declares an installation packages to the list of packages to be expected.
=func_note
=le This seems a little bit double ass add_pkg_info can do it also. This is to be
used (directly) by the Product (like TextPass, Krypton) to declare the expected
packages. This because the framework cannot know which packages are to be
expected (fully dynamic).
=le Only CFG_type_product/system types are passed without warning if not declared.
=le Theoretically a package can have mulitple parents (especially helpers).
=cut
function declare_pkgs() {
    local names="$1"     # (M) A list of names (sp sep) which is our reference. Components should match the used names. A IP_<name> variable will be created '-' -> '_', which should be used.
    local type="$2"      # (M) The package type
    local parent="$3"    # (O) The parent if not given then the package should be declared before.

    check_set    "$names"   'Package name(s) not given'
    check_in_set "$type"    "$CFG_types"

    local name
    for name in $names; do
        local map_entry="$map_cfg_ins/$name"
        local cur="$(map_get $map_entry "$ins_name")"
        if [ "$cur" == '' ]; then
            if [ "$parent" == '' -a "$type" != "$CFG_type_product" -a "$type" != "$CFG_type_system" ]; then
                log_info "The package '$name' has not been declared before, adding anyhow."
            fi
            make_constant_var IP "$name"    # make IP_<name> var
            map_put $map_entry $ins_name $name
        elif [ "$cur" != "$name" ]; then
            log_exit "Name change ($cur -> $name) of a package is not supported "
        fi

        local dtype="$(map_get $map_entry "$ins_decl_type")"
        if [ "$dtype" == '' ]; then
            map_put $map_entry $ins_decl_type $type
        elif [ "$dtype" != "$type" ]; then
            log_exit "Type ($type) of package '$name' does not match declared ($dtype)."
        fi

        if [ "$parent" != '' ]; then       # Name make some links
            map_link "$map_cfg_ins/$parent/$ins_childs" $name   "$map_cfg_ins" $name
            map_link "$map_cfg_ins/$name/$ins_parents"  $parent "$map_cfg_ins" $parent
        fi
    done
}

: <<=cut
=func_frm
Adds an installation packages to the known list of packages. Both the package
and entity information are stored under the same identifier. The package should
have been declared (by the main product) first otherwise a log_info will be
written.
=func_note
If the package already exists then it is updated with the new information.
=cut
function add_pkg_info() {
    local name="$1"      # (M) Is our reference. Components should match the used names. A IP_<name> variable will be created '-' -> '_', which should be used.
    local type="$2"      # (M) The package type
    local dir="$3"       # (M) The expected directory (could be one but lets keep it). Use $CFG_dir_*. The alias name if an alias type
    local pkgs="$4"      # (M) A list with package associated. The 1st is the main package (No OS or version) (space separated) referred package name
    local install="$5"   # (O) Instruct if files should be installed. install or conditionally or skip auto install
    local order="$6"     # (O) An optional order, currently only used/usefull for type=CFG_type+helper. The lowest ar listed first if needed.
    local options="$7"   # (O) Additional options, not verified separated by comma's

    check_set    "$name"    'Package name not given'
    check_in_set "$type"    "$CFG_types"
    check_in_set "$dir"     "$CFG_dirs"
    check_in_set "$install" "$CFG_installs"

    declare_pkgs "$name" "$type"         # Without parent so it should be declare before

    #
    # Backward compatible code: This due to the fact that order parameter
    # Was not in older Baseline packages (introduced in mainline after 12.4)
    # By defined the default here the old baseline can still run properly with
    # the new order definition.
    # The list contains the package which were known at the moment after 12.4
    # There is no need to to add packages which are added in later versions.
    #
    if [ "$type" == "$CFG_type_helper" -a "$order" == '' ]; then
        case "$name" in
            'Adax'         ) order='100'; ;;
            'OpenSource'   ) order='200'; ;;    # The real defined order differs from the fallback
            'MySQL-Cluster') order='300'; ;;    # this is on purpose. leave it unless impact understood
            'MySQL-Server' ) order='320'; ;;    # and fixed/verified.
            'Oracle-Client') order='340'; ;;
            'Berkeley-DB'  ) order='350'; ;;
            'Tools'        ) order='500'; ;;
        esac
    fi

    local map_entry="$map_cfg_ins/$name"
    map_put $map_entry $ins_type    "$type" 
    map_put $map_entry $ins_dir     "$dir"
    map_put $map_entry $ins_install "$install"
    map_put $map_entry $ins_order   "$order"
    map_put $map_entry $ins_options "$options"
    
    local pkg
    for pkg in $pkgs; do
        map_entry="$map_cfg_ins/$name/$ins_pkg/$pkg"
        # For now add the index the versions will be stored later, filter wildcards
        if [ "${pkg:0:1}" == '*' ]; then
            # The package name is a prefix to the real package.
            # E.g. LGP has MySQL (unknown) version in it.
            pkg="${pkg:1}"
            map_put "$map_entry" $ins_prefix yes 
        fi
        map_put "$map_entry" $ins_name $pkg 
    done
}

: <<=cut
=func_frm
Adds a single package/rpm replacement, where an old package is replace by a new
name. See also the pkgs parameter of add_pkg_info
=cut
function add_pkg_replacement() {
    local name="$1"    # (M) Our internal reference name
    local old_pkg="$2" # (M) A old package name
    local new_pkg="$3" # (M) The new package name, should be defined earlier. 'obsolete' is allowed to state no longer there

    check_set    "$name"    'Package name not given'
    check_set    "$old_pkg" 'Old package name not given'
    check_set    "$new_pkg" 'New package name not given'

    if [ "$(map_get $map_cfg_ins "$name/$ins_name")" == '' ]; then
        log_exit "The package ($name) to make pkg replacement [$old_pkg->$new_pkg] does not exist."
    fi
    map_exists "$map_cfg_ins/$name/$ins_pkg/$old_pkg"
    if [ $? != 0 ]; then
        log_exit "The old package ($old_pkg) of $name already exists."
    fi
    if [ "$new_pkg" == 'obsolete' ]; then   # Always add, won't conflict
        map_put "$map_cfg_ins/$name/$ins_pkg/$new_pkg" $ins_type "$CFG_type_none" 
    fi

    map_put "$map_cfg_ins/$name" "$ins_any_old" 'yes'

    # Now link it with new. The fact it is linked makes it old.
    map_link "$map_cfg_ins/$name/$ins_pkg" "$old_pkg"  "$map_cfg_ins/$name/$ins_pkg" "$new_pkg" 
}

: <<=cut
=func_frm
Adds an alias for an package. The reference package need to exist.
=cut
function add_pkg_alias() {
    local name="$1"    # (M) The name of an existing package
    local alias="$2"   # (M) The alias name to add.

    check_set    "$name"    'Package name not given'
    check_set    "$alias"   'Alias name not given'

    if [ "$(map_get $map_cfg_ins "$name/$ins_name")" == '' ]; then
        log_exit "The package ($name) to create alias '$alias' for does not exist."
    fi
    local map_entry="$map_cfg_ins/$alias"
    local cur="$(map_get $map_entry "$ins_name")"
    if [ "$cur" == '' ]; then
        map_put $map_entry $ins_name $alias
    elif [ "$cur" != "$alias" ]; then
        log_exit "Name change ($cur -> $alias) of a alias is not supported"
    fi

    map_exists "$map_cfg_ins/$name/$ins_alias"
    if [ $? != 0 ]; then
        log_exit "The alias ($alias) refers to an alias ($name), currently not allowed."
    fi

    # Create both forward and backward reference
    map_link "$map_cfg_ins/$alias"             $ins_alias  "$map_cfg_ins" $name 
    map_link "$map_cfg_ins/$name/$ins_aliases" $alias      "$map_cfg_ins"
}

: <<=cut
=func_frm
Adds installation component information to the known list of packages/entities.
Both the package and entity information are stored under the same identifier.
=func_note
If the entity already exists then it is updated with the new information. None
defined fields will stay as is.
=cut
function add_comp_info() {
    local name="$1"      # (M) Is our reference. Components should match the used names. A IP_<name> variable will be created '-' -> '_', which should be used.
    local base_snmp="$2" # (O) The base SNMP port belonging to this entity (none instantiated). Use 0 if can be started but not managed. Empty not startable. -1 to make it internal (== no select-able as comp).
    local run_par="$3"   # (O)  The common config run parameter. Empty none, 'Y' to create, or any string as exact parameter. 
    local offs_snmp="$4" # (O) If set the offset SNMP port used for instancing. Not set no instancing allowed.

    check_set    "$name"    'Component name not given'
    local lcase="$(get_lower "$name")"

    make_constant_var C "$name"    # make C_<name> var

    local map_entry="$map_cfg_ins/$name"
    local cur="$(map_get $map_entry "$cmp_name")"
    if [ "$cur" == '' ]; then
        map_put $map_entry $cmp_name $name
    elif [ "$cur" != "$name" ]; then
        log_exit "Name change ($cur -> $name) of a component is not supported"
    fi

    # Translate a name + baseport into a start option (almost straightforward
    if [ "$base_snmp" != '' ]; then
        local opt
        if [ "${lcase:0:2}" == 'ec' -o "${lcase:0:2}" == 'xs' ]; then
            opt="${lcase:0:2}_${lcase:2}"
        elif [ "${lcase:0:3}" == 'spf' ]; then
            opt="${lcase:0:3}_${lcase:3}"
        elif [ "$lcase" == 'rtr' ]; then
            opt='textpass'                  # Really old standard
        else
            opt="tp_$lcase"
        fi
        map_put $map_entry $cmp_start_opt "--$opt"
    fi

    # Now chekc for internal and disable if so.
    if [ "$base_snmp" == '-1' ]; then
        map_put $map_entry $cmp_internal "Y"
        base_snmp=''
    fi
        
    map_put $map_entry $cmp_lic       "$(LIC_get_lic_sect $name)"
    map_put $map_entry $cmp_device    "$(MGR_get_comp_type $name)"
    map_put $map_entry $cmp_snmp_base "$base_snmp"
    map_put $map_entry $cmp_snmp_offs "$offs_snmp"
    
    if [ "$run_par" == 'Y' ]; then
        run_par="runtext${lcase}process"
    fi
    # Is string then take as is otherwise it is empty
    map_put $map_entry $cmp_cfg_run_par "$run_par"
}

: <<=cut
=func_frm
Adds an interface definition.
=cut
function add_intf_info() {
    local name="$1"     # (M) Is the interface reference. A IF_<prot>_<name> variable will be created '-' -> '_', which should be used.
    local protocol="$2" # (O) The under-laying protocol use for creating the name, empty allowed.
    local version="$3"  # (O) Currently implemnted version (not handled yet)

    check_set  "$name" 'Interface  name not given'

    local if_name=$([ "$protocol" == '' ] && echo -n "$name" || echo -n "${protocol}_$name")
    make_constant_var IF "$if_name" "$name"    # make IF_<prot>_<name> var

    local map_entry="$map_cfg_if/$name"
    local cur="$(map_get $map_entry "$intf_name")"
    if [ "$cur" == '' ]; then
        map_put $map_entry $intf_name $name
    elif [ "$cur" != "$name" ]; then
        log_exit "Change of a interface name is not supported"
    fi

    cur="$(map_get $map_entry "$intf_prot")"
    if [ "$cur" == '' -a "$protocol" != '' ]; then
        map_put $map_entry $intf_prot "$protocol"
    elif [ "$cur" != "$protocol" ]; then
        log_exit "Change of a interface protocol is not supported"
    fi
}


: <<=cut
=func_frm
Adds an MM component and package at the same time. Which give less caller
overhead and less multiplicity.
=cut
function add_mm_pkg_and_comp() {
    local name="$1"     # (M) Is our reference. Package match the used names. E.g. RTR, AMS A IP_<name> variable will be created '-' -> '_', which should be used.
    local base_snmp="$2" # (O) The base SNMP port belonging to this entity (none instantiated). Use 0 if can be started but not managed. Empty if 
    local run_par="$3"   # (O)  The common config run parameter. Empty none, 'Y' to create, or any string as exact parameter. 
    local offs_snmp="$4" # (O) If set the offset SNMP port used for instancing. Not set no instancing allowed.

    check_set "$name"

    # Product packages
    add_pkg_info  $name $CFG_type_component $CFG_dir_mm_software "${pfx_mm_pkg}$name" $CFG_install_pkg
    add_comp_info $name "$base_snmp" "$run_par" "$offs_snmp"

}


: <<=cut
=func_frm
Retrieve all applicable packages for helper in a specific 
order. 
=stdout
A list (space separated) of the help package in order of the configured order.
=cut
function get_helper_pkgs() {
    local node="$1"     # (O) The node requesting it to add node specific packages
    local allow="$2"    # (O) A list (space separated) with components/package which are allowed for the retrieval. Empty all in the data resource

    node=${node:-'<not~set>'}       # Default to node name not possible
    log_debug "get_helper_pkgs called with node='$node', allow='$allow'"
    # First make an intermediate list which we can sort
    local list=''
    for ent in $(map_keys $map_cfg_ins sort); do
        local type="$(map_get "$map_cfg_ins/$ent" "$ins_type")"
        if [ "$type" != "$CFG_type_helper" ]; then continue; fi
        log_debug "Found pkg '$ent' of type $CFG_type_helper."
        if [ "$(get_who_requires "$ent" "$allow")" == '' ] &&
           [ "$(get_which_node_need_product "$ent" "$node")" == '' ]; then 
            continue
        fi
        log_debug "pkg '$ent' is required according to its rules."
        local order="$(map_get "$map_cfg_ins/$ent" "$ins_order")"
        order=${order:-0}
        list+="$(printf "%05d:$ent" $order)$nl"
    done

    # Return the list but first order and strip order.
    echo -n "$list" | sort | cut -d':' -f2- | tr '\n' ' '
}

: <<=cut
=func_frm
Retrieves all packages names from all entities. A package can be excluded.
The wild cards will be removed. Entries are separated by given character (default
space).
=cut
function get_all_packages() {
    local exclude="$1"  # (O) A entity name to exclude
    local use_sep="$2"  # (O) The separator to use (defualt space)

    use_sep=${use_sep:-' '}
    local ent
    local pkg
    local sep=''
    for ent in $(map_keys $map_cfg_ins); do
        if [ "$ent" == "$exclude" ]; then continue; fi
        for pkg in $(map_keys "$map_cfg_ins/$ent/$ins_pkg"); do
            echo -n "$sep$pkg"
            sep="$use_sep"
        done
    done
}

: <<=cut
=func_frm
Select a specific automation installation directory of a component (if any)
This was made separate from B<find_install> to allow future complexity and the
fact this is always optional
=func_note
Only to be called after a call to B<find_install> as data is taken from
install_* variables.
=set install_aut
The path where the specific component is installed.
=set install_ver
The version of the specific component requested
=cut
function select_install_aut() {
    local name="$1"         # (M) The name of the entitiy which defines the directory
    local req_ver="$2"      # (O) If given then this version is select

    if [ "$install_idx" == '' ] || [ "$install_idx" -le '0' ]; then
        log_exit "No packages selected"
    fi
        
    # Find the ver, either required, or to be installed or fallback
    local ver=${req_ver:-$install_ins_ver}
    if [ "$ver" == '' ] || [ ! -d "$pkgdir/$name/$ver" ]; then
        ver='fallback'
    fi

    # This is for now with local package directories. 
    # The package directory either reflect to the scripts or to an installed
    # package  in /opt/TextPass/$1/<version> with a link.
    install_aut="$pkgdir/$name/$ver"
    install_ver=$ver
    
    if [ ! -d $install_aut ]; then
        if [ "$req_ver" != '' ]; then
            log_exit "Failed to find requested version: $name-$ver"
        fi
        install_aut=''
        install_ver=''
    fi
}

: <<=cut
=func_frm
Searches for an install-able packages in the install array.
Normally the package needs to be found (and exits if not) unless
the I<optional> parameter is set.
=set install_idx
The index in the install array. 0 if not found.
=set install_ent
The install entity name. Empty if not found.
=set install_type
The type of entry. N=normal package, A=alias, R=related package (dif versions).
=set install_dir
The installation directory. Empty if not found.
=set install_pkgs
All the packages separate by a space. Empty if not found.
=set install_any_old
If set to any value then there are old values.
=set install_act_vld
If set (1) then active package are determined based on the found packages or
no old packages avaible. So active is valid.
=set install_act_pkgs
All the active packages separate by a space. Empty if not found.
=set install_old_pkgs
All the old (replaced) packages separate by a space. Empty if not found.
=set install_pkg
The first (active) install package name. Empty if not found.
=set install_files
Instruction to state if the files should be installed. Y=install,
=set install_aut_ver
The verison of the pkg automation scripts (set if collected)
=set install_cur_ver
The current version (set if collected)
=set install_ins_ver
The version to be installed (set if collected)
=set install_ins_nam
The name of the package to be installed (set if collected). Could be same as key
but might differ in case of name change.
=set install_row
The full row of data for this install package.
N=Only extract.
=cut
function find_install() {
    local name="$1"     # (M) The name (1st parameter to find), version will be stripped
    local optional="$2" # (O) If set to none empty then the package is allowed not to be found.

    [ -z help ] && show_ignore=1

    local req_ver=$(get_field 2 "$name" ':')  # get ver or empty
    name=$(get_field 1 "$name" ':')

    # A small optimization if comp_ent is already selected
    if [ "$name" != '' -a "$name" == "$install_ent" -a "$install_alias" == '' ]; then
        select_install_aut "$install_ent" "$req_ver"        #   Select the most recent version
        log_debug "found_install: found cached '$name', $install_idx, $install_aut"
        return
    fi
    
    set_install_fields $name
    if [ "$install_ent" != '' ]; then
        log_debug "Found install '$name'"
        select_install_aut "$install_ent" "$req_ver"
    elif [ "$optional" == '' ]; then
        log_exit "Did not found install-able package '$name', wrong configuration?"
    else
        set_install_fields
    fi
}

: <<=cut
=func_frm
Check if the given package is a alias
=return
1 if alias otherwise 0
=cut
function is_pkg_alias() {
    local name="$1"     # (M) The name to find

    map_exists "$map_cfg_ins/$name/$ins_alias"
    return $?
}

: <<=cut
=func_frm
Retrieve the main package name. Which translates the alias into a main package.
=func_note
Currently only 1 depth is supported. This could be changed by making it
recursive. Which is not needed at this point of time.
=stdout
The main package name. Could be the same an the given name if it was the
main package. Empty if package is not found at all.
=cut
function get_main_pkg() {
    local name="$1"     # (M) The name to find

    # An alias is a link to a package which should contain the main name
    # Only 1 depth is allowed
    local alias="$(map_get "$map_cfg_ins/$name/$ins_alias" "$ins_name")"
    if [ "$alias" != '' ]; then
        echo -n "$alias"
    else
        echo -n "$(map_get "$map_cfg_ins/$name" "$ins_name")"
    fi
}

: <<=cut
=func_frm
Retrieves the childs belong to a package. Wrapper to shields of logic.
=stdout
The childs (space sep), or empy if none
=cut
function get_childs() {
    local pkg="$1"  # (M) The package to find the childs forward
    
    map_keys "$map_cfg_ins/$pkg/$ins_childs"
}

: <<=cut
=func_frm
This will walk through all packages of one entity and calls a given
function. If the update field is given and the function returns a value
in $func_return then that field will be update. The function is called
with the entity name and the package name
=cut
function update_install_info_ent() {
    local ent="$1"      # (M) The entity to execute func for
    local func="$2"     # (O) The name of a function to call, empty to skip call and set result as empty
    local field="$3"    # (O) the field o update,should be =<char>:

    set_install_fields $ent
    if [ "$install_ent" != '' -a "$install_alias" ==  '' ]; then  # Only real packages not aliases
        local dir="$install_dir"        # Keep copy are it might change (due to func call)
        local pkg
        for pkg in $install_pkgs; do
            func_return=''
            [ "$func" != ''  ] && func "$func" "$ent" "$dir" "$pkg"
            [ "$field" != '' ] && update_install_pkg_field $ent $pkg "$field" "$func_return" # need to update (also empty)
        done
    fi
}

: <<=cut
=func_frm
This will walk through all the install-able packages and calls a given
function. If the update field is given and the function returns a value
in $func_return then that field will be update. The function is called
with the entity name and the package name
=cut
function update_install_info() {
    local func="$1"     # (M) The name of a function to call
    local field="$2"    # (O) the field o update,should be =<char>:

    local ent
    for ent in $(map_keys $map_cfg_ins sort); do
        update_install_info_ent "$ent" "$func" "$field"
    done
}

: <<=cut
=func_frm
Return the directory where the current installed component resides.
This is normally something like /opt/TextPass/<comp>/<release>
=func_note
The function does not searches the the directory for the best fit. It uses
the current installed component version to find the directory
=stdout
The directory, the component is expected to be found (error so it should be filled
=cut
function get_install_dir() {
    local ent="$1"  # (M) The enity to find from $C_*

    find_install "$ent"
    if [ "$install_cur_ver" == '' ]; then
        log_exit "Did not find a currently installed version for $ent"
    fi
    local dir="$MM_ins/$ent/$install_cur_ver"
    if [ ! -d "$dir" ]; then
        log_exit "Did not find installation dir for $ent: $dir"
    fi
    echo -n "$dir"
}

: <<=cut
=func_frm
Searches for a component in the ent_cfg array.
=set comp_idx
The found component index. 0 if not found.
=set comp_ent
The component entity name (short letter code). Empty if not found.
=set comp_lic
The license section. empty if not license is needed.
=set comp_device
Identifies if this is a device manageable by the MGR.
=set comp_snmp_port
The SNMP port which can be used to communicate with this device.
0 if no communication is possible. This is the base port so not directly usable
for instancing (to be implemented).
=set comp_snmp_offs
The SNMP offset port to be used for instancing. Empty if instancing not allowed.
=set comp_tp_opt
Option used for tools like tp_start.
=set comp_cfg_run
The common config run parameter.
=set comp_internal
Identifies if this is an internal component. 'Y' means not select-able as a
componentn in the data-file.
=cut
function find_component() {
    local name="$1"     # (M) The name of the component to find
    local man_inf="$2"  # (O)If set then the component needs to be found, this is used as extra info.
    
    # A small optimization if comp_ent is already selected
    if [ "$name" == "$comp_ent" ]; then
        return
    fi

    local map_entry="$map_cfg_ins/$name"
    comp_ent=$(map_get $map_entry $cmp_name)
    if [ "$comp_ent" == '' ]; then
        # Not found is it a problem?
        if [ "$man_inf" != '' ]; then
            log_exit "Mandatory component '$name' not found, extra info: $man_inf"
        fi

        comp_idx=0
        comp_ent=''
        comp_lic=''
        comp_device='N'
        comp_snmp_port=0
        comp_snmp_offs=0
        comp_tp_opt=''
        comp_cfg_run=''
        comp_internal='N'

        log_debug "Skipping '$name' as it is not identified as an internal component."
        return
    fi

    comp_idx=$(map_idx $map_cfg_ins $name)
    [ "$comp_idx" == '' ] && log_exit "Comp entry ($name) found but no index." # safety check
    comp_lic=$(      map_get $map_entry $cmp_lic         )
    comp_device=$(   map_get $map_entry $cmp_device   'N')
    comp_snmp_port=$(map_get $map_entry $cmp_snmp_base 0 )
    comp_snmp_offs=$(map_get $map_entry $cmp_snmp_offs   )
    comp_tp_opt=$(   map_get $map_entry $cmp_start_opt   )
    comp_cfg_run=$(  map_get $map_entry $cmp_cfg_run_par )
    comp_internal=$( map_get $map_entry $cmp_internal 'N')
            
    log_debug "Found component $comp_idx:$name,$comp_lic,$comp_device,$comp_snmp_port,$comp_tp_opt,$comp_cfg_run"
}

