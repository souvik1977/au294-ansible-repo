#!/bin/bash

# --- CONFIRMATION ---
echo "=========================================================="
echo "      WARNING: FORCEFUL DELETION OF LAB ENVIRONMENT       "
echo "=========================================================="
read -p "Are you absolutely sure you want to delete ALL VMs (except *pxe-server*)? [y/N]: " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cleanup aborted by user."
    exit 0
fi

# --- FETCH ALL DOMAINS ---
# Retrieves all VM names regardless of their power state (running, paused, shutoff)
ALL_DOMAINS=$(virsh list --all --name | sed '/^\s*$/d')

# --- LOOP AND DESTROY ---
for VM in $ALL_DOMAINS
do
    # Protection rules to skip the PXE environment
    if [[ "$VM" == *"pxe-server"* || "$VM" == *"controller"*  ]]; then
        echo "--> Skipping protected environment: $VM"
        continue
    fi

    echo "----------------------------------------------------------"
    echo "Purging Virtual Machine: $VM"
    echo "----------------------------------------------------------"

    # 1. Force stop the VM if running
    VM_STATE=$(virsh domstate "$VM" 2>/dev/null || echo "shutoff")
    if [ "$VM_STATE" != "shutoff" ]; then
        echo "Stopping active process..."
        virsh destroy "$VM" || true
    fi

    # 2. Delete all snapshots cleanly from libvirt tracking
    # Explains metadata and deletes chronological branches
    SNAPSHOTS=$(virsh snapshot-list "$VM" --name 2>/dev/null | sed '/^\s*$/d' || true)
    if [ -not -z "$SNAPSHOTS" ]; then
        echo "Removing structural VM snapshots..."
        for SNAP in $SNAPSHOTS; do
            virsh snapshot-delete "$VM" "$SNAP" --metadata || true
        done
    fi

    # 3. Undefine the VM configuration profile and wipe associated storage disks
    echo "Undefining configuration and purging storage volumes..."
    virsh undefine "$VM" --remove-all-storage --snapshots-metadata --nvram || true

    echo "Purged $VM successfully."
done

echo "=========================================================="
echo "Cleanup completed. Non-PXE environment has been removed."
echo "=========================================================="

