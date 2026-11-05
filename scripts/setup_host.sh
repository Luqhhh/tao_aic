#!/usr/bin/env bash
# Install the host-side container engine; EDA tools stay in the official image.
set -euo pipefail

if [[ $(id -u) != 0 ]]; then
  echo 'Run this script as root and pass the normal Linux username.' >&2
  exit 1
fi
target_user=${1:?Usage: bash scripts/setup_host.sh USERNAME}
getent passwd "$target_user" >/dev/null
. /etc/os-release
if [[ $ID != ubuntu || $(dpkg --print-architecture) != amd64 ]]; then
  echo 'This setup script supports Ubuntu amd64.' >&2
  exit 1
fi
if [[ $(cat /proc/1/comm) != systemd ]]; then
  echo 'This installer needs a systemd host. For a rented container, request a host Docker socket or a Docker-capable instance.' >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt_options=(-o Acquire::http::Timeout=20 -o Acquire::https::Timeout=20 -o Acquire::Retries=1)
apt-get "${apt_options[@]}" update
apt-get "${apt_options[@]}" install -y --no-install-recommends ca-certificates curl gnupg python3-venv
install -m 0755 -d /etc/apt/keyrings
curl --fail --show-error --location --retry 3 --connect-timeout 20 \
  https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod 0644 /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME:-$VERSION_CODENAME}
Components: stable
Architectures: amd64
Signed-By: /etc/apt/keyrings/docker.asc
EOF

nvidia_key=$(mktemp)
trap 'rm -f "$nvidia_key"' EXIT
curl --fail --show-error --location --retry 3 --connect-timeout 20 \
  https://nvidia.github.io/libnvidia-container/gpgkey -o "$nvidia_key"
gpg --batch --yes --dearmor --output /etc/apt/keyrings/nvidia-container-toolkit.gpg "$nvidia_key"
chmod 0644 /etc/apt/keyrings/nvidia-container-toolkit.gpg
curl --fail --show-error --location --retry 3 --connect-timeout 20 \
  https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit.gpg] https://#g' \
  > /etc/apt/sources.list.d/nvidia-container-toolkit.list

apt-get "${apt_options[@]}" update
apt-get "${apt_options[@]}" install -y --no-install-recommends \
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
  nvidia-container-toolkit
nvidia-ctk runtime configure --runtime=docker
usermod -aG docker "$target_user"
systemctl enable docker
systemctl restart docker
docker version
nvidia-ctk --version
