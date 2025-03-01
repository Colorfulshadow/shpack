#!/bin/bash

# ===================================================
# XrayR 安装配置脚本
# 功能：
# 1. 安装 XrayR
# 2. 配置 XrayR 连接到 v2board 面板
# 3. 设置证书
# 4. 启动服务
# 5. 支持 IPv4 和 IPv6 配置
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
LOG_FILE="/usr/local/shpack/logs/setup_xrayr.log"
CONFIG_DIR="/usr/local/shpack/config"
XRAYR_CONFIG_FILE="${CONFIG_DIR}/xrayr.conf"
XRAYR_INSTALL_DIR="/usr/local/XrayR"
XRAYR_CONFIG_DIR="/etc/XrayR"
SSL_DIR="/root/ssl"

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
    local packages=("curl" "wget" "git" "unzip" "ufw")
    
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

# 安装 XrayR
install_xrayr() {
    log_message "info" "安装 XrayR..."
    
    # 检查XrayR是否已安装
    if [ -f "/usr/local/bin/XrayR" ] || [ -f "/usr/bin/XrayR" ]; then
        log_message "info" "XrayR 已安装"
        
        read -p "是否重新安装/更新 XrayR? [y/N]: " reinstall
        if [[ "$reinstall" != "y" && "$reinstall" != "Y" ]]; then
            log_message "info" "跳过 XrayR 安装"
            return 0
        fi
    fi
    
    # 选择安装源
    echo -e "\n${GREEN}选择 XrayR 安装源:${NC}"
    echo -e "${BLUE}1)${NC} GitHub 官方源（国外服务器推荐）"
    echo -e "${BLUE}2)${NC} 国内镜像 (ghproxy.com)"
    read -p "请选择 [1-2] (默认: 1): " source_choice
    
    local install_command
    case ${source_choice:-1} in
        1)
            log_message "info" "使用 GitHub 官方源安装 XrayR..."
            install_command="bash <(curl -Ls https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/install.sh)"
            ;;
        2)
            log_message "info" "使用 ghproxy.com 安装 XrayR..."
            install_command="bash <(curl -Ls https://ghproxy.com/https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/install.sh)"
            ;;
        *)
            log_message "warn" "无效选项，使用 GitHub 官方源"
            install_command="bash <(curl -Ls https://raw.githubusercontent.com/XrayR-project/XrayR-release/master/install.sh)"
            ;;
    esac
    
    # 执行安装命令
    log_message "info" "下载并执行 XrayR 安装脚本..."
    eval "$install_command" &>>"$LOG_FILE"
    
    if [ -f "/usr/local/bin/XrayR" ] || [ -f "/usr/bin/XrayR" ]; then
        log_message "info" "XrayR 安装成功"
        return 0
    else
        log_message "error" "XrayR 安装失败"
        return 1
    fi
}

# 检查IPv6支持
check_ipv6_support() {
    if [ -f /proc/net/if_inet6 ]; then
        local ipv6_count=$(wc -l < /proc/net/if_inet6)
        if [ "$ipv6_count" -gt 0 ]; then
            log_message "info" "检测到IPv6支持"
            return 0
        fi
    fi
    
    log_message "warn" "未检测到IPv6支持"
    return 1
}

# 配置 XrayR
configure_xrayr() {
    log_message "info" "配置 XrayR..."
    
    # 确保配置目录存在
    mkdir -p "$XRAYR_CONFIG_DIR" &>>"$LOG_FILE"
    
    # 交互式配置
    echo -e "\n${GREEN}请提供 v2board 面板信息${NC}"
    
    # 获取API信息
    read -p "请输入 API 主机地址 (例如: https://your-panel.com): " api_host
    if [ -z "$api_host" ]; then
        log_message "error" "API 主机地址不能为空"
        return 1
    fi
    
    read -p "请输入 API Key: " api_key
    if [ -z "$api_key" ]; then
        log_message "error" "API Key 不能为空"
        return 1
    fi
    
    # 获取节点ID
    read -p "请输入节点ID: " node_id
    if ! [[ "$node_id" =~ ^[0-9]+$ ]]; then
        log_message "error" "节点ID必须是数字"
        return 1
    fi
    
    # 选择节点类型
    echo -e "\n${BLUE}选择节点类型:${NC}"
    echo -e "1) V2ray"
    echo -e "2) Shadowsocks"
    echo -e "3) Trojan"
    read -p "请选择 [1-3] (默认: 1): " node_type_choice
    
    local node_type
    case ${node_type_choice:-1} in
        1) node_type="V2ray" ;;
        2) node_type="Shadowsocks" ;;
        3) node_type="Trojan" ;;
        *) node_type="V2ray" ;;
    esac
    
    # 是否启用VLESS
    local enable_vless="false"
    if [ "$node_type" = "V2ray" ]; then
        read -p "是否启用VLESS? [y/N]: " vless_choice
        if [[ "$vless_choice" = "y" || "$vless_choice" = "Y" ]]; then
            enable_vless="true"
        fi
    fi
    
    # 是否启用XTLS
    local enable_xtls="false"
    if [ "$node_type" = "V2ray" ] || [ "$node_type" = "Trojan" ]; then
        read -p "是否启用XTLS? [y/N]: " xtls_choice
        if [[ "$xtls_choice" = "y" || "$xtls_choice" = "Y" ]]; then
            enable_xtls="true"
        fi
    fi
    
    # 证书配置
    echo -e "\n${BLUE}选择证书模式:${NC}"
    echo -e "1) 文件 (使用现有证书文件)"
    echo -e "2) DNS (使用ACME DNS验证)"
    echo -e "3) HTTP (使用ACME HTTP验证)"
    echo -e "4) 无 (禁用TLS)"
    read -p "请选择 [1-4] (默认: 1): " cert_mode_choice
    
    local cert_mode
    case ${cert_mode_choice:-1} in
        1) cert_mode="file" ;;
        2) cert_mode="dns" ;;
        3) cert_mode="http" ;;
        4) cert_mode="none" ;;
        *) cert_mode="file" ;;
    esac
    
    # 证书域名和路径
    local cert_domain=""
    local cert_file=""
    local key_file=""
    
    if [ "$cert_mode" != "none" ]; then
        read -p "请输入证书域名: " cert_domain
        if [ -z "$cert_domain" ]; then
            log_message "error" "证书域名不能为空"
            return 1
        fi
        
        if [ "$cert_mode" = "file" ]; then
            # 检查SSL目录
            if [ ! -d "$SSL_DIR" ]; then
                log_message "info" "SSL目录不存在，创建目录..."
                mkdir -p "$SSL_DIR" &>>"$LOG_FILE"
            fi
            
            # 检查证书文件是否存在
            cert_file="$SSL_DIR/$cert_domain.cer"
            key_file="$SSL_DIR/$cert_domain.key"
            
            if [ ! -f "$cert_file" ] || [ ! -f "$key_file" ]; then
                log_message "warn" "证书文件不存在: $cert_file 或 $key_file"
                
                # 询问用户是否要提供证书文件路径
                read -p "是否提供自定义证书文件路径? [y/N]: " custom_path_choice
                if [[ "$custom_path_choice" = "y" || "$custom_path_choice" = "Y" ]]; then
                    read -p "请输入证书文件路径 (.cer/.crt): " custom_cert_file
                    read -p "请输入密钥文件路径 (.key): " custom_key_file
                    
                    if [ -f "$custom_cert_file" ] && [ -f "$custom_key_file" ]; then
                        cert_file="$custom_cert_file"
                        key_file="$custom_key_file"
                    else
                        log_message "error" "自定义证书文件不存在"
                        return 1
                    fi
                else
                    log_message "error" "未找到证书文件，请确保证书文件存在或选择其他证书模式"
                    return 1
                fi
            fi
        fi
    fi
    
    # IPv6支持配置
    local enable_ipv6="false"
    local ipv6_node_id=""
    local ipv6_port_offset="0"
    
    # 检测是否支持IPv6
    if check_ipv6_support; then
        read -p "是否同时配置IPv6节点? [y/N]: " ipv6_choice
        if [[ "$ipv6_choice" = "y" || "$ipv6_choice" = "Y" ]]; then
            enable_ipv6="true"
            
            # 询问是否使用不同的节点ID
            read -p "是否为IPv6节点使用不同的节点ID? [y/N]: " diff_node_id_choice
            if [[ "$diff_node_id_choice" = "y" || "$diff_node_id_choice" = "Y" ]]; then
                read -p "请输入IPv6节点ID: " ipv6_node_id
                if ! [[ "$ipv6_node_id" =~ ^[0-9]+$ ]]; then
                    log_message "error" "节点ID必须是数字"
                    return 1
                fi
            else
                # 使用相同的节点ID
                ipv6_node_id="$node_id"
            fi

            # 询问是否使用不同的证书域名
            read -p "是否为IPv6节点使用不同的证书域名? [y/N]: " diff_cert_domain_choice
            if [[ "$diff_cert_domain_choice" = "y" || "$diff_cert_domain_choice" = "Y" ]]; then
                read -p "请输入IPv6证书域名: " ipv6_cert_domain
                if [ -z "$ipv6_cert_domain" ]; then
                    log_message "error" "证书域名不能为空"
                    return 1
                fi
            else
                # 使用相同的节点ID
                ipv6_cert_domain="$cert_domain"
            fi
            
            # 询问是否使用端口偏移
            read -p "是否为IPv6节点设置端口偏移（避免端口冲突）? [y/N]: " port_offset_choice
            if [[ "$port_offset_choice" = "y" || "$port_offset_choice" = "Y" ]]; then
                read -p "请输入端口偏移值（通常为1）: " ipv6_port_offset
                if ! [[ "$ipv6_port_offset" =~ ^[0-9]+$ ]]; then
                    log_message "error" "端口偏移值必须是数字"
                    ipv6_port_offset="0"
                fi
            fi
        fi
    fi
    
    # 创建配置文件
    log_message "info" "生成 XrayR 配置文件..."
    
    # 基础节点配置
    local nodes_config=""
    
    # IPv4节点配置
    nodes_config+="  -
    PanelType: \"V2board\" # Panel type: SSpanel, V2board
    ApiConfig:
      ApiHost: \"${api_host}\"
      ApiKey: \"${api_key}\"
      NodeID: ${node_id}
      NodeType: ${node_type} # Node type: V2ray, Shadowsocks, Trojan
      Timeout: 30 # Timeout for the api request
      EnableVless: ${enable_vless} # Enable Vless for V2ray Type
      EnableXTLS: ${enable_xtls} # Enable XTLS for V2ray and Trojan
    ControllerConfig:
      ListenIP: 0.0.0.0 # IP address you want to listen
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Enable custom DNS config
      CertConfig:
        CertMode: ${cert_mode} # Option about how to get certificate: none, file, http, dns
        CertDomain: \"${cert_domain}\" # Domain to cert
        CertFile: ${cert_file} # Provided if the CertMode is file
        KeyFile: ${key_file}"
    
    # 添加IPv6节点配置（如果启用）
    if [[ "$enable_ipv6" = "true" ]]; then
        nodes_config+="\n  -
    PanelType: \"V2board\" # Panel type: SSpanel, V2board
    ApiConfig:
      ApiHost: \"${api_host}\"
      ApiKey: \"${api_key}\"
      NodeID: ${ipv6_node_id}
      NodeType: ${node_type} # Node type: V2ray, Shadowsocks, Trojan
      Timeout: 30 # Timeout for the api request
      EnableVless: ${enable_vless} # Enable Vless for V2ray Type
      EnableXTLS: ${enable_xtls} # Enable XTLS for V2ray and Trojan
    ControllerConfig:
      ListenIP: \"::\" # IPv6 address you want to listen
      SendIP: \"::\" # Set send IP for vnext (v2ray only)
      UpdatePeriodic: 60 # Time to update the nodeinfo, how many sec.
      EnableDNS: false # Enable custom DNS config
      CertConfig:
        CertMode: ${cert_mode} # Option about how to get certificate: none, file, http, dns
        CertDomain: \"${ipv6_cert_domain}\" # Domain to cert
        CertFile: ${cert_file} # Provided if the CertMode is file
        KeyFile: ${key_file}"
    fi
    
    # 创建完整配置文件
    cat > "${XRAYR_CONFIG_DIR}/config.yml" << EOF
Log:
  Level: warning  # Log level: none, error, warning, info, debug
  AccessPath: /etc/XrayR/access.Log
  ErrorPath: /etc/XrayR/error.log
DnsConfigPath: # /etc/XrayR/dns.json # Path to dns config
RouteConfigPath: # /etc/XrayR/route.json # Path to route config
InboundConfigPath: # /etc/XrayR/custom_inbound.json # Path to custom inbound config
OutboundConfigPath: # /etc/XrayR/custom_outbound.json # Path to custom outbound config
ConnectionConfig:
  Handshake: 4 # Handshake time limit, Second
  ConnIdle: 30 # Connection idle time limit, Second
  UplinkOnly: 2 # Time limit when the connection downstream is closed, Second
  DownlinkOnly: 4 # Time limit when the connection is closed after the uplink is closed, Second
  BufferSize: 64 # The internal cache size of each connection, kB
Nodes:
$(echo -e "$nodes_config")
EOF
    
    check_command "创建配置文件"
    
    # 保存配置信息到shpack配置目录
    mkdir -p "$CONFIG_DIR" &>>"$LOG_FILE"
    cat > "$XRAYR_CONFIG_FILE" << EOF
# XrayR 配置信息
XRAYR_API_HOST=${api_host}
XRAYR_API_KEY=${api_key}
XRAYR_NODE_ID=${node_id}
XRAYR_NODE_TYPE=${node_type}
XRAYR_ENABLE_VLESS=${enable_vless}
XRAYR_ENABLE_XTLS=${enable_xtls}
XRAYR_CERT_MODE=${cert_mode}
XRAYR_CERT_DOMAIN=${cert_domain}
XRAYR_CERT_FILE=${cert_file}
XRAYR_KEY_FILE=${key_file}
XRAYR_ENABLE_IPV6=${enable_ipv6}
XRAYR_IPV6_NODE_ID=${ipv6_node_id}
XRAYR_IPV6_PORT_OFFSET=${ipv6_port_offset}
EOF
    
    check_command "保存配置信息到: $XRAYR_CONFIG_FILE"
    
    return 0
}

# 配置防火墙
setup_firewall() {
    log_message "info" "配置防火墙..."
    
    # 检查UFW是否可用
    if command -v ufw &> /dev/null; then
        # XrayR会根据面板配置自动开放端口，我们不需要手动配置
        log_message "info" "XrayR将根据面板设置自动管理端口"
        
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
    log_message "info" "启动 XrayR 服务..."
    systemctl daemon-reload &>>"$LOG_FILE"
    systemctl restart XrayR &>>"$LOG_FILE"
    check_command "启动 XrayR 服务"
    
    # 检查服务状态
    if systemctl is-active --quiet XrayR; then
        log_message "info" "XrayR 服务已成功启动"
        
        # 设置开机自启
        systemctl enable XrayR &>>"$LOG_FILE"
        check_command "设置 XrayR 服务开机自启"
    else
        log_message "error" "XrayR 服务启动失败"
        return 1
    fi
    
    return 0
}

# 显示服务信息
show_service_info() {
    log_message "info" "XrayR 服务信息..."
    
    # 读取配置文件
    if [ -f "$XRAYR_CONFIG_FILE" ]; then
        source "$XRAYR_CONFIG_FILE"
    else
        log_message "error" "找不到配置文件: $XRAYR_CONFIG_FILE"
        return 1
    fi
    
    # 获取服务器IP
    local server_ipv4=$(curl -s -4 https://api.ipify.org || curl -s -4 http://ifconfig.me || curl -s -4 icanhazip.com)
    if [ -z "$server_ipv4" ]; then
        server_ipv4="未知"
    fi
    
    # 获取IPv6地址（如果启用）
    local server_ipv6="未启用"
    if [[ "$XRAYR_ENABLE_IPV6" = "true" ]]; then
        server_ipv6=$(curl -s -6 https://api64.ipify.org || curl -s -6 http://ipv6.icanhazip.com || echo "未知")
    fi
    
    # 显示服务信息
    echo -e "\n${GREEN}========== XrayR 服务信息 ==========${NC}"
    echo -e "${BLUE}服务器IPv4:${NC} $server_ipv4"
    
    if [[ "$XRAYR_ENABLE_IPV6" = "true" ]]; then
        echo -e "${BLUE}服务器IPv6:${NC} $server_ipv6"
        echo -e "${BLUE}IPv4节点ID:${NC} $XRAYR_NODE_ID"
        echo -e "${BLUE}IPv6节点ID:${NC} $XRAYR_IPV6_NODE_ID"
        echo -e "${BLUE}IPv6端口偏移:${NC} $XRAYR_IPV6_PORT_OFFSET"
    else
        echo -e "${BLUE}节点ID:${NC} $XRAYR_NODE_ID"
    fi
    
    echo -e "${BLUE}节点类型:${NC} $XRAYR_NODE_TYPE"
    echo -e "${BLUE}面板地址:${NC} $XRAYR_API_HOST"
    echo -e "${BLUE}证书模式:${NC} $XRAYR_CERT_MODE"
    if [ "$XRAYR_CERT_MODE" != "none" ]; then
        echo -e "${BLUE}证书域名:${NC} $XRAYR_CERT_DOMAIN"
    fi
    echo -e "${GREEN}===========================================${NC}\n"
    
    # 显示服务状态
    echo -e "${YELLOW}服务状态:${NC}"
    systemctl status XrayR
    
    # 显示日志路径
    echo -e "\n${YELLOW}日志文件:${NC}"
    echo -e "访问日志: /etc/XrayR/access.Log"
    echo -e "错误日志: /etc/XrayR/error.log"
    
    # 显示命令提示
    echo -e "\n${YELLOW}常用命令:${NC}"
    echo -e "启动: ${GREEN}systemctl start XrayR${NC}"
    echo -e "停止: ${GREEN}systemctl stop XrayR${NC}"
    echo -e "重启: ${GREEN}systemctl restart XrayR${NC}"
    echo -e "状态: ${GREEN}systemctl status XrayR${NC}"
    echo -e "查看日志: ${GREEN}journalctl -u XrayR -f${NC}"
}

# 主函数
main() {
    log_message "info" "开始安装 XrayR..."
    
    # 确保以root用户运行
    check_root
    
    # 检测操作系统和包管理器
    detect_os
    
    # 安装依赖
    install_dependencies
    
    # 安装XrayR
    if ! install_xrayr; then
        log_message "error" "XrayR安装失败，退出"
        exit 1
    fi
    
    # 配置XrayR
    if ! configure_xrayr; then
        log_message "error" "XrayR配置失败，退出"
        exit 1
    fi
    
    # 配置防火墙
    setup_firewall
    
    # 启动服务
    if ! start_service; then
        log_message "error" "XrayR服务启动失败，请检查日志"
        exit 1
    fi
    
    # 显示服务信息
    show_service_info
    
    log_message "info" "XrayR 安装配置完成！"
    echo -e "\n${GREEN}XrayR 已成功安装和配置！${NC}"
}

# 执行主函数
main