kvm-base NIC:
    enp1s0: 10.10.1.100/24 [Base NIC connected with kvmhost machine]
    virbr10: 172.16.50.1/24 [Virtual NIC will be created in next step and will be used as gateway for guest machines]

Local Repo Server: local repo server is configured on kvmbase.lab.example.com [10.10.1.1/24] and published over http service
On kvm-base.domain24.example.net machine configure local repo
# mkdir /root/orig_repos
# mv /etc/yum.repos.d/* /root/orig_repos
# vim /etc/yum.repos.d/local.repo
[BaseOS]
name=BaseOS-Repo
baseurl=http://master.lab.example.com/alma10/BaseOS/
enabled=1
gpgcheck=0

[AppStream]
name=AppStream-Repo
baseurl=http://master.lab.example.com/alma10/AppStream/
enabled=1
gpgcheck=0


***********************************************************************************************************************
Pre-Configuration Step [Optional based on the situation if you want to configure full KVM Host and PXE server on it]:
1. Create a virtual NIC on the server:
# vim bridge-nic.xml
<network>
  <name>bridge-nic</name>
  <forward mode='nat'>
    <nat>
      <port start='1024' end='65535'/>
    </nat>
  </forward>
  <bridge name='virbr10' stp='off' delay='0'/>
  <ip address='172.16.50.1' netmask='255.255.255.0'>
  </ip>
</network>

IMP: libvirt network should not configure with DHCP option set else 'dnsmasq' will not work as expected
# virsh net-define bridge-nic.xml
# virsh net-autostart bridge-nic
# virsh net-start bridge-nic

2. Modify /etc/hosts on the kvm-base machine:
# vim /etc/hosts
10.10.1.1 master.lab.example.com master
*************************************************************************************************************************
1. Install dnsmasq [For DHCP and DNS Service]
# dnf install dnsmasq   //lightweight DNS server
2. Creating backup of configuration file
# cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bkp
# vim /etc/dnsmasq.conf

Remove "#" from conf-dir=/etc/dnsmasq.d line

3. Configuring dnsmasq
# vim /etc/dnsmasq.d/pxe.conf

interface=virbr10
# CHANGE bind-interfaces TO bind-dynamic
bind-dynamic
# Add this to ensure it doesn't conflict with other libvirt instances
except-interface=lo
dhcp-range=172.16.50.10,172.16.50.100,255.255.255.0,24h
dhcp-option=option:router,172.16.50.1
dhcp-option=option:dns-server,172.16.50.1
enable-tftp
tftp-root=/var/lib/tftpboot
dhcp-boot=pxelinux.0
# Add logging to debug
log-dhcp

########################################################
Testing if virbr10 is working and providing DHCP or not [Optional]
# Creating a dump interface to bring virbr10 up as test
# ip link add name dummy0 type dummy
# ip link set dummy0 master virbr10
# ip link set dummy0 up
# ip link set virbr10 up

Deleting dummy interface:
# ip link delete dummy0

Testing:
# dnsmasq -d -C /etc/dnsmasq.conf
# systemctl restart dnsmasq
# journalctl -u dnsmasq | grep DHCP [you should see the DHCP IP Range]

4. Install syslinux
# dnf install syslinux
# ls /usr/share/syslinux/

5. Install tftp-server and tftp client
# dnf install tftp-server tftp

6. Copy all contents from "syslinux" directory to "tftpboot" directory
# cp -r /usr/share/syslinux/* /var/lib/tftpboot

7. Setup PXE Server:
# mkdir /var/lib/tftpboot/pxelinux.cfg
# vim /var/lib/tftpboot/pxelinux.cfg/default
SERIAL 0 115200
CONSOLE 0
default menu.c32
prompt 0
timeout 300
menu title  ************************************** PXE Boot Menu **************************************
menu color tabmsg37;40      # white on black
menu color title 1;36;44    # cyan on blue
menu color border 30;44     # black on blue

ONTIMEOUT 1


label 1
menu label ^1) Install Alma-10 64 Bit with FTP Repo
kernel alma10/vmlinuz
append initrd=alma10/initrd.img inst.ks=ftp://10.10.1.200/pub/ks/alma10-ks.cfg inst.repo=ftp://10.10.1.200/pub/alma10 console=tty0 console=ttyS0,115200n8 rd.ramdisk.size=2097152

label 2
menu label ^2) Boot from local drive
localboot 0



8. Copy ISO contents to PXE Server
# mkdir /var/lib/tftpboot/alma10

9. Attaching Alma-10 ISO from Host machine to the guest machine
[On-Host]
# virsh attach-disk <guest-name> /path/to/image.iso hdz --targetbus scsi --type cdrom --mode readonly --config --live

[On-guest]
# lsscsi
# echo "- - - -" | sudo tee /sys/class/scsi_host/host*/scan
# lsblk
# mount -o loop /dev/sr1 /srv

10. Copy vmlinuz and initrd.img to "/var/lib/tftpboot/alma10" directory:
# cd /var/lib/tftpboot/alma10
# wget http://master.lab.example.com/alma10/images/pxeboot/vmlinuz
# wget http://master.lab.example.com/alma10/images/pxeboot/initrd.img

Check if "//var/lib/tftpboot/alma10/" contains these two files
# ls -l /var/lib/tftpboot/alma10/
total 169776
-rw-r--r--. 1 root root 157892004 Nov 19 14:24 initrd.img
-rwxr-xr-x. 1 root root  15955328 Nov 10 19:00 vmlinuz

11. Install ftp server
# dnf install vsftpd


12. Copying all contents from the /srv/ to /var/ftp/pub/
# mkdir /var/ftp/pub/alma10
# rsync -a /srv/* /var/ftp/pub/alma10
# cp /srv/.treeinfo /var/ftp/pub/alma10/

13. Enable Anonymous Access on vsftpd
# vim /etc/vsftpd/vsftpd.conf
listen=YES
listen_ipv6=NO
anonymous_enable=YES
local_enable=YES
write_enable=YES
# Important for active/passive mode through firewalls
pasv_min_port=30000
pasv_max_port=30005

14. Generate root and user password to use with kickstart file:
### Generate a root password and user password
# read -s -p "Enter Password :" mypass
# openssl passwd -6 $mypass


Generate a ssh-key file for devops user
#ssh-keygen -t rsa -b 4096 -f /home/devops/.ssh/id_rsa
#vim  /home/devops/.ssh/id_rsa.pub

remove the @<hostname> part from the end

15. Configure KickStart file:
# mkdir -p /var/ftp/pub/ks
# vim /var/ftp/pub/ks/alma10-ks.cfg
############################################################################################################################
# --- Basic Configuration ---
# Use text-mode installation
text
eula --agreed
# Set the installation source (Update <SERVER_IP> to your PXE server IP)
url --url="ftp://10.10.1.200/pub/alma10"
# Set language and keyboard
lang en_IN.UTF-8
keyboard --vckeymap=us --xlayouts='us'
# Set timezone
timezone Asia/Kolkata --utc

# --- Security and Access ---
# Set the root password (example: 'password123' - change this!)
rootpw --iscrypted <ROOT_PASSWORD_HASH>
# SELinux in enforcing mode
#selinux --enforcing
# Firewall allowing SSH
#firewall --enabled --service=ssh
# Network configuration (DHCP is standard for PXE)
network --bootproto=dhcp --device=link --activate --onboot=on

# --- Partitioning ---
# Wipe all existing partitions
zerombr
clearpart --all --initlabel
# Use automated partitioning
autopart --type=lvm

# Creating student user
user --name=student --password=<PASSWORD_HASH> --iscrypted --gecos="User with admin privilege" --shell=/bin/bash

# Creating devops user
user --name=devops --gecos="Devops user with admin privilege" --shell=/bin/bash


# --- Packages ---
%packages
@^minimal-environment
openssh-server
sudo
curl
wget
dnf
openssl
firewalld
selinux-policy
selinux-policy-targeted
policycoreutils
policycoreutils-python-utils
vim
# Remove unnecessary tools for a clean server
#-@graphical-server-environment
%end

# --- Post-Installation Scripts ---
%post
# Ensure sudo is configured for the wheel group (uncomment if needed)
# sed -i 's/^# %wheel\tALL=(ALL)\tALL/%wheel\tALL=(ALL)\tALL/' /etc/sudoers
SUDOERS_FILE="/etc/sudoers.d/student"
SUDO_RULE="student ALL=(ALL) ALL"
echo "$SUDO_RULE" > "$SUDOERS_FILE"
chmod 440 $SUDOERS_FILE

## Configuring devops key-based authentication
mkdir -p /home/devops/.ssh
chmod 700 /home/devops/.ssh
cat <<EOF > /home/devops/.ssh/authorized_keys
<YOUR_PUB_KEY_CONTENT> <YOUR_REMOTE_USER>
EOF

chmod 600 /home/devops/.ssh/authorized_keys
chown -R devops:devops /home/devops/.ssh
restorecon -R /home/devops/.ssh

# Setting up sudoers permission
echo "devops ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/devops
chmod 440 /etc/sudoers.d/devops

visudo -c
# SELinux in enforcing mode
selinux --enforcing
# Firewall allowing SSH
firewall --enabled --service=ssh

# Creating the configuration file
cat >/etc/selinux/config<<CONF
SELINUX=permissive
SELINUX=targeted
CONF
touch /.autorelabel
%end


# Reboot after installation finishes
reboot

###############################################################################################################################

16. Configuring SELinux to provide access for ftpd service and directories:
# setsebool -P ftpd_full_access 1
# restorecon -Rv /var/ftp/pub
# restorecon -Rv /var/ftp/pub/ks
# setsebool -P tftp_home_dir 1

17. Check if dns service is already on and if yes then disable it
# ss -tunlp | grep :67
# ss -tunlp | grep :53

# systemctl stop avahi-daemon.service
# systemctl stop avahi-daemon.socket
# systemctl disable avahi-daemon.service
# systemctl mask avahi-daemon

# virsh net-destroy default
# virsh net-undefine default
# virsh net-dumpxml > storage-net.xml
# vim storage-net.xml
Remove <dhcp></dhcp> specific lines
Add <dns enable='no'/> before <ip></ip> block
Set 'stp' to off
<bridge name='virbr10' stp='on' delay='0'/>

# virsh net-define storage-net.xml
# virsh net-start storage-net
# virsh net-autostart storage-net

18. Enable and start services
# systemctl enable --now nfs-server
# systemctl enable --now dnsmasq
# systemctl enable --now vsftpd

17. Adding required firewall rules:
# firewall-cmd --get-active-zones
# firewall-cmd  --zone=libvirt --permanent --add-service=ftp
# firewall-cmd  --zone=libvirt --permanent --add-service=dns
# firewall-cmd  --zone=libvirt --permanent --add-service=dhcp
# firewall-cmd  --zone=libvirt --permanent --add-service=nfs
# firewall-cmd  --zone=libvirt --permanent --add-port=69/udp
# firewall-cmd  --zone=libvirt --permanent --add-port=4011/udp
# firewall-cmd --permanent --zone=libvirt --add-port=21/tcp
# firewall-cmd --permanent --zone=libvirt --add-port=30000-30005/tcp
# firewall-cmd --reload
# firewall-cmd --list-all --zone libvirt



####################################### Testing #######################################################
1. tcpdump -i virbr10 port 67 or 68 -vv [On one terminal]

2. ################################################### VM Creation  ##########################################
# virt-install --name serverE.domain24.example.net  --vcpus 2  --memory 4096  --cpu host-passthrough  --disk path=/kvm-storage/images/serverE-root.qcow2,size=15,format=qcow2 --network network=host-only,model=virtio  --os-variant  almalinux10  --boot network,hd,useserial=on --graphics none

Imp: with 2 GB of RAM initrd.img will face space issue as post extraction of the compressed file it will expand more than 2 GB. It is advisable to
use 8GB memory while creating the VM and then shrink the memory to 2GB
8GB = 8192M
4GB = 4096M

3. Post VM Build Modify the RAM and all:
# read -p "Enter Hostname :" mHost
# virsh destroy $mHost
# virsh setmaxmem $mHost 2048M --config   [KiB: 2097152]
# virsh setmem $mHost 2048M --config
# virsh setvcpus --count 1 --domain $mHost --maximum --config

Remove the netboot:
# virsh edit node1.domain24.example.net

Remove the line under <os></os>:
<boot dev='network'/>

virsh dumpxml $mHost | sed "/<boot dev='network'\/>/d" | virsh define /dev/stdin


Start the VM:
# virsh start node1.domain24.example.net
# virsh list --all

Connect the the VM:
# virsh console node1.domain24.example.net
# virsh --connect qemu:///system start node1.domain24.example.net
Press Enter and you should see the login prompt

To comeout of the prompt press CTRL + ]



Attaching a network to a running domain:
# virsh attach-interface --domain serverB.domain24.example.net --source default --target enp3s0 --model virtio --managed --live --config --type network

--type: network
--source: <name-of-the-network>
--target: <target-network-name>
--model: virtio


Recreating a guest using existing OS disk
# virt-install --name serverB.domain24.example.net --memory 1800 --vcpus 1 --disk /kvm-storage/images/serverB-root.qcow2,bus=virtio --import --os-variant almalinux10  --network network=host-only,model=virtio
# virsh attach-interface --domain serverB.domain24.example.net --source default --target enp4s0 --model virtio --managed --live --config --type network

# virt-install --name serverC.domain24.example.net --memory 1800 --vcpus 1 --disk /kvm-storage/images/serverC-root.qcow2,bus=virtio --import --os-variant almalinux10  --network network=host-only,model=virtio
# virsh attach-interface --domain serverC.domain24.example.net --source default --target enp5s0 --model virtio --managed --live --config --type network

# virt-install --name serverD.domain24.example.net --memory 1800 --vcpus 1 --disk /kvm-storage/images/serverD-root.qcow2,bus=virtio --import --os-variant almalinux10  --network network=host-only,model=virtio
# virsh attach-interface --domain $mHost --source default --target enp7s0 --model virtio --managed --live --config --type network



Creating a volume and attaching to a running server:
#virsh vol-create-as --pool default --format qcow2 --capacity 2G --name serverE-data1.qcow2
#virsh attach-disk --domain serverE.domain24.example.net --source /kvm-storage/images/serverE-data1.qcow2 --target vdb --subdriver qcow2 --live --persistent --config


