# PixelOS API Documentation v3.0

## Overview

PixelOS is a graphical operating system for OpenComputers, based on MineOS by IgorTimofeev.
This document describes the API for developing applications.

**Repository:** https://github.com/IgorTimofeev/MineOS (Original)
**Based on:** MineOS architecture and API

---

## System Architecture

PixelOS follows the MineOS architecture:

```
OS.lua (Entry Point)
    ↓
Libraries (Core System)
    ↓
Applications (.app folders)
```

### Application Structure

```
Applications/MyApp.app/
├── Main.lua          # Application code
└── Icon.pic          # 8x8 icon in PIC format
```

### Main.lua Template

```lua
local GUI = require("GUI")
local system = require("System")
local localization = require("Localization")

local application = {}
-- 使用翻译支持应用名称
application.name = localization.AppWeather or "Weather"

function application.main()
    -- Get workspace
    local workspace = system.getWorkspace()

    -- Create window
    local window = GUI.window(10, 5, 40, 15, localization.AppWeather)

    -- Add content
    local label = GUI.label(12, 8, 30, 1, "Hello!")
    window:addChild(label)

    -- Add close button
    local closeBtn = GUI.button(30, 13, 8, 3, "Close")
    closeBtn.onTouch = function()
        workspace:removeChild(window)
    end
    window:addChild(closeBtn)

    -- Add to workspace
    workspace:addChild(window)

    return window
end

return application
```

---

## GUI Library

### Constants

```lua
GUI.BACKGROUND_COLOR = 0xE1E1E1
GUI.WINDOW_BACKGROUND_COLOR = 0xEEEEEE
GUI.WINDOW_TITLE_BACKGROUND_COLOR = 0x3366CC
GUI.BUTTON_BACKGROUND_COLOR = 0xC3C3C3
GUI.BUTTON_PRESSED_BACKGROUND_COLOR = 0x999999
GUI.INPUT_BACKGROUND_COLOR = 0xFFFFFF
GUI.FOREGROUND_COLOR = 0x2D2D2D
GUI.BORDER_COLOR = 0x878787
GUI.SELECTION_COLOR = 0x66B6FF
```

### Containers

#### GUI.workspace()
Creates the main workspace container.

**Returns:** Workspace object

**Methods:**
- `workspace:addChild(object)` - Add child object
- `workspace:removeChild(object)` - Remove child object
- `workspace:draw()` - Draw all children
- `workspace:start(delay)` - Start event loop

#### GUI.container(x, y, width, height)
Creates a container object.

**Returns:** Container object

**Properties:**
- `x`, `y` - Position
- `width`, `height` - Size
- `children` - Table of child objects
- `colors.background` - Background color

#### GUI.window(x, y, width, height)
Creates a window with title bar and border.

**Properties:**
- `title` - Window title
- `isActive` - Active state
- `colors.background` - Background color
- `colors.title` - Title bar color

**Methods:**
- `window:addChild(child)` - Add child
- `window:removeChild(child)` - Remove child
- `window:draw()` - Draw window

### Widgets

#### GUI.button(x, y, width, height, text)
Creates a clickable button.

**Properties:**
- `text` - Button text
- `pressed` - Pressed state
- `colors.background` - Background color
- `onTouch` - Callback function(x, y, button, player)

**Example:**
```lua
local btn = GUI.button(10, 10, 12, 3, "Click Me")
btn.onTouch = function(x, y, button, player)
    print("Button clicked!")
end
window:addChild(btn)
```

#### GUI.label(x, y, width, height, text)
Creates a text label.

**Properties:**
- `text` - Label text
- `alignment` - "left", "center", or "right"
- `colors.text` - Text color
- `colors.background` - Background color

**Example:**
```lua
local label = GUI.label(10, 5, 20, 1, "Hello World")
label.alignment = "center"
label.colors.text = 0x3366CC
window:addChild(label)
```

#### GUI.input(x, y, width, placeholder)
Creates a text input field.

**Properties:**
- `text` - Current text
- `placeholder` - Placeholder text
- `cursorPosition` - Cursor position
- `focused` - Focus state
- `onInput` - Callback function(text)

**Example:**
```lua
local input = GUI.input(10, 8, 20, "Enter name...")
input.onInput = function(text)
    print("Input: " .. text)
end
window:addChild(input)
```

#### GUI.progressBar(x, y, width, height, value, max, color)
Creates a progress bar.

**Properties:**
- `value` - Current value
- `maximumValue` - Maximum value
- `color` - Bar color

**Example:**
```lua
local bar = GUI.progressBar(10, 12, 30, 1, 50, 100, 0x3366CC)
window:addChild(bar)
```

### Dialogs

#### GUI.messageBox(workspace, title, text, buttons)
Shows a modal message box.

**Parameters:**
- `workspace` - Workspace object
- `title` - Dialog title
- `text` - Message text (can use \n for newlines)
- `buttons` - Table of button names, e.g., {"OK", "Cancel"}

**Example:**
```lua
GUI.messageBox(workspace, "Confirm", "Are you sure?", {"Yes", "No"})
```

#### GUI.inputDialog(title, prompt, default)
Shows an input dialog (simplified version).

**Parameters:**
- `title` - Dialog title
- `prompt` - Input prompt
- `default` - Default value

**Returns:** User input string or nil

---

## Filesystem Library

### Functions

#### filesystem.exists(path)
Check if path exists.

**Returns:** boolean

#### filesystem.isDirectory(path)
Check if path is a directory.

**Returns:** boolean

#### filesystem.list(path)
List directory contents.

**Returns:** Table of filenames

#### filesystem.makeDirectory(path)
Create a directory.

**Returns:** boolean

#### filesystem.remove(path)
Remove a file or directory.

**Returns:** boolean

#### filesystem.rename(oldPath, newPath)
Rename/move a file.

**Returns:** boolean

#### filesystem.copy(source, destination)
Copy a file.

**Returns:** boolean

#### filesystem.open(path, mode)
Open a file.

**Modes:** "r" (read), "w" (write), "rb" (read binary), "wb" (write binary)

**Returns:** File handle

#### filesystem.close(handle)
Close a file handle.

#### filesystem.read(handle, count)
Read data from file.

**Returns:** String data

#### filesystem.write(handle, data)
Write data to file.

#### filesystem.readTable(path)
Read a Lua table from file.

**Returns:** Table

#### filesystem.writeTable(path, table)
Write a Lua table to file.

**Example:**
```lua
local fs = require("Filesystem")

-- Read file
local handle = fs.open("test.txt", "r")
local data = fs.read(handle, math.huge)
fs.close(handle)

-- Write file
local handle = fs.open("output.txt", "w")
fs.write(handle, "Hello World")
fs.close(handle)

-- Check existence
if fs.exists("test.txt") then
    print("File exists")
end
```

---

## Event Library

### Functions

#### event.addHandler(func, priority)
Add an event handler.

**Parameters:**
- `func` - Handler function
- `priority` - Priority number (lower = higher priority)

**Returns:** Handler function

#### event.removeHandler(func)
Remove an event handler.

#### event.pull(timeout)
Wait for and return the next event.

**Parameters:**
- `timeout` - Maximum wait time in seconds

**Returns:** eventType, ...

#### event.skip(eventType)
Skip all events of a specific type.

**Example:**
```lua
local event = require("Event")

-- Add custom handler
event.addHandler(function(type, ...)
    if type == "touch" then
        local x, y = ...
        print("Touch at " .. x .. ", " .. y)
    end
end)

-- Main loop
while true do
    local e = {event.pull()}
    -- Handle events
end
```

---

## System Library

### Functions

#### system.getWorkspace()
Get the current workspace.

**Returns:** Workspace object

#### system.error(path, line, traceback)
Show an error dialog.

#### system.showError(message)
Show an error message.

#### system.getUserSettings()
Get user settings table.

**Returns:** Settings table

#### system.saveUserSettings(settings)
Save user settings.

#### system.getSystemInfo()
Get system information.

**Returns:**
```lua
{
    osName = "PixelOS",
    osVersion = "3.0",
    basedOn = "MineOS",
    totalMemory = 65536,
    freeMemory = 32768,
    uptime = 123.45
}
```

---

## Screen Library

### Functions

#### screen.setGPUAddress(address)
Set the active GPU.

#### screen.getGPUAddress()
Get the current GPU address.

#### screen.setScreenAddress(address, reset)
Bind to a screen.

#### screen.getScreenAddress()
Get the current screen address.

#### screen.getResolution()
Get screen resolution.

**Returns:** width, height

#### screen.set(x, y, char, background, foreground)
Set a character on screen.

#### screen.clear(color)
Clear the screen.

#### screen.draw()
Flush the buffer to screen (double buffering).

---

## Paths Library

### Constants

```lua
paths.extension = ".pic"           -- Image extension
paths.application = ".app"         -- Application extension
paths.desktop = "Desktop/"
systemPaths.system = "System/OS/"
systemPaths.icons = "System/OS/Icons/"
systemPaths.wallpapers = "System/OS/Wallpapers/"
systemPaths.applications = "Applications/"
```

### Functions

#### paths.path(path)
Get directory part of path.

#### paths.name(path)
Get filename from path.

#### paths.extension(path)
Get file extension.

#### paths.hideExtension(path)
Remove extension from path.

#### paths.concat(...)
Join path components.

**Example:**
```lua
local paths = require("Paths")
local fullPath = paths.concat("Applications", "MyApp.app", "Main.lua")
-- Returns: "Applications/MyApp.app/Main.lua"
```

---

## Color Library

### Functions

#### color.RGBToInteger(r, g, b)
Convert RGB to color integer.

#### color.integerToRGB(integer)
Convert color integer to RGB.

**Returns:** r, g, b

#### color.transition(color1, color2, factor)
Blend two colors.

**Parameters:**
- `factor` - 0.0 to 1.0

### Constants

```lua
color.black = 0x000000
color.white = 0xFFFFFF
color.red = 0xFF0000
color.green = 0x00FF00
color.blue = 0x0000FF
```

---

## Image Library

### Functions

#### image.create(width, height, background, foreground, char)
Create a new image.

#### image.load(path)
Load an image from file.

**Returns:** Image object

#### image.save(path, image)
Save an image to file.

#### image.draw(screen, x, y, image)
Draw an image to screen.

### Image Format (PIC)

```
PIC
width
height
0xRRGGBB
0xRRGGBB
...
```

**Example 2x2 image:**
```
PIC
2
2
0xFF0000
0x00FF00
0x0000FF
0xFFFFFF
```

---

## Text Library

### Functions

#### text.wrap(text, maxLength)
Wrap text to multiple lines.

**Returns:** Table of lines

#### text.limit(text, maxLength, postfix)
Truncate text with ellipsis.

**Example:**
```lua
local text = require("Text")
local lines = text.wrap("Long text here...", 20)
local short = text.limit("Very long text", 10)  -- "Very lo..."
```

---

## Best Practices

### 1. Error Handling
Always use pcall for error-prone operations:
```lua
local ok, result = pcall(function()
    return filesystem.readTable("config.cfg")
end)
if not ok then
    print("Error: " .. result)
end
```

### 2. Event Handling
Don't block the main thread:
```lua
while true do
    local e = {event.pull(0.1)}  -- 0.1 second timeout
    -- Process events
end
```

### 3. Memory Management
Close file handles:
```lua
local handle = filesystem.open("file.txt", "r")
local data = filesystem.read(handle, math.huge)
filesystem.close(handle)  -- Always close!
```

### 4. UI Updates
Redraw only when necessary:
```lua
local needsRedraw = true
while true do
    if needsRedraw then
        window:draw()
        needsRedraw = false
    end
    -- Handle events
end
```

### 5. No Emojis
Use only ASCII characters to ensure compatibility:
```lua
-- Good
label.text = "Settings"

-- Bad
label.text = "Settings ⚙️"
```

---

## Example: Complete Application

```lua
-- Applications/Counter.app/Main.lua

local GUI = require("GUI")
local system = require("System")
local event = require("Event")

local application = {}
application.name = "Counter"

function application.main()
    local workspace = system.getWorkspace()
    local count = 0

    -- Create window
    local window = GUI.window(10, 5, 40, 15, "Counter")

    -- Counter label
    local counterLabel = GUI.label(20, 8, 10, 1, "0")
    counterLabel.alignment = "center"
    counterLabel.colors.text = 0x3366CC
    window:addChild(counterLabel)

    -- Increment button
    local incBtn = GUI.button(12, 11, 10, 3, "+")
    incBtn.onTouch = function()
        count = count + 1
        counterLabel.text = tostring(count)
    end
    window:addChild(incBtn)

    -- Decrement button
    local decBtn = GUI.button(24, 11, 10, 3, "-")
    decBtn.onTouch = function()
        count = count - 1
        counterLabel.text = tostring(count)
    end
    window:addChild(decBtn)

    -- Reset button
    local resetBtn = GUI.button(18, 15, 10, 3, "Reset")
    resetBtn.onTouch = function()
        count = 0
        counterLabel.text = "0"
    end
    window:addChild(resetBtn)

    -- Close button
    local closeBtn = GUI.button(32, 15, 8, 3, "Close")
    closeBtn.onTouch = function()
        workspace:removeChild(window)
    end
    window:addChild(closeBtn)

    -- Add to workspace
    workspace:addChild(window)

    return window
end

return application
```

---

## Troubleshooting

### "Missing: GUI" Error
Ensure Libraries/GUI.lua exists and is not corrupted.

### "attempt to call a nil value"
Check that all required libraries are loaded.

### Out of Memory
Close unused applications or add more RAM to your OpenComputer.

### Screen Not Updating
Call `screen.draw()` to flush the buffer.

---

## Resources

- Original MineOS: https://github.com/IgorTimofeev/MineOS
- OpenComputers Wiki: https://ocdoc.cil.li/
- Lua 5.3 Manual: https://www.lua.org/manual/5.3/
- **Localization Guide:** See `LOCALIZATION_GUIDE.md` for complete translation documentation

## Non-Standard Lua Libraries

### OpenComputers Lua Environment

PixelOS runs on OpenComputers, which has some differences from standard Lua 5.3:

#### Basic Functions
- `collectgarbage` is not available
- `dofile` and `loadfile` are reimplemented to work with mounted filesystems
- `load` only loads text by default (bytecode loading is disabled for security)
- `print`, `io.write`, `io.stdout:write`, and `term.write` output to the screen

#### Module System
- `package.config` and `package.cpath` are not available
- `package.loadlib` is not implemented (no C code support)
- `require` is available globally

Default `package.path`:
```
/lib/?.lua;/usr/lib/?.lua;/home/lib/?.lua;./?.lua;/lib/?/init.lua;/usr/lib/?/init.lua;/home/lib/?/init.lua;./?/init.lua
```

#### Input/Output
- `io.open` does not support `+` modes (only `r`, `w`, `a`, `rb`, `wb`, `ab`)
- Binary vs Text modes:
  - Binary mode: `io.open(path, "rb")` - reads bytes
  - Text mode: `io.open(path)` or `io.open(path, "r")` - reads Unicode characters

#### Operating System Functions
- `os.clock` returns approximate CPU time
- `os.date` uses in-game time
- `os.execute` runs shell commands
- `os.exit` terminates the current coroutine
- `os.setenv` adds Lua shell environment variables
- `os.remove` is an alias for `filesystem.remove`
- `os.rename` is an alias for `filesystem.rename`
- `os.setlocale` is not available
- `os.time` returns in-game time (seconds since world creation)
- `os.tmpname` creates unused names in `/tmp`

#### Additional Functions
- `os.sleep(seconds)` - Pauses the script for the specified time

#### Debug
- Only `debug.traceback` and `debug.getinfo` are implemented

### OpenComputers Components API

PixelOS uses OpenComputers components through the `component` library:

```lua
local component = require("component")

-- Example: Get GPU component
local gpu = component.gpu
local screen = component.screen

gpu.bind(screen)
```

### Computer API

Additional system functions are available through the `computer` library:

```lua
local computer = require("computer")

-- Get system information
local totalMemory = computer.totalMemory()
local freeMemory = computer.freeMemory()
local uptime = computer.uptime()
local energy = computer.energy()
local maxEnergy = computer.maxEnergy()
```

---

## Application Name Translations

PixelOS supports translated application names for all 22 languages.

### Usage

```lua
local localization = require("Localization")

local application = {}
application.name = localization.AppBootManager or "Boot Manager"
```

### Available Application Names

All applications have translated names using the format `App[Name]`:

| Key | Description |
|-----|-------------|
| `AppBootManager` | Boot Manager application |
| `AppSystemUpdate` | System Update application |
| `AppBiosTool` | BIOS Tool application |
| `AppErrorReporter` | Error Reporter application |
| `AppDiskUtility` | Disk Utility application |
| `AppWeather` | Weather application |
| `AppMarket` | App Market application |
| `AppSettings` | Settings application |
| `AppFileExplorer` | File Explorer application |
| `AppBrowser` | Browser application |
| `AppCalculator` | Calculator application |
| `AppCalendar` | Calendar application |
| `AppClock` | Clock application |
| `AppContacts` | Contacts application |
| `AppEditor` | Text Editor application |
| `AppIRC` | IRC Chat application |
| `AppMinesweeper` | Minesweeper game |
| `AppPaint` | Paint application |
| `AppScreensaver` | Screensaver application |
| `AppTerminal` | Terminal application |
| `AppVK` | VK Chat application |

### Supported Languages

Application names are translated in all 22 supported languages:
- ChineseSimplified, ChineseTraditional
- English, Russian, Ukrainian, Belarusian
- French, German, Spanish, Italian
- Japanese, Korean
- Arabic, Hindi, Bengali
- Polish, Dutch, Finnish, Slovak
- Portuguese, Bulgarian
- Lolcat (for fun)

### Best Practices

1. **Always provide fallback**:
   ```lua
   application.name = localization.AppName or "Default Name"
   ```

2. **Use consistent naming**: All app names use `App[Name]` format

3. **Test in all languages**: Verify display in different languages

For complete localization documentation, see `LOCALIZATION_GUIDE.md`.

## Localization System

### Language File Locations

PixelOS has three locations for language files, each with different purposes:

#### 1. `/Localizations/` (System Core)
- **Path**: `PixelOS/Localizations/`
- **Purpose**: System core language files
- **Used by**: System libraries (System.lua, GUI.lua, etc.)
- **Access**: `paths.system.localizations`

#### 2. `Installer/Localizations/` (Installer)
- **Path**: `PixelOS/Installer/Localizations/`
- **Purpose**: Installer language files
- **Used by**: Installer (Installer/Main.lua)
- **Note**: Only used during installation

#### 3. `Applications/[App]/Localizations/` (Applications)
- **Path**: Each application's own Localizations folder
- **Purpose**: Application-specific language files
- **Used by**: Applications via `system.getCurrentScriptLocalization()`

### Language Compatibility

PixelOS provides automatic compatibility for language files:

#### Supported Language Names
- `ChineseSimplified` - Simplified Chinese (recommended)
- `ChineseTraditional` - Traditional Chinese (recommended)
- `Chinese` - Legacy name (auto-converted to ChineseSimplified)

#### Auto-Fallback Mechanism
```lua
-- System automatically tries in this order:
1. Requested language (e.g., ChineseSimplified.lang)
2. Legacy Chinese.lang (if requesting ChineseSimplified)
3. English.lang (fallback)
4. First available language file
```

#### Example: Loading Application Localization
```lua
local GUI = require("GUI")
local system = require("System")

-- Load this application's localization
local localization = system.getCurrentScriptLocalization()

-- Use localized strings
local window = GUI.window(10, 5, 40, 15, localization.myAppTitle)
```

### Best Practices for Developers

1. **Use new language names**: `ChineseSimplified` and `ChineseTraditional`
2. **Provide English fallback**: Always include `English.lang`
3. **Follow naming convention**: `[LanguageName].lang`
4. **Test without your language**: Ensure English fallback works

### Example Language File Structure
```
Applications/MyApp.app/
├── Localizations/
│   ├── ChineseSimplified.lang
│   ├── ChineseTraditional.lang
│   ├── English.lang
│   └── Russian.lang
├── Main.lua
└── Icon.pic
```

---

**End of API Documentation**
