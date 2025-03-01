#!/bin/bash

# ===================================================
# SHPACK 公共函数库
# 用途：为所有SHPACK脚本提供统一的工具函数
# ===================================================

# 定义路径
SHPACK_DIR="/usr/local/shpack"
SCRIPTS_DIR="${SHPACK_DIR}/scripts"
CONFIG_DIR="${SHPACK_DIR}/config"
LOGS_DIR="${SHPACK_DIR}/logs"

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # 无颜色

# 确保日志目录存在
mkdir -p "$LOGS_DIR" &>/dev/null

# 打印带颜色的消息
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
        "debug") 
            echo -e "${BLUE}[DEBUG]${NC} $message" 
            ;;
        *) 
            echo -e "$message" 
            ;;
    esac
}

# 记录日志到文件
log_message() {
    local type=$1
    local message=$2
    local log_file=$3
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # 如果没有指定日志文件，使用默认日志文件
    if [ -z "$log_file" ]; then
        # 获取调用脚本的名称
        local caller_script=$(basename "${BASH_SOURCE[1]}")
        log_file="${LOGS_DIR}/${caller_script%.*}.log"
    fi
    
    # 确保日志文件存在
    touch "$log_file" &>/dev/null
    
    # 写入日志
    echo "$timestamp [$type] $message" >> "$log_file"
    
    # 同时打印到控制台
    print_message "$type" "$message"
}

# 检查命令执行状态
check_command() {
    local cmd_desc=$1
    local log_file=$2
    
    if [ $? -ne 0 ]; then
        log_message "error" "命令执行失败: $cmd_desc" "$log_file"
        return 1
    else
        log_message "info" "命令执行成功: $cmd_desc" "$log_file"
        return 0
    fi
}

# 检测操作系统类型和包管理器
detect_os() {
    if command -v apt &> /dev/null; then
        OS_TYPE="debian"
        PKG_MANAGER="apt"
        PKG_UPDATE="apt update"
        PKG_INSTALL="apt install -y"
        PKG_REMOVE="apt remove -y"
    elif command -v yum &> /dev/null; then
        OS_TYPE="centos"
        PKG_MANAGER="yum"
        PKG_UPDATE="yum update -y"
        PKG_INSTALL="yum install -y"
        PKG_REMOVE="yum remove -y"
    elif command -v dnf &> /dev/null; then
        OS_TYPE="fedora"
        PKG_MANAGER="dnf"
        PKG_UPDATE="dnf check-update"
        PKG_INSTALL="dnf install -y"
        PKG_REMOVE="dnf remove -y"
    else
        log_message "error" "不支持的操作系统，无法确定包管理器"
        OS_TYPE="unknown"
        return 1
    fi
    
    log_message "info" "检测到操作系统类型: $OS_TYPE, 包管理器: $PKG_MANAGER"
    return 0
}

# 安装必要的软件包
install_packages() {
    local packages=("$@")
    local missing_pkgs=()
    
    # 确保OS已检测
    if [ -z "$PKG_MANAGER" ]; then
        detect_os
    fi
    
    # 检查哪些包需要安装
    for pkg in "${packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            missing_pkgs+=("$pkg")
        fi
    done
    
    # 如果有缺失的包，就安装它们
    if [ ${#missing_pkgs[@]} -gt 0 ]; then
        log_message "info" "安装缺失的软件包: ${missing_pkgs[*]}"
        eval "$PKG_UPDATE" &>/dev/null
        for pkg in "${missing_pkgs[@]}"; do
            log_message "info" "安装 $pkg..."
            eval "$PKG_INSTALL $pkg" &>/dev/null
            check_command "安装 $pkg"
        done
    else
        log_message "info" "所有必要的软件包都已安装"
    fi
}

# 读取配置文件
read_config() {
    local config_file="$1"
    local full_path
    
    # 检查是否提供了完整路径
    if [[ "$config_file" = /* ]]; then
        full_path="$config_file"
    else
        full_path="${CONFIG_DIR}/${config_file}"
    fi
    
    # 检查配置文件是否存在
    if [ ! -f "$full_path" ]; then
        log_message "error" "配置文件不存在: $full_path"
        return 1
    fi
    
    # 读取配置文件
    source "$full_path"
    check_command "读取配置文件: $full_path"
}

# 创建或更新配置文件
write_config() {
    local config_file="$1"
    local config_data="$2"
    local full_path
    
    # 确保配置目录存在
    mkdir -p "$CONFIG_DIR" &>/dev/null
    
    # 检查是否提供了完整路径
    if [[ "$config_file" = /* ]]; then
        full_path="$config_file"
    else
        full_path="${CONFIG_DIR}/${config_file}"
    fi
    
    # 写入配置数据
    echo "$config_data" > "$full_path"
    check_command "写入配置文件: $full_path"
}

# 显示输入提示，带有默认值
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local value
    
    # 显示带有默认值的提示
    read -p "$prompt [$default]: " value
    
    # 如果用户没有输入，使用默认值
    echo "${value:-$default}"
}

# 获取随机端口
get_random_port() {
    local min_port=${1:-10000}
    local max_port=${2:-65535}
    
    # 生成随机端口
    local port=$((RANDOM % (max_port - min_port + 1) + min_port))
    
    # 检查端口是否已被使用
    while netstat -tuln | grep -q ":$port "; do
        port=$((RANDOM % (max_port - min_port + 1) + min_port))
    done
    
    echo "$port"
}

# 生成随机字符串
generate_random_string() {
    local length=${1:-16}
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w "$length" | head -n 1
}

# 检查服务状态
check_service() {
    local service_name="$1"
    
    if systemctl is-active --quiet "$service_name"; then
        log_message "info" "服务 $service_name 正在运行"
        return 0
    else
        log_message "warn" "服务 $service_name 未运行"
        return 1
    fi
}

# 启动服务
start_service() {
    local service_name="$1"
    
    log_message "info" "启动服务: $service_name"
    systemctl start "$service_name"
    check_command "启动服务 $service_name"
}

# 停止服务
stop_service() {
    local service_name="$1"
    
    log_message "info" "停止服务: $service_name"
    systemctl stop "$service_name"
    check_command "停止服务 $service_name"
}

# 重启服务
restart_service() {
    local service_name="$1"
    
    log_message "info" "重启服务: $service_name"
    systemctl restart "$service_name"
    check_command "重启服务 $service_name"
}

# 启用服务开机自启
enable_service() {
    local service_name="$1"
    
    log_message "info" "启用服务开机自启: $service_name"
    systemctl enable "$service_name"
    check_command "启用服务 $service_name"
}

# 禁用服务开机自启
disable_service() {
    local service_name="$1"
    
    log_message "info" "禁用服务开机自启: $service_name"
    systemctl disable "$service_name"
    check_command "禁用服务 $service_name"
}

# 配置防火墙规则
add_firewall_rule() {
    local port="$1"
    local protocol="${2:-tcp}"
    
    # 检查ufw是否安装
    if command -v ufw &> /dev/null; then
        log_message "info" "允许端口: $port/$protocol"
        ufw allow "$port/$protocol" &>/dev/null
        check_command "添加防火墙规则: $port/$protocol"
    else
        log_message "warn" "ufw未安装，无法配置防火墙规则"
        return 1
    fi
}

# 获取系统信息
get_system_info() {
    # CPU信息
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -n 1 | cut -d ':' -f 2 | sed 's/^[ \t]*//')
    local cpu_cores=$(grep -c processor /proc/cpuinfo)
    
    # 内存信息
    local mem_total=$(free -h | grep "Mem:" | awk '{print $2}')
    local mem_used=$(free -h | grep "Mem:" | awk '{print $3}')
    
    # 磁盘信息
    local disk_total=$(df -h / | grep "/" | awk '{print $2}')
    local disk_used=$(df -h / | grep "/" | awk '{print $3}')
    local disk_percent=$(df -h / | grep "/" | awk '{print $5}')
    
    # 系统信息
    local os_name=$(cat /etc/os-release | grep "PRETTY_NAME" | cut -d '"' -f 2)
    local kernel=$(uname -r)
    local uptime=$(uptime -p)
    
    # 输出信息
    echo "系统信息:"
    echo "  操作系统: $os_name"
    echo "  内核版本: $kernel"
    echo "  运行时间: $uptime"
    echo ""
    echo "硬件信息:"
    echo "  CPU型号: $cpu_model"
    echo "  CPU核心: $cpu_cores"
    echo "  内存总量: $mem_total"
    echo "  内存使用: $mem_used"
    echo "  磁盘总量: $disk_total"
    echo "  磁盘使用: $disk_used ($disk_percent)"
}

# 导出公共变量和函数
export SHPACK_DIR SCRIPTS_DIR CONFIG_DIR LOGS_DIR
export OS_TYPE PKG_MANAGER PKG_UPDATE PKG_INSTALL PKG_REMOVE