#!/bin/sh

: <<=cut
=script
This script will explain (and do some simple checks) for complex upgrade 
procedures.
=script_note
It was chosen to put the explanation in the Automate because the steps file
are maintained here as well. Another location could be beetter but not persee
the most fitting. E,g, SPF for SubProvPlat, however that conaitn more then SPF
alone.
=version    $Id: explain_upgrade_procedure.1.sh,v 1.3 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com
=cut

local what="$1"    # (M) What to explain, see item below
local action="$2"  # (O) An exra action e.g. halt

check_in_set "$what"   'SubProvPlat,Rerun_Generic'   # Could be extended in the future
check_in_set "$action" "'',halt"

local gen_cfg='Step-Upgrade-Generic.cfg'

check_upgrade_plan_readable

local exp_cfg=''
[ "$action" == '' ] && exp_cfg="$(basename $STR_step_file)"        #=! Take from current step file running

if [ "$what" == 'SubProvPlat' ]; then

    if [ "$dd_prov_plat_nodes" == '' ]; then    #= No nodes for SUB Platform
        log_exit "No nodes for Subscriber Provisioning Platform, no use to continue"
    fi

    [ "$exp_cfg" == '' ] && exp_cfg='Step-Upgrade-Subscriber-Provisioning-Platform.cfg'     #=! Fallback to default expected.

    #
    # Check if we have a valid upgrade plan and that either the SPF or the 
    # MySQL-Cluster is in it.
    #
    #=skip_control
    local found=0
    local line
    IFS=''; while read line; do IFS=$def_IFS;      # The file is ordered, sw_pkg come at the end.
        local pkg=$(get_field 3 "$line")
        [ "$pkg" == "$IP_MySQL_Cluster" -o "$pkg" == "$IP_SPF" ] && ((found++))
    IFS=''; done < $STR_upg_plan_file; IFS=$def_IFS
    if [ $found == 0 ]; then    #= No products in need of this procedure
        log_exit "Did not find any mandatory products of Subscriber Provisioning Platform 
to be upgrades please check upgrade plan an the necessity to run this special
procedure."
    fi

    #=* A node list is required  from all nodes having subscriber element sw, which are
    #=- SPF, NDB-nodes, NDB-mysql, NDB-mgm, NDB-API users, being:
    #=- SSI, XS-[CPY|FWD|DIL|BWL|ARP|SIG], other future API users.
    #=skip_control
    local nodes=''
    local node
    for node in $dd_prov_plat_nodes; do
        nodes+="    * $node$nl"
    done
    
    log_wait "${COL_bold}Subscriber Provisioning Platform upgrade procedure$COL_def
${COL_bold}Normal procedure :$COL_def
 * Only run this when instructed (by .e.g '$gen_cfg')
 * See Limitations below what the effect is if run separately.
 * Make sure all nodes below has passed '$gen_cfg'
$nodes * Make sure that all above nodes are running automate with step_file, like:
   * # ${COL_bold}automate -s $exp_cfg --restart --sw_iso=$STR_sel_sw_iso$COL_def
 * The tool will only continue when all started.
 * The tool will synchronize actions when needed. 
 * When the tool is finished then the regular upgrade procedure should be 
   restarted (first on OAM). This may be done in sequence. E.g. like:
   * # automate -s $gen_cfg --restart --sw_iso=$STR_sel_sw_iso
 
${COL_bold}Limitations :$COL_def
 * This procedure should not do the actual ${COL_bold}kernel$COL_def upgrade
   nor ${COL_bold}generic entities$COL_def, that has to be done by e.g. '$gen_cfg'.
 * Normally the kernel upgrade is done before this procedure, it could be done 
   during or afterwards unless software prohibits it.
 * Master/Slave cluster has to be implemented. It starts with a single master.
 
${COL_bold}Remarks :$COL_def
 * Dependent components will only be upgraded if needed. However they will not 
   be restarted and stay in stopped state. This because the rest of the 
   components might need upgrading.
 * E.g. SSI should only upgrade if his part of the db scheme changed.
 
${COL_bold}Please read and understand the above.$COL_def
" 120
elif [ "$what" == 'Rerun_Generic' ]; then
    log_manual "Please Re-run Generic Upgrade Procedure" "The next step (up to user decision) is to run the Generic Upgrade procedure
with the same sw_iso. This will upgrade any none Subscriber Provisioning 
related entities. If this upgrade went okay then it will not ask for these
upgrades step again. E.g. use:
 # automate -s $gen_cfg --restart --sw_iso=$STR_sel_sw_iso"
else
    log_exit "Don't know what ($what) to explain, programming error!"
fi

if [ "$action" == 'halt' ]; then
    finish_step $STAT_info
    log_screen "Halting current automate please execute above procedure with
step_file : $exp_cfg."
    exit 1      # Do not use 0 as more actions are needed.
fi
    
return $STAT_passed
