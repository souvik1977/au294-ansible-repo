# Chapter6 - Task and Playbook import Demo

## 1 - Directory Structure

playbooks/
├── chapter6-import-tasks-demo.yml
├── chapter6-import-task-test-website.yml
├── tasks
│   ├── environment.yml
│   ├── firewall.yml
│   └── placeholder.yml
├── vars
│   └── secret.yml

## 2 - Note

Assumptions - You have already implemented 'chapter3-webserver-lab' and configured your

- vault password file

- encrypted htpasswd saved under 'vars/secret.yml' file as the same test configuration towards the
  same webservers using htaccess and htpasswd will be used to test the funcitonality.

- You can apply this playbook on a fresh server and in that case you need to modify 'chapter6-import-task-test-website.yml' accordingly

## 3 - Execution

ansible-navigator run playbooks/chapter6-import-tasks-demo.yml --start-at-task "Test Web Services" --vault-password-file ._vault/web-user
