## This document will describe how to practice collections installation in RHCE style

[a] - Create a requirements.yml file with below contents (or based on your requirement)

vim requirements.yml

---
collections:
  - name: amazon.aws
    version: "10.3.1"
  - name: ansible.netcommon
    version: "7.1.0"
  - name: ansible.utils
    version: "5.1.1"

[b] - Create a temporary stagging directory to hold the tar.gz files

mkdir /tmp/offline_packages

[c] - Download packages

ansible-galaxy collection download -r collections/requirements.yml -p /tmp/offline_packages

above command will download 'tar.gz' files and will create 'requirements.yml' file 

[d] - Installing collections 

cd /tmp/offline_packages

Install tar.gz one my one

ansible-galaxy collection install amazon-aws-10.3.1.tar.gz -p $HOME/ansible/collections

ansible-galaxy collection install ansible-netcommon-7.1.0.tar.gz -p $HOME/ansible/collections

ansible-galaxy collection install ansible-utils-5.1.1.tar.gz -p $HOME/ansible/collections

[e] - Check collections:

cd $HOME/ansible  [Switch back to your ansible project directory]

ansible-galaxy collection list -p ./collections

