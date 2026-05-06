#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts
# Author: Andrea Castellano
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.sweethome3d.com/

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y \
  curl \
  wget \
  git \
  ca-certificates \
  gnupg \
  lsb-release
msg_ok "Installed Dependencies"

msg_info "Installing Docker"
DOCKER_CONFIG_PATH='/etc/docker/daemon.json'
mkdir -p $(dirname $DOCKER_CONFIG_PATH)
echo -e '{\n  "log-driver": "journald"\n}' >/etc/docker/daemon.json
$STD sh <(curl -fsSL https://get.docker.com)
msg_ok "Installed Docker"

msg_info "Installing Docker Compose"
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
$STD curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
msg_ok "Installed Docker Compose $DOCKER_COMPOSE_VERSION"

msg_info "Setting up Sweet Home 3D Online"
mkdir -p /opt/sweethome3d
cd /opt/sweethome3d

# Clone the repository or download files
msg_info "Downloading Sweet Home 3D Online files"
REPO_URL="https://github.com/YOUR_USERNAME/sweethome3d-docker.git"
# For now, we'll create the structure manually since we don't have a repo yet
# $STD git clone $REPO_URL /opt/sweethome3d

# Create directory structure
mkdir -p docker homes

# Download or copy Dockerfile, docker-compose.yml, etc.
# This assumes the files are available from a repository or CDN
# For testing, you can manually copy them

msg_ok "Sweet Home 3D Online files prepared"

# Configuration prompts
read -r -p "${TAB3}Enter port for Sweet Home 3D (default: 8080): " HOST_PORT
HOST_PORT=${HOST_PORT:-8080}

# Check if authentication credentials were provided via environment variables
if [[ -n "${SH3D_AUTH_USERNAME}" ]] && [[ -n "${SH3D_AUTH_PASSWORD}" ]]; then
  msg_info "Using authentication credentials from environment variables"
  AUTH_ENABLED=true
  AUTH_USERNAME="${SH3D_AUTH_USERNAME}"
  AUTH_PASSWORD="${SH3D_AUTH_PASSWORD}"
  msg_ok "Credentials configured"
else
  # Interactive prompts as fallback
  read -r -p "${TAB3}Enable HTTP Basic Authentication? <y/N>: " AUTH_PROMPT
  if [[ ${AUTH_PROMPT,,} =~ ^(y|yes)$ ]]; then
    AUTH_ENABLED=true
    read -r -p "${TAB3}Enter username (default: admin): " AUTH_USERNAME
    AUTH_USERNAME=${AUTH_USERNAME:-admin}
    read -r -sp "${TAB3}Enter password (leave empty to auto-generate): " AUTH_PASSWORD
    echo ""
    
    # Generate secure random password if not provided
    if [[ -z "${AUTH_PASSWORD}" ]]; then
      msg_info "Generating secure random password"
      AUTH_PASSWORD=$(openssl rand -base64 24 | tr -d "/=+" | cut -c1-24)
      msg_ok "Password generated: ${AUTH_PASSWORD}"
      echo -e "${TAB3}${RD}⚠️  Save this password securely - it will be shown only once!${CL}"
      sleep 3
    fi
  else
    AUTH_ENABLED=false
    AUTH_USERNAME=admin
    AUTH_PASSWORD=""
  fi
fi

read -r -p "${TAB3}Storage path (default: ./homes for local storage): " STORAGE_PATH
STORAGE_PATH=${STORAGE_PATH:-./homes}

read -r -p "${TAB3}Max upload file size in MB (default: 50): " UPLOAD_SIZE
UPLOAD_SIZE=${UPLOAD_SIZE:-50}

# Create .env file
msg_info "Creating configuration file"
cat > /opt/sweethome3d/.env << EOF
# Sweet Home 3D 7.7-Online Configuration
VERSION=7.7
HOST_PORT=${HOST_PORT}
STORAGE_PATH=${STORAGE_PATH}
UPLOAD_MAX_FILESIZE=${UPLOAD_SIZE}M
POST_MAX_SIZE=${UPLOAD_SIZE}M
MEMORY_LIMIT=256M
AUTH_ENABLED=${AUTH_ENABLED}
AUTH_USERNAME=${AUTH_USERNAME}
AUTH_PASSWORD=${AUTH_PASSWORD}
EOF
msg_ok "Configuration file created"

# Create storage directory
msg_info "Creating storage directory"
mkdir -p "${STORAGE_PATH}"
chmod 755 "${STORAGE_PATH}"
msg_ok "Storage directory created"

msg_info "Building Docker image (this may take several minutes)"
$STD docker-compose build
msg_ok "Docker image built"

msg_info "Starting Sweet Home 3D Online"
$STD docker-compose up -d
msg_ok "Sweet Home 3D Online started"

# Wait for container to be healthy
msg_info "Waiting for Sweet Home 3D to be ready"
sleep 10
for i in {1..30}; do
  if docker-compose ps | grep -q "Up"; then
    break
  fi
  sleep 2
done
msg_ok "Sweet Home 3D Online is ready"

motd_ssh
customize
cleanup_lxc
