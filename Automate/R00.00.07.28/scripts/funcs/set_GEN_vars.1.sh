#!/bin/sh
: <<=cut
=script
This function sets the default values for generic generic variables which 
can be overrule in the [generic] section of the data file.
=version    $Id: set_GEN_vars.1.sh,v 1.4 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

# These are just default, overrule in data file [generic] if needed
GEN_mysql_tz='GMT'          # Time zone used by MySQL (for STV)
GEN_ntp_server=''           # Define to enable NTP
GEN_ss7_needed=0            # Needed for an Traffic Element
GEN_ssl_needed=0            # Need SSL certificates
GEN_shortcode_len=5         # The default shortcode_length as use by the MGR/system [3..6]
GEN_typ_reserved_mem=8192   # The typical amount of memory in MB reserved for MM processes, will scale down if needed
GEN_min_reserved_mem=1024   # The absolute minimal reserved memory in MB for MM processes

GEN_our_pkg_pfx='TextPass'  # Our(for Automate tool) current package prefix which could change
GEN_our_pkg_automate="${GEN_our_pkg_pfx}Automate"
GEN_our_pkg_baseline="${GEN_our_pkg_pfx}Baseline"
GEN_our_pkgs_sp="$GEN_our_pkg_automate $GEN_our_pkg_baseline" # Space separated list with our packages
GEN_our_pkgs_pi="$(echo -n "$GEN_our_pkgs_sp" | tr ' ' '|')"            # Same list but pipe separated.

readonly Upgraded_hardware='Gen8 Gen9'
