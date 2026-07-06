------------------------ vault-id with prompt -------------------------------
[1] Using 'vault-id' to encrypt and decrept:
"""
We will save our vault password within $HOME/.bashrc of the ansible user.
"""
[a] Creating the vault_pass entry
$vim $HOME/.bashrc
export vault_pass='<YOUR_CRITICAL_VAULT_PASSWORD>'

[b] Loading modified .bashrc
$source $HOME/.bashrc

[c] Encrypting an existing file:

$ansible-vault encrypt playbooks/Files/mysecret_file --vault-id prod@<(echo $vault_pass)

notes:
- Ingestion of vault password is happening through '<(echo $vault_pass)'
- prod@ here is the vault id

[d] Decrypting an encrypted file:

ansible-vault view playbooks/Files/mysecret_file --vault-id <(echo $vault_pass)


[e] Performing re-keying using vault-id:
Add another vault password into the environment file which will be used for re-keying

$vim $HOME/.bashrc

export prod_vault_pass='<PASS>'

$source $HOME/.bashrc

Performing the re-key operation:
$ ansible-vault rekey playbooks/Files/mysecret_file --vault-id <(echo $vault_pass) --new-vault-id dev@<(echo $prod_vault_pass)

Test if it is working by read the file back with new encrypted password:
$ansible-vault view playbooks/Files/mysecret_file --vault-id <(echo $prod_vault_pass)



[f] Decrypting a file using 'vault-id':
$ansible-vault decrypt playbooks/Files/mysecret_file --vault-id <(echo $prod_vault_pass)


---------------------- vault-id with vault password file -----------------------------
[a] Inside 'project/ansible' directoyr which is your base directory create a directory called '._vault': mkdir ._vault
chmod -R 750 ._vault

[b] Create 'dev-vault' file inside the '._vault' directory:
vim ._vault/dev-vault
chmod 0600 ._vault/dev-vault

[c] Create 'dev-db-credential.yml' within 'project or ansible directory':
vim playbooks/Files/dev-db-credential.yml

db_password: "<Your DB Password>"

[d] Encrypt the password file with --vault-id and vault file:
ansible-vault encrypt playbooks/Files/dev-db-credential.yml --vault-id dev@._vault/dev-vault

[e] Execute the playbook:
Validation: 
ansible-navigator run playbooks/encryption-with-vault-id-test.yml --vault-id dev@._vault/dev-vault --syntax-check

Execution:
ansible-navigator run playbooks/encryption-with-vault-id-test.yml --vault-id dev@._vault/dev-vault

------------------------- using the ._vault/dev-vault file as vault password file ----------------------- 
Execution:
ansible-navigator run playbooks/encryption-with-vault-id-test.yml --vault-password-file ._vault/dev-vault


------------------------- Working with classroom-ca.pem -------------------------------
Encrypting the certificate file: ansible-vault encrypt playbooks/Files/classroom-bundle.pem --vault-id prod@._vault/dev-vault

