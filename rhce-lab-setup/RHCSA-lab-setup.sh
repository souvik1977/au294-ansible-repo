#!/bin/bash
#getting the password from the user 'read -s -p "Enter Password :" mypass'
#Generating a hash: openssl passwd -6 $mypass
#
echo "Creating sarah and sam user........... and resetting her password"
useradd -p '$6$nGkCLBQmlS2wcxeR$nvSViT.U0qL6h9mpmf4MUKH1cxdZ/gmp1q9ZIP.gMrDeaTiKgGMT2njqDYjHjOwuap9tAFpl928ivJwR1SHwE.' sarah
useradd -p '$6$nGkCLBQmlS2wcxeR$nvSViT.U0qL6h9mpmf4MUKH1cxdZ/gmp1q9ZIP.gMrDeaTiKgGMT2njqDYjHjOwuap9tAFpl928ivJwR1SHwE.' sam
useradd -p '$6$nGkCLBQmlS2wcxeR$nvSViT.U0qL6h9mpmf4MUKH1cxdZ/gmp1q9ZIP.gMrDeaTiKgGMT2njqDYjHjOwuap9tAFpl928ivJwR1SHwE.' abid

echo "Creating LVM Partition on /dev/vdb............"
parted /dev/vdb mklabel gpt
parted /dev/vdb mkpart data 1M 2100M
udevadm settle
partprobe /dev/vdb
parted /dev/vdb set 1 lvm on

partprobe
udevadm settle

echo "Creating PV and VG with 8M Extent"
pvcreate /dev/vdb1
vgcreate -s 8M vg-data /dev/vdb1

echo "Creating LV......."
lvcreate -l 250 -n lv-data vg-data

echo "Creating Ext4 file system............"
mkfs.ext4 /dev/vg-data/lv-data

mkdir /data
echo "/dev/vg-data/lv-data  /data  ext4 defaults 0 0" >> /etc/fstab
systemctl daemon-reload
systemctl daemon-reexec
mount -a

echo "Creating some files owned by sarah user............"
touch /home/sarah/sarah-homefile1 /home/sarah/sarah-homefile2 /tmp/sarahfile
chown sarah:sarah /home/sarah/sarah-homefile1 /home/sarah/sarah-homefile2 /tmp/sarahfile

echo "Creating netuser1..............so that we can practice autofs"
useradd -u 2001 -d /rhome/netuser1 -M -p '$6$nGkCLBQmlS2wcxeR$nvSViT.U0qL6h9mpmf4MUKH1cxdZ/gmp1q9ZIP.gMrDeaTiKgGMT2njqDYjHjOwuap9tAFpl928ivJwR1SHwE.' netuser1

echo "Creating xanadu user and setting up password..............."
useradd -p '$6$nGkCLBQmlS2wcxeR$nvSViT.U0qL6h9mpmf4MUKH1cxdZ/gmp1q9ZIP.gMrDeaTiKgGMT2njqDYjHjOwuap9tAFpl928ivJwR1SHwE.' xanadu
cp /root/mycontainer/Containerfile /home/xanadu/
cp /root/mycontainer/index.html /home/xanadu/
chown xanadu:xanadu /home/xanadu/Containerfile
chown xanadu:xanadu /home/xanadu/index.html


echo "Setup Completed.............."

