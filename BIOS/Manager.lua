-- ============================================================
-- PixelOS Advanced BIOS Manager
-- Unique style with full features + Encryption
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

-- ============================================================
-- Encryption Functions
-- ============================================================
local function hashPassword(password)
    local hash = 0
    for i = 1, #password do
        hash = (hash * 31 + string.byte(password, i)) % 2147483647
    end
    return string.format("%08X", hash)
end

local function getStoredPasswordHash()
    local e = component.list("eeprom")()
    if e then
        local data = component.invoke(e, "getData") or ""
        return string.sub(data, 75, 82) or ""
    end
    return ""
end

local function setStoredPasswordHash(hash)
    local e = component.list("eeprom")()
    if e then
        local data = component.invoke(e, "getData") or ""
        local newData = string.sub(data, 1, 74) .. hash .. string.sub(data, 83)
        component.invoke(e, "setData", newData)
    end
end

local function isBIOSPasswordSet()
    return getStoredPasswordHash() ~= ""
end

local function checkDiskEncryption(address)
    local proxy = component.proxy(address)
    if proxy and proxy.exists then
        return proxy.exists("/.encrypted")
    end
    return false
end

local function getStoredDiskPassword(address)
    local proxy = component.proxy(address)
    if proxy and proxy.exists and proxy.exists("/.epassword") then
        local h = proxy.open("/.epassword", "rb")
        if h then
            local data = proxy.read(h, 32) or ""
            proxy.close(h)
            return data
        end
    end
    return ""
end

-- ============================================================
-- EEPROM Functions
-- ============================================================
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

-- ============================================================
-- Colors - PixelOS Theme
-- ============================================================
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
    cyan = 0x9CDCFE,
    purple = 0xC586C0
}

-- State
local CurrentMenu = "Boot"
local selectedIndex = 1
local filesystemList = {}
local passwordAttempts = 0
local maxPasswordAttempts = 3

-- ============================================================
-- Graphics Functions
-- ============================================================
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
                    local isEncrypted = checkDiskEncryption(address)
                    table.insert(filesystemList, {
                        address = address,
                        proxy = proxy,
                        label = label,
                        os = getOSName(address),
                        ready = hasOS or hasInit,
                        isDefault = address == computer.getBootAddress(),
                        encrypted = isEncrypted
                    })
                end
            end
        end
    end
    table.sort(filesystemList, function(a, b) return a.l < b.l end)
end

local function drawTopBar()
    fill(1, 1, 80, 1, " ", COLORS.title)
    local title = "[ PixelOS BIOS ] Advanced Manager"
    set(2, 1, title, COLORS.white, COLORS.title)
    
    -- Password status indicator
    if isBIOSPasswordSet() then
        set(68, 1, "[PWD]", COLORS.purple, COLORS.title)
    end
    
    set(71, 1, "F10:Exit", COLORS.darkGray, COLORS.title)
end

local function drawBottomBar()
    fill(1, 25, 80, 1, " ", COLORS.panel)
    local info = "v1.0 | Boot: " .. (computer.getBootAddress() and unicode.sub(computer.getBootAddress(), 1, 8) or "N/A")
    set(2, 25, info, COLORS.darkGray, COLORS.panel)
    
    if CurrentMenu == "Boot" then
        set(40, 25, "Arrows:Select | Enter:Boot | 1:SetDefault | F5:Refresh", COLORS.gray, COLORS.panel)
    elseif CurrentMenu == "Settings" then
        set(40, 25, "1:SetPriority | 2:Clear | 3:Format | 4:Password | 5:Encrypt", COLORS.gray, COLORS.panel)
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
    
    drawBorder(2, 4, 36, 20, " System Information ")
    
    local memTotal = computer.totalMemory()
    local memFree = computer.freeMemory()
    local memUsed = memTotal - memFree
    local memPercent = math.floor(memUsed / memTotal * 100)
    
    set(4, 6, "Memory", COLORS.cyan)
    set(4, 7, "  Total: " .. memTotal .. " KB", COLORS.white)
    set(4, 8, "  Used:  " .. memUsed .. " KB (" .. memPercent .. "%)", COLORS.white)
    set(4, 9, "  Free:  " .. memFree .. " KB", COLORS.green)
    
    fill(4, 10, 32, 1, " ", COLORS.border)
    fill(4, 10, math.floor(32 * memPercent / 100), 1, " ", COLORS.title)
    
    set(4, 12, "Computer", COLORS.cyan)
    set(4, 13, "  Address: " .. unicode.sub(computer.address(), 1, 20), COLORS.white)
    set(4, 14, "  Uptime: " .. string.format("%.1f", computer.uptime()) .. "s", COLORS.white)
    
    local energy = computer.energy()
    local maxEnergy = computer.maxEnergy()
    local energyPercent = math.floor(energy / maxEnergy * 100)
    set(4, 15, "  Energy: " .. math.floor(energy) .. "/" .. maxEnergy, COLORS.white)
    
    fill(4, 16, 32, 1, " ", COLORS.border)
    fill(4, 16, math.floor(32 * energyPercent / 100), 1, " ", COLORS.green)
    
    set(4, 18, "Boot Configuration", COLORS.cyan)
    set(4, 19, "  Boot: " .. (computer.getBootAddress() and unicode.sub(computer.getBootAddress(), 1, 18) or "N/A"), COLORS.yellow)
    set(4, 20, "  Priority: " .. (getPriorityAddress() ~= "" and unicode.sub(getPriorityAddress(), 1, 18) or "None"), COLORS.yellow)
    
    drawBorder(40, 4, 38, 10, " Quick Boot ")
    
    set(42, 6, "Detected " .. #filesystemList .. " device(s)", COLORS.white)
    
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
    
    drawBorder(40, 16, 38, 8, " Security ")
    
    if isBIOSPasswordSet() then
        set(42, 18, "BIOS Password: [Set]", COLORS.green)
    else
        set(42, 18, "BIOS Password: [Not Set]", COLORS.yellow)
    end
    
    local encCount = 0
    for _, fs in ipairs(filesystemList) do
        if fs.encrypted then encCount = encCount + 1 end
    end
    if encCount > 0 then
        set(42, 19, "Encrypted Disks: " .. encCount, COLORS.purple)
    else
        set(42, 19, "Encrypted Disks: 0", COLORS.gray)
    end
end

local function drawBootPage()
    refreshFilesystems()
    
    if selectedIndex > #filesystemList then
        selectedIndex = math.max(1, #filesystemList)
    end
    
    drawBorder(2, 4, 50, 18, " Boot Device List ")
    
    if #filesystemList == 0 then
        set(15, 13, "No bootable devices found!", COLORS.red)
        set(10, 15, "Press F5 to refresh or install an OS", COLORS.darkGray)
    else
        for i = 1, math.min(#filesystemList, 14) do
            local fs = filesystemList[i]
            local y = 6 + i
            
            if y <= 19 then
                local displayLabel = fs.label
                if fs.encrypted then
                    displayLabel = displayLabel .. " [Encrypted]"
                end
                
                if i == selectedIndex then
                    fill(3, y, 48, 1, " ", COLORS.highlight)
                    set(4, y, ">" .. displayLabel, COLORS.white, COLORS.highlight)
                    if fs.isDefault then
                        set(36, y, "[*]", COLORS.green, COLORS.highlight)
                    else
                        set(36, y, "[ ]", COLORS.gray, COLORS.highlight)
                    end
                else
                    fill(3, y, 48, 1, " ", COLORS.bg)
                    if fs.encrypted then
                        set(4, y, " " .. displayLabel, COLORS.purple)
                    else
                        set(4, y, " " .. displayLabel, COLORS.gray)
                    end
                    if fs.isDefault then
                        set(36, y, "[*]", COLORS.green)
                    else
                        set(36, y, "[ ]", COLORS.darkGray)
                    end
                end
            end
        end
    end
    
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
        
        set(56, 18, "Encryption:", COLORS.cyan)
        if fs.encrypted then
            set(56, 19, "  [Encrypted]", COLORS.purple)
        else
            set(56, 19, "  [Not Encrypted]", COLORS.gray)
        end
        
        set(56, 21, "Default:", COLORS.cyan)
        if fs.isDefault then
            set(56, 22, "  Yes", COLORS.green)
        else
            set(56, 22, "  No", COLORS.darkGray)
        end
    else
        set(56, 12, "No device", COLORS.darkGray)
        set(56, 13, "selected", COLORS.darkGray)
    end
end

local function drawSettingsPage()
    drawBorder(2, 4, 36, 20, " BIOS Settings ")
    
    set(4, 6, "1. Set Boot Priority", COLORS.white)
    set(4, 7, "   Set default boot device", COLORS.gray)
    
    set(4, 9, "2. Clear Priority", COLORS.white)
    set(4, 10, "   Remove default boot", COLORS.gray)
    
    set(4, 12, "3. Format EEPROM", COLORS.red)
    set(4, 13, "   Reset all settings!", COLORS.gray)
    
    set(4, 15, "4. Set BIOS Password", COLORS.white)
    if isBIOSPasswordSet() then
        set(4, 16, "   [Set] Change/Remove", COLORS.green)
    else
        set(4, 16, "   [Not Set]", COLORS.yellow)
    end
    
    set(4, 18, "5. Encrypt Disk", COLORS.white)
    set(4, 19, "   Encrypt selected device", COLORS.gray)
    
    set(4, 21, "6. Change Language", COLORS.white)
    set(4, 22, "   Current: " .. getEEPROMLanguage(), COLORS.yellow)
    
    drawBorder(40, 4, 38, 20, " Help ")
    
    set(42, 6, "Password:", COLORS.cyan)
    set(42, 7, "  Password protects BIOS", COLORS.gray)
    set(42, 8, "  access from F12", COLORS.gray)
    
    set(42, 10, "Encryption:", COLORS.cyan)
    set(42, 11, "  Encrypt disk to require", COLORS.gray)
    set(42, 12, "  password on boot", COLORS.gray)
    
    set(42, 14, "Note:", COLORS.cyan)
    set(42, 15, "  All settings stored in", COLORS.gray)
    set(42, 16, "  EEPROM", COLORS.gray)
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

-- ============================================================
-- Password Input
-- ============================================================
local function inputPassword(title, isNew)
    clear()
    drawBorder(15, 8, 50, 9, title)
    
    local password = ""
    local maxLen = 16
    
    while true do
        fill(17, 10, 46, 1, " ", COLORS.panel)
        
        local display = ""
        for i = 1, #password do
            display = display .. "*"
        end
        display = display .. "_"
        
        set(17, 10, display, COLORS.white, COLORS.panel)
        set(17, 12, "Enter:OK | F1:Cancel | Backspace:Del", COLORS.gray)
        
        if isNew then
            set(17, 11, "Max 16 characters", COLORS.darkGray)
        end
        
        local event = {computer.pullSignal()}
        
        if event[1] == "key_down" then
            local key = event[4]
            
            if key == 28 then -- Enter
                return password
            elseif key == 59 then -- F1 - Cancel
                return nil
            elseif key == 14 then -- Backspace
                if #password > 0 then
                    password = string.sub(password, 1, -2)
                end
            elseif key >= 2 and key <= 126 then
                if #password < maxLen then
                    password = password .. string.char(key)
                end
            end
        end
    end
end

-- ============================================================
-- Encryption Functions
-- ============================================================
local function setBIOSPassword()
    clear()
    drawBorder(15, 8, 50, 9, " Set BIOS Password ")
    
    if isBIOSPasswordSet() then
        set(17, 10, "Enter current password:", COLORS.white)
        local oldPass = inputPassword(" Verify Password ", false)
        if not oldPass then drawMain() return end
        
        if hashPassword(oldPass) ~= getStoredPasswordHash() then
            set(17, 12, "Incorrect password!", COLORS.red)
            os.sleep(1)
            drawMain()
            return
        end
        
        set(17, 11, "Options:", COLORS.white)
        set(17, 12, "1: Change | 2: Remove | Esc:Cancel", COLORS.gray)
        
        local event = {computer.pullSignal()}
        if event[1] == "key_down" then
            local key = event[4]
            if key == 2 then -- 1
                local newPass = inputPassword(" New Password ", true)
                if newPass and #newPass > 0 then
                    setStoredPasswordHash(hashPassword(newPass))
                    drawMain()
                    set(40, 4, "Password changed!", COLORS.green)
                    os.sleep(1)
                else
                    drawMain()
                end
            elseif key == 3 then -- 2
                setStoredPasswordHash("")
                drawMain()
                set(40, 4, "Password removed!", COLORS.yellow)
                os.sleep(1)
            else
                drawMain()
            end
        else
            drawMain()
        end
    else
        local newPass = inputPassword(" Set Password ", true)
        if newPass and #newPass > 0 then
            setStoredPasswordHash(hashPassword(newPass))
            drawMain()
            set(40, 4, "Password set!", COLORS.green)
            os.sleep(1)
        else
            drawMain()
        end
    end
end

local function encryptDisk()
    if #filesystemList == 0 or not filesystemList[selectedIndex] then
        drawMain()
        set(40, 4, "No device selected!", COLORS.red)
        os.sleep(1)
        return
    end
    
    local fs = filesystemList[selectedIndex]
    
    if fs.encrypted then
        -- Decrypt
        clear()
        drawBorder(15, 8, 50, 9, " Decrypt Disk ")
        set(17, 10, "Enter password to decrypt:", COLORS.white)
        
        local pass = inputPassword(" Decrypt ", false)
        if not pass then drawMain() return end
        
        local storedPass = getStoredDiskPassword(fs.address)
        if storedPass == hashPassword(pass) then
            fs.proxy.remove("/.encrypted")
            fs.proxy.remove("/.epassword")
            drawMain()
            set(40, 4, "Disk decrypted!", COLORS.green)
        else
            drawMain()
            set(40, 4, "Wrong password!", COLORS.red)
        end
        os.sleep(1)
    else
        -- Encrypt
        clear()
        drawBorder(15, 8, 50, 9, " Encrypt Disk ")
        set(17, 10, "Enter password for disk:", COLORS.white)
        
        local pass = inputPassword(" Encrypt ", true)
        if not pass then drawMain() return end
        
        if #pass < 4 then
            drawMain()
            set(40, 4, "Password too short!", COLORS.red)
            os.sleep(1)
            return
        end
        
        -- Create encryption marker
        local h = fs.proxy.open("/.encrypted", "wb")
        if h then
            fs.proxy.write(h, "ENCRYPTED")
            fs.proxy.close(h)
        end
        
        h = fs.proxy.open("/.epassword", "wb")
        if h then
            fs.proxy.write(h, hashPassword(pass))
            fs.proxy.close(h)
        end
        
        drawMain()
        set(40, 4, "Disk encrypted!", COLORS.green)
        os.sleep(1)
    end
end

-- ============================================================
-- Boot Functions
-- ============================================================
local function verifyDiskPassword(fs)
    clear()
    drawBorder(15, 8, 50, 9, " Disk Password Required ")
    
    set(17, 10, "Disk is encrypted!", COLORS.yellow)
    set(17, 11, "Enter password:", COLORS.white)
    
    local pass = inputPassword(" Boot Password ", false)
    if not pass then return false end
    
    local storedPass = getStoredDiskPassword(fs.address)
    if storedPass == hashPassword(pass) then
        return true
    end
    
    return false
end

local function bootDevice(index)
    local fs = filesystemList[index]
    if not fs then return end
    
    -- Check if disk is encrypted
    if fs.encrypted then
        if not verifyDiskPassword(fs) then
            drawMain()
            set(40, 4, "Wrong password!", COLORS.red)
            os.sleep(1)
            return
        end
    end
    
    clear()
    set(25, 10, "Booting " .. fs.label .. "...", COLORS.green)
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
        local defaultData = string.rep("-", 72) .. "en" .. string.rep("-", 10)
        component.invoke(e, "setData", defaultData)
    end
    
    set(25, 14, "EEPROM formatted!", COLORS.green)
    os.sleep(2)
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
    set(40, 4, "Language: " .. getEEPROMLanguage(), COLORS.green)
    os.sleep(1)
end

local function setBootPriority()
    if #filesystemList > 0 and filesystemList[selectedIndex] then
        local fs = filesystemList[selectedIndex]
        setPriorityAddress(fs.address)
        drawMain()
        set(40, 4, "Priority: " .. fs.label, COLORS.green)
        os.sleep(1)
    end
end

local function clearBootPriority()
    setPriorityAddress("")
    drawMain()
    set(40, 4, "Priority cleared!", COLORS.yellow)
    os.sleep(1)
end

-- ============================================================
-- Password Check on Startup
-- ============================================================
local function checkPassword()
    if not isBIOSPasswordSet() then
        return true
    end
    
    passwordAttempts = 0
    
    while passwordAttempts < maxPasswordAttempts do
        clear()
        drawBorder(15, 8, 50, 9, " BIOS Password ")
        
        set(17, 10, "BIOS is password protected", COLORS.yellow)
        set(17, 11, "Enter password:", COLORS.white)
        set(17, 13, "Attempts: " .. (maxPasswordAttempts - passwordAttempts) .. "/" .. maxPasswordAttempts, COLORS.gray)
        
        local pass = inputPassword(" BIOS ", false)
        
        if pass == nil then
            -- ESC pressed, return to BIOS
            return false
        end
        
        if hashPassword(pass) == getStoredPasswordHash() then
            return true
        end
        
        passwordAttempts = passwordAttempts + 1
        
        if passwordAttempts >= maxPasswordAttempts then
            clear()
            set(25, 12, "Too many attempts!", COLORS.red)
            set(20, 14, "Returning to BIOS...", COLORS.gray)
            os.sleep(2)
            return false
        end
        
        set(17, 12, "Wrong password!", COLORS.red)
        os.sleep(1)
    end
    
    return false
end

-- ============================================================
-- Main Loop
-- ============================================================
local function main()
    if not gpu then
        for i = 1, 10 do
            computer.pullSignal(0.5)
        end
        return
    end
    
    -- Check password first
    if not checkPassword() then
        return
    end
    
    drawMain()
    
    while true do
        local event = {computer.pullSignal()}
        
        if event[1] == "key_down" then
            local key = event[4]
            
            -- Tab switching
            if key == 37 then
                if CurrentMenu == "Boot" then CurrentMenu = "Info"
                elseif CurrentMenu == "Settings" then CurrentMenu = "Boot" end
                drawMain()
            elseif key == 39 then
                if CurrentMenu == "Info" then CurrentMenu = "Boot"
                elseif CurrentMenu == "Boot" then CurrentMenu = "Settings" end
                drawMain()
            
            elseif CurrentMenu == "Boot" then
                if key == 200 and selectedIndex > 1 then
                    selectedIndex = selectedIndex - 1
                    drawMain()
                elseif key == 208 and selectedIndex < #filesystemList then
                    selectedIndex = selectedIndex + 1
                    drawMain()
                elseif key == 28 then
                    bootDevice(selectedIndex)
                    break
                elseif key == 63 then
                    refreshFilesystems()
                    drawMain()
                elseif key == 2 then
                    setBootPriority()
                end
            
            elseif CurrentMenu == "Settings" then
                if key == 2 then
                    setBootPriority()
                elseif key == 3 then
                    clearBootPriority()
                elseif key == 4 then
                    formatEEPROM()
                    drawMain()
                elseif key == 5 then
                    setBIOSPassword()
                    drawMain()
                elseif key == 6 then
                    encryptDisk()
                    drawMain()
                elseif key == 7 then
                    changeLanguage()
                end
            end
            
            if key == 68 then
                break
            end
        end
    end
end

pcall(main)