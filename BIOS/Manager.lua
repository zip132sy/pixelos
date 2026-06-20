local component = component
local computer = computer
local unicode = unicode or { len = function(s) return #s end, sub = function(s, i, j) return string.sub(s, i, j) end }

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

local VERSION = "1.0"

local COLORS = {
    bg = 0xCDCDCF,
    title = 0x0000AF,
    text = 0x000000,
    white = 0xFFFFFF,
    highlight = 0x40E0D0,
    hint = 0x808080,
    red = 0xFF0000,
    green = 0x00FF00,
    yellow = 0xFFFF00
}

local CurrentMenu = "Boot"
local BootMenuStage = {1, 0}

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

local function setBg(c) gpu.setBackground(c) end
local function setFg(c) gpu.setForeground(c) end
local function fill(x, y, w, h, char) gpu.fill(x, y, char, w, h) end
local function set(x, y, text) gpu.set(x, y, text) end
local function setRes(w, h) gpu.setResolution(w, h) end
local function clearScreen() local w,h = gpu.getResolution() fill(1,1,w,h," ") end

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
    if proxy.exists("/init.lua") then return "OpenOS" end
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
                if string.len(label) > 12 then label = unicode.sub(label, 1, 10) .. ".." end
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
    table.sort(filesystems, function(a, b) return a.label < b.label end)
    return filesystems
end

local function drawBox()
    local cw, ch = gpu.getResolution()
    setRes(74, 25)
    cw, ch = 74, 25
    
    setBg(COLORS.bg)
    fill(1, 1, cw, ch, " ")
    
    set(1, 3, "=")
    fill(2, 3, cw - 2, 1, "=")
    set(cw, 3, "=")
    
    fill(1, 4, 1, ch - 3, "|")
    fill(cw, 4, 1, ch - 3, "|")
    
    fill(2, ch, cw - 2, 1, "=")
    set(1, ch, "=")
    set(cw, ch, "=")
    
    set(49, 3, "+")
    fill(49, 4, 1, ch - 3, "|")
    set(49, ch, "=")
    
    set(1, 5, "-")
    fill(2, 5, 47, 1, "-")
    set(49, 5, "+")
    
    setBg(COLORS.highlight)
    fill(1, 1, cw, 1, " ")
    set(22, 1, "Advanced BIOS Manager")
    
    setBg(COLORS.title)
    fill(1, 2, cw, 1, " ")
    
    setFg(COLORS.white)
    set(3, 2, " System Info ")
    set(25, 2, " Boot ")
    set(43, 2, " Settings ")
    
    setBg(COLORS.title)
    fill(1, ch, cw, 1, " ")
    setFg(COLORS.white)
    local vt = "v" .. VERSION .. " PixelOS"
    set(math.floor(37 - #vt/2), ch, vt)
    
    return cw, ch
end

local function drawInfoPage()
    setBg(COLORS.bg)
    fill(2, 6, 47, 18, " ")
    fill(50, 4, 24, 20, " ")
    
    setFg(COLORS.title)
    set(15, 4, "System Information")
    
    setFg(COLORS.text)
    set(4, 6, "Memory:")
    local tm, fm = computer.totalMemory(), computer.freeMemory()
    set(6, 7, "Total: " .. tm)
    set(6, 8, "Used: " .. (tm - fm))
    set(6, 9, "Free: " .. fm)
    
    set(4, 11, "Computer:")
    set(6, 12, "Addr: " .. unicode.sub(computer.address(), 1, 18))
    set(6, 13, "Uptime: " .. string.format("%.1f", computer.uptime()) .. "s")
    set(6, 14, "Energy: " .. math.floor(computer.energy()) .. "/" .. computer.maxEnergy())
    set(6, 15, "Boot: " .. unicode.sub(computer.getBootAddress() or "", 1, 18))
    set(6, 16, "Priority: " .. unicode.sub(getPriorityBootAddress(), 1, 18))
    
    set(50, 20, "<-> Tab")
    set(50, 21, "F9 Exit")
end

local function drawBootPage()
    setBg(COLORS.bg)
    fill(2, 6, 47, 18, " ")
    fill(50, 4, 24, 20, " ")
    
    setFg(COLORS.title)
    set(18, 4, "Select Boot Device")
    
    local fs = getFilesystems()
    BootMenuStage[2] = #fs
    
    if BootMenuStage[1] > #fs then BootMenuStage[1] = math.max(1, #fs) end
    
    for i = 1, #fs do
        local f = fs[i]
        local txt = string.format("[%s] %s", unicode.sub(f.address, 1, 8), f.label)
        if f.ready then txt = txt .. " [Ready]" else txt = txt .. " [No]" end
        
        if i == BootMenuStage[1] then
            setFg(COLORS.white)
            setBg(COLORS.title)
            fill(2, 5 + i, 47, 1, " ")
            set(4, 5 + i, ">>" .. txt)
            setBg(COLORS.bg)
            setFg(COLORS.text)
        else
            set(4, 5 + i, "  " .. txt)
        end
    end
    
    if #fs > 0 then
        local f = fs[BootMenuStage[1]]
        set(50, 4, "Details:")
        set(51, 6, "Addr: " .. unicode.sub(f.address, 1, 13))
        set(51, 7, "Name: " .. f.label)
        set(51, 8, "Ready: " .. (f.ready and "YES" or "NO"))
        set(51, 9, "OS: " .. f.os)
        set(51, 10, "Total: " .. f.proxy.spaceTotal())
        set(51, 11, "Used: " .. f.proxy.spaceUsed())
        set(51, 12, "Free: " .. (f.proxy.spaceTotal() - f.proxy.spaceUsed()))
        if computer.getBootAddress() == f.address then
            set(51, 14, "[*] Default")
        else
            set(51, 14, "[ ] Default")
        end
    else
        set(50, 6, "No devices")
    end
    
    set(50, 18, "<-> Tab")
    set(50, 19, "Up/Dn Select")
    set(50, 20, "Enter Boot")
    set(50, 21, "F5 Refresh")
    set(50, 22, "F9 Exit")
end

local function drawSettingsPage()
    setBg(COLORS.bg)
    fill(2, 6, 47, 18, " ")
    fill(50, 4, 24, 20, " ")
    
    setFg(COLORS.title)
    set(20, 4, "BIOS Settings")
    
    setFg(COLORS.text)
    set(4, 6, "1. Set Boot Priority")
    set(4, 7, "2. Clear Priority")
    set(4, 8, "3. Format EEPROM")
    set(4, 9, "4. About")
    
    set(50, 4, "Options:")
    set(50, 6, "1 - Set device")
    set(50, 7, "   as priority")
    set(50, 9, "2 - Clear")
    set(50, 10, "   priority")
    set(50, 12, "3 - Format")
    set(50, 13, "   EEPROM")
    set(50, 15, "4 - About")
    
    set(50, 18, "<-> Tab")
    set(50, 21, "1-4 Select")
    set(50, 22, "F9 Exit")
end

local function bootDevice(index)
    local fs = getFilesystems()
    local device = fs[index]
    if not device then return end
    
    setPriorityBootAddress(device.address)
    
    setBg(0x000000)
    fill(1, 1, 80, 25, " ")
    
    setFg(COLORS.green)
    set(1, 1, "Booting from: " .. device.label)
    set(1, 2, "Address: " .. device.address)
    set(1, 3, "OS: " .. device.os)
    set(1, 5, "Loading...")
    
    os.sleep(0.5)
    
    local bf = device.proxy.exists("/OS.lua") and "/OS.lua" or "/init.lua"
    local handle = device.proxy.open(bf, "rb")
    
    if not handle then
        setFg(COLORS.red)
        set(1, 6, "ERROR: Cannot open boot file!")
        os.sleep(3)
        return
    end
    
    local code = ""
    repeat
        local ch = device.proxy.read(handle, math.huge)
        code = code .. (ch or "")
    until not ch
    device.proxy.close(handle)
    
    computer.setBootAddress(device.address)
    
    local f = load(code, "=" .. bf)
    if f then
        setBg(0x000000)
        fill(1, 1, 80, 25, " ")
        pcall(f)
    else
        setFg(COLORS.red)
        set(1, 6, "ERROR: Failed to load!")
        os.sleep(3)
    end
end

local function formatEEPROM()
    setBg(0x000000)
    fill(1, 1, 80, 25, " ")
    setFg(COLORS.yellow)
    set(1, 12, "Formatting EEPROM...")
    os.sleep(1)
    
    local e = component.list("eeprom")()
    if e then
        local def = string.rep("-", 72) .. "en"
        component.invoke(e, "setData", def)
    end
    
    setFg(COLORS.green)
    set(1, 14, "Formatted successfully!")
    set(1, 15, "Press any key...")
    computer.pullSignal()
end

local function showAbout()
    setBg(0x000000)
    fill(1, 1, 80, 25, " ")
    setFg(COLORS.white)
    set(1, 10, "========================================")
    set(1, 11, "       PixelOS BIOS Manager v" .. VERSION)
    set(1, 12, "========================================")
    set(1, 14, "Based on OCBios design")
    set(1, 15, "Enhanced for PixelOS")
    set(1, 17, "Press any key...")
    computer.pullSignal()
end

local function main()
    if not gpu then return end
    
    local cw, ch = drawBox()
    CurrentMenu = "Boot"
    BootMenuStage[1] = 1
    
    while true do
        if CurrentMenu == "Info" then
            drawInfoPage()
        elseif CurrentMenu == "Boot" then
            drawBootPage()
        elseif CurrentMenu == "Settings" then
            drawSettingsPage()
        end
        
        setFg(COLORS.white)
        if CurrentMenu == "Info" then
            setBg(COLORS.title)
            set(3, 2, "> Info <")
            setBg(COLORS.title)
            set(25, 2, " Boot ")
            set(43, 2, " Settings ")
        elseif CurrentMenu == "Boot" then
            set(3, 2, " Info ")
            setBg(COLORS.title)
            set(25, 2, "> Boot <")
            set(43, 2, " Settings ")
        else
            set(3, 2, " Info ")
            set(25, 2, " Boot ")
            setBg(COLORS.title)
            set(43, 2, "> Settings <")
        end
        setBg(COLORS.bg)
        setFg(COLORS.text)
        
        local evt = {computer.pullSignal()}
        
        if evt[1] == "key_down" then
            local key = evt[4]
            
            if key == 37 then
                if CurrentMenu == "Boot" then CurrentMenu = "Info"
                elseif CurrentMenu == "Settings" then CurrentMenu = "Boot" end
            elseif key == 39 then
                if CurrentMenu == "Info" then CurrentMenu = "Boot"
                elseif CurrentMenu == "Boot" then CurrentMenu = "Settings" end
            
            elseif CurrentMenu == "Boot" then
                if key == 200 and BootMenuStage[1] > 1 then
                    BootMenuStage[1] = BootMenuStage[1] - 1
                elseif key == 208 and BootMenuStage[1] < BootMenuStage[2] then
                    BootMenuStage[1] = BootMenuStage[1] + 1
                elseif key == 28 then
                    bootDevice(BootMenuStage[1])
                    break
                elseif key == 63 then
                    BootMenuStage[1] = 1
                end
            
            elseif CurrentMenu == "Settings" then
                local fs = getFilesystems()
                if key == 2 then
                    if fs[BootMenuStage[1]] then
                        setPriorityBootAddress(fs[BootMenuStage[1]].address)
                        setFg(COLORS.green)
                        set(50, 4, "Set!")
                        os.sleep(1)
                    end
                elseif key == 3 then
                    setPriorityBootAddress("")
                    setFg(COLORS.yellow)
                    set(50, 4, "Cleared!")
                    os.sleep(1)
                elseif key == 4 then
                    formatEEPROM()
                    drawBox()
                elseif key == 5 then
                    showAbout()
                    drawBox()
                end
            end
            
            if key == 67 or (key == 79 and evt[3] == true) then
                break
            end
        end
    end
    
    if _G._B then return end
    computer.shutdown(false)
end

_G._B = true
pcall(main)