#!/bin/bash

# Add logging later

# Create ctera group and user
function setup_user() { 
adduser ctera && echo "created user"
groupadd ctera
usermod -aG wheel,ctera ctera
}


# edit sshd_config
edit_sshd_config() {
  file="/etc/ssh/sshd_config"  # Define the file to edit.
  for PARAM in "${param[@]}"
  do
    /usr/bin/sed -i "/^${PARAM}/d" "$file"
    echo "All lines beginning with '${PARAM}' were deleted from $file."
  done
  
  for PARAM_VALUE in "${param_values[@]}"
  do
    echo "$PARAM_VALUE" >> "$file"
    echo "'$PARAM_VALUE' was added to $file."
  done
}

reload_sshd_config() {
   systemctl reload sshd.service
   echo "Run 'systemctl reload sshd.service'...OK"
}

setup_and_activate_firewall_rules(){
  yum install -y firewalld
  systemctl start firewalld
  # Consider enabling
  echo "Adding firewall rules for HTTP, HTTPS, DNS, NTP, and Rsync..."
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  firewall-cmd --permanent --add-service=dns
  firewall-cmd --permanent --add-service=ntp
  # Rsync
  firewall-cmd --permanent --add-port=873/tcp
  firewall-cmd --reload
  echo "Firewall configuration completed."

}

setup_docker(){
  yum install -y yum-utils
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  # docker post install
  groupadd docker
  usermod -aG docker ctera
  usermod -aG docker centos
  newgrp docker
  systemctl start docker && systemctl enable docker
}

pull_nginx(){
  docker pull nginx
}

remove_obsolet_rpm(){
  if [ -f obsolete.txt ]; then
      echo "Removing obsolete RPM packages..."
      xargs yum remove -y < obsolete.txt
  else
      echo "No obsolete.txt file found, skipping package removal."
  fi

}

update_system(){
  echo "Updating system..."
  yum update -y
  echo "System updated."
}

# Usage of the function should define both the parameters to be deleted and the full lines to be added
# param=("PasswordAuthentication" "PubkeyAuthentication" "AuthorizedKeysFile")
# param_values=("PasswordAuthentication no" "PubkeyAuthentication yes" "AuthorizedKeysFile .ssh/authorized_keys")
# edit_sshd_config

# reload_sshd_config

# setup_and_activate_firewall_rules
# setup_docker
pull_nginx
remove_obsolet_rpm
update_system
