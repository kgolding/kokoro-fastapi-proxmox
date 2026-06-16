#!/usr/bin/env bash
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2026 community-scripts ORG
# Author: (your name here)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/remsky/Kokoro-FastAPI

APP="Kokoro-FastAPI"
var_tags="${var_tags:-ai;tts}"
var_cpu="${var_cpu:-4}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-12}"
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

  if [[ ! -d /opt/kokoro-fastapi ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating ${APP}"
  cd /opt/kokoro-fastapi
  $STD docker compose pull
  $STD docker compose up -d
  $STD docker image prune -f
  msg_ok "Updated ${APP}"
  exit
}

start
build_container
description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Web UI:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8880/web${CL}"
echo -e "${INFO}${YW} OpenAI-compatible API base URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8880/v1${CL}"
echo -e "${INFO}${YW} API docs:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8880/docs${CL}"
