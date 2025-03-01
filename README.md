# SHPACK

![Version](https://img.shields.io/github/v/release/colorfulshadow/shpack?label=version)
![License](https://img.shields.io/github/license/colorfulshadow/shpack)

SHPACK是一个功能强大的Linux服务器管理工具集，用于快速部署和管理常见的VPS服务，特别优化了对代理和加密通信服务的支持。该工具设计得既适合国内服务器环境，也适合国际服务器环境。

## 特性

- 🚀 **模块化设计**：所有功能被组织成独立的脚本，可以单独使用
- 🔄 **自动更新**：内置更新机制，保持工具集始终最新
- 🛡️ **多源安装支持**：支持多种安装源，适应不同网络环境（包括中国大陆）
- 📝 **详细日志**：所有操作都有详细日志记录，便于排查问题
- 🌈 **用户友好界面**：彩色输出和交互式菜单，提升用户体验
- 🔧 **多平台兼容**：支持Debian/Ubuntu、CentOS和其他主流Linux发行版
- 🔗 **一键部署**：快速安装和配置常用服务
- 🔒 **安全加固**：内置多种安全性增强措施

## 安装

### 快速安装

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Colorfulshadow/shpack/main/install.sh)"
```

对于中国大陆服务器，建议使用以下镜像安装命令：

```bash
bash -c "$(curl -fsSL https://ghproxy.com/https://raw.githubusercontent.com/Colorfulshadow/shpack/main/install.sh)"
```

### 手动安装

1. 克隆仓库
```bash
git clone https://github.com/Colorfulshadow/shpack.git
```

2. 进入目录并安装
```bash
cd shpack
bash shpack.sh
```

## 使用方法

安装完成后，可以通过以下命令启动shpack主菜单：

```bash
shpack
```

或者直接运行特定脚本：

```bash
# 初始化VPS
/usr/local/shpack/scripts/setup_vps.sh

# 安装Shadowsocks
/usr/local/shpack/scripts/setup_ss.sh

# 安装VLESS+Reality
/usr/local/shpack/scripts/setup_vless.sh

# 安装XrayR（用于v2board面板）
/usr/local/shpack/scripts/setup_xrayr.sh
```

## 目录结构

```
/usr/local/shpack/
├── shpack.sh                # 主脚本
├── lib/                     # 库文件
│   └── common.sh            # 共享函数库
├── scripts/                 # 各类安装脚本
│   ├── setup_vps.sh         # VPS初始化脚本
│   ├── setup_ss.sh          # Shadowsocks安装脚本
│   ├── setup_vless.sh       # VLESS安装脚本
│   └── setup_xrayr.sh       # XrayR安装脚本（v2board集成）
├── config/                  # 配置文件目录
│   ├── shadowsocks.conf     # Shadowsocks配置
│   ├── vless.conf           # VLESS配置
│   └── xrayr.conf           # XrayR配置
└── logs/                    # 日志目录
    ├── shpack.log           # 主脚本日志
    ├── setup_vps.log        # VPS初始化日志
    └── ...                  # 其他日志文件
```

## 可用脚本说明

### 1. setup_vps.sh

VPS初始化脚本，用于快速配置新服务器：

- 配置SSH密钥认证
- 禁用密码登录提高安全性
- 配置UFW防火墙
- 设置SSL证书自动更新

### 2. setup_ss.sh

Shadowsocks服务器安装和配置脚本：

- 安装Shadowsocks-libev
- 交互式配置（端口、密码、加密方式）
- 配置防火墙规则
- 生成客户端配置信息

### 3. setup_vless.sh

VLESS+Reality服务器安装和配置脚本：

- 安装Xray-core（支持多种安装源）
- 配置VLESS+Reality协议
- 自动生成密钥和证书
- 显示客户端连接信息

### 4. setup_xrayr.sh

XrayR安装配置脚本，用于v2board面板集成：

- 安装XrayR（支持国内外安装源）
- 配置与v2board面板的连接
- 灵活的证书配置选项
- 自动化服务管理

## 常见问题

### 如何更新SHPACK？

```bash
shpack
# 选择「更新shpack」选项
```

### 如何查看日志？

所有日志存储在`/usr/local/shpack/logs/`目录下，可以使用以下命令查看：

```bash
cat /usr/local/shpack/logs/setup_vless.log
# 或使用tail实时查看
tail -f /usr/local/shpack/logs/setup_ss.log
```

### 国内服务器安装失败怎么办？

如果遇到网络问题导致安装失败，请使用国内镜像安装选项：

1. 在安装Xray或XrayR时，选择「国内镜像」选项
2. 使用ghproxy.com或jsDelivr等镜像源
3. 对于完全无法访问外网的服务器，选择「手动安装」选项

## 支持的操作系统

- Debian 8+
- Ubuntu 16.04+
- CentOS 7+
- 其他基于这些系统的发行版

## 贡献指南

欢迎贡献代码或提出建议！请遵循以下步骤：

1. Fork本仓库
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 提交Pull Request

## 许可证

本项目采用MIT许可证 - 详见 [LICENSE](LICENSE) 文件

## 致谢

- [Xray-core](https://github.com/XTLS/Xray-core)
- [XrayR](https://github.com/XrayR-project/XrayR)
- [Shadowsocks-libev](https://github.com/shadowsocks/shadowsocks-libev)

---

**免责声明**：本工具仅供学习和研究网络技术使用，请遵守当地法律法规。使用者应对自己的行为负责，作者不对任何滥用行为承担责任。