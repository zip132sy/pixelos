# PixelOS

![](https://gitee.com/zip132sy/pixelos/raw/master/docs/pixelos_logo.png)

[English](README.md) | [中文](README_zh_CN.md) | [Русский](README-ru_RU.md)

## 简介

PixelOS 是一个基于 OpenComputers Minecraft Mod 的图形化操作系统。继承自 MineOS 项目并进行了大量定制化改造。主要特性包括：

- **多任务处理** - 支持多任务并行运行
- **双缓冲图形界面** - 流畅的 GUI 体验
- **多语言支持** - 内置语言包和软件本地化
- **多用户系统** - 支持用户配置文件和密码认证
- **BIOS 功能** - 启动项管理、硬盘加密、密码保护
- **文件共享** - 通过调制解调器进行局域网文件共享
- **FTP 客户端** - 连接真实 FTP 服务器
- **内置 IDE** - 语法高亮和调试功能
- **应用商店** - 发布和分享应用程序
- **自定义源** - 支持添加自定义应用源
- **动画和壁纸** - 动态壁纸和主题定制

## 安装方法

<!--
### 方法一：Pastebin 安装（推荐）

在 OpenComputers 计算机中插入 OpenOS 软盘和网卡，输入以下命令：

```
pastebin run <install_code>
```
-->

### 方法一：手动安装

```
wget -f https://gitee.com/zip132sy/pixelos/raw/master/Installer/OpenOS.lua /tmp/installer.lua && /tmp/installer.lua
```

安装程序会引导您完成：
- 选择语言
- 选择启动盘（可格式化）
- 创建用户账户
- 自定义设置

> **注意**：Pastebin 安装方式暂时不可用。原始 MineOS 项目请访问 [https://github.com/IgorTimofeev/MineOS](https://github.com/IgorTimofeev/MineOS)。

## 主要功能

### BIOS 系统
- 按 `F12` 或 `DEL` 进入 BIOS 设置
- 管理启动项顺序
- 设置 BIOS 密码
- 硬盘加密功能
- 中英文语言切换

### 磁盘加密
- 在"设置" → "磁盘"中管理加密
- 输入密码两次进行加密
- 使用 XOR + SHA-256 加密算法

### 应用商店
- 官方应用源：MineOS 官方应用库
- 自定义源：支持添加私人/第三方源
- 备份和恢复源配置

## 系统要求

- **显卡**：Tier 3 显卡（至少 8 色深度）
- **屏幕**：至少 160x50 分辨率
- **内存**：至少 2 个 Tier 3.5 内存条
- **硬盘**：Tier 2 或更高硬盘
- **网卡**：需要互联网卡
- **EEPROM**：需要 EEPROM 模块

## 开发指南

详细 API 文档请参考 [API_DOCS.md](API_DOCS.md)

## 项目结构

```
PixelOS/
├── Libraries/           # 系统库
│   ├── BIOS.lua         # BIOS 功能
│   └── Encryption.lua   # 加密库
├── Applications/       # 应用程序
├── Installer/          # 安装程序
├── Wallpapers/        # 壁纸
└── docs/             # 文档
```

## 许可证

PixelOS 基于 MIT 许可证开源。详见 [LICENSE](LICENSE) 文件。

## 致谢

- 原始项目：[MineOS by IgorTimofeev](https://github.com/IgorTimofeev/MineOS)
- OpenComputers Mod

## 联系方式

- Gitee: https://gitee.com/zip132sy/pixelos
- 问题反馈：提交 Issue
