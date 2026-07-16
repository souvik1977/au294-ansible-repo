#!/bin/bash
#
#
echo "Resetting hostname............"
hostnamectl set-hostname localhost.localdomain

echo "Resetting NTP............"
timedatectl set-ntp false
sed -i '/server/d' /etc/chrony.conf
systemctl daemon-reload
systemctl daemon-reexec
systemctl restart chronyd

echo "Cleaning up local users"
userdel -r harry
userdel -r natasha
userdel -r sarah
userdel -r rohan
userdel -r sam
userdel -r abid
userdel -r xanadu
groupdel sysadmin



echo "Removing netuser1............"
userdel -r netuser1

echo "Removing /home/materials directory............."
cd /home
rm -rf materials
cd

echo "Removing crontab for sarah......."
crontab -r -u sarah
rm -f /root/.cache/crontab/crontab.sarah.bak

echo "Resetting the http port from SELinux.............."
semanage port -d -t http_port_t -p tcp 82
rm -f /var/www/html/index.html

echo "Resetting the repos............"
rm -f /etc/yum.repos.d/*
dnf clean all

echo "Cleanup mysearch.sh.............."
cd /root
rm -rf mysearch
cd
rm -f /usr/local/bin/mysearch.sh


echo "Removing tar archive............."
rm -f /tmp/*.tar.bz2
dnf remmove bzip2

echo "Removing cron for user sarah............"
crontab -r -u sarah

echo "Removing /root/filefound......................"
rm -rf /root/filefound

echo "Removing sudo permission file................"
rm -f /etc/sudoers.d/dba
rm -f /etc/sudoers.d/geo
rm -f /etc/sudoers.d/sysadmin
rm -f /etc/sudoers.d/harry

echo "Cleaning up the rhcsa application file..........."
rm -f /usr/local/bin/rhcsa


echo "Removing /var/tmp/fstab file............"
rm -f /var/tmp/fstab

echo "Cleaning up /dev/vdb2 swap.............."
swapoff /dev/vdb2
sudo sed -i '\|^/dev/vdb2\b|d' /etc/fstab
parted /dev/vdb rm 2
udevadm settle
partprobe
systemctl daemon-reload
systemctl daemon-reexec

echo "Removing /data mount point, lv, vg, pv"
umount /data
sed -i '/\/data/d' /etc/fstab
systemctl daemon-reload
systemctl daemon-reexec

lvchange -an /dev/vg-data/lv-data
lvremove /dev/vg-data/lv-data
vgremove vg-data
pvremove /dev/vdb1

echo "Deleting /dev/vdb1 partition"
parted /dev/vdb rm 1


echo "Removing data-store..............."
umount /mnt/archive
lvchange -an /dev/datastore/database
lvremove /dev/datastore/database
vgremove datastore
pvremove /dev/vdb3
sed -i '/\/mnt\/archieve/d' /etc/fstab
rmdir /mnt/archive

echo "Removing /data directory"
rmdir /data

echo "Wipping out everything, filesystem signature an others........"
wipefs --all --force /dev/vdb
dd if=/dev/zero of=/dev/vdb bs=1M count=10 status=progress
blockdev --rereadpt /dev/vdb
partprobe /dev/vdb
udevadm settle

echo "Removing rm -f /root/commands.txt"
rm -f /root/commands.txt

echo "Resetting /etc/login.defs file.........."
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 99999/' /etc/login.defs

echo "Removing autofs files and packages..............."
systemctl disable --now autofs
dnf -y remove nfs-utils autofs
SUBMAPFILE=$(cat /etc/auto.master.d/* | cut -d' ' -f2)
rm -f $SUBMAPFILE
rm -f /etc/auto.master.d/*

echo "Disabling PermitRootLogin to /etc/ssh/sshd_config"
sed -i '/^PermitRootLogin/s/yes/no/' /etc/ssh/sshd_config
systemctl daemon-reload
systemctl restart sshd

echo "Cleaning up log_capture.service and log_capture.timer"
systemctl disable --now log_capture.timer
rm -f /etc/systemd/system/log_capture.service
rm -f /etc/systemd/system/log_capture.timer
rm -f /usr/local/bin/log_capture
rm -f /root/log_output/log_capture.trc
rmdir /root/log_output

echo "Clean up Container stuff............."
su - xanadu -c "systemctl disable --now container-mycontainer"

echo "Removing flatpak from the server..................."
su - harry -c "flatpak uninstall --user codium -y"
su - harry -c "flatpak remote-delete --user --force flatrepo"
su - harry -c "flatpak remotes --user"
dnf -y remove flatpak


echo "Resetting Network................."

nmcli conn modify enp3s0 ipv4.method auto
nmcli conn modify enp3s0 ipv4.addresses '' ipv4.gateway '' ipv4.dns '' ipv4.dns-search ''
nmcli conn down enp3s0
nmcli conn up enp3s0
hostnamectl set-hostname localhost.localdomain
systemctl daemon-reload
systemctl restart NetworkManager
