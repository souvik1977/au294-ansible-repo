# Chapter 7 - Role Demonstration

In this play we will configure vsftp service with TLS/SSL using ansible role.
We will follow certin steps to complete the whole task. Few of those actions need to be done on the ansible controller node.
For those actions/tasks we will specify [controller] for easy understanding.

- we are going to use 'block', 'pre_tasks' , 'post_tasks' into this playbook along with jinja2 templating to make it production ready and robust.

## 1 - Creating 'roles' directory and updating '$HOME/ansible/ansible.cfg' [controller]

Note: my ansible root directory is '/home/devops/ansible' and all other sub-directories are inside that root directory.

Creating directory to hold roles: mkdir $HOME/ansible/roles

Updating 'ansible.cfg' with role path: vim $HOME/ansible/ansible.cfg

roles_path = /home/devops/ansible/roles

Your 'ansible.cfg' will looks like:

[defaults]

inventory = inventory

host_key_checking = false

remote_user = devops

forks = 10

private_key_file = /home/devops/.ssh/controller-key

collections_path = /home/devops/ansible/collections:/usr/share/ansible/collections

roles_path = /home/devops/ansible/roles

[privileged_escalation]

become = True

become_user = root

become_method = sudo

become_ask_pass = False

[inventory]

ansible_plugins = community.general.nmap

## 2 - Creating a role named 'vsftp' inside the 'roles' directory

ansible-galaxy role init roles/vsftp

Now if you execute the 'ansible-galaxy' command to get role details you will see the role

ansible-galaxy role list

## 3 - Generate a self-signed TLS Certificate pair to use with vsftpd using a template

- vim roles/vsftp/templates/ssl.cnf.j2

- copy paste the contents from the file and modify as required

Note: command reference to generate self-signed certificate

The command we will use to generate the certificate on the remote servers:

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/pki/tls/private/vsftpd.key \
  -out /etc/pki/tls/certs/vsftpd.crt \
  -config /etc/ssl/vsftpd.cnf

[Note:] You do not need to execute above command anywhere as it will be executed by the role to generate self-signed certificates in idempotent way.

We will configure our vsftpd.cnf.j2 to provide our server FQDN and IPv4 address through ansible_fats.

DNS.3              = {{ ansible_facts['fqdn'] }}
IP.1               = 127.0.0.1
IP.2               = {{ ansible_facts['default_ipv4']['address'] }}

## 4 - Create the parent playbook

name: 'chapter7-vsftpd-config-using-role.yml' which will use the role

## 5 - Generate a password hash for ftp user named 'devapp1' which will be used inside 'roles/vsftp/vars/main.yml' [controller]

read -p 'Enter Password :' -s mypass
openssl passwd -6 $mypass

Get the hash value of the password and paste it inside the above mentioned vars/main.yml under appropriate variable.

Follow same steps for other ftp users creation in future

## 6 - Create vsftp role

vsftp role directory contains

roles/
└── vsftp
    ├── files
    │   └── vsftpd.user_list
    ├── handlers
    │   └── main.yml
    ├── meta
    │   └── main.yml
    ├── README.md
    ├── tasks
    │   └── main.yml
    ├── templates
    │   └── ssl.cnf.j2
    │   ├── vsftpd.conf.j2
    └── vars
        └── main.yml

This role will use few imporant tasks as follows:

- ansible.posix.seboolean : To enable 'allow_ftpd_full_access' at SELinux state

- ansible.builtin.stat : To check if required ssl key and ssl certificate file created or not

- Will create /var/log/vsftpd.log and will set the SELinux context to make it writeable by vsftpd service

Important Notes:

[a] - Password hash must be within ' and ' inside vars/main.yml

[b] - templates/vsftpd.conf.j2 contains dynamic port binding section based on the 'vars/main.yml' (ftp_port_ranges: 30000-31000/tcp), instead of static defined ports where every time we may need to modify it inside the template in case of any passive port range changes into variable file.

  pasv_min_port= {{ ftp_port_ranges.split['-'](0) }}
  pasv_max_port= {{ ftp_port_ranges.split['-'](1).split['/'](0) }}

[c] - 'chapter7-vsftpd-config-using-role.yml' contains a second play to do basic testing post configuration.

Also this playbook is configured to use 'pre_tasks' and 'post_tasks' sections along with 'roles'

[d] - 'chapter7-vsftpd-config-using-role.yml' - 'post_tasks' dynamically identifying the FTP server ip address to pass it on as 'fact' to the second play.

[e] - If 'vsftpd' service is not running on the FTP server then second play will not get executed as 'post_tasks' has a check point to end the play using ansible.builtin.meta module.

## 7 - Performing Manual Testing using lftp [controller]

[a] Install lftp on your controller node

sudo dnf install lftp

Create /tmp/testfile.txt:

echo "Test FTP File to upload from controller node" > /tmp/testfile.txt

read -p "Enter devapp1 ftp user password :" -s ftp_pass

lftp -c "
        set ftp:ssl-force true;
        set ftp:ssl-protect-data true;
        set ssl:verify-certificate false;
        set ftp:ssl-allow true;
        open -u devapp1, ${ftp_pass} ftp://10.10.1.30:21;
        put /tmp/testfile.txt -o testfile.txt;
        bye;
        "

On successful upload you should see below logs in "/var/log/vsftpd.log":

Sun Jul 12 14:52:10 2026 [pid 81233] [devapp1] FTP response: Client "10.10.1.100", "230 Login successful."
Sun Jul 12 14:52:10 2026 [pid 81233] [devapp1] FTP command: Client "10.10.1.100", "PWD"
Sun Jul 12 14:52:10 2026 [pid 81233] [devapp1] FTP response: Client "10.10.1.100", "257 "/" is the current directory"
Sun Jul 12 14:52:10 2026 [pid 81233] [devapp1] FTP command: Client "10.10.1.100", "PBSZ 0"
Sun Jul 12 14:52:10 2026 [pid 81233] [devapp1] FTP response: Client "10.10.1.100", "200 PBSZ set to 0."
Sun Jul 12 14:52:10 2026 [pid 81233] [devapp1] FTP command: Client "10.10.1.100", "PROT P"
Sun Jul 12 14:52:10 2026 [pid 81233] [devapp1] FTP response: Client "10.10.1.100", "200 PROT now Private."
Sun Jul 12 14:52:10 2026 [pid 81233] [devapp1] FTP command: Client "10.10.1.100", "TYPE I"
Sun Jul 12 14:52:10 2026 [pid 81233] [devapp1] FTP response: Client "10.10.1.100", "200 Switching to Binary mode."
Sun Jul 12 14:52:10 2026 [pid 81233] [devapp1] FTP command: Client "10.10.1.100", "PASV"
Sun Jul 12 14:52:10 2026 [pid 81233] [devapp1] FTP response: Client "10.10.1.100", "227 Entering Passive Mode (10,10,1,30,117,67)."
Sun Jul 12 14:52:10 2026 [pid 81233] [devapp1] FTP command: Client "10.10.1.100", "STOR testfile.txt"
Sun Jul 12 14:52:10 2026 [pid 81233] [devapp1] FTP response: Client "10.10.1.100", "150 Ok to send data."
Sun Jul 12 14:52:10 2026 [pid 81233] [devapp1] OK UPLOAD: Client "10.10.1.100", "/testfile.txt", 45 bytes, 0.77Kbyte/sec

Some descriptions:

'PROT P' - Client requested private data protection via encryption during file transfer

'227 Entering Passive Mode (10,10,1,30,117,67)' - first four values are the IP of the server and (117,67) indicates the random port number [(117 * 256) + 67 = 30019 ] for data
