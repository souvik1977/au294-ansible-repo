# Chapter 4 - Enforcing SELinux on a servers

## 1- Install nginx and php-fpm

This playbook will perform below actions on the servers

There are two plays

## 2- First Play

- Installation of requried packages

        - selinux-policy-targeted
        - policycoreutils
        - policycoreutils-python-utils
        - libselinux-utils
        - python3-libselinux

- Create '/.autorelabel' file on the servers

- Enforcing SELinux if disabled or Permissive

- Performs reboot operation post SELinux enforcement

## 3- Second Play

- Wait for Servers to come up post reboot

- Capture the SELinux State (Conditional)

- Display SELinux State (Conditional)

## 4- Troubleshooting

In case you are facing issue with half compiled SELinux issue follow the below steps

a- Reboot the server

b- While booting interrupt the booting sequence by pressing any key [space-bar]

c- Select the active kernel and press 'e'

d- Move to the line contains 'kernel' and move cursor to the end

e- write 'selinux=0'

f- Ctrl + x to reboot the server with SELinux disabled

g- Once login:

    touch /.autorelabel

    reboot
