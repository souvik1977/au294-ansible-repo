------------------------------------- template -------------------------------------------
[a] Create a 'httpd.conf' template insile your ansible root [in my case 'playbooks'] directory/files:
vim playbooks/files/httpd.conf [copy the contents from httpd.conf and paste here]

[b] Create a '.htaccess' template insile your ansible root [in my case 'playbooks'] directory/files:
vim playbooks/files/.htaccess [copy the contents from .htaccess and paste here]

[c] Create SSL Certificate file and key file inside 'files' directory:
openssl req -x509 -nodes -days 3650 -newkey rsa:4096 -keyout playbooks/files/server.key -out playbooks/files/server.crt

[d] Create a file named 'vars/secret.yml' on the ansible host under your root ansible folder [my case $HOME/ansible/vars ] which will contains the password to access the remote server:

web_pass: <Password for user 'guest' as defined into the instruction >

[e] Create a vault-password file inside your vault directory [in my case it is 'ansible/._vault'] named web-user contains vault password:

vim $HOME/ansible/._vault/web-user
content: <Your Vault Password >

[f] Encrypt your '$HOME/ansible/playbooks/vars/secret.yml' file:
ansible-vault encrypt $HOME/ansible/playbooks/vars/secret.yml --vault-id web-user@._vault/web-user

[g] Create pre-configured 'files/htpasswd' file on the ansible host:
Here we are going to use 'guest' as user name to connect to our webserver followed by the password ['redhat']

Generate a password hash for 'guest' user with 'redhat' password on the controller node: 
sudo dnf install httpd-tools
htpasswd -bc /tmp/htpasswd guest redhat

you will get a hash.

cat /tmp/htpasswd > files/htpasswd [Content]

guest:<Your Hashed Password >

Make sure that there are no gaps between 'guest:' and the hashed password

--------------------------- Execution -----------------------------------------
Checking for syntax err:
ansible-navigator run playbooks/webserver.yml --vault-password-file ._vault/web-user --syntax-check

Performing try run:
ansible-navigator run playbooks/webserver.yml --vault-password-file ._vault/web-user --check

Execution:
ansible-navigator run playbooks/webserver.yml --vault-password-file ._vault/web-user

Starting the playbook at a specific task:
[a] Get the task lists:
ansible-navigator run playbooks/webserver.yml --vault-password-file ._vault/web-user --list-tasks

[b] Executing at a specific task:
ansible-navigator run playbooks/webserver.yml --vault-password-file ._vault/web-user --start-at-task "testing connectivity to the remote server"


Manual Testing from ServerD:
curl -vk https://serverB.domain24.example.net
curl -vk -u guest:<actual_password> https://serverB.domain24.example.net

curl -vk -u guest:redhat https://serverB.domain24.example.net


Troubleshooting:
On serverB or serverC Check required modules got loaded or not:
httpd -M | egrep 'rewrite|auth'

Target modules:
rewrite_module
auth_basic_module
authn_file_module
authz_user_module

Check if htpasswd file is visible to apache on ServerB or ServerC:
namei -om /etc/httpd/secrets/htpasswd


Check the configuraiton:
httpd -t -D DUMP_RUN_CFG

On ServerB or serverC check if apache is able to read the file:
 sudo -u apache cat /etc/httpd/secrets/htpasswd



