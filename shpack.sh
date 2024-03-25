#!/bin/bash

# Define paths and URLs
SHPACK_DIR="/usr/local/shpack/"
SHPACK_URL="https://colorduck.me/shpack.tar.gz"
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
    install_base
    echo "Installing shpack..."
    cd /usr/local/
    systemctl stop shpack
    if [[ -e "$SHPACK_DIR" ]]; then
        rm "$SHPACK_DIR" -rf
    fi
    mkdir -p "$SHPACK_DIR"
    wget -O shpack.tar.gz "$SHPACK_URL"
    tar -zxf shpack.tar.gz
    rm shpack.tar.gz -f
    cd shpack
    chmod +x /usr/local/shpack/*
    cp -f shpack.service /etc/systemd/system/
    systemctl daemon-reload
    systemctl enable shpack
    systemctl start shpack
}

update_shpack() {
    echo "Updating shpack..."
    rm -rf $SHPACK_DIR/*
    wget -O "$SHPACK_DIR/shpack.tar.gz" "$SHPACK_URL"
    tar -zxf "$SHPACK_DIR/shpack.tar.gz" -C "$SHPACK_DIR"
}

run_setup_ss() {
    echo "Running setup_ss.sh..."
    SETUP_SS_SCRIPT="$SHPACK_DIR/setup_ss.sh"
    if [ -f "$SETUP_SS_SCRIPT" ]; then
        bash "$SETUP_SS_SCRIPT"
    else
        echo "setup_ss.sh script does not exist in $SHPACK_DIR."
    fi
}

run_setup_vps() {
    echo "Running setup_vps.sh..."
    SETUP_SS_SCRIPT="$SHPACK_DIR/setup_vps.sh"
    if [ -f "$SETUP_SS_SCRIPT" ]; then
        bash "$SETUP_SS_SCRIPT"
    else
        echo "setup_vps.sh script does not exist in $SHPACK_DIR."
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
  3. 运行setup_ss.sh
  4. 运行setup_vps.sh"
        # Prompt for user input
        read -p "请选择一个操作[0-4]: " option
        case "$option" in
            1) install_shpack ;;
            2) update_shpack ;;
            3) run_setup_ss ;;
            4) run_setup_vps ;;
            0) break ;;
            *) echo "无效选项: $option" ;;
        esac
    done
}

main() {
    show_menu
}

main "$@"
