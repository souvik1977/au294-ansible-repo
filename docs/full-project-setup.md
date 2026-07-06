[1] - Install Ansible packages and Ansible-build, ansible-navigator by following 'creating-custom-execution-environment.md'.

[2] Create a directories inside $HOME/projects directory
- collections
- group_vars
- host_vars
- other-files

[3] Create 'ansible.cfg' 
$vim $HOME/projects/ansible.cfg

[Paste ansible.cfg file contents and perform required modifications]

[4] Installing collections:
$vim $HOMe/projects/collection_requirements.yml 

---
collections:
  - name: ansible.posix
    version: "1.4.0"
  - name: community.general
    version: 12.6.0
  - name: containers.podman

$ansible-galaxy collection install -r collection_requirements.yml -p /home/devops/projects/collections/

[5] Create 'inventory' file inside $HOME/projects/' directory
$vim inventory

[6] Create 'Dockerfile' to create Almalinux docker containers to use as ansible clients:

$ mkdir $HOME/alma10_containers
$ cd $HOME/alma10_containers
$ cp -p $HOME/.ssh/controller-key.pub .
$ vim Dockerfile
----------------------------------------------------------------------
# Use this officially free RHEL Compatible AlmaLinux 10 base image
# We will use the containers as ansible clients

FROM docker.io/almalinux/10-base:latest

LABEL description="AlmaLinux 10 Client with SSH Key Authentication"

# Install SSH server and basic utilities
RUN dnf install -y \
    openssh-server \
    sudo \
    hostname \
    && dnf clean all \
    && rm -rf /var/cache/dnf/*

# Generate host keys required for the SSH daemon to start
RUN ssh-keygen -A

# Create the ansible user
RUN useradd -m -s /bin/bash ansibleuser && \
    echo "ansibleuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create the .ssh directory with secure permissions
RUN mkdir -p /home/ansibleuser/.ssh && \
    chmod 700 /home/ansibleuser/.ssh && \
    chown -R ansibleuser:ansibleuser /home/ansibleuser/.ssh

# Copy your local public key directly into the image layers
# Assumes 'id_rsa.pub' is in the same directory as your Dockerfile
COPY id_rsa.pub /home/ansibleuser/.ssh/authorized_keys

# Secure the authorized_keys file
RUN chmod 600 /home/ansibleuser/.ssh/authorized_keys && \
    chown ansibleuser:ansibleuser /home/ansibleuser/.ssh/authorized_keys

# Expose standard SSH port
EXPOSE 22

# Start the SSH daemon in the foreground
CMD ["/usr/sbin/sshd", "-D"]




Note: 
[a] LABEL maintainer=<your_email_id>
[b] replace 'ansibleuser' with your designated user
[c] Ensure that your ssh-pub key is present inside the same directory where Dockerfile exists
[d] replace 'id_rsa.pub' with actual key name
----------------------------------------------------------------------

[7] Build the image:
$podman build --network=host -t alma10-client .

#--network flag to ensure image is obtaining corrent host state including vpn inside WSL

[8] Create client-machines:

for i in {1..3}; do
  podman run -d \
    --name "managed-node-0$i" \
    --hostname "managed-node-0$i" \
    --network=host \
    --systemd=always \
    --privileged \
    --cgroupns=private \
    --tmpfs /run \
    --tmpfs /run/lock \
    --tmpfs /tmp \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    localhost/alma10-client
done

Connecting to container:
$sudo podman exec -it managed-node-01 bash

Testing [Manual Connectivity]
$ssh -i $HOME/.ssh/controller-key -p 2221 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null student@127.0.0.1 "cat /proc/sys/kernel/hostname && whoami"


[9] Configuring ansible-navigator.yml:
make sure if you are using WSL with Podman then your 'execution-environment' section must have

container-options:
        - "--workdir=/runner/project"
        #- "--net=host"

[10] Create proper inventory file to use containers:

[containers]
node01 ansible_host=host.containers.internal ansible_port=2221

Important to note: ansible_host should be 'host.containers.internal'

[11] Test/Run playbooks
$ansible-navigator run playbooks/db.yml



[12] Stopping multiple containers:
$ for i in $(sudo podman ps -a | awk -F' ' 'NR>1 {print $1}')
do
sudo podman stop $i
sleep 2
sudo podman rm $i
done