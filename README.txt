================================================================================
                         PixelOS v3.0 for OpenComputers
================================================================================

  Based on MineOS by IgorTimofeev
  https://github.com/IgorTimofeev/MineOS

================================================================================
                              DESCRIPTION
================================================================================

PixelOS is a graphical operating system for the OpenComputers mod in Minecraft.
It is a modified and enhanced version of MineOS, maintaining full compatibility
with the original architecture while adding new features and applications.

================================================================================
                              FEATURES
================================================================================

CORE SYSTEM:
  ✓ Full GUI with window management and double buffering
  ✓ Desktop environment with icons and taskbar
  ✓ Start menu with application launcher
  ✓ Error reporting and recovery system
  ✓ User settings and configuration management

APPLICATIONS:
  ✓ Settings       - System configuration and hardware info
  ✓ File Manager   - Browse and manage files
  ✓ System Check   - Hardware and software diagnostics
  ✓ App Store      - Application repository and installer
  ✓ Disk Utility   - Disk management and BIOS tools
  ✓ BIOS Tool      - EEPROM read/write and backup
  ✓ Error Reporter - View system error logs
  ✓ Terminal       - Command line interface
  ✓ Calculator     - Standard calculator

SYSTEM TOOLS:
  ✓ check_install.lua  - Pre-installation compatibility checker
  ✓ Installer/Main.lua - Guided installation wizard

================================================================================
                           REQUIREMENTS
================================================================================

HARDWARE:
  • OpenComputers GPU (Graphics Card)
  • OpenComputers Screen (Display)
  • OpenComputers Filesystem (Hard Drive)
  • OpenComputers EEPROM (BIOS)
  • Minimum 64KB RAM (32KB free)
  • Minimum 4KB EEPROM storage

SOFTWARE:
  • Minecraft with OpenComputers mod
  • Lua 5.2 or higher

================================================================================
                           INSTALLATION
================================================================================

METHOD 1: AUTOMATIC INSTALLATION (Recommended)
---------------------------------------------
1. Copy the PixelOS folder contents to your OpenComputers HDD
2. Navigate to the Installer directory
3. Run: Installer/Main.lua
4. Follow the on-screen instructions
5. Reboot when complete

METHOD 2: MANUAL INSTALLATION
------------------------------
1. Copy all files to the root of your OpenComputers HDD:
   - OS.lua
   - Libraries/ folder
   - Applications/ folder
   - System/ folder
   - Icons/ folder

2. Run: check_install.lua to verify compatibility
3. Run: OS.lua to start the system

METHOD 3: FROM GITHUB/MINEOS
-----------------------------
PixelOS is based on MineOS and maintains compatibility with MineOS applications.
You can install MineOS applications into the Applications/ folder.

================================================================================
                           FILE STRUCTURE
================================================================================

/
├── OS.lua                      # Main system file (bootloader)
├── Libraries/                  # System libraries
│   ├── GUI.lua                 # Graphical user interface
│   ├── Filesystem.lua          # File system operations
│   ├── Event.lua               # Event handling
│   ├── Screen.lua              # Screen/drawing management
│   ├── GPU.lua                 # GPU wrapper
│   ├── System.lua              # System utilities
│   ├── Image.lua               # Image loading/saving
│   ├── Paths.lua               # Path utilities
│   ├── Color.lua               # Color utilities
│   ├── Text.lua                # Text processing
│   ├── Number.lua              # Number utilities
│   ├── Keyboard.lua            # Keyboard handling
│   ├── Bit32.lua               # Bitwise operations
│   ├── Network.lua             # Network utilities
│   ├── JSON.lua                # JSON encoding/decoding
│   └── ...                     # Additional libraries
├── Applications/               # Installed applications
│   ├── Settings.app/           # System settings
│   │   ├── Main.lua
│   │   └── Icon.pic
│   ├── FileManager.app/        # File manager
│   ├── SystemCheck.app/        # System diagnostics
│   ├── AppStore.app/           # Application store
│   ├── DiskUtility.app/        # Disk management
│   ├── BiosTool.app/           # BIOS tools
│   ├── ErrorReporter.app/      # Error reporting
│   ├── Terminal.app/           # Terminal emulator
│   └── Calculator.app/         # Calculator
├── System/OS/                  # System files
│   ├── Settings.cfg            # User settings
│   ├── Properties.cfg          # System properties
│   ├── Icons/                  # System icons
│   ├── Wallpapers/             # Desktop wallpapers
│   └── Localization/           # Language files
├── Desktop/                    # User desktop folder
├── Pictures/                   # User pictures folder
└── Installer/                  # Installation files
    ├── check_install.lua
    └── Main.lua

================================================================================
                         DEVELOPER INFORMATION
================================================================================

PixelOS is fully compatible with MineOS application structure.
To create applications for PixelOS, follow the MineOS API.

Application Structure:
  Applications/MyApp.app/
  ├── Main.lua          # Application entry point
  └── Icon.pic          # Application icon (8x8 PIC format)

Main.lua Template:
--------------------------------------------------------------------------------
local GUI = require("GUI")
local system = require("System")

local application = {}
application.name = "My Application"

function application.main()
    local workspace = system.getWorkspace()
    local window = GUI.window(10, 5, 40, 15, "My App")

    local label = GUI.label(12, 8, 30, 1, "Hello, PixelOS!")
    window:addChild(label)

    local closeBtn = GUI.button(30, 17, 8, 3, "Close")
    closeBtn.onTouch = function()
        workspace:removeChild(window)
    end
    window:addChild(closeBtn)

    workspace:addChild(window)
    return window
end

return application
--------------------------------------------------------------------------------

================================================================================
                           KNOWN ISSUES
================================================================================

None reported.

================================================================================
                          TROUBLESHOOTING
================================================================================

Problem: "attempt to call a nil value" error
Solution: Ensure all library files are present in Libraries/ folder

Problem: "No GPU found" error
Solution: Install a graphics card and screen in your OpenComputer

Problem: Out of memory errors
Solution: Add more RAM or close unused applications

Problem: Applications won't start
Solution: Check that Main.lua exists in the application folder

================================================================================
                          VERSION HISTORY
================================================================================

v3.0 (Current)
  - Complete system rewrite based on MineOS
  - Added SystemCheck, AppStore, DiskUtility applications
  - Added BIOS tool with read/write/backup functionality
  - Added Error Reporter
  - Added installation checker and wizard
  - Full GUI library implementation
  - Compatible with MineOS applications

v3.1 (PixelOS Enhanced)
  - LANGUAGE SYSTEM IMPROVEMENTS:
    * Split Chinese into Simplified (ChineseSimplified) and Traditional (ChineseTraditional)
    * Added automatic compatibility layer for legacy "Chinese" name
    * Smart auto-fallback mechanism for missing language files
    * Applications from MineOS store automatically supported
  - INSTALLATION IMPROVEMENTS:
    * Multi-language LICENSE display (6 languages supported)
    * Default installation language set to Simplified Chinese
    * Dynamic disk space calculation before installation
    * Improved installation progress indicators
  - APPLICATIONS:
    * App Market now supports custom repository sources
    * Added OpenPrograms repository source
    * System info shows "Based on MineOS" attribution
  - FOLD CRAFT LAUNCHER COMPATIBILITY:
    * Fixed NullPointerException errors in Android environment
    * Replaced native Lua libraries with pure LuaJ implementation
    * Custom Unicode library for better compatibility
  - DOCUMENTATION:
    * Updated API.md with complete localization system docs
    * Improved README with language system information

================================================================================
                          LICENSE
================================================================================

PixelOS is based on MineOS by IgorTimofeev and maintains compatibility
with the original MineOS license terms.

Original MineOS: https://github.com/IgorTimofeev/MineOS

================================================================================
                          CREDITS
================================================================================

Original MineOS by IgorTimofeev
PixelOS modifications and enhancements by PixelOS Team

OpenComputers mod by Sangar

================================================================================
                     LANGUAGE SUPPORT
================================================================================

PixelOS now supports Simplified and Traditional Chinese:

SYSTEM LANGUAGE FILES:
  /Localizations/
  ├── ChineseSimplified.lang      ← Simplified Chinese (默认)
  ├── ChineseTraditional.lang     ← Traditional Chinese
  ├── English.lang                ← English
  └── ... (20+ languages)

APPLICATION LANGUAGE FILES:
  Each application has its own Localizations/ folder with:
  - ChineseSimplified.lang
  - ChineseTraditional.lang
  - English.lang
  - Other languages as needed

COMPATIBILITY:
  - Legacy "Chinese.lang" files are automatically supported
  - System auto-fallback ensures applications always work
  - MineOS store applications fully compatible

INSTALLATION:
  - Default language: Simplified Chinese
  - LICENSE displayed in selected language (6 languages)
  - Disk space shown before installation

================================================================================
