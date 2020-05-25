#!/bin/sh

: <<=cut
=script
This step configures the component in the MGR if needed/reuqested.
=version    $Id: configure_components.1.sh,v 1.2 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com

=feat Devices can configure themselves in the MGR
Each available component has the ability to configure itself in the manager. 
When a component has the function B<configure_component> defined it will be called
once the device and MGR is ready to be configured.
=cut

MGR_is_master
if [ $? == 0 ]; then
    return $STAT_not_applic
fi

#
#=* See if there is a component which has a device configuration file 
#=- to do more complex configuration. The component decided if and what
#=- additional steps to do.
#=search_func configure_component
#=skip_control
#
for comp in $dd_all_comps; do
    CONFIG_steps=''
    func $comp define_vars                      # make sure vars are always set
    func $comp configure_component
    if [ "$CONFIG_steps" != '' ];   then 
        # There are steps requested, first check if the components are running
        execute_step 0 "verify_Running TextPass comp $comp"
        queue_step "$CONFIG_steps"
        execute_queued_steps                        # Function might have queued steps
    fi
done

return $STAT_passed

