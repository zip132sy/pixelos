-- ============================================================
-- BIOS Manager - 完整的 BIOS 设置界面
-- ============================================================

local component = require("component")
local computer = require("computer")
local unicode = require("unicode")

-- GPU 和屏幕设置
local gpu = component.gpu
local screen = component.screen
gpu.bind(screen.address)
local w, h = gpu.getResolution()

-- 本地化文本
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
    hint = "↑↓ 选择  Enter 确认  Esc 返回",
    bootDevice = "启动设备",
    systemType = "系统类型",
    setPassword = "设置密码",
    clearPassword = "清除密码",
    currentPassword = "当前密码:",
    newPassword = "新密码:",
    confirmPassword = "确认密码:",
    passwordMismatch = "密码不匹配",
    passwordChanged = "密码已更改",
    passwordCleared = "密码已清除"
}

-- 颜色定义
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

-- 哈希函数
local function hashPassword(password)
    local hash = 1
    for i = 1, #password do
        hash = hash * 7 + string.byte(password, i)
    end
    return tostring(hash)
end

-- 检查磁盘是否加密
local function isEncrypted(diskProxy)
    if diskProxy and diskProxy.exists then
        return diskProxy.exists("/.bios_pwd")
    end
    return false
end

-- 获取保存的密码
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

-- 绘制标题栏
local function drawTitleBar()
    gpu.setBackground(colors.titleBar)
    gpu.fill(1, 1, w, 1, " ")
    gpu.set(2, 1, locale.title)
end

-- 绘制屏幕
local function drawScreen()
    gpu.setBackground(colors.background)
    gpu.fill(1, 1, w, h, " ")
end

-- 绘制文本
local function drawText(x, y, text, foreground, background)
    if foreground then gpu.setForeground(foreground) end
    if background then gpu.setBackground(background) end
    gpu.set(x, y, text)
end

-- 居中绘制文本
local function drawCenteredText(y, text, foreground, background)
    local x = math.floor((w - #text) / 2) + 1
    drawText(x, y, text, foreground, background)
end

-- 绘制选择项
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

-- 绘制提示栏
local function drawHint()
    gpu.setBackground(colors.titleBar)
    gpu.setForeground(colors.hint)
    gpu.fill(1, h, w, 1, " ")
    local hintText = locale.hint
    local x = math.floor((w - #hintText) / 2) + 1
    gpu.set(x, h, hintText)
end

-- 获取所有可启动设备
local function getBootDevices()
    local devices = {}
    local eeprom = component.eeprom
    local bootAddress = eeprom and eeprom.getData() or ""
    
    for address in component.list("filesystem") do
        local proxy = component.proxy(address)
        if proxy and proxy.exists then
            local hasOS = proxy.exists("/OS.lua")
            local hasInit = proxy.exists("/init.lua")
            
            if hasOS or hasInit then
                -- 检测系统类型
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
    
    -- 排序：默认启动项优先，然后按标签排序
    table.sort(devices, function(a, b)
        if a.isBootDefault ~= b.isBootDefault then
            return a.isBootDefault
        end
        return a.label < b.label
    end)
    
    return devices
end

-- 密码输入界面
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
            
            if key == 28 then -- Enter
                return password
            elseif key == 14 then -- Backspace
                if #password > 0 then
                    password = password:sub(1, -2)
                end
            end
        end
    end
end

-- 启动设备
local function bootDevice(device)
    drawScreen()
    drawTitleBar()
    drawCenteredText(math.floor(h / 2), "正在保存启动项...", colors.text)
    
    -- 保存启动地址到 EEPROM
    local eeprom = component.eeprom
    if eeprom then
        eeprom.setData(device.address)
    end
    
    -- 提示即将重启
    drawScreen()
    drawTitleBar()
    drawCenteredText(math.floor(h / 2), "启动项已保存!", colors.success)
    drawCenteredText(math.floor(h / 2) + 2, "即将启动: " .. device.label .. " [" .. device.systemType .. "]", colors.text)
    os.sleep(2)
    
    -- 重启电脑
    computer.shutdown(false)
end

-- 主菜单
local function mainMenu()
    local devices = getBootDevices()
    local selectedIndex = 1
    
    while true do
        devices = getBootDevices()
        
        drawScreen()
        drawTitleBar()
        drawHint()
        
        -- 标题
        drawText(4, 3, locale.selectBoot, colors.text)
        
        if #devices == 0 then
            drawCenteredText(math.floor(h / 2), locale.noBoot, colors.error)
            drawCenteredText(math.floor(h / 2) + 2, "按任意键继续...", colors.hint)
            computer.pullSignal()
            return
        end
        
        -- 计算菜单起始位置
        local menuStartY = 5
        
        -- 绘制设备列表
        for i, device in ipairs(devices) do
            local y = menuStartY + i - 1
            local displayText = device.label .. " [" .. device.systemType .. "]"
            if device.isBootDefault then
                displayText = displayText .. " *"
            end
            drawMenuItem(y, displayText, i == selectedIndex)
        end
        
        -- 添加分隔线
        local separatorY = menuStartY + #devices
        gpu.setBackground(colors.titleBar)
        gpu.fill(2, separatorY, w - 2, 1, " ")
        
        -- 添加选项
        drawMenuItem(separatorY + 1, locale.reboot, false)
        drawMenuItem(separatorY + 2, locale.shutdown, false)
        drawMenuItem(separatorY + 3, locale.exit, false)
        
        -- 处理事件
        local event = {computer.pullSignal()}
        
        if event[1] == "key_down" then
            local key = event[4]
            
            if key == 200 and selectedIndex > 1 then -- 上
                selectedIndex = selectedIndex - 1
            elseif key == 208 and selectedIndex < #devices then -- 下
                selectedIndex = selectedIndex + 1
            elseif key == 28 then -- Enter
                if selectedIndex <= #devices then
                    -- 检查是否加密
                    local device = devices[selectedIndex]
                    if isEncrypted(device.proxy) then
                        local storedPwd = getStoredPassword(device.proxy)
                        local inputPwd = hashPassword(passwordInput())
                        
                        if inputPwd == storedPwd then
                            bootDevice(device)
                        else
                            drawScreen()
                            drawTitleBar()
                            drawCenteredText(math.floor(h / 2), locale.wrongPassword, colors.error)
                            computer.pullSignal(2)
                        end
                    else
                        bootDevice(device)
                    end
                elseif selectedIndex == #devices + 1 then
                    computer.shutdown(false) -- 重启
                elseif selectedIndex == #devices + 2 then
                    computer.shutdown(true) -- 关机
                else
                    return -- 退出
                end
            elseif key == 27 then -- Esc
                return
            end
        end
    end
end

-- 主程序
local function main()
    drawScreen()
    drawTitleBar()
    
    mainMenu()
end

-- 运行
pcall(main)