# Chapter 4 - Handler Lesson Info

## 1- Install nginx and php-fpm

This play will install nginx, php-fpm on the webservers over port 8080 as we are already using httpd service on the same servers on port 443 [Ref: chapter3-webserver.yml]

## 2- Supporting configuration files

There are two supporting files named 'nginx.conf.j2' and 'php-fpm.conf.j2' both should be under 'files/' directory inside your playbook root. In my case it is 'playbook' directory

## 3- Two Plays

There are two plays into this playbook. First play will perform, below tasks

- Installation of the packages

- Configuring firewall on port 8080

- Creating '/var/www/nginx' directory as document root

- Creating an index.php file under '/var/www/nginx/' directory

- Setting up SELinux Context to 'httpd_sys_content_t'

- Performing restorecon command

- Performing service restart through handler

Second Play will perform below tasks:

- Test the connectivity over the port 8080

- Display the results

## 4- Playbook name

chapter4-handler-lesson.yml
