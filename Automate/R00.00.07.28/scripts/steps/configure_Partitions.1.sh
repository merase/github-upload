#!/bin/sh

: <<=cut
=script
This step configure the Disk Partitions. 
=le During installing it will configure and format them
=le During upgrade it will restore and check partition data
=le During verification it can check if all partition are recognized.
=brief Configure or restores the partitions after an OS installation. Can verify assignments as well.
=script_note
This is a very complex script, the main task will be described, however you
will need in linux administration tools to complete the tasks. This has
in the past already been shielded of by lnxcfg, which also does not have
and in-depth explanation. So use lnxcfg or look at the actual command in the 
scripts or log-files.
=fail
Make sure all disk should be defined as it should according to our standard
element installation. Use administration tools and lnxcfg to fix. After that
the step could be skipped.
=version    $Id: configure_Partitions.1.sh,v 1.21 2017/02/15 13:35:30 fkok Exp $
=author     Frank.Kok@newnet.com

=feat check partition definition
Can verify if all disk partition names are as expected and therefore valid
for an upgrade.

=feat restore partition
In case of an upgrade it is possible to recover existing partitions.

=feat partition disks
All disk except the root partition can be partitions. This includes defining
the logical drives in the smart array (linux) formatting disk, and mount the 
devices. The partition scheme will be most optimal for the component combination.
=cut

local run_type="$1" # (O) If set then should match STR_run_type, for extra safety
local what="$2"     # (O) Optional instruction on what to do. E.g. 'check'

if [ "$run_type" != '' -a "$run_type" != "$STR_run_type" ]; then #= Data file is not configured for requested run_type
    log_exit "The Current run_type ($STR_run_type) does not match requested ($run_type), safety stop!"
fi
check_in_set "$what" "'',check"

#
# A slightly more flexible approach is taken then the Element approach.
# Though it boils down to the same and the capbility to make it all work
# without additional configuration.
# The current mechnims does not bother about disk size (yet)).
#
# First check which partition are needed
#
# Define the partitions (potentially needed.
# The number in front of the mount point is our internal number which
# can be used to identify a potential fallback disk (in case not enough
# disk available. The disk creation will be tried in this order. So mounts with
# multiple disk should be put in the end
#
# The assignment of part need is as follows;
# <#phy disks>:<fallback disk#><RAID#>:<mnt point>:<ent> <ent>")
#
# The fallback will be a recursive mechanism. so dbamslog: 2 - > 1 -> 0 (* cannot fallback and is mandatory)

# FKO: This is not the best location nor best naming, should be fixed!
#=* The [$Upgraded_hardware] have new disk layout if so then use_new_configuration=1
#=skip_control
local use_new_configuration=0
local hw_prd_name="$(get_systen_var $SVAR_product_name)"
for hardware in $Upgraded_hardware; do
    is_substr "$hardware" "$hw_prd_name"
    if [ $? == 1 ]; then
        use_new_configuration=1
        break;
    fi
done

#=skip_control
local -a partneed 
partneed[0]="*:*:*:/var/TextPass:$C_SYS"              # This is the part is the last fallback and should be available already (remember some VMS migth not have it!)
partneed[1]="2:0:1:/data:$C_MGR $C_STV $C_BAT $C_RTR" # MGR db / STV db / BAT db / RTR LOGs|CDRs 
partneed[2]="2:1:1:/dbamsstore:$C_AMS"                 # AMS store
partneed[3]="2:2:1:/dbamslog:$C_AMS"                  # AMS log
partneed[4]="2:1:1:/var/log/STV:$C_STV"               # STV log
if [ "$use_new_configuration" == "1" ]; then              # use 8 disk for RAID5
    partneed[5]="8:1:5:/dblgp:$C_LGP"                     # LGP db
    partneed[6]="8:5:5:/dbspf:$C_SPF $C_SPFCORE"          # SPF db
else
    partneed[5]="6:1:5:/dblgp:$C_LGP"                     # LGP db
    partneed[6]="6:5:5:/dbspf:$C_SPF $C_SPFCORE"          # SPF db
fi
partneed[7]="2:1:1:/backup:$C_MGR"                    # Backup on OAM/MGR
local numpart="${#partneed[@]}"

local -a renames        # An array with renames which happened in the past
renames[0]="/stvlog:/var/log/STV"
renames[1]="/var/backup:/backup"
renames[2]="/var/adm/STV:/var/log/STV"
local numren="${#renames[@]}"

#
#=* Whenever [ $what == 'check' ], check if all current labels are recognized.
#=- This means that the labels are equal to the mount points.
#=- This is mandatory for an OS-Hop upgrade and called by verify_File-System
#=skip_control
#
if [ "$what" == 'check' ]; then
    [ "$run_type" != "$RT_upgrade" ] && log_exit "Invalid call: 'configure_Partitions <$run_type> $what', only allowed for '$RT_upgrade'"

    func OS collect_Partition_config
    local fail=0
    local inuse
    for inuse in $PART_inuse; do
        local dev=$(get_field 1 "$inuse" ':')
        local lab=$(get_field 2 "$inuse" ':')

        # Label happens to be mounts points (lucky us) find if it is needed
        local part=0
        local ok=0
        while [ $ok == 0 -a "$part" -lt "$numpart" ]; do
            local mnt=$(get_field 4 "${partneed[$part]}" ':')
            [ "$lab" == "$mnt" ] && ok=1
            local i=0
            while [ $ok == 0 -a "$i" -lt "$numren" ]; do
                [ "$lab" == "$(get_field 1 "${renames[$i]}" ':')" ] && ok=1
                ((i++))
            done
            ((part++))
        done
        if [ $ok == 0 ]; then
            log_warning "Found unexpected drive '/dev/$dev', label '$lab'"
            ((fail++))
        fi
    done
    if [ $fail != 0 ]; then
        log_warning "Found $fail unexpected disk(s), what todo:$nl* Fix 'mount-point' and 'labels' or;$nl* request to add a logical exception or;$nl* continue and accept a potential failure and manual fix in a later stage." 30
    fi
    return $STAT_passed
fi

#
#=* Find out which partitions are needed, Set them to [N]ot needed.
#=- This is done using the components and the available disks.
#=- See the standard roll-out model if it needs to be done by hand.
#=skip_control
#
local comp
local cnt=0
part=0
while [ "$part" -lt "$numpart" ]; do
    local fnd=0
    for comp in $(get_field 5 "${partneed[$part]}" ':'); do
        is_component_selected $hw_node $comp
        if [ $? != 0 ]; then
            log_debug "Needed: $part (${partneed[$part]})"
            fnd=1
            break       # Do not continue to search for any comp in this part
        fi
    done
    if [ $fnd == 0 ]; then
        partneed[$part]="N:$(get_field 2- "${partneed[$part]}" ':')"
    fi
    cnt=$((cnt + fnd))
    ((part++))
done
if [ $cnt == 0 ]; then          #= No additional partitioning needed
    return $STAT_not_applic     # None needed so whole step not applicable
fi

#
#=* See if there are partition to be reused or formatted.
#
func OS collect_Partition_config
local reuse
for reuse in $PART_reuse; do
    local dev=$(get_field 1 "$reuse" ':')
    local lab=$(get_field 2 "$reuse" ':')

    case "$STR_run_type" in
        "$RT_install" | "$RT_recover" )      # Always initialize disks
            execute_step 0 "configure_File-System OS clean $dev"
            ;;
        "$RT_upgrade" )
#=skip_until_marker
#=- Some older system require disk renaming, which is done during to process.
#=- Found disk (using label are reused)
#=- Unknown disk are tried to be reused (not cleaned for safety)
#=execute_step configure_File-System OS reuse $dev $mnt
            # Label happens to be mounts points (lucky us) find if it is needed
            part=0
            while [ "$part" -lt "$numpart" ]; do
                # The label could be an old label in case we rename it
                local i=0
                while [ "$i" -lt "$numren" ]; do
                    if [ "$lab" == "$(get_field 1 "${renames[$i]}" ':')" ]; then
                        local olab="$lab"
                        lab="$(get_field 2 "${renames[$i]}" ':')"
                        cmd "Changing disk-label (and new mountpoint) '$olab' -> '$lab'" $CMD_e2label "/dev/$dev" "$lab"
                        break
                    fi
                    ((i++))
                done

                local mnt=$(get_field 4 "${partneed[$part]}" ':')
                if [ "$lab" == "$mnt" ]; then
                    execute_step 0 "configure_File-System OS reuse $dev $mnt"
                    partneed["$part"]="R:$(get_field 2- "${partneed[$part]}" ':')"
                    break
                fi
                ((part++))
            done
            if [ "$part" -ge "$numpart" ]; then
                # Not found so theoretical wipe it. However lets always accept is as it
                # execute_step 0 "configure_File-System OS clean $dev"
                log_warning "Found unexpected drive '$dev' label '$lab', reusing it!"
                execute_step 0 "configure_File-System OS reuse $dev $lab"
            fi
#=skip_until_here
            ;;
        *) log_warning "Found reusable disk but don't know what to do with it in '$STR_run_type' mode."; ;;        
    esac
done

#
#=* Next see if the partition are already available. If so set them to [D]one
#=- Verifies the partitions by looking at the mount points
#=- Some partition are mandatory, other might create a fallback directory.
#=skip_control
#
local logneed=''
part=0
while [ "$part" -lt "$numpart" ]; do
    local mnt=$(get_field 4 "${partneed[$part]}" ':')
    if [ "${partneed[$part]:0:1}" == 'N' ]; then
        : # skip
    elif [ "$(get_filesys_for_mnt "$mnt")" != '' ]; then
        log_info "Partition for $mnt already available."
        partneed["$part"]="D:$(get_field 2- "${partneed[$part]}" ':')"
    elif [ "$(get_field 1 "${partneed[$part]}" ':')" == '*' ];  then
        [ $HW_skip_raid_cfg == 0 ] && log_exit "Mandatory partition $mnt, should have been available."
        cmd "Create fallback for $mnt" $CMD_mkdir "$mnt"
        partneed["$part"]="D:$(get_field 2- "${partneed[$part]}" ':')"
    else
        logneed=$(get_concat "$logneed" $(get_field 1-3 "${partneed[$part]}" ':') "$nl")
    fi
    ((part++))
done
if [ "$logneed" == '' ]; then   #= All partitions are available
    return $STAT_done           # ALl has been done before, so state as done
fi


#
#=* RAID partitioning only done if not upgrade and if hardware allows it.
#=- E.g. Virtual Hardware does not allow raid configuration.
#=- Create all the RAID array as described in the implementation plan.
#=skip_control
#
if [ "$STR_run_type" !=  "$RT_upgrade" -a "$HW_skip_raid_cfg" == 0 ]; then 
    #
    # See if there are any partition not allocated. If so then assign them. 
    # This is not normal behavior. so give a warning ase the size may be incorrect
    #
    func OS collect_Partition_config
    local unalloc=$(get_word_count "$PART_unalloc")
    local free=$(get_word_count "$PART_free")
    local skip=$((unalloc + free))
    log_debug "Skipping $skip (= $unalloc + $free)"
    #
    # First configure the RAID-Array. We do that by requesting a logical disk
    # for every required mount. This may lead to not enough disks. Therefore it
    # will be executed based on the smallest amount of disk first. The incompatible
    # setup is normally a Full element or some kind of test setup which will not
    # need the full disk capacity. Otherwise, get more disks!
    #
    for log_disk in $(echo -n "$logneed" | sort); do
        local pars="RAID$(get_field 3 "$log_disk" ':') $(get_field 1 "$log_disk" ':')"
        if [ "$skip" == 0 ]; then
            execute_step 0 "configure_RAID-Array OS $pars"
        else
            log_debug "skipping $pars as there are unallocated disks"
            ((skip--))
        fi 
    done

    # 
    # All disk are current configured with only 1 partition
    #
    func OS collect_RAID_config     # Make sure we have the latest disk info (only once needed)
    local disk
    for disk in `ls $OS_hd_dev/$OS_all_hd_dev`; do
        is_substr "$(basename "$disk")" "$PART_skip"
        if [ $? == 0 ] &&  [[ ! $(ls $disk${OS_part_pfx}[0-9] 2>/dev/null) ]]; then
            execute_step 0 "configure_Disk OS $disk full"
        fi
    done
fi

#
#=* Get the free disk and assign the file systems
#=- Walk through current free list and decide if they are free or not.
#=- Initialize fully new disk (the one added by RAID cfg above).
#=execute_step configure_File-System OS new <dev> <mnt>
#=skip_control
#
func OS collect_Partition_config
local free_disks=$PART_free
part=0
while [ "$part" -lt "$numpart" ]; do
    disks=$(get_field 1 "${partneed[$part]}" ':')
    case $disks in
        D|N|F) : ;;
        [123456789])
            if [ "$free_disks" == '' ]; then    # Need fallback, register do later
                partneed[$part]="F:$(get_field 2- "${partneed[$part]}" ':')"
            elif [ "$STR_run_type" ==  "$RT_upgrade" ]; then
                log_warning "Found a free, but not used during upgrade: $(get_field 1 "$free_disks")"
                free_disks=$(get_field 2- "$free_disks")
            else
                execute_step 0 "configure_File-System OS new $(get_field 1 "$free_disks") $(get_field 4 "${partneed[$part]}" ':')"
                free_disks=$(get_field 2- "$free_disks")
            fi
            ;;
        *) log_exit "Strange disk($disks) definition par part($part): ${partneed[$part]}"; ;;
    esac
    ((part++))
done

#
#=* Create the fallbacks if needed
#=- If partition not found then a fallback directory is created.
#=- Falback are created on configured fallback disk order (fixed config)
#=- E.g. if /backup is not a partition: (1st-fb=/data, 2nd-fb=/var/textpass) 
#=-   mkdir /data/backup
#=-   ln /data/backup /backup
#=skip_control
#
part=0
while [ "$part" -lt "$numpart" ]; do
    if [ "${partneed[$part]:0:1}" == 'F' ]; then
        local mnt=$(get_field 4 "${partneed[$part]}" ':')
        if [ -d "$mnt" -o -L "$mnt" ]; then
            partneed[$part]="e:$(get_field 2- "${partneed[$part]}" ':')"
            log_warning "The intended mount directory ($mnt) already exists, skipping"
        else
            local bname=$(basename "$mnt")
            local fb=$(get_field 2 "${partneed[$part]}" ':')
            while [ "$fb" != '*' ]; do    # Try all the fallback until found or none
                local fdir="$(get_field 4 "${partneed[$fb]}" ':')"
                if [ -d "$fdir" ] && [ ! -L "$fdir" ]; then   # dir/mnt exist and not linked by itself
                    if [ -d "$fdir/$bname" ] ;then              # dest already exists
                        if [ "$STR_run_type" ==  "$RT_upgrade" ]; then
                            log_info "Found fallback destination ($fdir/$bname) as expected."
                        else
                            log_warning "The fallback destination exists ($fdir/$bname), not creating"
                        fi
                    else
                        if [ "$STR_run_type" ==  "$RT_upgrade" ]; then
                            log_warning "Did not found fallback destination ($fdir/$bname), which is strange, creating"
                        fi
                        cmd '' $CMD_mkdir "$fdir/$bname"
                    fi
                    cmd '' $CMD_ln "$fdir/$bname" "$mnt"
                    partneed[$part]="d:$(get_field 2- "${partneed[$part]}" ':')"
                    local warn="Created fallback directory (no mount) for '$mnt' -> '$fdir/$bname'"
                    if [ "$HW_skip_raid_cfg" == 0 ]; then
                        log_warning "$warn"         # Always a warning in case RAID support
                    else
                        log_screen_info '' "$warn"  # Screen info in case no RAID support
                    fi
                    break       # Done with this fallback
                fi
                fb=$(get_field 2 "${partneed[$fb]}" ':')
            done
        fi
    fi
    ((part++))
done

#
#=* Internally a sanity check happens to see if all fallbacks are actually created
#=- which is unexpected and thus an generates.
#=skip_control
#
part=0
while [ "$part" -lt "$numpart" ]; do
    if [ "${partneed[$part]:0:1}" == 'F' ]; then
        log_exit "Could not resolved all necessary fallback mount points!"
    fi
    ((part++))
done

return $STAT_passed
