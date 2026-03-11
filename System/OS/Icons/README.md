# 锁图标文件

## 文件说明

- **Lock.pic** - 锁图标文件（32x32 像素，OCIF 格式）✅
- **Lock.png** - PNG 格式版本（32x32 像素）✅
- **Lock.lua** - Lua 表格格式（备用）✅
- **README.md** - 本说明文件

## 生成器工具

锁图标生成器已移动到 `tools` 目录：

- `tools/generate_lock_icon.py` - Python 版本（推荐）
- `tools/generate_lock_icon.lua` - Lua 版本（备用）

查看 `tools/README.md` 获取详细使用说明。

## 使用方法

### 在 OpenComputers 中加载

```lua
-- 方法 1: 直接加载 Lua 文件
local lockIcon = dofile("/System/OS/Icons/Lock.lua")
local widget = GUI.image(x, y, lockIcon)
workspace:addChild(widget)

-- 方法 2: 转换为 PIC 格式后加载
local lockIcon = image.load("/System/OS/Icons/Lock.pic")
local widget = GUI.image(x, y, lockIcon)
workspace:addChild(widget)
```

## 图标设计

```
        银色锁梁
      ╭─────────╮
     ╱           ╲
    │   金色锁体   │
    │   ⬤ ⬤      │  ← 黑色钥匙孔
    │   ⬤ ⬤      │
      ╰─────────╯
```

**颜色方案**：
- 🔶 锁体：金色 (0xFFD700)
- 🥇 边框：深金色 (0xDAA520)
- 🥈 锁梁：银色 (0xC0C0C0)
- ⚫ 钥匙孔：黑色 (0x000000)
- ⬜ 背景：透明/白色 (0xFFFFFF)

## 转换为 PIC 格式（可选）

如需更好的兼容性，可以使用 OCIFImageConverter 转换为 .pic 格式：

1. 下载 OCIFImageConverter:
   ```bash
   git clone https://github.com/IgorTimofeev/OCIFImageConverter.git
   ```

2. 转换图标:
   ```bash
   python OCIFImageConverter.py Lock.png Lock.pic
   ```

3. 复制到 PixelOS:
   ```bash
   cp Lock.pic PixelOS/System/OS/Icons/
   ```

## 用途

- 系统加密设置图标
- 密码验证界面显示
- 安全相关功能标识

## 技术规格

- 尺寸：32x32 像素
- 格式：Lua 表格（兼容 OpenComputers image API）
- 颜色数：5 色
- 透明度：支持
