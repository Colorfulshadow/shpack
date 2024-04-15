#!/bin/bash

# Step 1: Install Xray
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

if ! command -v ufw &> /dev/null; then
    echo "ufw could not be found, attempting to install..."
    apt update && apt install ufw -y
fi
if ! command -v jq &> /dev/null; then
    echo "jq could not be found, attempting to install..."
    apt update && apt install jq -y
fi

# Step 2: Generate new port and UUID
new_port=$(shuf -i 10000-65535 -n 1)
uuid=$(xray uuid)

# Step 2: Extract private and public keys from xray x25519 output
keys_output=$(xray x25519)
private_key=$(echo "$keys_output" | grep "Private key:" | cut -d' ' -f3)
public_key=$(echo "$keys_output" | grep "Public key:" | cut -d' ' -f3)

# Step 2: Save public key to a file
echo "$public_key" > /usr/local/etc/xray/public_key.txt

# Step 2: Update the configuration file
cat << EOF > /usr/local/etc/xray/config.json
{
  "log": {
    "loglevel": "warning",
    "error": "/var/log/xray/error.log",
    "access": "/var/log/xray/access.log"
  },
  "api": {
    "services": [
      "HandlerService",
      "LoggerService",
      "StatsService"
    ],
    "tag": "api"
  },
  "stats": {},
  "policy": {
    "levels": {
      "0": {
        "handshake": 2,
        "connIdle": 128,
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  },
  "dns": {
    "servers": [
      "https+local://cloudflare-dns.com/dns-query",
      "1.1.1.1",
      "1.0.0.1",
      "8.8.8.8",
      "8.8.4.4",
      "localhost"
    ]
  },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "inboundTag": [
          "api"
        ],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "ip": [
          "geoip:cn"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "domain": [
          "geosite:category-ads-all"
        ],
        "outboundTag": "block"
      }
    ]
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 32768,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api",
      "sniffing": null
    },
    {
      "tag": "color_vless",
      "listen": "0.0.0.0",
      "port": ${new_port},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "email": "vless@xtls.reality",
            "id": "${uuid}",
            "flow": "xtls-rprx-vision",
            "level": 0
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.apple.com:443",
          "xver": 0,
          "serverNames": [
            "www.apple.com",
            "images.apple.com"
          ],
          "privateKey": "${private_key}",
          "shortIds": [
            ""
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls",
          "quic"
        ]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct",
      "protocol": "freedom"
    },
    {
      "tag": "block",
      "protocol": "blackhole"
    }
  ]
}
EOF

# Step 3: Update firewall rules and enable UFW
ufw allow $new_port

# Step 4: Restart Xray service
systemctl restart xray

# Step 5: Generate and display the subscription link
function show_share_link() {
  local sl=""
  # share link contents
  local sl_host=$(wget -qO- -t1 -T2 ipv4.icanhazip.com)
  local sl_inbound=$(jq '.inbounds[] | select(.tag == "color_vless")' /usr/local/etc/xray/config.json)
  local sl_port=$(echo ${sl_inbound} | jq -r '.port')
  local sl_protocol=$(echo ${sl_inbound} | jq -r '.protocol')
  local sl_uuid=$(echo ${sl_inbound} | jq -r '.settings.clients[].id')  # UUID directly from the config
  local sl_public_key=$(cat /usr/local/etc/xray/public_key.txt)
  # Hardcode serverName as www.apple.com
  local sl_sni="sni=www.apple.com"
  # share link fields
  local sl_security='security=reality'
  local sl_flow='flow=xtls-rprx-vision'
  local sl_fingerprint='fp=chrome'
  local sl_publicKey="pbk=${sl_public_key}"
  local sl_spiderX='spx=%2F'
  local sl_descriptive_text='VLESS-XTLS-uTLS-REALITY'
  local sl_shortId=""  # Empty shortId

  # generate and display the link
  sl="${sl_protocol}://${sl_uuid}@${sl_host}:${sl_port}?${sl_security}&${sl_flow}&${sl_fingerprint}&${sl_publicKey}&${sl_sni}&${sl_spiderX}&${sl_shortId}"
  echo "below is your link"
  echo "-------------------------------"
  echo "${sl%&}#${sl_descriptive_text}"  # Print the link
}

# Call the function to display the link
show_share_link