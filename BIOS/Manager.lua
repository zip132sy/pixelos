-- ============================================================
-- PixelOS Advanced BIOS Manager
-- Unique style with full features
-- ============================================================

local component = component
local computer = computer
local unicode = unicode or { len = function(s) return #s end, sub = function(s, i, j) return string.sub(s, i, j) end }

-- GPU initialization
local gpu = nil
local screen = nil

for address in component.list("gpu", true) do
    gpu = component.proxy(address)
    break
end

for address in component.list("screen", true) do
    screen = component.proxy(address)
    break
end

if gpu and screen then
    gpu.bind(screen)
    gpu.setResolution(80, 25)
end

_G._B = true

-- EEPROM Functions
computer.getBootAddress = function()
    local e = component.list("eeprom")()
    if e then
        local data = component.invoke(e, "getData") or ""
        return string.sub(data, 1, 36)
    end
    return ""
end

computer.setBootAddress = function(address)
    if #address == 36 then
        local e = component.list("eeprom")()
        if e then
            local data = component.invoke(e, "getData") or ""
            component.invoke(e, "setData", address .. string.sub(data, 37))
        end
    end
end

local function getEEPROMLanguage()
    local e = component.list("eeprom")()
    if e then
        local data = component.invoke(e, "getData") or ""
        return string.sub(data, 73, 74) or "en"
    end
    return "en"
end

local function setEEPROMLanguage(lang)
    local e = component.list("eeprom")()
    if e then
        local data = component.invoke(e, "getData") or ""
        local newData = string.sub(data, 1, 72) .. lang .. string.sub(data, 75)
        component.invoke(e, "setData", newData)
    end
end

local function getPriorityAddress()
    local e = component.list("eeprom")()
    if e then
        local data = component.invoke(e, "getData") or ""
        return string.sub(data, 37, 72)
    end
    return ""
end

local function setPriorityAddress(address)
    local e = component.list("eeprom")()
    if e then
        local data = component.invoke(e, "getData") or ""
        local newData = string.sub(data, 1, 36) .. address .. string.sub(data, 73)
        component.invoke(e, "setData", newData)
    end
end

-- Colors - PixelOS Theme
local COLORS = {
    bg = 0x1E1E1E,
    panel = 0x2D2D2D,
    border = 0x3C3C3C,
    title = 0x007ACC,
    highlight = 0x0E639C,
    white = 0xFFFFFF,
    gray = 0xAAAAAA,
    darkGray = 0x808080,
    green = 0x4EC9B0,
    yellow = 0xDCDCAA,
    red = 0xF14C4C,
    orange = 0xCE9178,
    cyan = 0x9CDCFE
}

-- State
local CurrentMenu = "Boot"
local selectedIndex = 1
local filesystemList = {}

-- Graphics Functions
local function clear()
    if gpu then
        gpu.setBackground(COLORS.bg)
        gpu.fill(1, 1, 80, 25, " ")
    end
end

local function set(x, y, text, fg, bg)
    if gpu then
        if fg then gpu.setForeground(fg) end
        if bg then gpu.setBackground(bg) end
        gpu.set(x, y, text)
    end
end

local function fill(x, y, w, h, char, bg)
    if gpu then
        if bg then gpu.setBackground(bg) end
        gpu.fill(x, y, w, h, char)
    end
end

local function drawBorder(x, y, w, h, title)
    fill(x, y, w, 1, " ", COLORS.panel)
    fill(x, y + h - 1, w, 1, " ", COLORS.panel)
    fill(x, y, 1, h, " ", COLORS.panel)
    fill(x + w - 1, y, 1, h, " ", COLORS.panel)
    
    -- Title bar
    fill(x, y, w, 1, " ", COLORS.title)
    if title then
        set(x + 2, y, title, COLORS.white, COLORS.title)
    end
end

local function getOSName(address)
    local proxy = component.proxy(address)
    if not proxy then return "Unknown" end
    
    if proxy.exists("/OS.lua") then
        local h = proxy.open("/OS.lua", "rb")
        if h then
            local data = proxy.read(h, 500) or ""
            proxy.close(h)
            if data:find("PixelOS") then return "PixelOS"
            elseif data:find("MineOS") then return "MineOS"
            elseif data:find("ForgeOS") then return "ForgeOS"
            elseif data:find("OpenOS") then return "OpenOS"
            else return "Custom" end
        end
    end
    if proxy.exists("/init.lua") then return "OpenOS" end
    return "Unknown"
end

local function refreshFilesystems()
    filesystemList = {}
    for address in component.list("filesystem") do
        local proxy = component.proxy(address)
        if proxy and proxy.getLabel then
            local label = proxy.getLabel()
            if label and label ~= "tmpfs" then
                local hasOS = proxy.exists("/OS.lua")
                local hasInit = proxy.exists("/init.lua")
                if hasOS or hasInit then
                    table.insert(filesystemList, {
                        address = address,
                        proxy = proxy,
                        label = label,
                        os = getOSName(address),
                        ready = hasOS or hasInit,
                        isDefault = address == computer.getBootAddress()
                    })
                end
            end
        end
    end
    table.sort(filesystemList, function(a, b) return a.label < b.label end)
end

local function drawTopBar()
    -- Title
    fill(1, 1, 80, 1, " ", COLORS.title)
    local title = "[ PixelOS BIOS ] Advanced Manager"
    set(2, 1, title, COLORS.white, COLORS.title)
    set(71, 1, "F10:Exit", COLORS.darkGray, COLORS.title)
end

local function drawBottomBar()
    fill(1, 25, 80, 1, " ", COLORS.panel)
    local info = "v1.0 | Boot: " .. (computer.getBootAddress() and unicode.sub(computer.getBootAddress(), 1, 8) or "N/A")
    set(2, 25, info, COLORS.darkGray, COLORS.panel)
    
    if CurrentMenu == "Boot" then
        set(40, 25, "Arrows:Select | Enter:Boot | 1:SetDefault | F5:Refresh", COLORS.gray, COLORS.panel)
    elseif CurrentMenu == "Settings" then
        set(40, 25, "1:SetPriority | 2:Clear | 3:Format | 4:About", COLORS.gray, COLORS.panel)
    else
        set(40, 25, "<>:Switch Tab | F10:Exit", COLORS.gray, COLORS.panel)
    end
end

local function drawMenuTabs()
    fill(1, 2, 80, 1, " ", COLORS.bg)
    
    local tabs = {
        {name = "Info", x = 2},
        {name = "Boot", x = 18},
        {name = "Settings", x = 32}
    }
    
    for _, tab in ipairs(tabs) do
        if CurrentMenu == tab.name then
            set(tab.x, 2, " " .. tab.name .. " ", COLORS.white, COLORS.highlight)
        else
            set(tab.x, 2, " " .. tab.name .. " ", COLORS.gray, COLORS.bg)
        end
    end
end

local function drawInfoPage()
    refreshFilesystems()
    
    -- Left Panel - System Info
    drawBorder(2, 4, 36, 20, " System Information ")
    
    local memTotal = computer.totalMemory()
    local memFree = computer.freeMemory()
    local memUsed = memTotal - memFree
    local memPercent = math.floor(memUsed / memTotal * 100)
    
    set(4, 6, "Memory", COLORS.cyan)
    set(4, 7, "  Total: " .. memTotal .. " KB", COLORS.white)
    set(4, 8, "  Used:  " .. memUsed .. " KB (" .. memPercent .. "%)", COLORS.white)
    set(4, 9, "  Free:  " .. memFree .. " KB", COLORS.green)
    
    -- Memory bar
    fill(4, 10, 32, 1, " ", COLORS.border)
    fill(4, 10, math.floor(32 * memPercent / 100), 1, " ", COLORS.title)
    
    set(4, 12, "Computer", COLORS.cyan)
    set(4, 13, "  Address: " .. unicode.sub(computer.address(), 1, 20), COLORS.white)
    set(4, 14, "  Uptime: " .. string.format("%.1f", computer.uptime()) .. "s", COLORS.white)
    
    local energy = computer.energy()
    local maxEnergy = computer.maxEnergy()
    local energyPercent = math.floor(energy / maxEnergy * 100)
    set(4, 15, "  Energy: " .. math.floor(energy) .. "/" .. maxEnergy .. " (" .. energyPercent .. "%)", COLORS.white)
    
    -- Energy bar
    fill(4, 16, 32, 1, " ", COLORS.border)
    fill(4, 16, math.floor(32 * energyPercent / 100), 1, " ", COLORS.green)
    
    set(4, 18, "Boot Configuration", COLORS.cyan)
    set(4, 19, "  Boot Addr: " .. (computer.getBootAddress() and unicode.sub(computer.getBootAddress(), 1, 18) or "N/A"), COLORS.yellow)
    set(4, 20, "  Priority: " .. (getPriorityAddress() ~= "" and unicode.sub(getPriorityAddress(), 1, 18) or "None"), COLORS.yellow)
    
    -- Right Panel - Boot Devices Summary
    drawBorder(40, 4, 38, 10, " Quick Boot ")
    
    set(42, 6, "Detected " .. #filesystemList .. " boot device(s)", COLORS.white)
    
    if #filesystemList > 0 then
        local default = filesystemList[1]
        for _, fs in ipairs(filesystemList) do
            if fs.isDefault then
                default = fs
                break
            end
        end
        set(42, 8, "Default: " .. default.label, COLORS.green)
        set(42, 9, "OS: " .. default.os, COLORS.orange)
    end
    
    -- Right Panel - BIOS Info
    drawBorder(40, 16, 38, 8, " BIOS Information ")
    
    set(42, 18, "Version: 1.0", COLORS.white)
    set(42, 19, "Language: " .. getEEPROMLanguage(), COLORS.white)
    set(42, 20, "EEPROM: " .. (component.list("eeprom")() and "Present" or "Not Found"), COLORS.white)
    set(42, 21, "Devices: " .. #filesystemList, COLORS.white)
end

local function drawBootPage()
    refreshFilesystems()
    
    if selectedIndex > #filesystemList then
        selectedIndex = math.max(1, #filesystemList)
    end
    
    -- Main panel
    drawBorder(2, 4, 50, 18, " Boot Device List ")
    
    if #filesystemList == 0 then
        set(15, 13, "No bootable devices found!", COLORS.red)
        set(10, 15, "Press F5 to refresh or install an OS", COLORS.darkGray)
    else
        for i = 1, math.min(#filesystemList, 14) do
            local fs = filesystemList[i]
            local y = 6 + i
            
            if y <= 19 then
                if i == selectedIndex then
                    fill(3, y, 48, 1, " ", COLORS.highlight)
                    set(4, y, ">" .. fs.label, COLORS.white, COLORS.highlight)
                    if fs.isDefault then
                        set(36, y, "[*]", COLORS.green, COLORS.highlight)
                    else
                        set(36, y, "[ ]", COLORS.gray, COLORS.highlight)
                    end
                else
                    fill(3, y, 48, 1, " ", COLORS.bg)
                    set(4, y, " " .. fs.label, COLORS.gray)
                    if fs.isDefault then
                        set(36, y, "[*]", COLORS.green)
                    else
                        set(36, y, "[ ]", COLORS.darkGray)
                    end
                end
            end
        end
    end
    
    -- Details panel
    drawBorder(54, 4, 24, 18, " Details ")
    
    if #filesystemList > 0 and filesystemList[selectedIndex] then
        local fs = filesystemList[selectedIndex]
        
        set(56, 6, "Name:", COLORS.cyan)
        set(56, 7, "  " .. fs.label, COLORS.white)
        
        set(56, 9, "Address:", COLORS.cyan)
        set(56, 10, "  " .. unicode.sub(fs.address, 1, 18), COLORS.gray)
        
        set(56, 12, "OS Type:", COLORS.cyan)
        set(56, 13, "  " .. fs.os, COLORS.orange)
        
        set(56, 15, "Status:", COLORS.cyan)
        if fs.ready then
            set(56, 16, "  [Ready]", COLORS.green)
        else
            set(56, 16, "  [Not Ready]", COLORS.red)
        end
        
        set(56, 18, "Space:", COLORS.cyan)
        set(56, 19, "  " .. fs.proxy.spaceTotal() .. " KB", COLORS.white)
        set(56, 20, "  Used: " .. fs.proxy.spaceUsed() .. " KB", COLORS.gray)
        
        set(56, 22, "Default:", COLORS.cyan)
        if fs.isDefault then
            set(56, 23, "  Yes", COLORS.green)
        else
            set(56, 23, "  No", COLORS.darkGray)
        end
    else
        set(56, 12, "No device", COLORS.darkGray)
        set(56, 13, "selected", COLORS.darkGray)
    end
end

local function drawSettingsPage()
    drawBorder(2, 4, 36, 18, " BIOS Settings ")
    
    set(4, 6, "1. Set Boot Priority", COLORS.white)
    set(4, 7, "   Set selected device as", COLORS.gray)
    set(4, 8, "   default boot device", COLORS.gray)
    
    set(4, 10, "2. Clear Priority", COLORS.white)
    set(4, 11, "   Remove boot priority,", COLORS.gray)
    set(4, 12, "   use last booted device", COLORS.gray)
    
    set(4, 14, "3. Format EEPROM", COLORS.red)
    set(4, 15, "   Reset all BIOS settings", COLORS.gray)
    set(4, 16, "   to factory defaults!", COLORS.gray)
    
    set(4, 18, "4. Change Language", COLORS.white)
    set(4, 19, "   Current: " .. getEEPROMLanguage(), COLORS.yellow)
    set(4, 20, "   Options: en/zh/ru", COLORS.gray)
    
    set(4, 22, "5. About", COLORS.white)
    set(4, 23, "   BIOS Manager info", COLORS.gray)
    
    -- Right Panel
    drawBorder(40, 4, 38, 18, " Help ")
    
    set(42, 6, "Boot Management:", COLORS.cyan)
    set(42, 7, "  1 - Set current device", COLORS.white)
    set(42, 8, "     as default boot", COLORS.gray)
    set(42, 10, "  2 - Clear default", COLORS.white)
    set(42, 11, "     boot setting", COLORS.gray)
    set(42, 13, "  F5 - Refresh device", COLORS.white)
    set(42, 14, "     list", COLORS.gray)
    
    set(42, 17, "Safety:", COLORS.cyan)
    set(42, 18, "  EEPROM data is", COLORS.white)
    set(42, 19, "  preserved except", COLORS.white)
    set(42, 20, "  format option", COLORS.gray)
end

local function drawMain()
    clear()
    drawTopBar()
    drawMenuTabs()
    
    if CurrentMenu == "Info" then
        drawInfoPage()
    elseif CurrentMenu == "Boot" then
        drawBootPage()
    else
        drawSettingsPage()
    end
    
    drawBottomBar()
end

local function bootDevice(index)
    local fs = filesystemList[index]
    if not fs then return end
    
    clear()
    set(30, 10, "Booting " .. fs.label .. "...", COLORS.green)
    os.sleep(0.5)
    
    local bootFile = fs.proxy.exists("/OS.lua") and "/OS.lua" or "/init.lua"
    local h = fs.proxy.open(bootFile, "rb")
    
    if not h then
        set(25, 12, "Error: Cannot open boot file!", COLORS.red)
        os.sleep(2)
        return
    end
    
    local code = ""
    repeat
        local chunk = fs.proxy.read(h, math.huge)
        code = code .. (chunk or "")
    until not chunk
    fs.proxy.close(h)
    
    computer.setBootAddress(fs.address)
    
    local func = load(code, "=" .. bootFile)
    if func then
        clear()
        pcall(func)
    else
        clear()
        set(30, 10, "Boot failed!", COLORS.red)
        os.sleep(2)
    end
end

local function formatEEPROM()
    clear()
    set(25, 10, "Formatting EEPROM...", COLORS.yellow)
    set(20, 12, "This will reset all BIOS settings!", COLORS.red)
    os.sleep(1.5)
    
    local e = component.list("eeprom")()
    if e then
        local defaultData = string.rep("-", 72) .. "en"
        component.invoke(e, "setData", defaultData)
    end
    
    set(25, 14, "EEPROM formatted!", COLORS.green)
    set(20, 16, "All settings have been reset.", COLORS.white)
    os.sleep(2)
end

local function showAbout()
    clear()
    drawBorder(15, 6, 50, 13, " About ")
    
    set(30, 8, "PixelOS BIOS Manager", COLORS.cyan)
    set(32, 9, "Version 1.0", COLORS.white)
    
    set(20, 11, "Advanced BIOS configuration tool", COLORS.gray)
    set(20, 12, "for PixelOS and OpenComputers", COLORS.gray)
    
    set(30, 15, "Based on OCBios design", COLORS.darkGray)
    set(25, 17, "Press any key to continue...", COLORS.gray)
    
    computer.pullSignal()
end

local function setBootPriority()
    if #filesystemList > 0 and filesystemList[selectedIndex] then
        local fs = filesystemList[selectedIndex]
        setPriorityAddress(fs.address)
        drawMain()
        set(40, 4, "Priority set to: " .. fs.label, COLORS.green)
        os.sleep(1)
    end
end

local function clearBootPriority()
    setPriorityAddress("")
    drawMain()
    set(40, 4, "Boot priority cleared!", COLORS.yellow)
    os.sleep(1)
end

local function changeLanguage()
    local current = getEEPROMLanguage()
    if current == "en" then
        setEEPROMLanguage("zh")
    elseif current == "zh" then
        setEEPROMLanguage("ru")
    else
        setEEPROMLanguage("en")
    end
    drawMain()
    set(40, 4, "Language changed to: " .. getEEPROMLanguage(), COLORS.green)
    os.sleep(1)
end

-- Main loop
local function main()
    if not gpu then
        for i = 1, 10 do
            computer.pullSignal(0.5)
        end
        return
    end
    
    drawMain()
    
    while true do
        local event = {computer.pullSignal()}
        
        if event[1] == "key_down" then
            local key = event[4]
            
            -- Tab switching
            if key == 37 then -- Left
                if CurrentMenu == "Boot" then CurrentMenu = "Info"
                elseif CurrentMenu == "Settings" then CurrentMenu = "Boot" end
                drawMain()
            elseif key == 39 then -- Right
                if CurrentMenu == "Info" then CurrentMenu = "Boot"
                elseif CurrentMenu == "Boot" then CurrentMenu = "Settings" end
                drawMain()
            
            -- Boot menu navigation
            elseif CurrentMenu == "Boot" then
                if key == 200 and selectedIndex > 1 then -- Up
                    selectedIndex = selectedIndex - 1
                    drawMain()
                elseif key == 208 and selectedIndex < #filesystemList then -- Down
                    selectedIndex = selectedIndex + 1
                    drawMain()
                elseif key == 28 then -- Enter
                    bootDevice(selectedIndex)
                    break
                elseif key == 63 then -- F5
                    refreshFilesystems()
                    drawMain()
                elseif key == 2 then -- 1
                    setBootPriority()
                end
            
            -- Settings menu
            elseif CurrentMenu == "Settings" then
                if key == 2 then -- 1
                    setBootPriority()
                elseif key == 3 then -- 2
                    clearBootPriority()
                elseif key == 4 then -- 3
                    formatEEPROM()
                    drawMain()
                elseif key == 5 then -- 4
                    showAbout()
                    drawMain()
                elseif key == 6 then -- 5
                    changeLanguage()
                end
            end
            
            -- Exit
            if key == 68 then -- F10
                break
            end
        end
    end
end

pcall(main)