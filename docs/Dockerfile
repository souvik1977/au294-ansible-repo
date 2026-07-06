FROM docker.io/almalinux/10-base:latest

LABEL description="AlmaLinux 10 System Container - VM Equivalent for Ansible Testing"
LABEL environment="Rootless Podman / WSL2 Optimized"

# 1. Install Systemd, DBus, SSH daemon, Firewalld, and essential client binaries
# NOTE: We include iptables-nft to give firewalld an operational backend in rootless mode.
RUN dnf install -y \
    systemd \
    dbus-broker \
    openssh-server \
    sudo \
    hostname \
    iproute \
    procps-ng \
    && dnf clean all \
    && rm -rf /var/cache/dnf/*

# 2. Tell systemd it is running inside a Podman container wrapper
ENV container=podman

# 5. Pre-generate required SSH cryptographic host keys
RUN ssh-keygen -A

# 6. Provision a dedicated Ansible user with passwordless administrative rights
RUN useradd -m -s /bin/bash ansibleuser && \
    echo "ansibleuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 7. Inject your local public key for key-based authentication
RUN mkdir -p /home/ansibleuser/.ssh && chmod 700 /home/ansibleuser/.ssh
COPY id_rsa.pub /home/ansibleuser/.ssh/authorized_keys
RUN chmod 600 /home/ansibleuser/.ssh/authorized_keys && \
    chown -R ansibleuser:ansibleuser /home/ansibleuser/.ssh

# 8. Set the default entry execution to the Linux system initialization process
# This triggers a complete VM-like boot sequence when the container starts.
CMD ["/usr/sbin/init"]
