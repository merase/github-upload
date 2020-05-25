#!/bin/sh

: <<=cut
=script
This step configure the OS TimeZone settings.
=version    $Id: configure_Time-Zone.1.Linux.-RH6_0.sh,v 1.2 2017/02/15 13:35:29 fkok Exp $
=author     Frank.Kok@newnet.com
=help_todo Older version pre RHEL 6.0, not verified at this moment.
=cut


check_mandatory_genvar GEN_os_tz

# This is a GUI base tool not suitable for autation. The command line does not
# seem to work. So I've made a smal script which executes the underlying
# library to do it stuff. We are not doing it.

# This will similate the linux cmd: /usr/sbin/timeconfig
local tmp="$(mktemp)"
cat > $tmp << EOF
#!/usr/bin/python2

import sys
sys.path.insert(0, '/usr/share/system-config-date')

import timezoneBackend
timezoneBackend = timezoneBackend.timezoneBackend()

timezone='$GEN_os_tz'
timezoneBackend.writeConfig(timezone, 1, 0)
EOF

# Next execute the python script
cmd 'Configure OS Time-Zone' $CMD_python $tmp

remove_temp $tmp 