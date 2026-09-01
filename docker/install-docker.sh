#!/usr/bin/env bash
# Install Docker Engine + Compose plugin on Ubuntu (official Docker apt repo).
# Run once on the HOST:  sudo bash docker/install-docker.sh
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run me with sudo:  sudo bash $0" >&2
  exit 1
fi

# The user who should end up in the docker group (works under sudo).
TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")"
ARCH="$(dpkg --print-architecture)"

echo "==> Removing distro Docker packages that conflict with docker-ce"
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  apt-get remove -y "$pkg" >/dev/null 2>&1 || true
done

echo "==> Adding Docker's apt repository ($CODENAME/$ARCH)"
apt-get update
apt-get install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
cat > /etc/apt/sources.list.d/docker.list <<LIST
deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${CODENAME} stable
LIST

echo "==> Installing Docker Engine, CLI, buildx and compose plugins"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "==> Enabling and starting the docker service"
systemctl enable --now docker

if [ "$TARGET_USER" != "root" ]; then
  echo "==> Adding '$TARGET_USER' to the docker group (lets you run docker without sudo)"
  groupadd -f docker
  usermod -aG docker "$TARGET_USER"
fi

echo
echo "==> Verifying"
docker --version
docker compose version
docker run --rm hello-world >/dev/null && echo "hello-world container ran OK"

echo
echo "DONE. Group membership needs a new login session to take effect."
echo "Either log out and back in, or run:  newgrp docker"
