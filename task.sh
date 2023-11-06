#!/bin/bash

# Add logging later

# Create ctera group and user
function setup_user() { 
adduser ctera && echo "created user"
groupadd ctera
usermod -aG wheel,ctera ctera
}


# edit sshd_config


