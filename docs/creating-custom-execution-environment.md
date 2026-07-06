### Purpose: Creating our own Execution Environment to mimic Red Hat AAP (Ansible Automation Platform)
## RedHat Execution Flow:
# controller
#     |
#    copies project => /runner/project
#    copies inventory => /runner/inventory
#    copies env => /runner/env


### Purpose of each component of RedHat AAP ###
EE (Execution-Environment) : How to Run (Python, Ansible)
    EE Contains:
    - ansible-core
    - ansible-runner
    - python
    - system-dependencies
    - collections

Runner : How to Execute (path, structure, orchestration)
Controller : What to run (playbook, credentials)

#### Assumptions ####
# 'devops' user is existing on the controller node
# current working directory "/home/devops" if not then follow below steps
Perform all below actions as devops user

##### End Assumptions ####


###### Create a ssh-key for devops user##############
[a] Add 'devops' user on the controller machine:
$ sudo useradd -m devops
$ sudo passwd devops
$ sudo mkdir /home/devops/.ssh
$ sudo chown -R devops:devops /home/devops/.ssh
$ sudo chmod -R 700 /home/devops/.ssh


[b] Creating ssh-key pair
$ sudo ssh-keygen -t rsa -b 4096 -f /home/devops/.ssh/controller-key
Modify the username of the generated key:
$ sudo vim /home/devops/.ssh/controller-key.pub

replace 'root' with 'devops'

###### End of SSH Key ############

#### Steps #######
[step-0]: Install required packages
# dnf install -y python3-pip podman git

[step-1]: Install ansible-core, ansible-navigator, ansible-build:
# python3 -m pip install ansible-builder --user
# python3 -m pip install yq --user
# python3 -m pip install ansible-navigator --user

## Setting up PATH variable to "~/.local/bin".
echo 'export PATH=$PATH:$HOME/.local/bin' >> ~/.profile
source ~/.profile

## Check the versions ##
ansible-builder --version
ansible-runner --version
ansible-navigator --version
git --version

# [step-1]: Create required directory structure
[1.a - We will create one container image for execution environment with 'devops' user and ssh-key 
"""
Here we will hardcode the user name and ssh-key to setup. 
Check 'execution-environment-hardcode.yml' for details.
Rename the file as 'execution-environment-hardcode.yml' to 'execution-environment.yml'
"""
]
$mkdir -p ~/secure-ee/files 

[1.b - We will create RedHat Style EE
"""
Here we will create a actual RedHat type execution environment where any user or any ssh-key will work.
This is recommended approach rather than 1.a
"""
]
Create a directory structure inside your working directory:

$mkdir -p $PWD/aae/files       


[1.c - We will create one container image for execution environment with 'devops' user and ssh-key ]
$cd secure-ee | aae           [depending upon the directory you are working ]

[1.d - Create ] (Optional - not recommended as this is has explained in 1a. )
### We will create 'execution-environment.yml' file ###

$vim execution-environment.yml

version: 3
images:
  base_image:
    name: ghcr.io/ansible-community/community-ee-minimal:latest

dependencies:
  ansible_core:
    package_pip: ansible-core==2.20.5
  ansible_runner:
    package_pip: ansible-runner==2.4.3
  galaxy: requirements.yml
  python: requirements.txt
  system: bindep.txt

additional_build_files:
  - src: files/controller-key
    dest: ssh/

additional_build_steps:
  append_final:
    - RUN useradd -m devops
    - RUN mkdir -p ~/devops/.ssh
    - COPY --chown=devops:devops _build/ssh/controller-key /home/devops/.ssh/controller-key
    - RUN chmod 600 /home/devops/.ssh/controller-key
    - RUN echo "Host *" >> /home/devops/.ssh/config
    - RUN echo "   IdentityFile /home/devops/.ssh/controller-key" >> /home/devops/.ssh/config
    - RUN echo "   StrictHostKeyChecking no" >> /home/devops/.ssh/config
    - RUN chown -R devops:devops /home/devops/.ssh || true


### We will create 'execution-environment.yml' file ###
$vim execution-environment.yml

version: 3
images:
  base_image:
    name: ghcr.io/ansible-community/community-ee-minimal:latest

dependencies:
  ansible_core:
    package_pip: ansible-core==2.20.5
  ansible_runner:
    package_pip: ansible-runner==2.4.3
  galaxy: requirements.yml
  python: requirements.txt
  system: bindep.txt

additional_build_files:
  - src: files/controller-key
    dest: ssh/

additional_build_steps:
  append_final:
    - USER root
    - RUN dnf install -y openssh-clients && dnf clean all
    - ENV ANSIBLE_GALAXY_SERVER_TIMEOUT=120
    - ENV ANSIBLE_GALAXY_DISABLE_GPG_VERIFY=1


### [Imp Note - You can change 'anisble-core' and 'ansible-runner' versions as required. ]

### (Start of Optional Block ###)
[1.e - Copying private-key from the $HOME/.ssh/<private-key> to '[secure-ee | aae]/files' directory ]
#cp ~/.ssh/<private-key> ~/secure-ee/files/<private-key>
or
#cp ~/.ssh/<private-key> ~/aae/files/<private-key>

### (Start of Optional Block ###)

# [1.f - Creating Supporting files to support exection-environment.yml ]

## Creating supporting documents ###
$cat<<EOF >requirements.yml
collections:
  - name: ansible.posix
  - name: community.general
EOF

## Creating 'requirements.txt' 

$cat<<EOF >requirements.txt
requests
netaddr
EOF

## Creating 'bindep.txt'

$cat<<EOF >bindep.txt
openssh-clients [platform:rpm]
iputils [platform:rpm]
EOF

#### [Step-2]: Building Container Image ####

$ansible-builder build -t my-custom-ee [--verbosity | --verbose]  3

Note: """
In few machines 'ansible-builder build' command accepts --verbose and in other few it might accept '--verbosity'.
This command will create context and will save inside 'context' directory, which will contains the 'Containerfile' and '_build' directory
"""

[-t <tag>]
This will take some-time to create your container image

## [Step-3]: Check the images and cleanup
$sudo systemctl enable --now podman
$sudo systemctl status podman
$podman images
$podman image prune [To remove intermediate images]

## Output:

REPOSITORY                                      TAG         IMAGE ID      CREATED      SIZE
localhost/my-aae-ee                             latest      5212838c95d2  2 hours ago  501 MB
localhost/my-custom-ee                          latest      a98d2e22abbc  8 hours ago  500 MB


## [Step-4]: Check current image
$ansible-navigator exec "pwd" --eei my-custom-ee

--eei => Execution Environment Image

## [Step-5]: Creating ansible-navigator.yml Sample file ###

$mkdir projects
$cd projects   [Ensure 'ansible' directory exists inside '/home/devops/' ]
$ansible-navigator settings --effective --mode stdout | yq -y > /tmp/test-ansible-navigator.yml

## Copying sample file to '/home/devops/ansible'
$cp /tmp/test-ansible-navigator.yml /home/devops/projects/ansible-navigator.yml

or create a file manually:
$cd projects
$vim ansible-navigator.yml

---
ansible-navigator:
  mode: stdout
  ansible:
    config:
      help: false
      path: /home/devops/projects/ansible.cfg
    doc:
      help: false
      plugin:
        type: module
    inventory:
      entries:
      - /home/devops/projects/inventory
      help: false
    playbook:
      help: false
  ansible-builder:
    help: false
    workdir: /home/devops/projects
  ansible-runner:
    job-events: false
  app: settings
  collection-doc-cache-path: /home/devops/.cache/ansible-navigator/collection_doc_cache.db
  color:
    enable: true
    osc4: true
  editor:
    command: vi +{line_number} {filename}
    console: true
  enable-prompts: false
  exec:
    command: /bin/bash
    shell: true
  execution-environment:
    container-engine: podman
    #container-options:
    #  - "--user=devops"
    enabled: true
    volume-mounts:
      - src: .
        dest: /runner/project
      - src: $HOME/.ssh
        dest: /home/devops/.ssh
    #image: ghcr.io/ansible/community-ansible-dev-tools:latest
    image: my-aae-ee:latest
    pull:
        policy: missing
    # ---- Add this to force the container to execute from mount -----
    container-options:
        - "--workdir=/runner/project"
    environment-variables:
      set:
        ANSIBLE_COLLECTIONS_PATHS: /runner/project/collections
  format: yaml
  images:
    details:
    - everything
  logging:
    append: true
    file: /home/devops/projects/ansible-navigator.log
    level: warning

  playbook-artifact:
    enable: false
    save-as: '{playbook_dir}/{playbook_name}-artifact-{time_stamp}.json'
  settings:
    effective: true
    sample: false
    schema: json
    sources: false
  time-zone: UTC


Notes: """
image - parameter must match with your custome Execution image (output of 'podman images')
/home/devops - can be anything but must be replace properly as per your configuration
"""



## [Step-6]: Execution ###
#ansible-navigator run <Your_Playbook>