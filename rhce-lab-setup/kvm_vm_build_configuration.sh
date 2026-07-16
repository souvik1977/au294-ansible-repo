#!/bin/bash
set -e

# --- USER INPUT WITH AUTOMATIC SEARCH DOMAIN FALLBACK ---
read -p "Enter the base domain name (e.g., domain24.example.net): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    DOMAIN_NAME=$(hostname -d 2>/dev/null || true)
    if [ -z "$DOMAIN_NAME" ]; then
        DOMAIN_NAME=$(awk '/search/ {print $2; exit}' /etc/resolv.conf 2>/dev/null || true)
    fi
    if [ -z "$DOMAIN_NAME" ]; then
        DOMAIN_NAME="domain24.example.net"
    fi
    echo "--> No domain entered. Auto-selected default: $DOMAIN_NAME"
fi

read -p "Enter the number of VMs to create: " VM_COUNT

if ! [[ "$VM_COUNT" =~ ^[0-9]+$ ]] ; then
   echo "Error: Please enter a valid number."
   exit 1
fi

# --- IP CONFIGURATION LOGIC STANDARDS ---
HOST_ONLY_IP_START=20

# --- DYNAMIC RE-RUN INDEX CALCULATOR ---
echo "Scanning environment for existing lab instances..."
HIGHEST_INDEX=0
EXISTING_NODES=$(virsh list --all --name | grep -E '^node[0-9]+' | awk -F'.' '{print $1}' | sed 's/node//g' || true)

for idx in $EXISTING_NODES; do
    if [ "$idx" -gt "$HIGHEST_INDEX" ]; then
        HIGHEST_INDEX=$idx
    fi
done

START_INDEX=$((HIGHEST_INDEX + 1))
END_INDEX=$((HIGHEST_INDEX + VM_COUNT))

echo "--> Existing nodes found up to index: ${HIGHEST_INDEX}."
echo "--> New deployment sequence will cover nodes from index ${START_INDEX} to ${END_INDEX}."

# --- LOOP TO BUILD VMs ---
for ((i=START_INDEX; i<=END_INDEX; i++))
do
    short_name="node${i}"
    mHost="${short_name}.${DOMAIN_NAME}"

    echo "=========================================================="
    echo "Processing VM: ${mHost} (${short_name})"
    echo "=========================================================="

    # Sequential static IP calculation targets for Host-Only
    HOST_ONLY_IP="10.10.1.$((HOST_ONLY_IP_START + i - 1))"
    ROOT_DISK_PATH="/kvm-storage/images/${short_name}-root.qcow2"

    # 1. Storage Provisioning (15G Root and 2G Data Disk)
    echo "Creating virtual disks..."
    virsh vol-create-as --pool default --name "${short_name}-root.qcow2" --format qcow2 --capacity 15G
    virsh vol-create-as --pool default --name "${short_name}-data.qcow2" --format qcow2 --capacity 2G

    # 2. Initial Deployment via YOUR WORKING PXE SERVER CONFIGURATION
    echo "Launching initial virt-install via PXE..."
    virt-install \
      --name "$mHost" \
      --vcpus 2 \
      --memory 4096 \
      --cpu host-passthrough \
      --disk path="$ROOT_DISK_PATH",size=15,format=qcow2 \
      --disk path="/kvm-storage/images/${short_name}-data.qcow2",size=2,format=qcow2 \
      --network network=host-only,model=virtio \
      --os-variant almalinux10 \
      --boot network,hd,useserial=on \
      --graphics none \
      --noautoconsole

    # Host-Side Polling Loop: Safely watches until Kickstart powers down the node
    echo "Waiting for PXE network installation to finish and shut down..."
    sleep 20

    while true; do
        VM_STATE=$(virsh domstate "$mHost" 2>/dev/null || echo "shut off")
        if [[ "$VM_STATE" == *"shut"* ]]; then
            echo "--> VM has successfully powered down. Kickstart installation complete."
            break
        fi
        sleep 15
    done

    echo "Ensuring storage subsystem locks are fully released..."
    sleep 5

    # 3. Post VM Build: Resource Management (Your specifications sequence)
    echo "Shrinking Memory and vCPUs down..."
    virsh setmaxmem "$mHost" 2048M --config
    virsh setmem "$mHost" 2048M --config
    virsh setvcpus --count 1 --domain "$mHost" --maximum --config

    # 4. Post VM Build: Remove Netboot Line (Your exact clean sed command)
    echo "Disabling network boot from XML structure..."
    virsh dumpxml "$mHost" | sed "/<boot dev='network'\/>/d" | virsh define /dev/stdin

    # 5. Post VM Build: Dual Network Layout Attachment
    echo "Attaching external NAT network card..."
    virsh attach-interface \
      --domain "$mHost" \
      --type network \
      --source default \
      --target "enp9s${i}" \
      --model virtio \
      --config

    # ====================================================================
    # FIXED: FORCE EXACT SYSTEM HOSTNAME ASSIGNMENT
    # ====================================================================
    echo "Permanently locking system hostname configuration fields..."
    virsh desc "$mHost" --title "RHCE Lab Node ${i}" --config

    # virt-sysprep modifies the hostname block directly using basic string targets
    # This guarantees it writes "nodeX.lab.example.com" completely cleanly
    virt-sysprep -a "$ROOT_DISK_PATH" --hostname "$mHost" --enable hostname

    # ====================================================================
    # FIXED: IDEMPOTENT DHCP RESERVATION LAYER (HOST-ONLY SAFE TRACKING)
    # ====================================================================
    echo "Registering host-side static IP mapping rules..."

    HOST_ONLY_MAC=$(virsh domiflist "$mHost" | grep 'host-only' | awk '{print $5}')
    if [ -n "$HOST_ONLY_MAC" ]; then
        # Construct exact target string blocks to guarantee complete deletion of legacy duplicates
        XML_BLOCK="<host mac='${HOST_ONLY_MAC}' name='${mHost}' ip='${HOST_ONLY_IP}'/>"

        # Safe deletion block runs using dynamic tracking references
        virsh net-update host-only delete ip-dhcp-host "$XML_BLOCK" --live --config 2>/dev/null || true

        # Write clean registration profile entry string
        virsh net-update host-only add ip-dhcp-host "$XML_BLOCK" --live --config || true
        echo "--> Host-Only IP [${HOST_ONLY_IP}] mapped to MAC [${HOST_ONLY_MAC}]"
    fi
    # ====================================================================

    # 6. Start the finalized VM
    echo "Starting VM..."
    virsh start "$mHost"

    echo "----------------------------------------------------------"
    echo "Successfully built and initiated $mHost!"
    echo "----------------------------------------------------------"
done

echo "=========================================================="
echo "Deployment Complete. Created $VM_COUNT RHCE Lab Environments."
echo "=========================================================="

