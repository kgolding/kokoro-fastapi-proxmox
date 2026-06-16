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

# --- Kokoro-FastAPI is not (yet) part of the official community-scripts
# catalog. build.func's own build_container() always tries to fetch
# install/${var_install}.sh from the OFFICIAL community-scripts/ProxmoxVE
# repo (this is hardcoded inside build.func, not something a third-party
# script can redirect). Since that file doesn't exist there, that step
# 404s, curl returns nothing, and the resulting "bash -c ''" silently
# does nothing - you may see a harmless-looking
# "curl: (22) The requested URL returned error: 404" line above. That's it.
#
# So we run the real installer ourselves, from THIS repo, reusing the same
# container/environment (CTID, FUNCTIONS_FILE_PATH, VERBOSE, $STD, etc.)
# that build_container() already set up and exported.
KOKORO_REPO_URL="${KOKORO_REPO_URL:-https://raw.githubusercontent.com/kgolding/kokoro-fastapi-proxmox/main}"
KOKORO_INSTALL_SCRIPT="$(curl -fsSL "${KOKORO_REPO_URL}/install/kokoro-fastapi-install.sh")"
if [[ -z "$KOKORO_INSTALL_SCRIPT" ]]; then
  msg_error "Could not fetch the installer from ${KOKORO_REPO_URL}/install/kokoro-fastapi-install.sh"
  echo -e "${INFO} Check that the repo is public and the path/branch are correct, then run manually:"
  echo -e "${TAB}pct exec ${CTID} -- bash -c \"\$(curl -fsSL ${KOKORO_REPO_URL}/install/kokoro-fastapi-install.sh)\""
else
  msg_info "Installing ${APP} (custom script - not yet in community-scripts)"
  if lxc-attach -n "$CTID" -- bash -c "$KOKORO_INSTALL_SCRIPT"; then
    msg_ok "Installed ${APP}"
  else
    msg_error "Installer exited with an error - inspect with: pct enter ${CTID}"
  fi
fi

description

msg_ok "Completed successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Web UI:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8880/web${CL}"
echo -e "${INFO}${YW} OpenAI-compatible API base URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8880/v1${CL}"
echo -e "${INFO}${YW} API docs:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8880/docs${CL}"
