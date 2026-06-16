#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: (your name here)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/remsky/Kokoro-FastAPI

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get install -y curl sudo mc gnupg
msg_ok "Installed Dependencies"

msg_info "Setting up Docker"
setup_docker
msg_ok "Docker is ready"

# Default to the CPU image. Only switch to the GPU image if this container
# already has a working NVIDIA GPU passthrough set up (i.e. nvidia-smi works
# *before* this script runs). This script does not attempt to install or
# match NVIDIA host drivers itself - see the repo README for why, and for
# manual GPU passthrough steps.
KOKORO_IMAGE="ghcr.io/remsky/kokoro-fastapi-cpu:latest"
GPU_BLOCK=""

if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
  msg_info "NVIDIA GPU detected, installing NVIDIA Container Toolkit"
  $STD curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
  $STD apt-get update
  $STD apt-get install -y nvidia-container-toolkit
  $STD nvidia-ctk runtime configure --runtime=docker
  $STD systemctl restart docker
  KOKORO_IMAGE="ghcr.io/remsky/kokoro-fastapi-gpu:latest"
  GPU_BLOCK=$(
    cat <<'EOF'
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: ["gpu"]
EOF
  )
  msg_ok "NVIDIA Container Toolkit installed, using GPU image"
else
  msg_info "No GPU passthrough detected"
  msg_ok "Will run Kokoro-FastAPI on CPU"
fi

msg_info "Deploying Kokoro-FastAPI"
mkdir -p /opt/kokoro-fastapi
cat <<EOF >/opt/kokoro-fastapi/docker-compose.yml
services:
  kokoro-fastapi:
    image: ${KOKORO_IMAGE}
    container_name: kokoro-fastapi
    restart: unless-stopped
    ports:
      - "8880:8880"
    environment:
      # DEBUG/INFO/WARNING/ERROR - see core/config.py upstream for the full
      # list of tunable env vars (chunking, voice defaults, etc.)
      - API_LOG_LEVEL=INFO
${GPU_BLOCK}
EOF

cd /opt/kokoro-fastapi
$STD docker compose up -d
msg_ok "Deployed Kokoro-FastAPI"

echo "latest" >/opt/${APP}_version.txt

motd_ssh
customize
cleanup_lxc
