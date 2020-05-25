#!/bin/sh

: <<=cut
=script
This step is able execute a specific tp_tool on several components.

=script_note
DISCLAIMER you can most likely break it with a wrong config. Don't do it is
expected to be created/correct. This makes the code so much easier!

=script_note
If all is given then all known installed components are executed one by one
If you want something like restart use tp_start (which does that, or 2 steps:
first stop then start).

=script_note
Keep in mind that this bypasses the func <comp> service scripts to allow
more then standard.E.g. the LGP should not be upgrading (this is used in install)

=version    $Id: execute_tp.1.sh,v 1.6 2017/02/17 14:55:27 fkok Exp $
=author     Frank.Kok@newnet.com
=man1 tp_tools
The tp_tool to call.
=opt2 comp
=le multiple component names (not --tp_ams but AMS) separated by space
=le all of or all installed components
=le <empty> for configured ones
=cut

# Just call the internal help function
tp $*

return $STAT_passed
