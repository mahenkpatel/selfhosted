#!/usr/bin/env bash

# 1. Source the library
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

# 2. Capture Container Name
echo -e "${YW}Enter a name for your new Docker LXC:${CL}"
read -r HN
HN=${HN:-docker-lxc} 

# 3. Automation Variables
APP="Docker"
NSAPP="true"
export STABLE="yes"
export INSTALL_PORTAINER="no"
export INSTALL_PORTAINER_AGENT="no"
export EXPOSE_DOCKER="n"
export DNS_SERVERS="8.8.8.8 1.1.1.1"

# Resource Overrides
var_tags="docker"
var_cpu="2"
var_ram="512"
var_disk="2"
var_os="debian"
var_version="12" # Changed to 12 (Bookworm) for repository compatibility
var_unprivileged="1"
var_hostname="$HN"

# 4. Initialize Build
header_info "$APP"
variables
color
catch_errors

start
build_container

# 5. Custom Post-Installation Block
msg_info "Configuring 'ubuntu' user and Docker Repositories"

# Set Timezone
$STD timedatectl set-timezone Asia/Kolkata

# Force Docker Repo to Bookworm (prevents the Trixie 404 error)
$STD apt-get update
$STD apt-get install -y ca-certificates curl gnupg
$STD mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
$STD apt-get update

# Install Docker packages explicitly using the verified repo
$STD apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Create user 'ubuntu'
if ! id "ubuntu" &>/dev/null; then
    $STD useradd -m -s /bin/bash ubuntu
    echo "ubuntu:password" | $STD chpasswd
fi

# Permissions and directory setup
$STD usermod -aG docker ubuntu
$STD mkdir -p /home/ubuntu/.docker
$STD chown -R ubuntu:ubuntu /home/ubuntu/.docker
$STD chmod 700 /home/ubuntu/.docker

msg_ok "Post-install configuration complete"

# 6. Finalization
description
msg_ok "Completed successfully!\n"

echo -e "${CREATING}${GN}${HN} setup has been successfully initialized!${CL}"
