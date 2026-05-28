#!/usr/bin/env bash
# Sweet Home 3D 7.7-Online - Proxmox LXC Installation Script
# Community Scripts Standard Compliant
# Automatically creates container and installs Sweet Home 3D with Docker
#
# Copyright (c) 2021-2026 community-scripts
# Author: Andrea Castellano
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.sweethome3d.com/

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

APP="Sweet Home 3D Online"
var_tags="${var_tags:-3d-design;home-design}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

# Export authentication credentials if provided via environment variables
# Usage: SH3D_AUTH_USERNAME=myuser SH3D_AUTH_PASSWORD='MyPass!' bash -c "$(wget -qLO - ...)"
export SH3D_AUTH_USERNAME="${SH3D_AUTH_USERNAME:-}"
export SH3D_AUTH_PASSWORD="${SH3D_AUTH_PASSWORD:-}"

header_info "$APP"
variables
color
catch_errors

# Update function for later updates
function update_script() {
  header_info
  check_container_storage
  check_container_resources

  msg_info "Updating Sweet Home 3D Online"
  pct exec "$CTID" bash -c "cd /opt/sweethome3d && docker-compose pull"
  pct exec "$CTID" bash -c "cd /opt/sweethome3d && docker-compose up -d --force-recreate"
  msg_ok "Sweet Home 3D Online updated"

  msg_ok "Updated successfully!"
  exit
}

start

# Create and build container
build_container

# Installation inside container - executed after container is created
msg_info "Installing Sweet Home 3D inside container..."

pct exec "$CTID" bash <<'INSTALLATION_SCRIPT'
#!/bin/bash
set -e

# Update system
apt-get update > /dev/null 2>&1
apt-get install -y \
    curl wget git ca-certificates gnupg lsb-release \
    > /dev/null 2>&1

# Install Docker
mkdir -p /etc/docker
echo -e '{\n  "log-driver": "journald"\n}' > /etc/docker/daemon.json
sh <(curl -fsSL https://get.docker.com) > /dev/null 2>&1

# Install Docker Compose
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest 2>/dev/null | grep 'tag_name' | cut -d\" -f4)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose 2>/dev/null
chmod +x /usr/local/bin/docker-compose

# Setup Sweet Home 3D directory
mkdir -p /opt/sweethome3d
cd /opt/sweethome3d

GITHUB_RAW="https://raw.githubusercontent.com/andry360/sweethome3d-docker/main"

mkdir -p docker backups homes
chmod 775 homes

# Download files from repository
wget -q -O Dockerfile "${GITHUB_RAW}/Dockerfile"
wget -q -O docker-compose.yml "${GITHUB_RAW}/docker-compose.yml"
wget -q -O .env.example "${GITHUB_RAW}/.env.example"
wget -q -O backup-homes.sh "${GITHUB_RAW}/backup-homes.sh"
wget -q -O restore-homes.sh "${GITHUB_RAW}/restore-homes.sh"
chmod +x backup-homes.sh restore-homes.sh

mkdir -p docker
wget -q -O docker/apache-config.conf "${GITHUB_RAW}/docker/apache-config.conf"
wget -q -O docker/htaccess.conf "${GITHUB_RAW}/docker/htaccess.conf"
wget -q -O docker/entrypoint.sh "${GITHUB_RAW}/docker/entrypoint.sh"
chmod +x docker/entrypoint.sh

# Create .env file with provided credentials
AUTH_ENABLED=false
[[ -n "${SH3D_AUTH_USERNAME}" ]] && AUTH_ENABLED=true

cat > .env << EOF
VERSION=7.7
HOST_PORT=8080
STORAGE_PATH=./homes
UPLOAD_MAX_FILESIZE=50M
POST_MAX_SIZE=50M
MEMORY_LIMIT=256M
AUTH_ENABLED=${AUTH_ENABLED}
AUTH_USERNAME=${SH3D_AUTH_USERNAME:-admin}
AUTH_PASSWORD=${SH3D_AUTH_PASSWORD:-}
EOF

# Build and start Sweet Home 3D
export DOCKER_BUILDKIT=1
docker-compose build
docker-compose up -d

# Wait for container to be ready
sleep 15
for i in {1..60}; do
  if docker-compose ps 2>/dev/null | grep -q "Up"; then
    break
  fi
  sleep 2
done

INSTALLATION_SCRIPT

msg_ok "Sweet Home 3D installed and started"

description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access Sweet Home 3D Online at the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080${CL}"

echo -e ""
echo -e "${INFO}${YW}Configuration:${CL}"
echo -e "${TAB}${GATEWAY}Config file: /opt/sweethome3d/.env${CL}"
echo -e "${TAB}${GATEWAY}Storage path: /opt/sweethome3d/homes${CL}"
echo -e "${TAB}${GATEWAY}Logs: docker-compose logs -f${CL}"

if [[ -n "${SH3D_AUTH_USERNAME}" ]]; then
  echo -e ""
  echo -e "${INFO}${YW}Authentication enabled:${CL}"
  echo -e "${TAB}${GATEWAY}Username: ${SH3D_AUTH_USERNAME}${CL}"
  echo -e "${TAB}${GATEWAY}Password: ${SH3D_AUTH_PASSWORD}${CL}"
  echo -e "${TAB}${GATEWAY}${RD}⚠️  Save these credentials securely!${CL}"
fi

echo -e ""
echo -e "${INFO}${YW}Useful commands:${CL}"
echo -e "${TAB}${GATEWAY}Status: pct exec ${CTID} docker-compose ps${CL}"
echo -e "${TAB}${GATEWAY}Logs: pct exec ${CTID} docker-compose logs -f${CL}"
echo -e "${TAB}${GATEWAY}Restart: pct exec ${CTID} docker-compose restart${CL}"
echo -e "${TAB}${GATEWAY}Backup: pct exec ${CTID} bash /opt/sweethome3d/backup-homes.sh${CL}"

function create_installation_script() {
  cat << 'SCRIPT_EOF'
#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=================================================="
echo "🏠 Sweet Home 3D 7.7-Online Installation"
echo "=================================================="
echo ""

# Update system
echo -e "${BLUE}[1/6]${NC} Updating system packages..."
apt-get update > /dev/null 2>&1
apt-get install -y \
    curl wget git ca-certificates gnupg lsb-release \
    > /dev/null 2>&1
echo -e "${GREEN}✓${NC} System updated"
echo ""

# Install Docker
echo -e "${BLUE}[2/6]${NC} Installing Docker..."
DOCKER_CONFIG_PATH='/etc/docker/daemon.json'
mkdir -p $(dirname $DOCKER_CONFIG_PATH)
echo -e '{\n  "log-driver": "journald"\n}' > $DOCKER_CONFIG_PATH
curl -fsSL https://get.docker.com -o /tmp/get-docker.sh > /dev/null 2>&1
sh /tmp/get-docker.sh > /dev/null 2>&1
rm /tmp/get-docker.sh
echo -e "${GREEN}✓${NC} Docker installed"
echo ""

# Install Docker Compose
echo -e "${BLUE}[3/6]${NC} Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest 2>/dev/null | grep 'tag_name' | cut -d\" -f4)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose > /dev/null 2>&1
chmod +x /usr/local/bin/docker-compose
echo -e "${GREEN}✓${NC} Docker Compose $DOCKER_COMPOSE_VERSION installed"
echo ""

# Create and setup Sweet Home 3D directory
echo -e "${BLUE}[4/6]${NC} Setting up Sweet Home 3D..."
mkdir -p /opt/sweethome3d
cd /opt/sweethome3d

# Download files from GitHub
GITHUB_RAW="https://raw.githubusercontent.com/andry360/sweethome3d-docker/main"

mkdir -p docker backups

# Download core files
wget -q -O Dockerfile "${GITHUB_RAW}/Dockerfile"
wget -q -O docker-compose.yml "${GITHUB_RAW}/docker-compose.yml"
wget -q -O .env.example "${GITHUB_RAW}/.env.example"
wget -q -O backup-homes.sh "${GITHUB_RAW}/backup-homes.sh"
wget -q -O restore-homes.sh "${GITHUB_RAW}/restore-homes.sh"
chmod +x backup-homes.sh restore-homes.sh

# Download docker configuration files
wget -q -O docker/apache-config.conf "${GITHUB_RAW}/docker/apache-config.conf"
wget -q -O docker/htaccess.conf "${GITHUB_RAW}/docker/htaccess.conf"
wget -q -O docker/entrypoint.sh "${GITHUB_RAW}/docker/entrypoint.sh"
chmod +x docker/entrypoint.sh

# Create homes directory
mkdir -p homes
chmod 775 homes

echo -e "${GREEN}✓${NC} Files downloaded and configured"
echo ""

# Configuration
echo -e "${BLUE}[5/6]${NC} Configuring installation..."

# Determine authentication settings
if [[ -n "${SH3D_AUTH_USERNAME}" ]] && [[ -n "${SH3D_AUTH_PASSWORD}" ]]; then
    AUTH_ENABLED=true
    AUTH_USERNAME="${SH3D_AUTH_USERNAME}"
    AUTH_PASSWORD="${SH3D_AUTH_PASSWORD}"
else
    AUTH_ENABLED=false
    AUTH_USERNAME="admin"
    AUTH_PASSWORD=""
fi

# Create .env file
cat > /opt/sweethome3d/.env << EOF
# Sweet Home 3D 7.7-Online Configuration
VERSION=7.7
HOST_PORT=8080
STORAGE_PATH=./homes
UPLOAD_MAX_FILESIZE=50M
POST_MAX_SIZE=50M
MEMORY_LIMIT=256M
AUTH_ENABLED=${AUTH_ENABLED}
AUTH_USERNAME=${AUTH_USERNAME}
AUTH_PASSWORD=${AUTH_PASSWORD}
EOF

echo -e "${GREEN}✓${NC} Configuration created"
echo ""

# Build Docker image
echo -e "${BLUE}[6/6]${NC} Building Docker image (this may take 20-30 minutes)..."
echo -e "${YELLOW}⏳ Please be patient...${NC}"
echo ""

# Use BuildKit for better caching if available
export DOCKER_BUILDKIT=1
if docker-compose build > /tmp/docker-build.log 2>&1; then
    echo -e "${GREEN}✓${NC} Docker image built successfully"
else
    echo -e "${RED}✗${NC} Docker build failed"
    echo -e "${RED}Error log:${NC}"
    tail -50 /tmp/docker-build.log
    exit 1
fi
echo ""

# Start container
echo -e "Starting Sweet Home 3D container..."
docker-compose up -d

# Wait for container to be healthy
echo -e "Waiting for container to be ready..."
for i in {1..30}; do
    if docker-compose ps | grep -q "Up"; then
        break
    fi
    sleep 2
done

echo ""
echo -e "${GREEN}✓${NC} Installation completed successfully!"
echo ""

SCRIPT_EOF
}

# Actual installation inside container
function install_sweethome3d() {
  msg_info "Installing Sweet Home 3D (this will take 20-30 minutes)..."
  
  create_installation_script
  
  pct exec "$CTID" bash <<'INSTALLATION_INLINE'
#!/bin/bash
set -e

# System update
apt-get update
apt-get install -y curl wget git ca-certificates gnupg lsb-release

# Install Docker
mkdir -p /etc/docker
echo -e '{\n  "log-driver": "journald"\n}' > /etc/docker/daemon.json
curl -fsSL https://get.docker.com | sh

# Install Docker Compose
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Setup Sweet Home 3D
mkdir -p /opt/sweethome3d
cd /opt/sweethome3d

GITHUB_RAW="https://raw.githubusercontent.com/andry360/sweethome3d-docker/main"

mkdir -p docker backups homes
chmod 775 homes

# Download files
wget -q -O Dockerfile "${GITHUB_RAW}/Dockerfile"
wget -q -O docker-compose.yml "${GITHUB_RAW}/docker-compose.yml"
wget -q -O .env.example "${GITHUB_RAW}/.env.example"
wget -q -O backup-homes.sh "${GITHUB_RAW}/backup-homes.sh"
wget -q -O restore-homes.sh "${GITHUB_RAW}/restore-homes.sh"
chmod +x backup-homes.sh restore-homes.sh

wget -q -O docker/apache-config.conf "${GITHUB_RAW}/docker/apache-config.conf"
wget -q -O docker/htaccess.conf "${GITHUB_RAW}/docker/htaccess.conf"
wget -q -O docker/entrypoint.sh "${GITHUB_RAW}/docker/entrypoint.sh"
chmod +x docker/entrypoint.sh

# Create .env file with provided credentials
AUTH_ENABLED=${SH3D_AUTH_USERNAME:+true}
AUTH_ENABLED=${AUTH_ENABLED:-false}

cat > .env << EOF
VERSION=7.7
HOST_PORT=8080
STORAGE_PATH=./homes
UPLOAD_MAX_FILESIZE=50M
POST_MAX_SIZE=50M
MEMORY_LIMIT=256M
AUTH_ENABLED=${AUTH_ENABLED}
AUTH_USERNAME=${SH3D_AUTH_USERNAME:-admin}
AUTH_PASSWORD=${SH3D_AUTH_PASSWORD:-}
EOF

# Build and start
export DOCKER_BUILDKIT=1
docker-compose build
docker-compose up -d

# Wait for container
sleep 10
for i in {1..30}; do
  if docker-compose ps | grep -q "Up"; then
    break
  fi
  sleep 2
done

INSTALLATION_INLINE

  msg_ok "Sweet Home 3D installed"
}

start
build_container

# Installation inside container
msg_info "Installing Sweet Home 3D inside container..."

pct exec "$CTID" bash <<'INSTALLATION_INLINE'
#!/bin/bash
set -e

# System update
apt-get update > /dev/null 2>&1
apt-get install -y curl wget git ca-certificates gnupg lsb-release > /dev/null 2>&1

# Install Docker
mkdir -p /etc/docker
echo -e '{\n  "log-driver": "journald"\n}' > /etc/docker/daemon.json
sh <(curl -fsSL https://get.docker.com) > /dev/null 2>&1

# Install Docker Compose
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest 2>/dev/null | grep 'tag_name' | cut -d\" -f4)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose 2>/dev/null
chmod +x /usr/local/bin/docker-compose

# Setup Sweet Home 3D directory
mkdir -p /opt/sweethome3d
cd /opt/sweethome3d

GITHUB_RAW="https://raw.githubusercontent.com/andry360/sweethome3d-docker/main"

mkdir -p docker backups homes
chmod 775 homes

# Download files from repository
wget -q -O Dockerfile "${GITHUB_RAW}/Dockerfile"
wget -q -O docker-compose.yml "${GITHUB_RAW}/docker-compose.yml"
wget -q -O .env.example "${GITHUB_RAW}/.env.example"
wget -q -O backup-homes.sh "${GITHUB_RAW}/backup-homes.sh"
wget -q -O restore-homes.sh "${GITHUB_RAW}/restore-homes.sh"
chmod +x backup-homes.sh restore-homes.sh

mkdir -p docker
wget -q -O docker/apache-config.conf "${GITHUB_RAW}/docker/apache-config.conf"
wget -q -O docker/htaccess.conf "${GITHUB_RAW}/docker/htaccess.conf"
wget -q -O docker/entrypoint.sh "${GITHUB_RAW}/docker/entrypoint.sh"
chmod +x docker/entrypoint.sh

# Create .env file with provided credentials
AUTH_ENABLED=false
[[ -n "${SH3D_AUTH_USERNAME}" ]] && AUTH_ENABLED=true

cat > .env << EOF
VERSION=7.7
HOST_PORT=8080
STORAGE_PATH=./homes
UPLOAD_MAX_FILESIZE=50M
POST_MAX_SIZE=50M
MEMORY_LIMIT=256M
AUTH_ENABLED=${AUTH_ENABLED}
AUTH_USERNAME=${SH3D_AUTH_USERNAME:-admin}
AUTH_PASSWORD=${SH3D_AUTH_PASSWORD:-}
EOF

# Build and start Sweet Home 3D
export DOCKER_BUILDKIT=1
docker-compose build
docker-compose up -d

# Wait for container to be healthy
sleep 15
for i in {1..60}; do
  if docker-compose ps 2>/dev/null | grep -q "Up"; then
    break
  fi
  sleep 2
done

INSTALLATION_INLINE

msg_ok "Sweet Home 3D installed and started"

description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access Sweet Home 3D Online at the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080${CL}"

echo -e ""
echo -e "${INFO}${YW}Configuration:${CL}"
echo -e "${TAB}${GATEWAY}Config file: /opt/sweethome3d/.env${CL}"
echo -e "${TAB}${GATEWAY}Storage path: /opt/sweethome3d/homes${CL}"
echo -e "${TAB}${GATEWAY}Logs: docker-compose logs -f${CL}"

if [[ -n "${SH3D_AUTH_USERNAME}" ]]; then
  echo -e ""
  echo -e "${INFO}${YW}Authentication enabled:${CL}"
  echo -e "${TAB}${GATEWAY}Username: ${SH3D_AUTH_USERNAME}${CL}"
  echo -e "${TAB}${GATEWAY}Password: ${SH3D_AUTH_PASSWORD}${CL}"
  echo -e "${TAB}${GATEWAY}${RD}⚠️  Save these credentials securely!${CL}"
fi

echo -e ""
echo -e "${INFO}${YW}Useful commands:${CL}"
echo -e "${TAB}${GATEWAY}Status: pct exec ${CTID} docker-compose ps${CL}"
echo -e "${TAB}${GATEWAY}Logs: pct exec ${CTID} docker-compose logs -f${CL}"
echo -e "${TAB}${GATEWAY}Restart: pct exec ${CTID} docker-compose restart${CL}"
echo -e "${TAB}${GATEWAY}Backup: pct exec ${CTID} bash /opt/sweethome3d/backup-homes.sh${CL}"
