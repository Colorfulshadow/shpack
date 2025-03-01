#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 定义路径和URL
SHPACK_DIR="/usr/local/shpack"
SCRIPTS_DIR="${SHPACK_DIR}/scripts"
LOG_FILE="${SHPACK_DIR}/shpack.log"
GITHUB_REPO="Colorfulshadow/shpack"
COLORDUCK_URL="https://download.colorduck.me/shpack.tar.gz"

# OS检测变量
OS_NAME=""
OS_VERSION=""

# 打印带颜色的消息
print_message() {
    local type=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case $type in
        "info") 
            echo -e "${GREEN}[INFO]${NC} $message" 
            echo "$timestamp [INFO] $message" >> "$LOG_FILE" 2>/dev/null
            ;;
        "warn") 
            echo -e "${YELLOW}[WARN]${NC} $message" 
            echo "$timestamp [WARN] $message" >> "$LOG_FILE" 2>/dev/null
            ;;
        "error") 
            echo -e "${RED}[ERROR]${NC} $message" 
            echo "$timestamp [ERROR] $message" >> "$LOG_FILE" 2>/dev/null
            ;;
        *) 
            echo -e "$message" 
            ;;
    esac
}

# 检测操作系统
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        OS_NAME=$DISTRIB_ID
        OS_VERSION=$DISTRIB_RELEASE
    elif [[ -f /etc/redhat-release ]]; then
        OS_NAME="centos"
        OS_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | cut -d '.' -f1)
    else
        print_message "error" "不支持的操作系统"
        exit 1
    fi
    
    OS_NAME=$(echo "$OS_NAME" | tr '[:upper:]' '[:lower:]')
    print_message "info" "检测到操作系统: $OS_NAME $OS_VERSION"
}

# 检查操作系统兼容性
check_os_compatibility() {
    case "$OS_NAME" in
        "centos")
            if [[ $(echo "$OS_VERSION" | cut -d '.' -f1) -lt 7 ]]; then
                print_message "error" "请使用CentOS 7或更高版本的系统！"
                exit 1
            fi
            ;;
        "ubuntu")
            if [[ $(echo "$OS_VERSION" | cut -d '.' -f1) -lt 16 ]]; then
                print_message "error" "请使用Ubuntu 16或更高版本的系统！"
                exit 1
            fi
            ;;
        "debian")
            if [[ $(echo "$OS_VERSION" | cut -d '.' -f1) -lt 8 ]]; then
                print_message "error" "请使用Debian 8或更高版本的系统！"
                exit 1
            fi
            ;;
        *)
            print_message "error" "不支持的操作系统: $OS_NAME"
            exit 1
            ;;
    esac
}

# 安装基础软件包
install_base_packages() {
    print_message "info" "安装基础软件包..."
    
    case "$OS_NAME" in
        "centos")
            yum install -y wget curl tar git jq &>/dev/null || {
                print_message "error" "无法在CentOS上安装基础软件包"
                return 1
            }
            ;;
        "ubuntu"|"debian")
            apt update -y &>/dev/null
            apt install -y wget curl tar git jq &>/dev/null || {
                print_message "error" "无法在$OS_NAME上安装基础软件包"
                return 1
            }
            ;;
        *)
            print_message "error" "不支持的操作系统"
            return 1
            ;;
    esac
    
    print_message "info" "基础软件包安装成功"
    return 0
}

# 获取最新版本号
get_latest_version() {
    # 尝试从GitHub API获取最新版本
    local latest_version
    latest_version=$(curl -s -m 10 "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | jq -r '.tag_name' 2>/dev/null)
    
    # 如果API调用失败，尝试从git标签获取
    if [[ -z "$latest_version" || "$latest_version" == "null" ]]; then
        print_message "warn" "无法从GitHub API获取最新版本"
        
        # 如果当前已安装，尝试从远程获取标签
        if [[ -d "${SHPACK_DIR}/.git" ]]; then
            cd "$SHPACK_DIR" || return ""
            git fetch --tags &>/dev/null
            latest_version=$(git describe --tags "$(git rev-list --tags --max-count=1 2>/dev/null)" 2>/dev/null)
        fi
    fi
    
    echo "$latest_version"
}

# 获取当前版本号
get_current_version() {
    if [[ -d "${SHPACK_DIR}/.git" ]]; then
        cd "$SHPACK_DIR" || return ""
        local current_version
        current_version=$(git describe --tags "$(git rev-list --tags --max-count=1 2>/dev/null)" 2>/dev/null || echo "")
        echo "$current_version"
    else
        echo ""
    fi
}

# 检查更新
check_update() {
    print_message "info" "检查更新..."
    
    # 检查shpack目录是否存在
    if [[ ! -d "$SHPACK_DIR" ]]; then
        print_message "warn" "shpack目录不存在，跳过更新检查"
        return 1
    fi
    
    # 获取当前版本
    local current_version
    current_version=$(get_current_version)
    
    if [[ -z "$current_version" ]]; then
        print_message "warn" "无法获取当前版本，跳过更新检查"
        return 1
    fi
    
    # 获取最新版本
    local latest_version
    latest_version=$(get_latest_version)
    
    if [[ -z "$latest_version" ]]; then
        print_message "warn" "无法获取最新版本，跳过更新检查"
        return 1
    fi
    
    print_message "info" "当前版本: $current_version, 最新版本: $latest_version"
    
    # 比较版本
    if [[ "$current_version" != "$latest_version" ]]; then
        print_message "info" "有新版本可用: $latest_version (当前版本: $current_version)"
        read -p "是否要更新? [y/N]: " update_choice
        if [[ "$update_choice" == "y" || "$update_choice" == "Y" ]]; then
            update_shpack
            return $?
        fi
    else
        print_message "info" "shpack已是最新版本 (版本: $current_version)"
    fi
    
    return 0
}

# 下载shpack
download_shpack() {
    local source_option
    
    echo -e "\n选择下载来源:"
    echo -e "${BLUE}1)${NC} GitHub (最新版本)"
    echo -e "${BLUE}2)${NC} Colorduck (https://download.colorduck.me/shpack.tar.gz)"
    read -p "请输入选项 [1-2] (默认: 1): " source_option
    
    local download_url
    local download_success=false
    local attempt=1
    local max_attempts=3
    
    while [[ $attempt -le $max_attempts && $download_success == false ]]; do
        case "$source_option" in
            1|"")
                print_message "info" "尝试从GitHub获取下载URL (尝试 $attempt/$max_attempts)..."
                download_url=$(curl -s -m 10 "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | jq -r '.assets[0].browser_download_url')
                
                if [[ -z "$download_url" || "$download_url" == "null" ]]; then
                    print_message "warn" "无法从GitHub API获取下载URL"
                    if [[ $attempt -eq $max_attempts ]]; then
                        print_message "info" "切换到Colorduck镜像"
                        download_url="$COLORDUCK_URL"
                    fi
                fi
                ;;
            2)
                print_message "info" "使用Colorduck镜像"
                download_url="$COLORDUCK_URL"
                ;;
            *)
                print_message "warn" "无效选项: $source_option. 使用GitHub作为默认选项."
                source_option=1
                continue
                ;;
        esac
        
        if [[ -z "$download_url" ]]; then
            print_message "error" "无法获取下载URL"
            ((attempt++))
            continue
        fi
        
        print_message "info" "从以下地址下载shpack: $download_url"
        
        # 创建临时目录
        local temp_dir
        temp_dir=$(mktemp -d)
        
        # 下载软件包
        if wget --no-check-certificate -q -O "${temp_dir}/shpack.tar.gz" "$download_url"; then
            # 提取软件包
            if tar -xzf "${temp_dir}/shpack.tar.gz" -C "$temp_dir"; then
                download_success=true
                
                # 清理下载
                rm -f "${temp_dir}/shpack.tar.gz"
                
                # 移动文件到安装目录
                if [[ -d "$SHPACK_DIR" ]]; then
                    print_message "info" "备份配置文件..."
                    # 备份配置文件
                    mkdir -p "${temp_dir}/config_backup"
                    if [[ -d "${SHPACK_DIR}/config" ]]; then
                        cp -r "${SHPACK_DIR}/config" "${temp_dir}/config_backup/" || print_message "warn" "无法备份配置目录"
                    fi
                    
                    print_message "info" "删除现有shpack目录"
                    rm -rf "$SHPACK_DIR"
                fi
                
                # 确保父目录存在
                mkdir -p "$(dirname "$SHPACK_DIR")"
                
                # 移动提取的文件到安装目录
                if mv "${temp_dir}/shpack" "$SHPACK_DIR"; then
                    # 恢复配置文件
                    if [[ -d "${temp_dir}/config_backup/config" ]]; then
                        print_message "info" "恢复配置文件..."
                        cp -r "${temp_dir}/config_backup/config" "${SHPACK_DIR}/" || print_message "warn" "无法恢复配置目录"
                    fi
                    
                    # 创建scripts目录（如果不存在）
                    mkdir -p "$SCRIPTS_DIR"
                    
                    # 将setup脚本移动到scripts目录（如果尚未移动）
                    for script in "${SHPACK_DIR}"/setup_*.sh; do
                        if [[ -f "$script" ]]; then
                            script_name=$(basename "$script")
                            # 检查是否已存在于scripts目录
                            if [[ ! -f "${SCRIPTS_DIR}/${script_name}" ]]; then
                                cp "$script" "${SCRIPTS_DIR}/${script_name}" || print_message "warn" "无法复制 $script_name 到scripts目录"
                            fi
                        fi
                    done
                    
                    # 初始化git仓库
                    cd "$SHPACK_DIR" || {
                        print_message "error" "无法切换到 $SHPACK_DIR 目录"
                        rm -rf "$temp_dir"
                        return 1
                    }
                    
                    git init &>/dev/null
                    git config --global --add safe.directory "$SHPACK_DIR" &>/dev/null
                    
                    print_message "info" "shpack下载并提取成功"
                    rm -rf "$temp_dir"
                    return 0
                else
                    print_message "error" "无法安装shpack"
                fi
            else
                print_message "error" "无法提取shpack"
            fi
        else
            print_message "error" "无法下载shpack"
        fi
        
        # 清理临时目录
        rm -rf "$temp_dir"
        ((attempt++))
    done
    
    if [[ $download_success == false ]]; then
        print_message "error" "下载失败，请检查网络连接或尝试其他下载源"
        return 1
    fi
    
    return 0
}

# 安装shpack
install_shpack() {
    print_message "info" "安装shpack..."
    
    # 安装基础软件包
    install_base_packages || {
        print_message "error" "无法安装基础软件包"
        return 1
    }
    
    # 下载shpack
    if ! download_shpack; then
        print_message "error" "无法下载shpack"
        return 1
    fi
    
    # 设置可执行权限
    chmod +x "${SHPACK_DIR}/shpack.sh" || {
        print_message "error" "无法为shpack.sh设置可执行权限"
        return 1
    }
    
    # 创建到/usr/bin的符号链接
    ln -sf "${SHPACK_DIR}/shpack.sh" /usr/bin/shpack || {
        print_message "error" "无法创建到/usr/bin/shpack的符号链接"
        return 1
    }
    
    print_message "info" "shpack安装成功"
    return 0
}

# 更新shpack
update_shpack() {
    print_message "info" "更新shpack..."
    
    # 安装基础软件包
    install_base_packages || {
        print_message "error" "无法安装基础软件包"
        return 1
    }
    
    # 下载并安装shpack
    if ! download_shpack; then
        print_message "error" "无法更新shpack"
        return 1
    fi
    
    # 创建到/usr/bin的符号链接
    ln -sf "${SHPACK_DIR}/shpack.sh" /usr/bin/shpack || {
        print_message "error" "无法创建到/usr/bin/shpack的符号链接"
        return 1
    }
    
    print_message "info" "shpack更新成功"
    return 0
}

# 运行设置脚本
run_setup_script() {
    local script_name=$1
    local script_path="${SCRIPTS_DIR}/${script_name}.sh"
    
    # 先检查scripts目录
    if [[ ! -f "$script_path" ]]; then
        # 如果不在scripts目录，检查主目录（向后兼容）
        script_path="${SHPACK_DIR}/${script_name}.sh"
    fi
    
    if [[ -f "$script_path" ]]; then
        print_message "info" "运行 ${script_name}.sh..."
        bash "$script_path"
        return $?
    else
        print_message "error" "${script_name}.sh 脚本不存在"
        return 1
    fi
}

# 发现可用的设置脚本
discover_setup_scripts() {
    local scripts=()
    
    # 首先检查scripts目录
    if [[ -d "$SCRIPTS_DIR" ]]; then
        for script in "${SCRIPTS_DIR}"/setup_*.sh; do
            if [[ -f "$script" ]]; then
                local script_name=$(basename "$script" .sh)
                scripts+=("$script_name")
            fi
        done
    fi
    
    # 然后检查主目录（向后兼容）
    for script in "${SHPACK_DIR}"/setup_*.sh; do
        if [[ -f "$script" ]]; then
            local script_name=$(basename "$script" .sh)
            # 检查是否已经添加
            if [[ ! " ${scripts[@]} " =~ " ${script_name} " ]]; then
                scripts+=("$script_name")
            fi
        fi
    done
    
    # 返回脚本名称列表
    echo "${scripts[@]}"
}

# 显示菜单并处理用户选择
show_menu() {
    while true; do
        # 发现可用的设置脚本
        local scripts=($(discover_setup_scripts))
        
        clear
        echo -e "\n${GREEN}  shpack管理脚本${NC}"
        echo -e "${YELLOW}  请输入你的选项-->:${NC}"
        echo -e "\n  ${BLUE}0.${NC} 退出脚本"
        echo -e "${YELLOW}————————————————${NC}"
        echo -e "  ${BLUE}1.${NC} 安装 shpack"
        echo -e "  ${BLUE}2.${NC} 更新 shpack"
        echo -e "${YELLOW}————————————————${NC}"
        
        # 动态列出设置脚本
        local i=3
        local script_indices=()
        
        for script in "${scripts[@]}"; do
            # 从脚本提取更易读的名称
            local readable_name=$(echo "$script" | sed 's/setup_//' | tr '_' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) tolower(substr($i,2));}1')
            echo -e "  ${BLUE}${i}.${NC} 安装 ${readable_name}"
            script_indices[$i]=$script
            ((i++))
        done
        
        echo -e "${YELLOW}————————————————${NC}\n"
        
        # 获取用户输入
        read -p "请选择一个操作[0-$((i-1))]: " option
        
        case "$option" in
            0) 
                echo -e "${GREEN}退出脚本.${NC}"
                break 
                ;;
            1) 
                install_shpack 
                read -p "按Enter键继续..."
                ;;
            2) 
                update_shpack 
                read -p "按Enter键继续..."
                ;;
            [3-9]|[1-9][0-9]) 
                if [[ -n "${script_indices[$option]}" ]]; then
                    run_setup_script "${script_indices[$option]}"
                    read -p "按Enter键继续..."
                else
                    print_message "error" "无效选项: $option"
                    read -p "按Enter键继续..."
                fi
                ;;
            *) 
                print_message "error" "无效选项: $option" 
                read -p "按Enter键继续..."
                ;;
        esac
    done
}

# 主函数
main() {
    # 如果不存在，创建日志目录
    mkdir -p "$(dirname "$LOG_FILE")" &>/dev/null
    
    # 检测操作系统
    detect_os
    
    # 检查操作系统兼容性
    check_os_compatibility
    
    # 如果shpack已安装，检查更新
    if [[ -d "$SHPACK_DIR" ]]; then
        check_update
    fi
    
    # 显示菜单
    show_menu
}

# 执行主函数
main "$@"