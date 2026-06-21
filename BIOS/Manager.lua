local component = component
local computer = computer
local unicode = unicode or { len = function(s) return #s end, sub = function(s, i, j) return string.sub(s, i, j) end, len = string.len }

-- GPU initialization
local gpu = nil
local screen = nil

for address in component.list("gpu") do
    gpu = component.proxy(address)
    break
end

for address in component.list("screen") do
    screen = component.proxy(address)
    break
end

if gpu and screen then
    gpu.bind(screen)
end

local w, h = 80, 25
if gpu then
    w, h = gpu.getResolution()
    gpu.setResolution(80, 25)
end

_G._B = true

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
        end
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

local function clear()
    if gpu then
        gpu.setBackground(0x000000)
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

local function getOS(address)
    local proxy = component.proxy(address)
    if not proxy then return "Unknown" end
    if proxy.exists("/OS.lua") then
        local h = proxy.open("/OS.lua", "rb")
        if h then
            local d = proxy.read(h, 500) or ""
            proxy.close(h)
            if d:find("PixelOS") then return "PixelOS"
            elseif d:find("MineOS") then return "MineOS"
            elseif d:find("ForgeOS") then return "ForgeOS"
            else return "Custom OS" end
        end
    end
    if proxy.exists("/init.lua") then return "OpenOS" end
    return "Unknown"
end

local function getFilesystems()
    local list = {}
    for address in component.list("filesystem") do
        local proxy = component.proxy(address)
        if proxy and proxy.getLabel then
            local label = proxy.getLabel()
            if label and label ~= "tmpfs" and (proxy.exists("/OS.lua") or proxy.exists("/init.lua")) then
                table.insert(list, {a = address, p = proxy, l = label, t = getOS(address)})
            end
        end
    end
    table.sort(list, function(a, b) return a.l < b.l end)
    return list
end

local CurrentMenu = "Boot"
local selectedIndex = 1

local function drawHeader()
    set(1, 1, "", 0x000000, 0x40E0D0)
    if gpu then gpu.fill(1, 1, 80, 1, " ") end
    set(25, 1, "PixelOS BIOS Manager", 0xFFFFFF, 0x40E0D0)
    
    set(1, 2, "", 0xFFFFFF, 0x0000AF)
    if gpu then gpu.fill(1, 2, 80, 1, " ") end
    
    if CurrentMenu == "Info" then
        set(3, 2, "[ System Info ]", 0xFFFFFF, 0x0000AF)
        set(25, 2, "  Boot  ", 0xAAAAAA, 0x0000AF)
        set(43, 2, "  Settings  ", 0xAAAAAA, 0x0000AF)
    elseif CurrentMenu == "Boot" then
        set(3, 2, "  System Info  ", 0xAAAAAA, 0x0000AF)
        set(25, 2, "[ Boot ]", 0xFFFFFF, 0x0000AF)
        set(43, 2, "  Settings  ", 0xAAAAAA, 0x0000AF)
    else
        set(3, 2, "  System Info  ", 0xAAAAAA, 0x0000AF)
        set(25, 2, "  Boot  ", 0xAAAAAA, 0x0000AF)
        set(43, 2, "[ Settings ]", 0xFFFFFF, 0x0000AF)
    end
end

local function drawInfoPage()
    if gpu then gpu.fill(2, 4, 47, 19, " ") end
    
    set(15, 4, "System Information", 0x0000AF)
    
    set(4, 6, "Memory:", 0x000000)
    local tm, fm = computer.totalMemory(), computer.freeMemory()
    set(6, 7, "Total: " .. tm, 0x000000)
    set(6, 8, "Used: " .. (tm - fm), 0x000000)
    set(6, 9, "Free: " .. fm, 0x000000)
    
    set(4, 11, "Computer:", 0x000000)
    set(6, 12, "Address: " .. unicode.sub(computer.address(), 1, 18), 0x000000)
    set(6, 13, "Uptime: " .. string.format("%.1f", computer.uptime()) .. "s", 0x000000)
    set(6, 14, "Energy: " .. math.floor(computer.energy()) .. "/" .. computer.maxEnergy(), 0x000000)
    set(6, 15, "Boot: " .. unicode.sub(computer.getBootAddress() or "", 1, 18), 0x000000)
    set(6, 16, "Priority: " .. unicode.sub(getPriorityAddress(), 1, 18), 0x000000)
    
    if gpu then gpu.fill(50, 4, 30, 19, " ") end
    set(55, 8, "Use <- -> to switch tabs", 0x808080)
    set(55, 10, "F9 to save and exit", 0x808080)
end

local function drawBootPage()
    if gpu then gpu.fill(2, 4, 47, 19, " ") end
    
    set(18, 4, "Select Boot Device", 0x0000AF)
    
    local fs = getFilesystems()
    
    if selectedIndex > #fs then selectedIndex = math.max(1, #fs) end
    
    for i = 1, #fs do
        local f = fs[i]
        local txt = "[" .. unicode.sub(f.a, 1, 8) .. "] " .. f.l
        if i == selectedIndex then
            set(4, 4 + i, ">> " .. txt .. " <<", 0xFFFFFF, 0x0000AF)
        else
            set(4, 4 + i, "   " .. txt .. "   ", 0x000000)
        end
    end
    
    if #fs > 0 and fs[selectedIndex] then
        local f = fs[selectedIndex]
        if gpu then gpu.fill(50, 4, 30, 19, " ") end
        set(55, 5, "Device:", 0x0000AF)
        set(55, 6, "Name: " .. f.l, 0x000000)
        set(55, 7, "Addr: " .. unicode.sub(f.a, 1, 15), 0x000000)
        set(55, 8, "OS: " .. f.t, 0x000000)
        set(55, 9, "Space: " .. f.p.spaceTotal(), 0x000000)
        if computer.getBootAddress() == f.a then
            set(55, 11, "[*] Default", 0x00AA00)
        else
            set(55, 11, "[ ] Default", 0x000000)
        end
    end
    
    set(55, 14, "Up/Dn: Select", 0x808080)
    set(55, 15, "Enter: Boot", 0x808080)
    set(55, 16, "1: Set Default", 0x808080)
end

local function drawSettingsPage()
    if gpu then gpu.fill(2, 4, 47, 19, " ") end
    
    set(20, 4, "BIOS Settings", 0x0000AF)
    
    set(4, 6, "1. Set Boot Priority", 0x000000)
    set(4, 7, "2. Clear Priority", 0x000000)
    set(4, 8, "3. Format EEPROM", 0x000000)
    set(4, 9, "4. About", 0x000000)
    
    if gpu then gpu.fill(50, 4, 30, 19, " ") end
    set(55, 6, "Options:", 0x0000AF)
    set(55, 8, "1 - Set selected", 0x808080)
    set(55, 9, "   as boot priority", 0x808080)
    set(55, 11, "2 - Clear", 0x808080)
    set(55, 12, "   priority", 0x808080)
    set(55, 14, "3 - Format", 0x808080)
    set(55, 15, "   EEPROM", 0x808080)
end

local function drawFooter()
    set(1, 25, "", 0xFFFFFF, 0x0000AF)
    if gpu then gpu.fill(1, 25, 80, 1, " ") end
    local vt = "v1.0 PixelOS BIOS"
    set(math.floor(40 - #vt/2), 25, vt, 0xFFFFFF, 0x0000AF)
end

local function draw()
    clear()
    drawHeader()
    
    if CurrentMenu == "Info" then
        drawInfoPage()
    elseif CurrentMenu == "Boot" then
        drawBootPage()
    else
        drawSettingsPage()
    end
    
    drawFooter()
end

local function bootDevice(index)
    local fs = getFilesystems()
    local device = fs[index]
    if not device then return end
    
    setPriorityAddress(device.a)
    
    clear()
    set(1, 1, "Booting: " .. device.l, 0x00FF00)
    os.sleep(0.5)
    
    local bf = device.p.exists("/OS.lua") and "/OS.lua" or "/init.lua"
    local h = device.p.open(bf, "rb")
    if not h then
        set(1, 2, "Error: Cannot open boot file!", 0xFF0000)
        os.sleep(2)
        return
    end
    
    local code = ""
    repeat
        local ch = device.p.read(h, math.huge)
        code = code .. (ch or "")
    until not ch
    device.p.close(h)
    
    computer.setBootAddress(device.a)
    
    local f = load(code, "=" .. bf)
    if f then
        clear()
        pcall(f)
    else
        clear()
        set(1, 1, "Boot failed!", 0xFF0000)
        os.sleep(2)
    end
end

local function main()
    if not gpu then
        for i = 1, 10 do
            computer.pullSignal(0.5)
        end
        return
    end
    
    draw()
    
    while true do
        local event = {computer.pullSignal()}
        
        if event[1] == "key_down" then
            local key = event[4]
            
            if key == 37 then -- Left
                if CurrentMenu == "Boot" then CurrentMenu = "Info"
                elseif CurrentMenu == "Settings" then CurrentMenu = "Boot" end
                draw()
            elseif key == 39 then -- Right
                if CurrentMenu == "Info" then CurrentMenu = "Boot"
                elseif CurrentMenu == "Boot" then CurrentMenu = "Settings" end
                draw()
            elseif key == 200 and CurrentMenu == "Boot" then -- Up
                local fs = getFilesystems()
                if selectedIndex > 1 then
                    selectedIndex = selectedIndex - 1
                    draw()
                end
            elseif key == 208 and CurrentMenu == "Boot" then -- Down
                local fs = getFilesystems()
                if selectedIndex < #fs then
                    selectedIndex = selectedIndex + 1
                    draw()
                end
            elseif key == 28 and CurrentMenu == "Boot" then -- Enter
                bootDevice(selectedIndex)
                break
            elseif key == 2 then -- 1
                if CurrentMenu == "Boot" then
                    local fs = getFilesystems()
                    if fs[selectedIndex] then
                        setPriorityAddress(fs[selectedIndex].a)
                        draw()
                        set(55, 14, "Set as default!", 0x00FF00)
                    end
                end
            elseif key == 3 and CurrentMenu == "Settings" then -- 2
                setPriorityAddress("")
                draw()
                set(55, 14, "Priority cleared!", 0xFFFF00)
            elseif key == 67 or key == 79 then -- F9 or O
                break
            end
        end
    end
end

pcall(main)