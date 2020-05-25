#!/bin/sh

: <<=cut
=script
This script contains simple helper functions which are related to the 
installation command. Newly done by yum (most generic name), but it is
also used for the backwards compatibility with rpm.
commands.
=version    $Id: 10-helper_yum.sh,v 1.2 2017/06/08 11:45:10 fkok Exp $
=author     Frank.Kok@newnet.com

=feat make use of yum in RHEL7 environments
In RHEL7 R&D started to use yum and a repository to install and upgrade
packages. This in stead of the more loosely coupled rpm approach. A smoothly
integration is supplied by this module.

=cut

readonly YUM_aut_repo="$OS_yum_repos/newnet-automate.repo"

YUM_supported=0     # Will hold support, will stay read/write don't write yourself

: <<=cut
=func_frm
Will set the proper install command based on the OS and if the package actually
supports yum. This anticipates that in the early transition not all packages
can be done using yum. And if if they would then this is the location where
it smoothly moves on.

To-do this it check the following:
- Is yum enabled (and thus support in ISO release
- Does this package for this version requires checking
  - If checking required then check_yum_support function is called to determine

=remark
it is preparing for a future as the future is behind is lacking behind.
=set CMD_install
=set CMD_ins_freshen
=set CMD_ins_upgrade
=set CMD_uninstall
=ret
1 if yum is selected otherwise 0
=cut
function set_install_comands() {
    local name="$1"         # (O) The name of the package, if none then cmds set to yum support
    local ver="$2"          # (O) The version to check (if known)
    local force_rpm="$3"    # (O) If set then always use the older rpm.

    [ -z help ] && [ "$name" == '' ] && [ "$force_rpm" == '' ] && show_short="Set the proper install commands based on generic YUM support"
    [ -z help ] && [ "$name" != '' ] && [ "$force_rpm" == '' ] && show_short="Set the proper install commands using generic and package needs '$name:$ver'"
    [ -z help ] &&                      [ "$force_rpm" != '' ] && show_short="Forcing install commands to use RPM"
    [ -z help ] && show_trans=0

    local yum=$YUM_supported
    [ "$force_rpm" != '' ] && yum=0

    if [ $yum !=  0 ] && [ "$name" != '' ]; then
        find_install "$name" 'opt'
        if [ "$install_ent" != '' -a "$install_options" != '' ] ; then
            is_substr "$CFG_opt_check_yum_sup" "$install_options" ','
            if [ $? == 1 ]; then
                YUM_check_support=0
                func "*$name" check_yum_support "$ver"  # Try calling the optional function itself
                [ $? != 0 ] && yum=$YUM_check_support || yum=0   # Only overrule if func defined, otherwise none support (easier upgrade)
            fi
        fi
    fi

    # This will only alter the RPM/YUM commands. It is no use at this point
    # to alter the RPM query commands
    if [ $yum == 0 ]; then
            CMD_install="$CMD_rpm_install"
        CMD_ins_freshen="$CMD_rpm_ins_freshen"
        CMD_ins_upgrade="$CMD_rpm_ins_upgrade"
          CMD_uninstall="$CMD_rpm_uninstall"
    else
            CMD_install="$CMD_yum_install"
        CMD_ins_freshen="$CMD_yum_ins_freshen"
        CMD_ins_upgrade="$CMD_yum_ins_upgrade"
          CMD_uninstall="$CMD_yum_uninstall"
    fi

    return $yum
}

: <<=cut
=func_int
Checks if yum is supported,(call once), needs;
- RH7
- Yum installed (on RH7 it should or exit)
=set
YUM_supported [0|1], make it read-only afterward so call once 
=cut
function init_yum_support() {
    local not_found=$?

    if [ $OS_prefix != 'RH' ] || [ $OS_ver_numb -lt 70 ]; then
        YUM_supported=0
        log_info "No support for yum, wrong OS version: $OS_version, [$OS_prefix,$OS_ver_numb]"
    else
        # We should have yum at this stage check it!
        [ "$CMD_yum" == '' ] && prg_err "This is RH7+ but no CMD_yum defined"
        add_cmd_require $CMD_yum
        [ ! -d "$OS_yum_repos" ] && log_exit "Did not find yum repo directory ($OS_yum_repos), check yum installation"
        YUM_supported=1
    fi
    log_info "init_yum_support : YUM_supported=$YUM_supported"

    set_install_comands
}
init_yum_support        # And init it once

return 0

