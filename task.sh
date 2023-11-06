#!/bin/bash

exec > >(tee -i setup.log)
exec 2>&1



require_sudo() {
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root!" >&2
        exit 1
    fi
    echo "Starting Script Execution"
}


# Create ctera group and user
function setup_user() { 
  echo "Creating group and user 'ctera'..."
  adduser ctera && echo "created user ctera" || echo "failed to create user"
  usermod -aG wheel,ctera ctera && echo "added user cetera to wheel group" || echo "failed to add user to group"
}


edit_sshd_config() {
  echo "editing the sshd config file"
  file="/etc/ssh/sshd_config"  
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

  # Check if sshd conf is Valid
  if ! /usr/sbin/sshd -t -f "$file"; then
      echo "There was a syntax error in the sshd_config file! Continuing with the script anyway..."
    else
      echo "sshd_config file was edited and is valid."
    fi

}

reload_sshd_config() {
   systemctl reload sshd.service && echo "restarted 'systemctl reload sshd.service'...OK" || echo "Failed to reload 'sshd.service'."
}

setup_and_activate_firewall_rules(){
  echo "installing firwalld"
  yum install -y firewalld
  systemctl start firewalld

  echo "Adding firewall rules for HTTP, HTTPS, DNS, NTP, and Rsync..."
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  firewall-cmd --permanent --add-service=dns
  firewall-cmd --permanent --add-service=ntp
  # Rsync
  firewall-cmd --permanent --add-port=873/tcp
  firewall-cmd --reload && echo "Firewall rules are active"
  echo "Firewall configuration completed."

}

setup_docker(){
  echo "installing Docker"
  yum install -y yum-utils
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin 
  if [ $? -ne 0 ]; then
    echo "Failed to install Docker Engine and its components."
  else
    echo "Docker was installed"
  fi

  # docker post install
  groupadd docker
  usermod -aG docker ctera
  usermod -aG docker centos
  echo "Starting docker"
  systemctl start docker && systemctl enable docker && echo "docker process started and enabled"
}


pull_nginx(){
  echo "Pulling nginx image"
  docker pull nginx && echo "Nginx image was pulled sucessfully"
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

install_rpm_from_dkpg_folder(){
  if [ -d pkgs ]; then
    echo "Installing RPM packages from pkgs directory..."
    yum install -y pkgs/*.rpm
  else
    echo "pkgs directory does not exist, skipping custom package installation."
  fi
}


setup_webserver(){
  echo "Setting up web server..."
  docker network create webnet
  echo "hello world!" > index.html
  docker run -d --name webapp --network webnet -v "$PWD/index.html:/usr/share/nginx/html/index.html" nginx && echo "web server is up and running" || echo "docker failed to intsall web server"
}

setup_reverse_proxy(){
    cat > default.conf <<EOF
    server {
        listen 80;
        location /app {
            proxy_pass http://webapp/;
        }
    }
EOF

    docker run -d --name nginx-proxy --network webnet -v "$PWD/default.conf:/etc/nginx/conf.d/default.conf" -p 80:80 nginx && echo "Reverse proxy setup complete." || echo "reverse proxy setup failed"
}

require_sudo
setup_user

param=("PasswordAuthentication" "PubkeyAuthentication" "AuthorizedKeysFile")
param_values=("PasswordAuthentication no" "PubkeyAuthentication yes" "AuthorizedKeysFile .ssh/authorized_keys")
edit_sshd_config
reload_sshd_config

setup_and_activate_firewall_rules
setup_docker
pull_nginx
remove_obsolet_rpm
# update_system
install_rpm_from_dkpg_folder
setup_webserver
setup_reverse_proxy