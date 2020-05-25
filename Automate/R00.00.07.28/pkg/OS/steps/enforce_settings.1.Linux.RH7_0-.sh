#!/bin/sh

: <<=cut
=script
This script will verify some required settings and change them if needed 
(enforce it). This means that no changes are made unless really needed.

Rest to be filled in the comparision and runlevels do work differently in
RHEL 7 therfore this enforce steps has been disabled for now.
=version    $Id: enforce_settings.1.Linux.RH7_0-.sh,v 1.2 2017/02/22 09:05:50 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

#TODO: Decide what/how/if we want to do this.
return $STAT_not_applic
