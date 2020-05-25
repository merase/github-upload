#!/bin/sh

: <<=cut
=script
This functions gather information about a package before it is actually installed.
The automation data is stored in the package itself. In some case this could
lead to a chicken and an egg (e.g. upgrade where required info is needed).
If that is the case then this function retrieves the data from the linux rpm.
=version    $Id: gather_automate_data.1.Linux.sh,v 1.1 2014/11/07 12:15:38 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local pkg="$1"      # (M) The package name to extract

# For Linux we have to use rpm2cpio to extract the file
find_file "$pkg"
rpm2cpio TextPassAutomate-R00.00.00.01-RHEL5-x86_64.rpm | cpio -it "*pkg*" 2>/dev/null 
cmd_hybrid '' "$CMD_rpm2cpio $found_file | cpio -idmv