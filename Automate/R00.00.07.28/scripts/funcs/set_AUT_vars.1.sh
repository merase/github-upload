#!/bin/sh
: <<=cut
=script
This function sets the generic AUT variables which are valid for the Automation
tool. Not all AUT_* vars are in here, perhaps because they are localized. 
However if same data is et twice then it should be in this file.
=version    $Id: set_AUT_vars.1.sh,v 1.2 2015/06/10 07:13:01 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

readonly AUT_tmp_mnt_dir="$OS_mnt/Automate"
readonly AUT_boot_data_dir='automate-boot-data'
readonly AUT_down_data_dir='download-data'
readonly AUT_upgr_data_dir='automate-update-data'

