#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts
# Author: Andrea Castellano
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://www.sweethome3d.com/

APP="Sweet Home 3D Online"
var_tags="${var_tags:-3d-design;home-design}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources

  msg_info "Updating base system"
  $STD apt update
  $STD apt upgrade -y
  msg_ok "Base system updated"

  if [[ -d /opt/sweethome3d ]]; then
    msg_info "Updating Sweet Home 3D Online"
    cd /opt/sweethome3d
    
    # Pull latest Docker image
    $STD docker-compose pull
    
    # Recreate container with new image
    $STD docker-compose up -d --force-recreate
    
    msg_ok "Sweet Home 3D Online updated"
  else
    msg_error "Sweet Home 3D installation not found"
    exit 1
  fi

  msg_ok "Updated successfully!"
  exit
}

start

# Export authentication credentials if provided via environment variables
# Usage: SH3D_AUTH_USERNAME=myuser SH3D_AUTH_PASSWORD='MyPass!' bash -c "$(wget -qLO - ...)"
export SH3D_AUTH_USERNAME="${SH3D_AUTH_USERNAME:-}"
export SH3D_AUTH_PASSWORD="${SH3D_AUTH_PASSWORD:-}"

build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access Sweet Home 3D Online at the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080${CL}"

# Show authentication credentials if enabled
if grep -q "AUTH_ENABLED=true" /opt/sweethome3d/.env 2>/dev/null; then
  echo -e "${INFO}${YW} Authentication credentials:${CL}"
  AUTH_USER=$(grep "AUTH_USERNAME=" /opt/sweethome3d/.env | cut -d'=' -f2)
  AUTH_PASS=$(grep "AUTH_PASSWORD=" /opt/sweethome3d/.env | cut -d'=' -f2)
  echo -e "${TAB}${GATEWAY}Username: ${AUTH_USER}${CL}"
  echo -e "${TAB}${GATEWAY}Password: ${AUTH_PASS}${CL}"
  echo -e "${TAB}${GATEWAY}${RD}⚠️  Save these credentials securely!${CL}"
fi
echo -e ""
echo -e "${INFO}${YW} Configuration:${CL}"
echo -e "${TAB}${GATEWAY}Config file: /opt/sweethome3d/.env${CL}"
echo -e "${TAB}${GATEWAY}Storage path: /opt/sweethome3d/homes${CL}"
echo -e "${TAB}${GATEWAY}Logs: docker-compose logs -f${CL}"
echo -e ""
echo -e "${INFO}${YW} To configure NPMplus reverse proxy:${CL}"
echo -e "${TAB}${GATEWAY}Domain: sweethome.yourdomain.com${CL}"
echo -e "${TAB}${GATEWAY}Forward to: http://${IP}:8080${CL}"
echo -e "${TAB}${GATEWAY}Enable SSL: Yes (Let's Encrypt)${CL}"
