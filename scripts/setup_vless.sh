#!/bin/bash

# ===================================================
# VLESS + Reality 安装脚本
# 功能：
# 1. 安装 Xray-core
# 2. 配置 VLESS + Reality 协议
# 3. 设置防火墙
# 4. 生成客户端连接信息
# ===================================================

# 加载公共函数库
if [[ -f "/usr/local/shpack/lib/common.sh" ]]; then
    source "/usr/local/shpack/lib/common.sh"
else
    # 如果找不到公共库，定义基本函数
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # 无颜色

    print_message() {
        local type=$1
        local message=$2
        
        case $type in
            "info") 
                echo -e "${GREEN}[INFO]${NC} $message" 
                ;;
            "warn") 
                echo -e "${YELLOW}[WARN]${NC} $message" 
                ;;
            "error") 
                echo -e "${RED}[ERROR]${NC} $message" 
                ;;
            *) 
                echo -e "$message" 
                ;;
        esac
    }
    
    log_message() {
        print_message "$1" "$2"
    }
    
    check_command() {
        if [ $? -ne 0 ]; then
            print_message "error" "命令执行失败: $1"
            return 1
        else
            print_message "info" "命令执行成功: $1"
            return 0
        fi
    }
fi

# 定义变量
LOG_FILE="/usr/local/shpack/logs/setup_vless.log"
CONFIG_DIR="/usr/local/shpack/config"
VLESS_CONFIG_FILE="${CONFIG_DIR}/vless.conf"
XRAY_CONFIG_DIR="/usr/local/etc/xray"
XRAY_CONFIG_FILE="${XRAY_CONFIG_DIR}/config.json"
XRAY_PUBLIC_KEY_FILE="${XRAY_CONFIG_DIR}/public_key.txt"
DEFAULT_DEST="www.apple.com:443"
DEFAULT_SNI="www.apple.com"

# 确保日志目录存在
mkdir -p "$(dirname "$LOG_FILE")" &>/dev/null
touch "$LOG_FILE"

# 确保以root用户运行
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        log_message "error" "此脚本必须以root用户运行"
        exit 1
    fi
}

# 检测操作系统类型和包管理器
detect_os() {
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
        PKG_UPDATE="apt update"
        PKG_INSTALL="apt install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        PKG_UPDATE="yum update -y"
        PKG_INSTALL="yum install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        PKG_UPDATE="dnf check-update"
        PKG_INSTALL="dnf install -y"
    else
        log_message "error" "不支持的操作系统，无法确定包管理器"
        exit 1
    fi
    
    log_message "info" "检测到包管理器: $PKG_MANAGER"
}

# 安装依赖
install_dependencies() {
    log_message "info" "安装依赖项..."
    
    # 更新包管理器
    eval "$PKG_UPDATE" &>>"$LOG_FILE"
    
    # 安装必要的软件包
    local packages=("curl" "wget" "jq" "ufw")
    
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            log_message "info" "安装 $pkg..."
            eval "$PKG_INSTALL $pkg" &>>"$LOG_FILE"
            check_command "安装 $pkg"
        else
            log_message "info" "$pkg 已安装"
        fi
    done
}

# 安装 Xray
install_xray() {
    log_message "info" "安装 Xray-core..."
    
    # 检查Xray是否已安装
    if command -v xray &> /dev/null; then
        log_message "info" "Xray 已安装，检查版本..."
        local current_version=$(xray version | head -n1 | awk '{print $2}')
        log_message "info" "当前 Xray 版本: $current_version"
        
        read -p "是否重新安装/更新 Xray? [y/N]: " reinstall
        if [[ "$reinstall" != "y" && "$reinstall" != "Y" ]]; then
            log_message "info" "跳过 Xray 安装"
            return 0
        fi
    fi
    
    # 备份之前的配置（如果存在）
    if [[ -f "$XRAY_CONFIG_FILE" ]]; then
        cp "$XRAY_CONFIG_FILE" "${XRAY_CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)" &>>"$LOG_FILE"
        log_message "info" "已备份当前配置文件"
    fi

    # 选择安装源
    echo -e "\n${GREEN}选择 Xray 安装源:${NC}"
    echo -e "${BLUE}1)${NC} GitHub 官方源（国外服务器推荐）"
    echo -e "${BLUE}2)${NC} 国内镜像1 (cdn.jsdelivr.net)"
    echo -e "${BLUE}3)${NC} 国内镜像2 (ghproxy.com)"
    echo -e "${BLUE}4)${NC} 手动安装（适用于完全无法访问外网的服务器）"
    read -p "请选择 [1-4] (默认: 1): " source_choice
    
    case ${source_choice:-1} in
        1)
            log_message "info" "使用 GitHub 官方源安装 Xray..."
            bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install &>>"$LOG_FILE"
            ;;
        2)
            log_message "info" "使用 JSDelivr CDN 安装 Xray..."
            bash -c "$(curl -L https://cdn.jsdelivr.net/gh/XTLS/Xray-install@main/install-release.sh)" @ install &>>"$LOG_FILE"
            ;;
        3)
            log_message "info" "使用 ghproxy.com 安装 Xray..."
            bash -c "$(curl -L https://ghproxy.com/https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install &>>"$LOG_FILE"
            ;;
        4)
            log_message "info" "执行手动安装 Xray..."
            # 手动安装Xray
            manual_install_xray
            ;;
        *)
            log_message "warn" "无效选项，使用 GitHub 官方源"
            bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install &>>"$LOG_FILE"
            ;;
    esac
    
    if ! command -v xray &> /dev/null; then
        log_message "error" "Xray 安装失败"
        return 1
    fi
    
    log_message "info" "Xray 安装成功: $(xray version | head -n1)"
    return 0
}

# 手动安装 Xray（适用于无法访问GitHub的环境）
manual_install_xray() {
    log_message "info" "开始手动安装 Xray..."
    
    # 创建必要的目录
    mkdir -p /usr/local/bin /usr/local/etc/xray /var/log/xray /usr/local/share/xray
    
    # 检测系统架构
    local ARCH
    case "$(uname -m)" in
        x86_64|amd64)
            ARCH="64"
            ;;
        armv7l|armv8l|arm)
            ARCH="arm32-v7a"
            ;;
        aarch64|arm64)
            ARCH="arm64-v8a"
            ;;
        *)
            log_message "error" "不支持的系统架构: $(uname -m)"
            return 1
            ;;
    esac
    
    # 设置下载链接（使用镜像站点）
    local DOWNLOAD_URL="https://ghproxy.com/https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${ARCH}.zip"
    
    # 尝试多个下载源
    local temp_dir=$(mktemp -d)
    log_message "info" "下载 Xray 二进制文件..."
    
    if ! curl -L -o "${temp_dir}/xray.zip" "$DOWNLOAD_URL" &>>"$LOG_FILE"; then
        # 如果第一个源失败，尝试备用源
        DOWNLOAD_URL="https://cdn.jsdelivr.net/gh/XTLS/Xray-core@latest/Xray-linux-${ARCH}.zip"
        log_message "warn" "下载失败，尝试备用源..."
        
        if ! curl -L -o "${temp_dir}/xray.zip" "$DOWNLOAD_URL" &>>"$LOG_FILE"; then
            log_message "error" "无法下载 Xray，请检查网络连接"
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    # 解压文件
    log_message "info" "解压 Xray 文件..."
    if ! unzip -o "${temp_dir}/xray.zip" -d "$temp_dir" &>>"$LOG_FILE"; then
        log_message "error" "解压失败，请确保已安装 unzip"
        # 尝试安装 unzip
        eval "$PKG_INSTALL unzip" &>>"$LOG_FILE"
        if ! unzip -o "${temp_dir}/xray.zip" -d "$temp_dir" &>>"$LOG_FILE"; then
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    # 移动文件到正确位置
    log_message "info" "安装 Xray 文件..."
    cp "${temp_dir}/xray" /usr/local/bin/
    chmod +x /usr/local/bin/xray
    cp "${temp_dir}/geoip.dat" /usr/local/share/xray/
    cp "${temp_dir}/geosite.dat" /usr/local/share/xray/
    
    # 创建systemd服务
    log_message "info" "创建 Xray 服务..."
    cat > /etc/systemd/system/xray.service << 'EOF'
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOF
    
    # 清理临时文件
    rm -rf "$temp_dir"
    
    # 重新加载systemd配置
    systemctl daemon-reload
    log_message "info" "Xray 手动安装完成"
    
    return 0
}

# 生成配置
generate_config() {
    log_message "info" "生成 Xray 配置..."
    
    # 创建配置目录
    mkdir -p "$XRAY_CONFIG_DIR" &>>"$LOG_FILE"
    
    # 交互式配置
    echo -e "\n${GREEN}配置 VLESS + Reality 服务器参数${NC}"
    
    # 随机端口
    local default_port=$(shuf -i 10000-65535 -n 1)
    read -p "请输入服务器端口 [${default_port}]: " port
    port=${port:-$default_port}
    
    # 检查端口是否可用
    if netstat -tuln | grep -q ":$port "; then
        log_message "warn" "端口 ${port} 已被占用，使用新的随机端口"
        port=$(shuf -i 10000-65535 -n 1)
        while netstat -tuln | grep -q ":$port "; do
            port=$(shuf -i 10000-65535 -n 1)
        done
        log_message "info" "选择新端口: ${port}"
    fi
    
    # 生成 UUID
    local uuid=$(xray uuid)
    log_message "info" "生成 UUID: ${uuid}"
    
    # 生成 X25519 密钥对
    log_message "info" "生成 X25519 密钥对..."
    local keys_output=$(xray x25519)
    local private_key=$(echo "$keys_output" | grep "Private key:" | cut -d' ' -f3)
    local public_key=$(echo "$keys_output" | grep "Public key:" | cut -d' ' -f3)
    
    # 保存公钥到文件
    echo "$public_key" > "$XRAY_PUBLIC_KEY_FILE"
    log_message "info" "公钥已保存到: $XRAY_PUBLIC_KEY_FILE"
    
    # Reality 设置
    echo -e "\n${BLUE}选择目标网站:${NC}"
    echo -e "1) www.apple.com (默认)"
    echo -e "2) www.microsoft.com"
    echo -e "3) www.amazon.com"
    echo -e "4) www.cloudflare.com"
    echo -e "5) 自定义"
    read -p "请选择 [1-5] (默认: 1): " target_choice
    
    local dest=""
    local server_names=()
    
    case ${target_choice:-1} in
        1)
            dest="www.apple.com:443"
            server_names=("www.apple.com" "images.apple.com")
            ;;
        2)
            dest="www.microsoft.com:443"
            server_names=("www.microsoft.com" "docs.microsoft.com")
            ;;
        3)
            dest="www.amazon.com:443"
            server_names=("www.amazon.com" "images-na.ssl-images-amazon.com")
            ;;
        4)
            dest="www.cloudflare.com:443"
            server_names=("www.cloudflare.com" "dash.cloudflare.com")
            ;;
        5)
            read -p "请输入目标网站 (格式: 域名:端口): " custom_dest
            dest=${custom_dest:-$DEFAULT_DEST}
            
            read -p "请输入服务器名称 (ServerName): " custom_sni
            server_names=("${custom_sni:-$(echo $dest | cut -d':' -f1)}")
            ;;
        *)
            dest="$DEFAULT_DEST"
            server_names=("$DEFAULT_SNI")
            ;;
    esac
    
    # 转换 server_names 数组为 JSON 格式
    local server_names_json=""
    for name in "${server_names[@]}"; do
        if [[ -z "$server_names_json" ]]; then
            server_names_json="\"$name\""
        else
            server_names_json="$server_names_json, \"$name\""
        fi
    done
    
    # 创建 Xray 配置文件
    cat > "$XRAY_CONFIG_FILE" << EOF
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
      "port": ${port},
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
          "dest": "${dest}",
          "xver": 0,
          "serverNames": [
            ${server_names_json}
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
    
    check_command "创建配置文件"
    
    # 保存配置信息到shpack配置目录
    mkdir -p "$CONFIG_DIR" &>>"$LOG_FILE"
    cat > "$VLESS_CONFIG_FILE" << EOF
# VLESS + Reality 配置信息
VLESS_PORT=$port
VLESS_UUID=$uuid
VLESS_PRIVATE_KEY=$private_key
VLESS_PUBLIC_KEY=$public_key
VLESS_DEST=$dest
VLESS_SNI=${server_names[0]}
EOF
    
    check_command "保存配置信息到: $VLESS_CONFIG_FILE"
    
    return 0
}

# 配置防火墙
setup_firewall() {
    log_message "info" "配置防火墙..."
    
    # 读取配置文件
    if [[ -f "$VLESS_CONFIG_FILE" ]]; then
        source "$VLESS_CONFIG_FILE"
    else
        log_message "error" "找不到配置文件: $VLESS_CONFIG_FILE"
        return 1
    fi
    
    # 检查UFW是否可用
    if command -v ufw &> /dev/null; then
        log_message "info" "允许端口 ${VLESS_PORT} 通过防火墙"
        ufw allow "$VLESS_PORT/tcp" &>>"$LOG_FILE"
        check_command "添加防火墙规则: $VLESS_PORT/tcp"
        
        # 确保UFW已启用
        if ! ufw status | grep -q "Status: active"; then
            log_message "info" "启用UFW防火墙..."
            echo "y" | ufw enable &>>"$LOG_FILE"
            check_command "启用UFW防火墙"
        fi
    else
        log_message "warn" "UFW未安装，跳过防火墙配置"
    fi
    
    return 0
}

# 启动服务
start_service() {
    log_message "info" "重启Xray服务..."
    systemctl daemon-reload &>>"$LOG_FILE"
    systemctl restart xray &>>"$LOG_FILE"
    check_command "重启Xray服务"
    
    # 检查服务状态
    if systemctl is-active --quiet xray; then
        log_message "info" "Xray服务已成功启动"
        
        # 设置开机自启
        systemctl enable xray &>>"$LOG_FILE"
        check_command "设置Xray服务开机自启"
    else
        log_message "error" "Xray服务启动失败"
        return 1
    fi
    
    return 0
}

# 显示连接信息
show_client_info() {
    log_message "info" "生成客户端连接信息..."
    
    # 读取配置文件
    if [[ -f "$VLESS_CONFIG_FILE" ]]; then
        source "$VLESS_CONFIG_FILE"
    else
        log_message "error" "找不到配置文件: $VLESS_CONFIG_FILE"
        return 1
    fi
    
    # 获取服务器IP
    local server_ip=$(curl -s https://api.ipify.org || curl -s http://ifconfig.me || curl -s icanhazip.com)
    if [[ -z "$server_ip" ]]; then
        log_message "warn" "无法获取服务器IP地址"
        server_ip="YOUR_SERVER_IP"
    fi
    
    # 默认参数
    local flow="xtls-rprx-vision"
    local fingerprint="chrome"
    local spiderX="%2F"
    local shortId=""
    local descriptive_text="VLESS-XTLS-uTLS-REALITY"
    
    # 生成分享链接
    local share_link="${VLESS_UUID}@${server_ip}:${VLESS_PORT}?security=reality&flow=${flow}&fp=${fingerprint}&pbk=${VLESS_PUBLIC_KEY}&sni=${VLESS_SNI}&spx=${spiderX}${shortId}"
    local full_link="vless://${share_link}#${descriptive_text}"
    
    # 显示连接信息
    echo -e "\n${GREEN}========== VLESS + Reality 客户端配置 ==========${NC}"
    echo -e "${BLUE}协议:${NC} VLESS"
    echo -e "${BLUE}地址:${NC} $server_ip"
    echo -e "${BLUE}端口:${NC} $VLESS_PORT"
    echo -e "${BLUE}UUID:${NC} $VLESS_UUID"
    echo -e "${BLUE}流控:${NC} $flow"
    echo -e "${BLUE}加密:${NC} none"
    echo -e "${BLUE}传输协议:${NC} tcp"
    echo -e "${BLUE}传输层安全:${NC} reality"
    echo -e "${BLUE}SNI:${NC} $VLESS_SNI"
    echo -e "${BLUE}Fingerprint:${NC} $fingerprint"
    echo -e "${BLUE}PublicKey:${NC} $VLESS_PUBLIC_KEY"
    echo -e "${BLUE}ShortId:${NC} $shortId"
    echo -e "${BLUE}SpiderX:${NC} $spiderX"
    echo -e "${GREEN}===========================================${NC}\n"
    
    echo -e "${YELLOW}分享链接:${NC}"
    echo -e "$full_link\n"
}

# 主函数
main() {
    log_message "info" "开始安装 VLESS + Reality..."
    
    # 确保以root用户运行
    check_root
    
    # 检测操作系统和包管理器
    detect_os
    
    # 安装依赖
    install_dependencies
    
    # 安装Xray
    if ! install_xray; then
        log_message "error" "Xray安装失败，退出"
        exit 1
    fi
    
    # 生成配置
    if ! generate_config; then
        log_message "error" "配置生成失败，退出"
        exit 1
    fi
    
    # 配置防火墙
    setup_firewall
    
    # 启动服务
    if ! start_service; then
        log_message "error" "服务启动失败，退出"
        exit 1
    fi
    
    # 显示客户端连接信息
    show_client_info
    
    log_message "info" "VLESS + Reality 安装完成！"
    echo -e "\n${GREEN}VLESS + Reality 已成功安装和配置！${NC}"
}

# 执行主函数
main