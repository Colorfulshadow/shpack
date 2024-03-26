#!/bin/bash

# Ensure running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Install necessary environments: snapd and ufw
if ! command -v snap &> /dev/null; then
    echo "snap could not be found, attempting to install..."
    apt update && apt install -y snapd
fi
if ! command -v ufw &> /dev/null; then
    echo "ufw could not be found, attempting to install..."
    apt update && apt install ufw -y
fi

# ufw allow basic port 
ufw allow ssh
ufw allow http
ufw allow https
ufw enable

# 1. Install snap core
echo "Installing snap core..."
snap install core

# 2. Install shadowsocks-libev from the edge channel
echo "Installing shadowsocks-libev..."
snap install shadowsocks-libev --edge

# 3. Configure shadowsocks-libev
echo "Configuring shadowsocks-libev..."
mkdir -p /var/snap/shadowsocks-libev/common/etc/shadowsocks-libev
echo '{
    "server":["::0","0.0.0.0"],
    "server_port":16378,
    "method":"chacha20-ietf-poly1305",
    "password":"oYTmX8zLp4M0RccAcv7o",
    "mode":"tcp_and_udp",
    "fast_open":false
}' > /var/snap/shadowsocks-libev/common/etc/shadowsocks-libev/config.json

# 4. Start and enable shadowsocks-libev service
echo "Starting and enabling shadowsocks-libev service..."
systemctl start snap.shadowsocks-libev.ss-server-daemon.service
systemctl enable snap.shadowsocks-libev.ss-server-daemon.service

# 5. Allow shadowsocks service port through UFW
echo "Allowing port 16378 through UFW..."
ufw allow 16378

echo "Setup completed successfully."
