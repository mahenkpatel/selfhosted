#!/usr/bin/env bash

# 1. Source the library
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

# 2. Capture Container Name
echo -e "${YW}Enter a name for your new Docker LXC:${CL}"
read -r HN
HN=${HN:-docker-lxc} 

# 3. Define Resource & Automation Variables
APP="Docker"
NSAPP="true"      # Skip the "Do you want to proceed?" prompt
var_tags="docker"
var_cpu="2"
var_ram="512"
var_disk="2"
var_os="debian"
var_version="13"
var_unprivileged="1"
var_hostname="$HN"

# 4. Initialize Build
header_info "$APP"
variables
color
catch_errors

# Executes the container creation and Docker installation
start
build_container

# 5. Custom Post-Installation Block
msg_info "Configuring 'ubuntu' user, Timezone, and Permissions"

# Set Timezone (Defaulted to Asia/Kolkata, change if needed)
$STD timedatectl set-timezone Asia/Kolkata

# Create user 'ubuntu' with password 'password'
if ! id "ubuntu" &>/dev/null; then
    $STD useradd -m -s /bin/bash ubuntu
    echo "ubuntu:password" | $STD chpasswd
fi

# Add to Docker group and setup .docker directory
$STD usermod -aG docker ubuntu
$STD mkdir -p /home/ubuntu/.docker
$STD chown -R ubuntu:ubuntu /home/ubuntu/.docker
$STD chmod 700 /home/ubuntu/.docker

msg_ok "Post-install configuration complete"

# 6. Finalization
description
msg_ok "Completed successfully!\n"

echo -e "${CREATING}${GN}${HN} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Timezone set to: $(cat /etc/timezone)${CL}"
echo -e "${INFO}${YW} Access the container via Proxmox console or 'pct enter'${CL}"
