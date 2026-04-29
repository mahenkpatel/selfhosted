#!/usr/bin/env bash

# 1. Source the library
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

# 2. Capture Container Name
echo -e "${YW}Enter a name for your new Docker LXC:${CL}"
read -r HN
HN=${HN:-docker-lxc} 

# 3. Define Resource & Automation Variables
APP="Docker"
NSAPP="true"      # Skip initial confirmation
var_tags="docker"
var_cpu="2"
var_ram="512"
var_disk="2"
var_os="debian"
var_version="13"
var_unprivileged="1"
var_hostname="$HN"

# --- THE FIX: PRE-ANSWER PORTAINER QUESTIONS ---
# Setting these to "no" prevents the library from asking
export INSTALL_PORTAINER="no"
export INSTALL_PORTAINER_AGENT="no"

# --- DNS FIX: Ensure resolution works inside the build context ---
export DNS_SERVERS="8.8.8.8 1.1.1.1"

# 4. Initialize Build
header_info "$APP"
variables
color
catch_errors

start
build_container

# 5. Custom Post-Installation Block
msg_info "Configuring 'ubuntu' user, Timezone, and Permissions"

# Set Timezone
$STD timedatectl set-timezone Asia/Kolkata

# Create user 'ubuntu'
if ! id "ubuntu" &>/dev/null; then
    $STD useradd -m -s /bin/bash ubuntu
    echo "ubuntu:password" | $STD chpasswd
fi

# Add to Docker group and setup .docker directory
# (Docker is now installed correctly because DNS is forced)
if getent group docker > /dev/null 2>&1; then
    $STD usermod -aG docker ubuntu
    msg_ok "User 'ubuntu' added to docker group"
else
    # Fallback install if the library step failed
    msg_info "Docker group missing, running manual install..."
    $STD apt-get update
    $STD apt-get install -y docker-ce docker-ce-cli containerd.io
    $STD usermod -aG docker ubuntu
fi

$STD mkdir -p /home/ubuntu/.docker
$STD chown -R ubuntu:ubuntu /home/ubuntu/.docker
$STD chmod 700 /home/ubuntu/.docker

msg_ok "Post-install configuration complete"

# 6. Finalization
description
msg_ok "Completed successfully!\n"

echo -e "${CREATING}${GN}${HN} setup has been successfully initialized!${CL}"
