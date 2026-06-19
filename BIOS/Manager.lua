-- ============================================================
-- Advanced BIOS Manager for PixelOS
-- Based on OCBios design
-- ============================================================

local component = component
local computer = computer
local unicode = unicode
if not unicode then
    pcall(function() unicode = require("unicode") end)
end
if type(unicode) ~= "table" then
    unicode = { len = function(s) return #s end, sub = function(s, i, j) return string.sub(s, i, j) end }
end

-- Component proxies
local gpu, screen
local gpuAddr = component.list("gpu")()
local screenAddr = component.list("screen")()
if gpuAddr then
    gpu = component.proxy(gpuAddr)
    if screenAddr then
        gpu.bind(screenAddr)
    end
end
local w, h = gpu and gpu.getResolution() or 80, 25

-- Constants
local EXIT_KEY = 14
local VERSION = "1.0"

-- Colors
local COLORS = {
    background = 0xCDCDCF,
    title = 0x0000AF,
    text = 0x000000,
    white = 0xFFFFFF,
    highlight = 0x40E0D0,
    hint = 0x808080
}

-- Menu states
local CurrentMenu = "Boot"
local BootMenuStage = {1, 0}
local selectedScreen = 1

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
            local newData = address .. string.sub(data, 37)
            component.invoke(e, "setData", newData)
            return true
        end
    end
    return false
end

local function getPriorityBootAddress()
    local e = component.list("eeprom")()
    if e then
        local data = component.invoke(e, "getData") or ""
        return string.sub(data, 37, 72)
    end
    return ""
end

local function setPriorityBootAddress(address)
    local e = component.list("eeprom")()
    if e then
        local data = component.invoke(e, "getData") or ""
        local newData = string.sub(data, 1, 36) .. address .. string.sub(data, 73)
        component.invoke(e, "setData", newData)
    end
end

local function getLanguage()
    local e = component.list("eeprom")()
    if e then
        local data = component.invoke(e, "getData") or ""
        return string.sub(data, 73, 74)
    end
    return "en"
end

-- Graphics functions
local function setBackground(c)
    gpu.setBackground(c)
end

local function setForeground(c)
    gpu.setForeground(c)
end

local function fill(x, y, w, h, char)
    gpu.fill(x, y, char, w, h)
end

local function set(x, y, text)
    gpu.set(x, y, text)
end

local function setResolution(w, h)
    gpu.setResolution(w, h)
end

local function clearScreen()
    local w, h = gpu.getResolution()
    gpu.fill(1, 1, w, h, " ")
end

local function drawBox()
    local w, h = gpu.getResolution()
    gpu.setResolution(74, 25)
    w, h = 74, 25
    
    setBackground(COLORS.background)
    fill(1, 1, 74, 25, " ")
    
    -- Main border
    set(1, 3, "=")
    fill(2, 3, 72, 1, "=")
    set(74, 3, "=")
    
    fill(1, 4, 1, 20, "|")
    fill(74, 4, 1, 20, "|")
    
    fill(2, 24, 72, 1, "=")
    set(1, 24, "=")
    set(74, 24, "=")
    
    -- Separator
    set(49, 3, "+")
    fill(49, 4, 1, 20, "|")
    set(49, 24, "=")
    
    set(1, 5, "-")
    fill(2, 5, 47, 1, "-")
    set(49, 5, "+")
    
    -- Title bar
    setBackground(COLORS.highlight)
    fill(1, 1, 74, 1, " ")
    set(22, 1, "Advanced BIOS Manager")
    setBackground(COLORS.title)
    fill(1, 2, 74, 1, " ")
    
    -- Menu tabs
    setForeground(COLORS.white)
    set(3, 2, " System Information ")
    set(25, 2, " Boot or Repair ")
    set(43, 2, " BIOS Settings ")
    
    -- Status bar
    setBackground(COLORS.title)
    fill(1, 25, 74, 1, " ")
    setForeground(COLORS.white)
    local versionText = "v" .. VERSION .. " PixelOS BIOS"
    set(math.floor(37 - #versionText/2), 25, versionText)
    
    return w, h
end

local function getOS(address)
    local proxy = component.proxy(address)
    if not proxy then return "Unknown" end
    
    if proxy.exists("/OS.lua") then
        local handle = proxy.open("/OS.lua", "rb")
        if handle then
            local data = proxy.read(handle, 500) or ""
            proxy.close(handle)
            
            if data:find("PixelOS") then return "PixelOS"
            elseif data:find("MineOS") then return "MineOS"
            elseif data:find("ForgeOS") then return "ForgeOS"
            else return "Custom OS" end
        end
    end
    
    if proxy.exists("/init.lua") then
        return "OpenOS"
    end
    
    return "Unknown"
end

local function getFilesystems()
    local filesystems = {}
    for address in component.list("filesystem") do
        local proxy = component.proxy(address)
        if proxy and proxy.getLabel then
            local label = proxy.getLabel()
            if label and label ~= "tmpfs" then
                local hasOS = proxy.exists("/OS.lua")
                local hasInit = proxy.exists("/init.lua")
                local ready = hasOS or hasInit
                
                if string.len(label) > 12 then
                    label = unicode.sub(label, 1, 10) .. ".."
                end
                
                table.insert(filesystems, {
                    proxy = proxy,
                    label = label,
                    address = address,
                    ready = ready,
                    os = getOS(address)
                })
            end
        end
    end
    
    table.sort(filesystems, function(a, b)
        return a.label < b.label
    end)
    
    return filesystems
end

local function clearMainArea()
    fill(2, 6, 47, 18, " ")
end

local function clearSidePanel()
    fill(50, 4, 24, 20, " ")
end

local function drawSystemInfoPage()
    clearMainArea()
    clearSidePanel()
    
    setForeground(COLORS.title)
    local title = "System Information"
    set(math.floor(25 - #title/2), 4, title)
    
    local totalMem = computer.totalMemory()
    local freeMem = computer.freeMemory()
    local uptime = computer.uptime()
    
    setForeground(COLORS.text)
    set(4, 6, "Memory Information:")
    set(6, 7, "Total memory: " .. totalMem)
    set(6, 8, "Used memory: " .. (totalMem - freeMem))
    set(6, 9, "Free memory: " .. freeMem)
    
    set(4, 11, "Computer Information:")
    set(6, 12, "Address: " .. unicode.sub(computer.address(), 1, 18))
    set(6, 13, "Uptime: " .. string.format("%.1f", uptime) .. "s")
    set(6, 14, "Max energy: " .. computer.maxEnergy())
    set(6, 15, "Energy: " .. math.floor(computer.energy()))
    set(6, 16, "Boot addr: " .. unicode.sub(computer.getBootAddress() or "", 1, 18))
    set(6, 17, "Priority addr: " .. unicode.sub(getPriorityBootAddress(), 1, 18))
    
    set(50, 20, "<->    Select Screen")
    set(50, 21, "F9    Save and Exit")
end

local function drawBootPage()
    clearMainArea()
    clearSidePanel()
    
    setForeground(COLORS.title)
    local title = "Select Device to Boot"
    set(math.floor(25 - #title/2), 4, title)
    
    local filesystems = getFilesystems()
    BootMenuStage[2] = #filesystems
    
    if BootMenuStage[1] > #filesystems then
        BootMenuStage[1] = math.max(1, #filesystems)
    end
    
    for i = 1, #filesystems do
        local fs = filesystems[i]
        local itemText = string.format("[%s] %s", unicode.sub(fs.address, 1, 8), fs.label)
        if fs.ready then
            itemText = itemText .. " [Ready]"
        else
            itemText = itemText .. " [Not Ready]"
        end
        
        if i == BootMenuStage[1] then
            setForeground(COLORS.white)
            set(4, 5 + i, ">>" .. itemText)
            setForeground(COLORS.text)
        else
            set(4, 5 + i, "  " .. itemText)
        end
    end
    
    if #filesystems > 0 then
        local fs = filesystems[BootMenuStage[1]]
        set(50, 4, "Hard Drive Details:")
        set(51, 6, "Address: " .. unicode.sub(fs.address, 1, 13))
        set(51, 7, "Name: " .. unicode.sub(fs.label, 1, 15))
        set(51, 8, "Ready: " .. (fs.ready and "YES" or "NO"))
        set(51, 9, "OS: " .. fs.os)
        set(51, 10, "Total: " .. fs.proxy.spaceTotal())
        set(51, 11, "Used: " .. fs.proxy.spaceUsed())
        set(51, 12, "Free: " .. (fs.proxy.spaceTotal() - fs.proxy.spaceUsed()))
        
        local bootAddr = computer.getBootAddress()
        if bootAddr == fs.address then
            set(51, 14, "[*] Default Boot")
        else
            set(51, 14, "[ ] Default Boot")
        end
    else
        set(50, 6, "No bootable devices")
        set(50, 7, "found.")
    end
    
    set(50, 18, "<->    Select Screen")
    set(50, 19, "Up/Dn  Select Item")
    set(50, 20, "Enter   Boot/Select")
    set(50, 21, "F5     Refresh List")
    set(50, 22, "F9     Save and Exit")
end

local function drawSettingsPage()
    clearMainArea()
    clearSidePanel()
    
    setForeground(COLORS.title)
    local title = "BIOS Settings"
    set(math.floor(25 - #title/2), 4, title)
    
    setForeground(COLORS.text)
    set(4, 6, "1. Set Boot Priority")
    set(4, 7, "2. Clear Boot Priority")
    set(4, 8, "3. Format EEPROM Data")
    set(4, 9, "4. About")
    
    local currentLang = getLanguage()
    set(4, 12, "Current Language: " .. currentLang)
    
    set(50, 4, "Options:")
    set(50, 6, "1 - Set selected device")
    set(50, 7, "   as boot priority")
    set(50, 9, "2 - Clear boot priority")
    set(50, 10, "   (use last boot)")
    set(50, 12, "3 - Reset all BIOS")
    set(50, 13, "   settings to default")
    set(50, 15, "4 - Show BIOS info")
    
    set(50, 18, "<->    Select Screen")
    set(50, 21, "1-4    Select Option")
    set(50, 22, "F9     Save and Exit")
end

local function bootFromDevice(index)
    local filesystems = getFilesystems()
    local device = filesystems[index]
    
    if not device then return end
    
    -- Save as boot priority
    setPriorityBootAddress(device.address)
    
    -- Clear screen and show booting message
    setBackground(0x000000)
    fill(1, 1, 80, 25, " ")
    
    setForeground(0x00FF00)
    set(1, 1, "Booting from: " .. device.label)
    set(1, 2, "Address: " .. device.address)
    set(1, 3, "OS: " .. device.os)
    set(1, 4, "")
    set(1, 5, "Loading...")
    
    os.sleep(0.5)
    
    -- Load and execute boot file
    local bootFile = device.proxy.exists("/OS.lua") and "/OS.lua" or "/init.lua"
    local handle = device.proxy.open(bootFile, "rb")
    
    if not handle then
        setForeground(0xFF0000)
        set(1, 6, "ERROR: Cannot open boot file!")
        os.sleep(3)
        return
    end
    
    local bootCode = ""
    repeat
        local chunk = device.proxy.read(handle, math.huge)
        bootCode = bootCode .. (chunk or "")
    until not chunk
    device.proxy.close(handle)
    
    computer.setBootAddress(device.address)
    
    local bootFunc = load(bootCode, "=" .. bootFile)
    if bootFunc then
        setBackground(0x000000)
        fill(1, 1, 80, 25, " ")
        pcall(bootFunc)
    else
        setForeground(0xFF0000)
        set(1, 6, "ERROR: Failed to load boot code!")
        os.sleep(3)
    end
end

local function formatEEPROM()
    setBackground(0x000000)
    fill(1, 1, 80, 25, " ")
    setForeground(0xFFFF00)
    set(1, 12, "Formatting EEPROM...")
    os.sleep(1)
    
    local e = component.list("eeprom")()
    if e then
        local defaultData = string.rep("-", 72) .. "en"
        component.invoke(e, "setData", defaultData)
    end
    
    setForeground(0x00FF00)
    set(1, 14, "EEPROM formatted successfully!")
    set(1, 15, "Press any key to continue...")
    computer.pullSignal()
end

local function showAbout()
    setBackground(0x000000)
    fill(1, 1, 80, 25, " ")
    setForeground(0x00FFFF)
    set(1, 10, "========================================")
    set(1, 11, "       PixelOS Advanced BIOS Manager")
    set(1, 12, "              Version " .. VERSION)
    set(1, 13, "========================================")
    setForeground(0xAAAAAA)
    set(1, 15, "Based on OCBios design")
    set(1, 16, "Enhanced for PixelOS compatibility")
    setForeground(0xFFFFFF)
    set(1, 18, "Press any key to continue...")
    computer.pullSignal()
end

local function passwordInput()
    local password = ""
    local cursorPos = 1
    
    while true do
        setBackground(0x000000)
        fill(1, 10, 80, 10, " ")
        
        setForeground(0xFFFF00)
        set(1, 12, "Enter BIOS Password:")
        
        setForeground(0xFFFFFF)
        local display = ""
        for i = 1, #password do
            display = display .. "*"
        end
        set(1, 14, display .. "_")
        
        local event = {computer.pullSignal()}
        
        if event[1] == "key_down" then
            local key = event[4]
            
            if key == 28 then
                return password
            elseif key == 14 then
                if #password > 0 then
                    password = string.sub(password, 1, -2)
                end
            elseif key >= 2 and key <= 126 then
                password = password .. string.char(key)
            end
        end
    end
end

local function main()
    -- Initialize
    if gpu and screen then
        setResolution(74, 25)
    end
    
    local w, h = drawBox()
    
    -- Default to boot page
    CurrentMenu = "Boot"
    BootMenuStage[1] = 1
    
    local filesystems = {}
    
    while true do
        -- Draw selected page
        if CurrentMenu == "Info" then
            drawSystemInfoPage()
        elseif CurrentMenu == "Boot" then
            drawBootPage()
        elseif CurrentMenu == "Settings" then
            drawSettingsPage()
        end
        
        -- Highlight selected tab
        setForeground(COLORS.white)
        if CurrentMenu == "Info" then
            setBackground(COLORS.title)
            set(3, 2, "> System Information <")
            set(25, 2, " Boot or Repair ")
            set(43, 2, " BIOS Settings ")
        elseif CurrentMenu == "Boot" then
            set(3, 2, " System Information ")
            setBackground(COLORS.title)
            set(25, 2, "> Boot or Repair <")
            set(43, 2, " BIOS Settings ")
        else
            set(3, 2, " System Information ")
            set(25, 2, " Boot or Repair ")
            setBackground(COLORS.title)
            set(43, 2, "> BIOS Settings <")
        end
        
        local event = {computer.pullSignal()}
        
        if event[1] == "key_down" then
            local key = event[4]
            
            -- Tab navigation
            if key == 37 then -- Left arrow
                if CurrentMenu == "Boot" then CurrentMenu = "Info"
                elseif CurrentMenu == "Settings" then CurrentMenu = "Boot"
                end
            elseif key == 39 then -- Right arrow
                if CurrentMenu == "Info" then CurrentMenu = "Boot"
                elseif CurrentMenu == "Boot" then CurrentMenu = "Settings"
                end
            
            -- Boot page navigation
            elseif CurrentMenu == "Boot" then
                if key == 200 and BootMenuStage[1] > 1 then -- Up
                    BootMenuStage[1] = BootMenuStage[1] - 1
                elseif key == 208 and BootMenuStage[1] < BootMenuStage[2] then -- Down
                    BootMenuStage[1] = BootMenuStage[1] + 1
                elseif key == 28 then -- Enter
                    bootFromDevice(BootMenuStage[1])
                    break
                elseif key == 63 then -- F5
                    filesystems = getFilesystems()
                    BootMenuStage[1] = 1
                end
            
            -- Settings page
            elseif CurrentMenu == "Settings" then
                filesystems = getFilesystems()
                if key == 2 then -- 1
                    if BootMenuStage[2] > 0 then
                        local selected = BootMenuStage[1] or 1
                        if filesystems[selected] then
                            setPriorityBootAddress(filesystems[selected].address)
                            clearSidePanel()
                            setForeground(0x00FF00)
                            set(50, 4, "Boot priority set!")
                            set(50, 5, filesystems[selected].label)
                            os.sleep(1)
                        end
                    end
                elseif key == 3 then -- 2
                    setPriorityBootAddress("")
                    clearSidePanel()
                    setForeground(0xFFFF00)
                    set(50, 4, "Boot priority cleared!")
                    os.sleep(1)
                elseif key == 4 then -- 3
                    formatEEPROM()
                    drawBox()
                elseif key == 5 then -- 4
                    showAbout()
                    drawBox()
                end
            end
            
            -- Exit
            if key == 67 or (key == 79 and event[3] == true) then -- F9 or Shift+O
                break
            end
        end
    end
    
    if _G._B then
        return
    end
    
    computer.shutdown(false)
end

_G._B = true
pcall(main)