-- ============================================================
-- BIOS Manager - 完整的 BIOS 设置界面
-- 注意：运行在 Minecraft Mod (OpenComputers) 中，ESC 键被 Minecraft 截获
-- 因此使用 Backspace(14) 作为退出键
-- ============================================================

local component = component
local computer = computer
local unicode = unicode
if not unicode then
	pcall(function() unicode = require("unicode") end)
end
if type(unicode) ~= "table" then
	unicode = { wlen = function(s) return #s end }
end

-- Get GPU and screen (compatible with EFI context)
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

-- Backspace = 14 退出键 (ESC 被 Minecraft 截获)
local EXIT_KEY = 14

local locale = {
    title = "BIOS 设置",
    selectBoot = "选择启动项",
    noBoot = "没有可启动的设备",
    password = "请输入密码:",
    wrongPassword = "密码错误",
    booting = "正在启动: ",
    shutdown = "关机",
    reboot = "重启",
    exit = "退出",
    back = "返回",
    hint = "↑↓ 选择  Enter 确认  Backspace 返回",
    bootDevice = "启动设备",
    systemType = "系统类型",
    setPassword = "设置密码",
    clearPassword = "清除密码",
    currentPassword = "当前密码:",
    newPassword = "新密码:",
    confirmPassword = "确认密码:",
    passwordMismatch = "密码不匹配",
    passwordChanged = "密码已更改",
    passwordCleared = "密码已清除",
    sysInfo = "系统信息",
    totalMem = "总内存: ",
    usedMem = "已用内存: ",
    freeMem = "可用内存: ",
    compAddr = "计算机地址: ",
    uptime = "运行时间: ",
    maxEnergy = "最大能量: ",
    currentEnergy = "当前能量: ",
    bootPriority = "启动优先级: ",
    lastBoot = "上次启动: ",
    biosVersion = "BIOS 版本: 1.0",
    rename = "重命名",
    setDefault = "设为默认",
    moveUp = "上移",
    moveDown = "下移",
    bootLocation = "引导位置: ",
    confirmRename = "输入新名称:",
    renamed = "已重命名!",
    defaultSet = "已设为默认!"
}

local colors = {
    background = 0x2D2D2D,
    titleBar = 0x1E1E1E,
    text = 0xFFFFFF,
    selectionBg = 0x007ACC,
    selectionText = 0xFFFFFF,
    hint = 0x888888,
    error = 0xFF4444,
    success = 0x44FF44
}

local function hashPassword(password)
    local hash = 1
    for i = 1, #password do
        hash = hash * 7 + string.byte(password, i)
    end
    return tostring(hash)
end

local function isEncrypted(diskProxy)
    if diskProxy and diskProxy.exists then
        return diskProxy.exists("/.bios_pwd")
    end
    return false
end

local function getStoredPassword(diskProxy)
    if not isEncrypted(diskProxy) then
        return nil
    end
    local handle = diskProxy.open("/.bios_pwd", "r")
    if handle then
        local password = ""
        local chunk
        repeat
            chunk = diskProxy.read(handle, 256)
            if chunk then
                password = password .. chunk
            end
        until not chunk
        diskProxy.close(handle)
        return password
    end
    return nil
end

local function drawTitleBar()
    gpu.setBackground(colors.titleBar)
    gpu.fill(1, 1, w, 1, " ")
    gpu.set(2, 1, locale.title)
end

local function drawScreen()
    gpu.setBackground(colors.background)
    gpu.fill(1, 1, w, h, " ")
end

local function drawText(x, y, text, foreground, background)
    if foreground then gpu.setForeground(foreground) end
    if background then gpu.setBackground(background) end
    gpu.set(x, y, text)
end

local function drawCenteredText(y, text, foreground, background)
    local x = math.floor((w - #text) / 2) + 1
    drawText(x, y, text, foreground, background)
end

local function drawMenuItem(y, text, selected)
    if selected then
        gpu.setBackground(colors.selectionBg)
        gpu.setForeground(colors.selectionText)
    else
        gpu.setBackground(colors.background)
        gpu.setForeground(colors.text)
    end
    gpu.fill(2, y, w - 2, 1, " ")
    gpu.set(4, y, (selected and "> " or "  ") .. text)
end

local function drawHint()
    gpu.setBackground(colors.titleBar)
    gpu.setForeground(colors.hint)
    gpu.fill(1, h, w, 1, " ")
    local hintText = locale.hint
    local x = math.floor((w - #hintText) / 2) + 1
    gpu.set(x, h, hintText)
end

local function getBootDevices()
    local devices = {}
    local bootAddress = (computer.getBootAddress and computer.getBootAddress()) or ""
    
    for address in component.list("filesystem") do
        local proxy = component.proxy(address)
        if proxy and proxy.exists then
            local hasOS = proxy.exists("/OS.lua")
            local hasInit = proxy.exists("/init.lua")
            
            if hasOS or hasInit then
                local systemType = "Unknown"
                if hasOS then
                    local handle = proxy.open("/OS.lua", "r")
                    if handle then
                        local data = ""
                        local chunk
                        repeat
                            chunk = proxy.read(handle, 200)
                            if chunk then
                                data = data .. chunk
                            end
                        until not chunk
                        proxy.close(handle)
                        
                        if data:find("PixelOS") then
                            systemType = "PixelOS"
                        elseif data:find("MineOS") then
                            systemType = "MineOS"
                        else
                            systemType = "Custom OS"
                        end
                    end
                else
                    systemType = "OpenOS"
                end
                
                table.insert(devices, {
                    address = address,
                    label = proxy.getLabel() or "Unnamed Drive",
                    hasOS = hasOS,
                    systemType = systemType,
                    isBootDefault = (address == bootAddress),
                    proxy = proxy
                })
            end
        end
    end
    
    table.sort(devices, function(a, b)
        if a.isBootDefault ~= b.isBootDefault then
            return a.isBootDefault
        end
        return a.label < b.label
    end)
    
    return devices
end

local function passwordInput()
    drawScreen()
    drawTitleBar()
    drawHint()
    
    drawCenteredText(math.floor(h / 2) - 2, locale.password, colors.text)
    drawCenteredText(math.floor(h / 2) + 2, "Enter - 确认    Backspace - 删除", colors.hint)
    
    local password = ""
    
    while true do
        local display = ""
        for i = 1, #password do
            display = display .. "*"
        end
        
        drawCenteredText(math.floor(h / 2), display, colors.text)
        
        local event = {computer.pullSignal()}
        
        if event[1] == "key_down" then
            local key = event[4]
            
            if key == 28 then
                return password
            elseif key == 14 then
                if #password > 0 then
                    password = password:sub(1, -2)
                end
            end
        end
    end
end

local function textInput(prompt)
    drawScreen()
    drawTitleBar()
    drawHint()
    
    drawCenteredText(math.floor(h / 2) - 2, prompt, colors.text)
    
    local text = ""
    
    while true do
        gpu.fill(2, math.floor(h / 2), w - 2, 1, " ")
        drawCenteredText(math.floor(h / 2), text, colors.text)
        
        local event = {computer.pullSignal()}
        
        if event[1] == "key_down" then
            local key = event[4]
            
            if key == 28 then
                return text
            elseif key == 14 then
                if #text > 0 then
                    text = text:sub(1, -2)
                end
            elseif key >= 32 and key <= 126 then
                text = text .. string.char(key)
            end
        end
    end
end

local function bootDevice(device)
    drawScreen()
    drawTitleBar()
    drawCenteredText(math.floor(h / 2), "正在保存启动项...", colors.text)
    
    if computer.setBootAddress then
        computer.setBootAddress(device.address)
    end
    
    drawScreen()
    drawTitleBar()
    drawCenteredText(math.floor(h / 2), locale.defaultSet, colors.success)
    drawCenteredText(math.floor(h / 2) + 2, "即将启动: " .. device.label .. " [" .. device.systemType .. "]", colors.text)
    
    if _G._B then
        os.sleep(1)
        return
    end
    
    os.sleep(2)
    computer.shutdown(false)
end

local function sysInfoPage()
    while true do
        drawScreen()
        drawTitleBar()
        drawHint()
        
        drawText(4, 3, locale.sysInfo, colors.text)
        
        local totalMem = computer.totalMemory()
        local freeMem = computer.freeMemory()
        local usedMem = totalMem - freeMem
        local uptime = computer.uptime()
        local maxEnergy = computer.maxEnergy()
        local currentEnergy = math.floor(computer.energy())
        local compAddr = computer.address()
        
        local bootPriority = (computer.getBootAddress and computer.getBootAddress()) or "未设置"
        if type(bootPriority) == "string" and #bootPriority > 18 then
            bootPriority = bootPriority:sub(1, 18) .. "..."
        end
        
        local uptimeStr
        if uptime >= 60 then
            local minutes = math.floor(uptime / 60)
            local seconds = math.floor(uptime % 60)
            uptimeStr = minutes .. " 分钟 " .. seconds .. " 秒"
        else
            uptimeStr = math.floor(uptime) .. " 秒"
        end
        
        local infoY = 5
        drawText(4, infoY, locale.totalMem .. totalMem, colors.text) infoY = infoY + 1
        drawText(4, infoY, locale.usedMem .. usedMem, colors.text) infoY = infoY + 1
        drawText(4, infoY, locale.freeMem .. freeMem, colors.text) infoY = infoY + 1
        
        infoY = infoY + 1
        drawText(4, infoY, locale.compAddr .. compAddr:sub(1, 18), colors.text) infoY = infoY + 1
        drawText(4, infoY, locale.uptime .. uptimeStr, colors.text) infoY = infoY + 1
        
        infoY = infoY + 1
        drawText(4, infoY, locale.maxEnergy .. maxEnergy, colors.text) infoY = infoY + 1
        drawText(4, infoY, locale.currentEnergy .. currentEnergy, colors.text) infoY = infoY + 1
        
        infoY = infoY + 1
        drawText(4, infoY, locale.bootPriority .. tostring(bootPriority), colors.text) infoY = infoY + 1
        
        infoY = infoY + 2
        drawCenteredText(infoY, locale.biosVersion, colors.hint)
        
        local event = {computer.pullSignal()}
        if event[1] == "key_down" and event[4] == EXIT_KEY then
            return
        end
    end
end

-- 设备详情菜单
local function deviceMenu(device)
    local menuItems = {
        { text = locale.setDefault, action = "default" },
        { text = locale.rename, action = "rename" },
        { text = locale.moveUp, action = "up" },
        { text = locale.moveDown, action = "down" },
        { text = "启动", action = "boot" },
        { text = locale.back, action = "back" }
    }
    
    local selected = 1
    
    while true do
        drawScreen()
        drawTitleBar()
        drawHint()
        
        drawText(4, 3, device.label .. " [" .. device.systemType .. "]", colors.text)
        drawText(4, 4, locale.bootLocation .. device.address:sub(1, 18) .. "...", colors.hint)
        
        if device.isBootDefault then
            drawText(4, 5, "★ 当前默认启动", colors.success)
        end
        
        local menuStartY = 7
        for i, item in ipairs(menuItems) do
            local y = menuStartY + i - 1
            drawMenuItem(y, item.text, i == selected)
        end
        
        local event = {computer.pullSignal()}
        if event[1] == "key_down" then
            local key = event[4]
            
            if key == 200 and selected > 1 then
                selected = selected - 1
            elseif key == 208 and selected < #menuItems then
                selected = selected + 1
            elseif key == 28 then
                local action = menuItems[selected].action
                
                if action == "default" then
                    if computer.setBootAddress then
                        computer.setBootAddress(device.address)
                    end
                    drawScreen()
                    drawTitleBar()
                    drawCenteredText(math.floor(h / 2), locale.defaultSet, colors.success)
                    os.sleep(1)
                    return
                elseif action == "rename" then
                    local newName = textInput(locale.confirmRename)
                    if newName and #newName > 0 then
                        pcall(device.proxy.setLabel, newName)
                        drawScreen()
                        drawTitleBar()
                        drawCenteredText(math.floor(h / 2), locale.renamed, colors.success)
                        os.sleep(1)
                        return
                    end
                elseif action == "up" then
                    drawScreen()
                    drawTitleBar()
                    drawCenteredText(math.floor(h / 2), "移动顺序功能开发中", colors.hint)
                    os.sleep(1)
                elseif action == "down" then
                    drawScreen()
                    drawTitleBar()
                    drawCenteredText(math.floor(h / 2), "移动顺序功能开发中", colors.hint)
                    os.sleep(1)
                elseif action == "boot" then
                    if isEncrypted(device.proxy) then
                        local storedPwd = getStoredPassword(device.proxy)
                        local inputPwd = hashPassword(passwordInput())
                        
                        if inputPwd == storedPwd then
                            bootDevice(device)
                            return
                        else
                            drawScreen()
                            drawTitleBar()
                            drawCenteredText(math.floor(h / 2), locale.wrongPassword, colors.error)
                            os.sleep(2)
                        end
                    else
                        bootDevice(device)
                        return
                    end
                elseif action == "back" then
                    return
                end
            elseif key == EXIT_KEY then
                return
            end
        end
    end
end

local function mainMenu()
    local devices = getBootDevices()
    local selectedIndex = 1
    
    while true do
        devices = getBootDevices()
        
        drawScreen()
        drawTitleBar()
        drawHint()
        
        drawText(4, 3, locale.selectBoot, colors.text)
        
        if #devices == 0 then
            drawCenteredText(math.floor(h / 2), locale.noBoot, colors.error)
            drawCenteredText(math.floor(h / 2) + 2, "按任意键继续...", colors.hint)
            computer.pullSignal()
            return
        end
        
        local menuStartY = 5
        
        for i, device in ipairs(devices) do
            local y = menuStartY + i - 1
            local displayText = device.label .. " [" .. device.systemType .. "]"
            if device.isBootDefault then
                displayText = displayText .. " *"
            end
            drawMenuItem(y, displayText, i == selectedIndex)
        end
        
        local separatorY = menuStartY + #devices
        gpu.setBackground(colors.titleBar)
        gpu.fill(2, separatorY, w - 2, 1, " ")
        
        drawMenuItem(separatorY + 1, locale.sysInfo, false)
        drawMenuItem(separatorY + 2, locale.reboot, false)
        drawMenuItem(separatorY + 3, locale.shutdown, false)
        drawMenuItem(separatorY + 4, locale.back, false)
        
        local event = {computer.pullSignal()}
        
        if event[1] == "key_down" then
            local key = event[4]
            
            if key == 200 and selectedIndex > 1 then
                selectedIndex = selectedIndex - 1
            elseif key == 208 and selectedIndex < #devices + 4 then
                selectedIndex = selectedIndex + 1
            elseif key == 28 then
                if selectedIndex <= #devices then
                    deviceMenu(devices[selectedIndex])
                elseif selectedIndex == #devices + 1 then
                    sysInfoPage()
                elseif selectedIndex == #devices + 2 then
                    if _G._B then
                        return
                    end
                    computer.shutdown(false)
                elseif selectedIndex == #devices + 3 then
                    computer.shutdown(true)
                else
                    return
                end
            elseif key == EXIT_KEY then
                return
            end
        end
    end
end

local function main()
    drawScreen()
    drawTitleBar()
    mainMenu()
    
    if _G._B then
        return
    end
    
    computer.shutdown(false)
end

pcall(main)