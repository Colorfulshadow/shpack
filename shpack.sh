#!/bin/bash

# Define paths and URLs
SHPACK_DIR="/usr/local/shpack/"
os_version=""
release=""

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    release=$ID
fi


# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

install_base() {
    echo "Installing base packages..."
    if [[ $release == "centos" ]]; then
        yum install wget curl tar -y
    elif [[ $release == "ubuntu" || $release == "debian" ]]; then
        apt update && apt install wget curl tar -y
    else
        echo "Unsupported OS"
        exit 1
    fi
}

install_shpack() {
    echo "Installing shpack..."
    install_base
    
    # Check if jq is installed, if not, attempt to install it
    if ! command -v jq &> /dev/null; then
        echo "jq could not be found, attempting to install..."
        if [[ $release == "centos" ]]; then
            yum install jq -y
        elif [[ $release == "ubuntu" || $release == "debian" ]]; then
            apt update && apt install jq -y
        else
            echo "Unsupported OS for jq installation"
            exit 1
        fi
    fi

    echo "请选择你的下载来源："
    echo "1) GitHub (最新版)"
    echo "2) Colorduck (https://download.colorduck.me/shpack.tar.gz)"
    read -p "请输入选项 [1-2]: " source_option
    
    case "$source_option" in
        1)
            # Use GitHub API to fetch the latest release download URL for shpack
            SHPACK_URL=$(curl -s https://api.github.com/repos/Colorfulshadow/shpack/releases/latest | jq -r '.assets[0].browser_download_url')
            if [[ "$SHPACK_URL" == "null" ]]; then
                echo "无法获取最新版本的下载链接，请检查GitHub仓库或尝试其他下载来源。"
                exit 1
            fi
            ;;
        2)
            SHPACK_URL="https://download.colorduck.me/shpack.tar.gz"
            ;;
        *)
            echo "无效选项: $source_option. 使用默认Colorduck下载来源."
            SHPACK_URL="https://download.colorduck.me/shpack.tar.gz"
            ;;
    esac
    
    cd /usr/local/
    if [[ -e "$SHPACK_DIR" ]]; then
        rm "$SHPACK_DIR" -rf
    fi
    wget --no-check-certificate -O shpack.tar.gz "$SHPACK_URL"
    tar -zxf shpack.tar.gz
    rm shpack.tar.gz -f
    cd shpack
    chmod +x /usr/local/shpack
    \cp /usr/local/shpack/shpack.sh /usr/bin/shpack
    chmod +x /usr/bin/shpack
}


update_shpack() {
    echo "Updating shpack..."
    rm -rf $SHPACK_DIR/*
    # Add a prompt for the user to choose the download source
    echo "请选择你的下载来源："
    echo "1) github(https://github.com/Colorfulshadow/shpack)"
    echo "2) Colorduck(https://download.colorduck.me/shpack.tar.gz)"
    read -p "请输入选项 [1-2]: " source_option
    
    # Set the SHPACK_URL based on the user's choice
    case "$source_option" in
        1)
            SHPACK_URL="https://github.com/Colorfulshadow/shpack/archive/refs/heads/master.tar.gz"
            ;;
        2)
            SHPACK_URL="https://download.colorduck.me/shpack.tar.gz"
            ;;
        *)
            echo "无效选项: $source_option. 使用默认Colorduck下载来源."
            SHPACK_URL="https://download.colorduck.me/shpack.tar.gz"
            ;;
    esac
    wget -O "$SHPACK_DIR/shpack.tar.gz" "$SHPACK_URL"
    tar -zxf "$SHPACK_DIR/shpack.tar.gz" -C "$SHPACK_DIR"
}

run_setup_ss() {
    echo "Running setup_ss.sh..."
    SETUP_SCRIPT="$SHPACK_DIR/setup_ss.sh"
    if [ -f "$SETUP_SCRIPT" ]; then
        bash "$SETUP_SCRIPT"
    else
        echo "setup_ss.sh script does not exist in $SHPACK_DIR."
    fi
}

run_setup_vps() {
    echo "Running setup_vps.sh..."
    SETUP_SCRIPT="$SHPACK_DIR/setup_vps.sh"
    if [ -f "$SETUP_SCRIPT" ]; then
        bash "$SETUP_SCRIPT"
    else
        echo "setup_vps.sh script does not exist in $SHPACK_DIR."
    fi
}

run_setup_vless(){
    echo "Running setup_vless.sh..."
    SETUP_SCRIPT="$SHPACK_DIR/setup_vless.sh"
    if [ -f "$SETUP_SCRIPT" ]; then
        bash "$SETUP_SCRIPT"
    else
        echo "setup_vless.sh script does not exist in $SHPACK_DIR."
    fi
}

# Show menu
show_menu() {
    while true; do
        echo -e "
  shpack管理脚本
  0. 退出脚本
————————————————
  1. 安装shpack
  2. 更新shpack
————————————————
  3. 初始化 vps
  3. 安装shadowsocks-libev
  4. 安装vless-reality
————————————————

  "
        # Prompt for user input
        read -p "请选择一个操作[0-4]: " option
        case "$option" in
            1) install_shpack ;;
            2) update_shpack ;;
            3) run_setup_vps ;;
            4) run_setup_ss ;;
            5) run_setup_vless ;;
            0) break ;;
            *) echo "无效选项: $option" ;;
        esac
    done
}

main() {
    show_menu
}

main "$@"
