read -p "Enter the target disk with full path :" TARGET_DISK

# Search all configurations for the disk path
ATTACHED_VM=$(virsh list --all --name | while read -r VM; do
    if [ -n "$VM" ] && virsh domblklist "$VM" | grep -q "$TARGET_DISK"; then
        echo "$VM"
        break
    fi
done)

if [ -n "$ATTACHED_VM" ]; then
    echo "ERROR: Cannot remove disk! It is currently locked/attached to VM: $ATTACHED_VM"
else
    echo "SUCCESS: Disk is completely orphaned. Proceeding with safe removal..."
    virsh vol-delete --pool default --vol "$TARGET_DISK"
fi
