# PixelOS

![](https://gitee.com/zip132sy/pixelos/raw/master/docs/pixelos_logo.png)

[English](README.md) | [中文](README_zh_CN.md) | [Русский](README-ru_RU.md)

## Introduction

PixelOS is a GUI-based operating system for the OpenComputers Minecraft mod. Based on MineOS with extensive customizations. Main features include:

- **Multitasking** - Run multiple applications simultaneously
- **Double-buffered GUI** - Smooth graphical interface
- **Multi-language Support** - Built-in language packs and localization
- **Multi-user System** - User profiles with password authentication
- **BIOS Features** - Boot management, disk encryption, password protection
- **File Sharing** - LAN file sharing via modems
- **FTP Client** - Connect to real FTP servers
- **Built-in IDE** - Syntax highlighting and debugging
- **App Market** - Publish and share applications
- **Custom Sources** - Add private/third-party sources
- **Animations & Wallpapers** - Live wallpapers and themes

## Installation

<!--
### Method 1: Pastebin (Recommended)

Insert OpenOS floppy disk and Internet Card, type:

```
pastebin run <install_code>
```
-->

### Method 1: Manual Installation

```
wget -f https://gitee.com/zip132sy/pixelos/raw/master/Installer/OpenOS.lua /tmp/installer.lua && /tmp/installer.lua
```

The installer will guide you through:
- Language selection
- Boot drive selection (can format)
- User account creation
- Custom settings

> **Note**: The Pastebin installation method is temporarily disabled. The original MineOS project can be found at [https://github.com/IgorTimofeev/MineOS](https://github.com/IgorTimofeev/MineOS).

## Main Features

### BIOS System
- Press `F12` or `DEL` to enter BIOS setup
- Manage boot priority order
- Set BIOS password
- Disk encryption feature
- English/Chinese language switching

### Disk Encryption
- Access via "Settings" → "Disks"
- Enter password twice to encrypt
- Uses XOR + SHA-256 encryption

### App Market
- Official source: MineOS official repository
- Custom sources: Add private/third-party sources
- Backup and restore source configuration

## System Requirements

- **GPU**: Tier 3 graphics card (8+ color depth)
- **Screen**: 160x50 minimum resolution
- **RAM**: 2x Tier 3.5 RAM modules minimum
- **Storage**: Tier 2 hard disk or better
- **Network**: Internet card required
- **EEPROM**: EEPROM module required

## Development Guide

For detailed API documentation, see [API_DOCS.md](API_DOCS.md)

## Project Structure

```
PixelOS/
├── Libraries/           # System libraries
│   ├── BIOS.lua         # BIOS functionality
│   └── Encryption.lua    # Encryption library
├── Applications/       # Applications
├── Installer/          # Installer
├── Wallpapers/        # Wallpapers
└── docs/             # Documentation
```

## License

PixelOS is licensed under the MIT License. See [LICENSE](LICENSE) file for details.

## Acknowledgments

- Original project: [MineOS by IgorTimofeev](https://github.com/IgorTimofeev/MineOS)
- OpenComputers Mod

## Contact

- Gitee: https://gitee.com/zip132sy/pixelos
- Issues: Submit an Issue
