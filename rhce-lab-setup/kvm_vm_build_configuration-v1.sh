#!/bin/bash
set -euo pipefail

# ==========================================================
# RHCE KVM Lab VM Builder
#
# Goals:
# 1. Create KVM VMs using PXE installation
# 2. Assign deterministic host-only IPs in 10.10.1.0/24
# 3. Attach NAT as second network
# 4. Set guest hostname equal to KVM VM name
#
# Example:
# VM name    : node1.domain24.example.net
# Hostname   : node1.domain24.example.net
# Host-only  : 10.10.1.20
# NAT IP     : DHCP from libvirt default network
# ==========================================================

# -----------------------------
# User configurable values
# -----------------------------
HOST_ONLY_NET="host-only"
NAT_NET="default"

HOST_ONLY_SUBNET_PREFIX="10.10.1"
HOST_ONLY_IP_START=20

STORAGE_POOL="default"

OS_VARIANT="almalinux10"

ROOT_DISK_SIZE="15G"
DATA_DISK_SIZE="2G"

INITIAL_VCPUS=2
INITIAL_MEMORY_MB=4096

FINAL_VCPUS=1
FINAL_MEMORY_MB=2048

PXE_WAIT_INITIAL_SECONDS=20
PXE_CHECK_INTERVAL_SECONDS=15
STORAGE_LOCK_WAIT_SECONDS=5

# -----------------------------
# Helper functions
# -----------------------------
fail() {
    echo "ERROR: $*" >&2
    exit 1
}

info() {
    echo "--> $*"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

network_is_active() {
    local net_name="$1"
    virsh net-info "$net_name" 2>/dev/null | awk '/^Active:/ {print $2}'
}

start_network_if_needed() {
    local net_name="$1"

    virsh net-info "$net_name" >/dev/null 2>&1 || fail "Libvirt network not found: $net_name"

    local state
    state=$(network_is_active "$net_name")

    if [ "$state" != "yes" ]; then
        info "Starting libvirt network: $net_name"
        virsh net-start "$net_name"
    fi
}

get_domain_name() {
    local detected_domain=""

    detected_domain=$(hostname -d 2>/dev/null || true)

    if [ -z "$detected_domain" ]; then
        detected_domain=$(awk '/^search/ {print $2; exit}' /etc/resolv.conf 2>/dev/null || true)
    fi

    if [ -z "$detected_domain" ]; then
        detected_domain="domain24.example.net"
    fi

    echo "$detected_domain"
}

get_highest_node_index() {
    local highest_index=0
    local existing_nodes
    local idx

    existing_nodes=$(
        virsh list --all --name |
        grep -E '^node[0-9]+(\.|$)' |
        sed -E 's/^node([0-9]+).*/\1/' || true
    )

    for idx in $existing_nodes; do
        if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -gt "$highest_index" ]; then
            highest_index="$idx"
        fi
    done

    echo "$highest_index"
}

delete_existing_dhcp_entries() {
    local network_name="$1"
    local mac_address="$2"
    local ip_address="$3"
    local old_entries
    local old_entry

    old_entries=$(
        virsh net-dumpxml "$network_name" |
        awk -v mac="$mac_address" -v ip="$ip_address" '
            /<host / && (index($0, mac) || index($0, ip)) {
                gsub(/^[ \t]+|[ \t]+$/, "", $0)
                print
            }
        ' || true
    )

    if [ -n "$old_entries" ]; then
        while IFS= read -r old_entry; do
            [ -z "$old_entry" ] && continue

            virsh net-update "$network_name" \
                delete ip-dhcp-host "$old_entry" \
                --live --config \
                --parent-index 0 >/dev/null 2>&1 || true
        done <<< "$old_entries"
    fi
}

add_dhcp_reservation() {
    local network_name="$1"
    local mac_address="$2"
    local vm_name="$3"
    local ip_address="$4"
    local host_xml

    host_xml="<host mac='${mac_address}' name='${vm_name}' ip='${ip_address}'/>"

    echo "------------------------------------------------"
    echo "Creating DHCP reservation"
    echo "Network : $network_name"
    echo "VM      : $vm_name"
    echo "MAC     : $mac_address"
    echo "IP      : $ip_address"
    echo "------------------------------------------------"

    delete_existing_dhcp_entries \
        "$network_name" \
        "$mac_address" \
        "$ip_address"

    virsh net-update "$network_name" \
        add-last ip-dhcp-host "$host_xml" \
        --live \
        --config \
        --parent-index 0

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to add DHCP reservation"
        exit 1
    fi

    sleep 1

    if ! virsh net-dumpxml "$network_name" | grep -iq "$mac_address"
    then
        echo "ERROR: Reservation verification failed"
        exit 1
    fi

    echo "DHCP reservation verified successfully"
}

remove_network_boot_from_xml() {
    local vm_name="$1"
    local tmp_xml

    tmp_xml=$(mktemp)

    virsh dumpxml "$vm_name" |
        sed -e "/<boot dev=['\"]network['\"]\/>/d" > "$tmp_xml"

    virsh define "$tmp_xml"

    rm -f "$tmp_xml"
}

# -----------------------------
# Pre-flight validation
# -----------------------------
require_command virsh
require_command virt-install
require_command virt-customize
require_command awk
require_command sed
require_command grep
require_command mktemp

start_network_if_needed "$HOST_ONLY_NET"
start_network_if_needed "$NAT_NET"

# -----------------------------
# User input
# -----------------------------
read -r -p "Enter the base domain name (e.g., domain24.example.net): " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    DOMAIN_NAME=$(get_domain_name)
    info "No domain entered. Auto-selected default: $DOMAIN_NAME"
fi

read -r -p "Enter the number of VMs to create: " VM_COUNT

if ! [[ "$VM_COUNT" =~ ^[0-9]+$ ]]; then
    fail "Please enter a valid number."
fi

if [ "$VM_COUNT" -lt 1 ]; then
    fail "VM count must be greater than zero."
fi

# -----------------------------
# Calculate node sequence
# -----------------------------
info "Scanning existing lab instances..."

HIGHEST_INDEX=$(get_highest_node_index)

START_INDEX=$((HIGHEST_INDEX + 1))
END_INDEX=$((HIGHEST_INDEX + VM_COUNT))

info "Existing nodes found up to index: $HIGHEST_INDEX"
info "New deployment sequence will cover node indexes: $START_INDEX to $END_INDEX"

# -----------------------------
# Main VM build loop
# -----------------------------
for ((i=START_INDEX; i<=END_INDEX; i++)); do
    short_name="node${i}"
    mHost="${short_name}.${DOMAIN_NAME}"

    host_octet=$((HOST_ONLY_IP_START + i - 1))
    HOST_ONLY_IP="${HOST_ONLY_SUBNET_PREFIX}.${host_octet}"

    ROOT_VOL="${short_name}-root.qcow2"
    DATA_VOL="${short_name}-data.qcow2"

    echo "=========================================================="
    echo "Processing VM      : $mHost"
    echo "Short name         : $short_name"
    echo "Host-only IP       : $HOST_ONLY_IP"
    echo "Host-only network  : $HOST_ONLY_NET"
    echo "NAT network        : $NAT_NET"
    echo "=========================================================="

    if virsh dominfo "$mHost" >/dev/null 2>&1; then
        fail "VM already exists: $mHost"
    fi

    if virsh vol-info --pool "$STORAGE_POOL" "$ROOT_VOL" >/dev/null 2>&1; then
        fail "Root volume already exists: $ROOT_VOL"
    fi

    if virsh vol-info --pool "$STORAGE_POOL" "$DATA_VOL" >/dev/null 2>&1; then
        fail "Data volume already exists: $DATA_VOL"
    fi

    # -----------------------------
    # Create virtual disks
    # -----------------------------
    info "Creating virtual disks..."

    virsh vol-create-as \
        --pool "$STORAGE_POOL" \
        --name "$ROOT_VOL" \
        --format qcow2 \
        --capacity "$ROOT_DISK_SIZE"

    virsh vol-create-as \
        --pool "$STORAGE_POOL" \
        --name "$DATA_VOL" \
        --format qcow2 \
        --capacity "$DATA_DISK_SIZE"

    ROOT_DISK_PATH=$(virsh vol-path --pool "$STORAGE_POOL" "$ROOT_VOL")
    DATA_DISK_PATH=$(virsh vol-path --pool "$STORAGE_POOL" "$DATA_VOL")

    info "Root disk path: $ROOT_DISK_PATH"
    info "Data disk path: $DATA_DISK_PATH"

    # -----------------------------
    # Initial PXE deployment
    # -----------------------------
    info "Launching initial PXE installation..."

    virt-install \
        --name "$mHost" \
        --vcpus "$INITIAL_VCPUS" \
        --memory "$INITIAL_MEMORY_MB" \
        --cpu host-passthrough \
        --disk path="$ROOT_DISK_PATH",format=qcow2,bus=virtio \
        --network network="$HOST_ONLY_NET",model=virtio \
        --os-variant "$OS_VARIANT" \
        --boot network,hd,useserial=on \
        --graphics none \
        --noautoconsole

    # -----------------------------
    # Wait for Kickstart completion
    # -----------------------------
    info "Waiting for PXE/Kickstart installation to finish and power off..."

    sleep "$PXE_WAIT_INITIAL_SECONDS"

    while true; do
        VM_STATE=$(virsh domstate "$mHost" 2>/dev/null || echo "shut off")

        if echo "$VM_STATE" | grep -qi "shut"; then
            info "VM has powered down. Kickstart installation appears complete."
            break
        fi

        sleep "$PXE_CHECK_INTERVAL_SECONDS"
    done

    info "Waiting for storage locks to release..."
    sleep "$STORAGE_LOCK_WAIT_SECONDS"

    # -----------------------------
    # Reduce VM resources
    # -----------------------------
    info "Reducing VM resources..."

    virsh setmaxmem "$mHost" "${FINAL_MEMORY_MB}M" --config
    virsh setmem "$mHost" "${FINAL_MEMORY_MB}M" --config

    virsh setvcpus "$mHost" "$FINAL_VCPUS" --config

    # -----------------------------
    # Remove network boot entry
    # -----------------------------
    info "Removing PXE network boot entry from VM XML..."

    remove_network_boot_from_xml "$mHost"

    
    # -----------------------------
    # Attach data disk as /dev/vdb
    # -----------------------------
    info "Attaching data disk..."

    virsh attach-disk \
        "$mHost" \
        "$DATA_DISK_PATH" \
        vdb \
        --subdriver qcow2 \
        --config

    info "Data disk attached as vdb"


    # -----------------------------
    # Attach NAT network as second NIC
    # -----------------------------
    info "Attaching NAT network as second NIC..."

    virsh attach-interface \
        --domain "$mHost" \
        --type network \
        --source "$NAT_NET" \
        --model virtio \
        --config

    # -----------------------------
    # Get host-only MAC address
    # -----------------------------
    info "Detecting host-only MAC address..."

    HOST_ONLY_MAC=$(
        virsh domiflist "$mHost" |
        awk -v net="$HOST_ONLY_NET" '$3 == net {print $5; exit}'
    )

    if [ -z "$HOST_ONLY_MAC" ]; then
        fail "Could not detect host-only MAC address for $mHost"
    fi

    info "Host-only MAC detected: $HOST_ONLY_MAC"

    # -----------------------------
    # Register static DHCP reservation
    # -----------------------------
    info "Registering host-only DHCP reservation..."

    add_dhcp_reservation "$HOST_ONLY_NET" "$HOST_ONLY_MAC" "$mHost" "$HOST_ONLY_IP"

    
    echo "Current DHCP reservations:"

    virsh net-dumpxml "$HOST_ONLY_NET" | grep "<host "


    info "Static host-only IP reserved: $HOST_ONLY_IP"

    # -----------------------------
    # Set hostname inside guest disk
    # -----------------------------
    info "Setting guest hostname inside disk image..."

    # -----------------------------
    # Start finalized VM
    # -----------------------------
    info "Starting finalized VM..."

    virsh start "$mHost"


    
    # -----------------------------
    # Wait for VM to come online
    # -----------------------------
    info "Waiting for VM networking..."

    until ping -c1 -W1 "$HOST_ONLY_IP" >/dev/null 2>&1
    do
        sleep 5
    done

    
    # -----------------------------
    # Configure hostname and static IP
    # -----------------------------
    
    # -----------------------------
    # Discover actual DHCP IP
    # -----------------------------
     CURRENT_IP=$(
            arp -an |
            awk -v mac="$HOST_ONLY_MAC" '
            BEGIN { IGNORECASE=1 }
            index(tolower($0), tolower(mac)) {
                gsub(/[()]/, "", $2)
                print $2
                exit
            }'
    )

    if [ -z "$CURRENT_IP" ]; then
            fail "Unable to determine DHCP address for $mHost"
    fi

    info "Current DHCP IP: $CURRENT_IP"

    # -----------------------------
    # Configure hostname and static IP
    # -----------------------------
    ssh -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            student@"$CURRENT_IP" \
    "sudo hostnamectl set-hostname '$mHost' && \
    sudo nmcli con mod enp1s0 \
            ipv4.addresses '${HOST_ONLY_IP}/24' \
            ipv4.gateway '10.10.1.1' \
            ipv4.dns '10.10.1.1' \
            ipv4.method manual && \
    sudo nmcli con up enp1s0"

    info "Static IP and hostname configured."


    echo "----------------------------------------------------------"
    echo "Successfully built VM:"
    echo "  VM name      : $mHost"
    echo "  Hostname     : $mHost"
    echo "  Host-only IP : $HOST_ONLY_IP"
    echo "  NAT network  : $NAT_NET"
    echo "----------------------------------------------------------"
done

echo "=========================================================="
echo "Deployment complete."
echo "Created VM count: $VM_COUNT"
echo "=========================================================="
echo
echo "Validation commands:"
echo "  virsh list --all"
echo "  virsh net-dhcp-leases $HOST_ONLY_NET"
echo "  virsh domiflist node<N>.$DOMAIN_NAME"
echo "  ssh root@${HOST_ONLY_SUBNET_PREFIX}.<LAST_OCTET> hostname -f"
echo "=========================================================="
