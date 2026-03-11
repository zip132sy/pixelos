-- System Password Verification Screen for PixelOS
-- Displays before desktop loads if encryption is enabled

local c, co = component, computer

-- Initialize GPU
local gpuAddress = c.list("gpu")()
local screenAddress = c.list("screen")()

if not gpuAddress or not screenAddress then
    error("No GPU or screen found")
end

local gpu = c.proxy(gpuAddress)
local screen = screenAddress
gpu.bind(screen)
gpu.setResolution(80, 25)
local sw, sh = gpu.getResolution()

-- Helper functions
local function centrize(width)
    return math.floor(sw / 2 - width / 2)
end

local function clear(color)
    gpu.setBackground(color or 0x000000)
    gpu.fill(1, 1, sw, sh, " ")
end

local function drawText(x, y, text, fg, bg)
    gpu.setForeground(fg or 0xFFFFFF)
    gpu.setBackground(bg or 0x000000)
    gpu.set(x, y, text)
end

local function drawBox(x, y, w, h, color, fill)
    gpu.setBackground(color or 0xFFFFFF)
    if fill then
        gpu.fill(x, y, w, h, " ")
    else
        -- Draw border
        gpu.fill(x, y, w, 1, " ")
        gpu.fill(x, y + h - 1, w, 1, " ")
        gpu.fill(x, y, 1, h, " ")
        gpu.fill(x + w - 1, y, 1, h, " ")
    end
end

-- Get system info
local function getBatteryInfo()
    local battery = c.list("battery")()
    if battery then
        local proxy = c.proxy(battery)
        if proxy.energy and proxy.maxEnergy then
            local current = proxy.energy()
            local max = proxy.maxEnergy()
            if max > 0 then
                return math.floor((current / max) * 100)
            end
        end
    end
    return -1
end

local function getRAMInfo()
    return math.floor(co.totalMemory() / 1024)
end

local function getTime()
    local t = os.date("*t")
    return string.format("%02d:%02d", t.hour, t.min)
end

-- Draw status bar with time, battery, RAM
local function drawStatusBar()
    -- White background
    gpu.setBackground(0xFFFFFF)
    gpu.fill(1, 1, sw, 1, " ")
    
    -- Black text
    gpu.setForeground(0x000000)
    
    -- Time in center
    local timeText = getTime()
    gpu.set(centrize(#timeText), 1, timeText)
    
    -- Battery on right
    local battery = getBatteryInfo()
    local batteryText = battery >= 0 and ("电量：" .. battery .. "%") or "电量：--%"
    gpu.set(sw - #batteryText + 1, 1, batteryText)
    
    -- RAM on left
    local ram = getRAMInfo()
    local ramText = "RAM: " .. ram .. "KB"
    gpu.set(2, 1, ramText)
end

-- Main password verification screen
local function verifyPassword()
    clear(0x2D2D2D)
    drawStatusBar()
    
    -- Draw main window
    local winX, winY, winW, winH = centrize(50), 6, 50, 12
    drawBox(winX, winY, winW, winH, 0xE1E1E1, true)
    
    -- Draw lock icon (simple ASCII art)
    local iconY = winY + 2
    drawText(centrize(10), iconY, "  ┌────┐  ", 0x3366CC, 0xE1E1E1)
    drawText(centrize(10), iconY + 1, "  │████│  ", 0x3366CC, 0xE1E1E1)
    drawText(centrize(10), iconY + 2, "  │████│  ", 0x3366CC, 0xE1E1E1)
    drawText(centrize(10), iconY + 3, "  └────┘  ", 0x3366CC, 0xE1E1E1)
    
    -- Draw title
    drawText(centrize(20), winY + 6, "系统加密保护", 0x000000, 0xE1E1E1)
    drawText(centrize(20), winY + 7, "请输入密码以启动系统", 0x666666, 0xE1E1E1)
    
    -- Draw password input
    local inputX, inputY = centrize(30), winY + 9
    drawBox(inputX - 1, inputY - 1, 32, 3, 0xFFFFFF, true)
    gpu.setForeground(0x000000)
    gpu.set(inputX, inputY, string.rep("_", 30))
    
    -- Draw buttons
    local btnW, btnH = 10, 3
    local confirmX = centrize(btnW + 6)
    local cancelX = centrize(btnW + 6) + btnW + 4
    
    -- Confirm button
    drawBox(confirmX, winY + 10, btnW, btnH, 0x3366CC, true)
    drawText(confirmX + 2, winY + 11, "确认", 0xFFFFFF, 0x3366CC)
    
    -- Cancel button (Shutdown)
    drawBox(cancelX, winY + 10, btnW, btnH, 0xCC4940, true)
    drawText(cancelX + 1, winY + 11, "关机", 0xFFFFFF, 0xCC4940)
    
    -- Draw reboot button
    local rebootX = cancelX + btnW + 2
    drawBox(rebootX, winY + 10, btnW, btnH, 0xFF9933, true)
    drawText(rebootX + 1, winY + 11, "重启", 0xFFFFFF, 0xFF9933)
    
    gpu.setForeground(0xFFFFFF)
    
    -- Password input
    local password = ""
    local inputActive = true
    local cursorVisible = true
    local lastBlink = computer.uptime()
    
    while inputActive do
        -- Blink cursor
        if computer.uptime() - lastBlink > 0.5 then
            cursorVisible = not cursorVisible
            lastBlink = computer.uptime()
            
            -- Redraw input
            drawBox(inputX - 1, inputY - 1, 32, 3, 0xFFFFFF, true)
            gpu.setForeground(0x000000)
            local masked = string.rep("•", #password)
            if cursorVisible then
                masked = masked .. "_"
            end
            gpu.set(inputX, inputY, masked)
        end
        
        -- Handle input
        local signal = {co.pullSignal()}
        if signal[1] == "key_down" then
            local char = signal[3]
            if char == 28 then -- Enter
                inputActive = false
            elseif char == 14 then -- Backspace
                password = password:sub(1, -2)
            elseif char >= 32 and char <= 126 then
                password = password .. string.char(char)
            end
        elseif signal[1] == "touch" then
            local tx, ty, button = signal[3], signal[4], signal[5]
            if button == 0 then -- Left click
                -- Check confirm button
                if tx >= confirmX and tx < confirmX + btnW and ty >= winY + 10 and ty < winY + 10 + btnH then
                    inputActive = false
                -- Check shutdown button
                elseif tx >= cancelX and tx < cancelX + btnW and ty >= winY + 10 and ty < winY + 10 + btnH then
                    co.shutdown()
                -- Check reboot button
                elseif tx >= rebootX and tx < rebootX + btnW and ty >= winY + 10 and ty < winY + 10 + btnH then
                    co.shutdown(true)
                end
            end
        end
    end
    
    return password
end

-- Load encryption module
local encryption
local fsAddress = c.list("filesystem")()
if fsAddress then
    local fs = c.proxy(fsAddress)
    if fs.exists("/Libraries/Encryption.lua") then
        local handle = fs.open("/Libraries/Encryption.lua", "r")
        if handle then
            local data = fs.read(handle, math.huge)
            fs.close(handle)
            local func, err = load(data)
            if func then
                encryption = func()
            end
        end
    end
end

-- Main execution
local function main()
    -- Check if encryption is enabled
    local fsAddress = c.list("filesystem")()
    if not fsAddress then
        error("No filesystem found")
    end
    
    local fs = c.proxy(fsAddress)
    local isEncrypted = fs.exists("/.encrypted")
    
    if not isEncrypted then
        -- No encryption, boot normally
        return nil
    end
    
    -- Show password screen
    local password = verifyPassword()
    
    -- Verify password
    if encryption and encryption.verifyPassword(fs, password) then
        -- Password correct, continue boot
        return password
    else
        -- Password incorrect, show error and shutdown
        clear(0xCC4940)
        drawStatusBar()
        drawText(centrize(30), 10, "密码错误！系统将关闭", 0xFFFFFF, 0xCC4940)
        os.sleep(2)
        co.shutdown()
    end
end

return main()
