#!/bin/sh

: <<=cut
=script
This step uninstalls any package delivered by NewNet and which is part
of the package list of the automation tool.

This is actual a wrapper around the existing undo script of install_package
=script_note
It does not yet work with Linux/Solaris variants. There is only one version
.u. for undo scripts so no need to keep that in mind.
=version    $Id: uninstall_package.1.sh,v 1.4 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local name="$1"		# (M) Name of package to be un-installed.

local file='install_package.u.sh'

# Fist check if there is package specific file
find_install $name
if [ "$install_aut" != '' ] && [ -r "$install_aut/$stepfld/$file" ]; then   #= there is a package specific uninstall file
    . $install_aut/$stepfld/$file
elif [ -r "$stepdir/$file" ]; then
    . $stepdir/$file $name
else
    log_exit "Did not find step '$file'"
fi

return $?
