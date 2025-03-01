#!/bin/bash

# ===================================================
# Shadowsocks-libev 安装脚本
# 功能：
# 1. 安装 Shadowsocks-libev
# 2. 配置服务器参数 (端口, 密码, 加密方式)
# 3. 配置防火墙
# 4. 启动服务并设置开机自启
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
LOG_FILE="/usr/local/shpack/logs/setup_ss.log"
CONFIG_DIR="/usr/local/shpack/config"
SS_CONFIG_FILE="${CONFIG_DIR}/shadowsocks.conf"
SS_SNAP_CONFIG_DIR="/var/snap/shadowsocks-libev/common/etc/shadowsocks-libev"
SS_DEFAULT_PORT="16378"
SS_DEFAULT_METHOD="chacha20-ietf-poly1305"

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

# 生成随机密码
generate_password() {
    local length=${1:-16}
    local password=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | fold -w "$length" | head -n 1)
    echo "$password"
}

# 检查端口是否可用
check_port_available() {
    local port=$1
    if netstat -tuln | grep -q ":$port "; then
        return 1
    else
        return 0
    fi
}

# 获取可用端口
get_available_port() {
    local start_port=${1:-10000}
    local end_port=${2:-60000}
    local port
    
    # 首先尝试默认端口
    if check_port_available "$SS_DEFAULT_PORT"; then
        echo "$SS_DEFAULT_PORT"
        return 0
    fi
    
    # 如果默认端口不可用，随机选择一个端口
    port=$((RANDOM % (end_port - start_port + 1) + start_port))
    while ! check_port_available "$port"; do
        port=$((RANDOM % (end_port - start_port + 1) + start_port))
    done
    
    echo "$port"
}

# 安装 Shadowsocks-libev
install_shadowsocks() {
    log_message "info" "开始安装 Shadowsocks-libev..."
    
    # 检查安装方式，优先使用snap安装
    if command -v snap &> /dev/null; then
        log_message "info" "使用snap安装 Shadowsocks-libev..."
        
        # 安装snap core
        log_message "info" "安装snap core..."
        snap install core &>>"$LOG_FILE"
        check_command "安装snap core"
        
        # 安装shadowsocks-libev
        log_message "info" "安装shadowsocks-libev..."
        snap install shadowsocks-libev --edge &>>"$LOG_FILE"
        check_command "安装shadowsocks-libev"
        
        return 0
    elif command -v apt &> /dev/null; then
        # 如果snap不可用，尝试使用apt
        log_message "info" "使用apt安装 Shadowsocks-libev..."
        apt update &>>"$LOG_FILE"
        apt install -y shadowsocks-libev &>>"$LOG_FILE"
        check_command "使用apt安装shadowsocks-libev"
        
        return 0
    elif command -v yum &> /dev/null; then
        # 如果apt不可用，尝试使用yum
        log_message "info" "使用yum安装 Shadowsocks-libev..."
        # 添加EPEL仓库
        yum install -y epel-release &>>"$LOG_FILE"
        yum install -y shadowsocks-libev &>>"$LOG_FILE"
        check_command "使用yum安装shadowsocks-libev"
        
        return 0
    else
        log_message "error" "不支持的包管理器，无法安装 Shadowsocks-libev"
        return 1
    fi
}

# 配置 Shadowsocks
configure_shadowsocks() {
    local config_file
    local service_name
    
    log_message "info" "配置 Shadowsocks-libev..."
    
    # 获取服务相关配置
    if command -v snap &> /dev/null && snap list | grep -q shadowsocks-libev; then
        # 使用snap安装的配置路径
        mkdir -p "$SS_SNAP_CONFIG_DIR" &>>"$LOG_FILE"
        config_file="${SS_SNAP_CONFIG_DIR}/config.json"
        service_name="snap.shadowsocks-libev.ss-server-daemon.service"
    elif command -v shadowsocks-libev &> /dev/null || command -v ss-server &> /dev/null; then
        # 使用apt/yum安装的配置路径
        mkdir -p "/etc/shadowsocks-libev" &>>"$LOG_FILE"
        config_file="/etc/shadowsocks-libev/config.json"
        service_name="shadowsocks-libev"
    else
        log_message "error" "未找到 Shadowsocks-libev 安装，配置失败"
        return 1
    fi
    
    # 交互配置
    echo -e "\n${GREEN}配置 Shadowsocks 服务器参数${NC}"
    
    # 选择端口
    local default_port=$(get_available_port)
    read -p "请输入服务器端口 [${default_port}]: " ss_port
    ss_port=${ss_port:-$default_port}
    
    # 检查端口是否可用
    if ! check_port_available "$ss_port"; then
        log_message "warn" "端口 ${ss_port} 已被占用，使用随机端口"
        ss_port=$(get_available_port)
        log_message "info" "选择新端口: ${ss_port}"
    fi
    
    # 设置密码
    local default_password=$(generate_password 20)
    read -p "请输入密码 [随机生成]: " ss_password
    ss_password=${ss_password:-$default_password}
    
    # 选择加密方式
    echo -e "\n选择加密方式:"
    echo -e "${BLUE}1)${NC} chacha20-ietf-poly1305 (推荐)"
    echo -e "${BLUE}2)${NC} aes-256-gcm"
    echo -e "${BLUE}3)${NC} aes-128-gcm"
    read -p "请选择 [1-3] (默认: 1): " encrypt_choice
    
    case ${encrypt_choice:-1} in
        1) ss_method="chacha20-ietf-poly1305" ;;
        2) ss_method="aes-256-gcm" ;;
        3) ss_method="aes-128-gcm" ;;
        *) ss_method="$SS_DEFAULT_METHOD" ;;
    esac
    
    # 生成配置文件
    log_message "info" "生成 Shadowsocks 配置文件..."
    cat > "$config_file" << EOF
{
    "server": ["::0", "0.0.0.0"],
    "server_port": $ss_port,
    "method": "$ss_method",
    "password": "$ss_password",
    "mode": "tcp_and_udp",
    "fast_open": false,
    "timeout": 300
}
EOF
    check_command "生成配置文件: $config_file"
    
    # 保存配置信息到shpack配置目录
    mkdir -p "$CONFIG_DIR" &>>"$LOG_FILE"
    cat > "$SS_CONFIG_FILE" << EOF
# Shadowsocks 配置信息
SS_PORT=$ss_port
SS_PASSWORD=$ss_password
SS_METHOD=$ss_method
SS_CONFIG_FILE=$config_file
SS_SERVICE=$service_name
EOF
    check_command "保存配置信息到: $SS_CONFIG_FILE"
    
    # 配置防火墙
    if command -v ufw &> /dev/null; then
        log_message "info" "配置防火墙，允许端口 ${ss_port}..."
        ufw allow "$ss_port/tcp" &>>"$LOG_FILE"
        ufw allow "$ss_port/udp" &>>"$LOG_FILE"
        check_command "配置防火墙规则"
    else
        log_message "warn" "未找到ufw，跳过防火墙配置"
    fi
    
    # 返回服务名称
    echo "$service_name"
}

# 启动 Shadowsocks 服务
start_shadowsocks() {
    local service_name=$1
    
    log_message "info" "启动 Shadowsocks 服务..."
    systemctl daemon-reload &>>"$LOG_FILE"
    systemctl restart "$service_name" &>>"$LOG_FILE"
    check_command "启动服务: $service_name"
    
    # 设置开机自启
    log_message "info" "设置开机自启..."
    systemctl enable "$service_name" &>>"$LOG_FILE"
    check_command "设置开机自启"
    
    # 检查服务状态
    if systemctl is-active --quiet "$service_name"; then
        log_message "info" "Shadowsocks 服务已成功启动"
    else
        log_message "error" "Shadowsocks 服务启动失败"
        return 1
    fi
    
    return 0
}

# 显示客户端配置信息
show_client_config() {
    # 读取配置文件
    if [ -f "$SS_CONFIG_FILE" ]; then
        source "$SS_CONFIG_FILE"
    else
        log_message "error" "找不到配置文件: $SS_CONFIG_FILE"
        return 1
    fi
    
    # 获取服务器IP
    local server_ip=$(curl -s https://api.ipify.org || curl -s http://ifconfig.me || curl -s icanhazip.com)
    if [ -z "$server_ip" ]; then
        server_ip="YOUR_SERVER_IP"
        log_message "warn" "无法获取服务器IP，请手动替换"
    fi

    # 显示客户端配置
    echo -e "\n${GREEN}========== Shadowsocks 客户端配置 ==========${NC}"
    echo -e "${BLUE}服务器地址:${NC} $server_ip"
    echo -e "${BLUE}端口:${NC} $SS_PORT"
    echo -e "${BLUE}密码:${NC} $SS_PASSWORD"
    echo -e "${BLUE}加密方式:${NC} $SS_METHOD"
    echo -e "${BLUE}插件选项:${NC} 无"
    echo -e "${GREEN}===========================================${NC}\n"
    
    # 生成URI（适用于扫码）
    local uri_encoded_password=$(echo -n "$SS_PASSWORD" | xxd -p | tr -d '\n' | sed 's/\(..\)/%\1/g')
    local ss_uri="ss://${SS_METHOD}:${uri_encoded_password}@${server_ip}:${SS_PORT}"
    
    echo -e "${YELLOW}URI 链接 (适用于客户端扫描):${NC}"
    echo -e "$ss_uri\n"
}

# 主函数
main() {
    log_message "info" "开始安装 Shadowsocks-libev..."
    
    # 确保以root用户运行
    check_root
    
    # 安装必要的软件包
    if ! command -v curl &> /dev/null; then
        log_message "info" "安装 curl..."
        if command -v apt &> /dev/null; then
            apt update &>>"$LOG_FILE" && apt install -y curl &>>"$LOG_FILE"
        elif command -v yum &> /dev/null; then
            yum install -y curl &>>"$LOG_FILE"
        fi
    fi
    
    if ! command -v ufw &> /dev/null; then
        log_message "info" "安装 ufw..."
        if command -v apt &> /dev/null; then
            apt update &>>"$LOG_FILE" && apt install -y ufw &>>"$LOG_FILE"
        elif command -v yum &> /dev/null; then
            yum install -y ufw &>>"$LOG_FILE"
        fi
    fi
    
    # 安装 snap（如果需要）
    if ! command -v snap &> /dev/null; then
        log_message "info" "安装 snap..."
        if command -v apt &> /dev/null; then
            apt update &>>"$LOG_FILE" && apt install -y snapd &>>"$LOG_FILE"
            check_command "安装 snap"
        elif command -v yum &> /dev/null; then
            yum install -y epel-release &>>"$LOG_FILE"
            yum install -y snapd &>>"$LOG_FILE"
            systemctl enable --now snapd.socket &>>"$LOG_FILE"
            check_command "安装 snap"
        else
            log_message "warn" "无法安装 snap，将尝试其他安装方式"
        fi
    fi
    
    # 安装 Shadowsocks-libev
    if ! install_shadowsocks; then
        log_message "error" "Shadowsocks-libev 安装失败"
        exit 1
    fi
    
    # 配置 Shadowsocks
    local service_name=$(configure_shadowsocks)
    if [ -z "$service_name" ]; then
        log_message "error" "Shadowsocks-libev 配置失败"
        exit 1
    fi
    
    # 启动服务
    if ! start_shadowsocks "$service_name"; then
        log_message "error" "Shadowsocks-libev 服务启动失败"
        exit 1
    fi
    
    # 显示客户端配置
    show_client_config
    
    log_message "info" "Shadowsocks-libev 安装完成！"
    echo -e "\n${GREEN}Shadowsocks-libev 已成功安装和配置！${NC}"
}

# 执行主函数
main