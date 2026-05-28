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

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  msg_info "Updating Sweet Home 3D Online"
  pct exec "$CTID" -- bash -c "cd /opt/sweethome3d && docker-compose pull && docker-compose up -d --force-recreate"
  msg_ok "Updated Sweet Home 3D Online"
  exit
}

start
build_container

# Download install script to temp file on Proxmox host, inject credentials,
# then push+exec inside container.
# NOTE: pct exec does NOT support heredoc stdin redirect (causes exit code 127).
msg_info "Preparing installation script"
INSTALL_TMP="/tmp/sh3d-install-${CTID}.sh"

curl -fsSL \
  "https://raw.githubusercontent.com/andry360/sweethome3d-docker/main/install/sweethome3d-install.sh" \
  -o "${INSTALL_TMP}"

# Prepend credentials export so they are available inside the container
sed -i "1a export SH3D_AUTH_USERNAME='${SH3D_AUTH_USERNAME}'" "${INSTALL_TMP}"
sed -i "2a export SH3D_AUTH_PASSWORD='${SH3D_AUTH_PASSWORD}'" "${INSTALL_TMP}"

chmod +x "${INSTALL_TMP}"
msg_ok "Installation script prepared"

msg_info "Installing Sweet Home 3D Online (this may take 20-30 minutes)"
pct push "${CTID}" "${INSTALL_TMP}" /tmp/sh3d-install.sh
pct exec "${CTID}" -- bash /tmp/sh3d-install.sh
rm -f "${INSTALL_TMP}"
msg_ok "Sweet Home 3D Online installed"

description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW}Access Sweet Home 3D Online at the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8080${CL}"
echo -e ""
echo -e "${INFO}${YW}Configuration:${CL}"
echo -e "${TAB}${GATEWAY}Config file:  /opt/sweethome3d/.env${CL}"
echo -e "${TAB}${GATEWAY}Storage path: /opt/sweethome3d/homes${CL}"
if [[ -n "${SH3D_AUTH_USERNAME}" ]]; then
  echo -e ""
  echo -e "${INFO}${YW}Authentication enabled:${CL}"
  echo -e "${TAB}${GATEWAY}Username: ${SH3D_AUTH_USERNAME}${CL}"
  echo -e "${TAB}${GATEWAY}Password: ${SH3D_AUTH_PASSWORD}${CL}"
  echo -e "${TAB}${GATEWAY}${RD}Save these credentials securely!${CL}"
fi
echo -e ""
echo -e "${INFO}${YW}Useful commands (run on Proxmox node):${CL}"
echo -e "${TAB}${GATEWAY}Status:  pct exec ${CTID} -- bash -c 'cd /opt/sweethome3d && docker-compose ps'${CL}"
echo -e "${TAB}${GATEWAY}Logs:    pct exec ${CTID} -- bash -c 'cd /opt/sweethome3d && docker-compose logs -f'${CL}"
echo -e "${TAB}${GATEWAY}Restart: pct exec ${CTID} -- bash -c 'cd /opt/sweethome3d && docker-compose restart'${CL}"
