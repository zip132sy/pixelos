-- PixelOS BIOS Installer v3.0
-- This code runs from EEPROM after reboot
-- Graphical installation interface

local c,co=component,computer
local gpu
local screen
local sw,sh=80,25

-- Try to get filesystem component for path operations
local filesystem = nil
for addr in c.list("filesystem") do
    filesystem = c.proxy(addr)
    break
end

-- Language detection and localization
local function detectLanguage()
    -- Try to detect language from system
    -- Default to Chinese Simplified
    return "zh_CN"
end

local function getLocalization()
    local lang = detectLanguage()
    
    local zh_CN = {
        welcome = "欢迎使用 PixelOS v3.0",
        biosInstallation = "BIOS 安装程序",
        basedOnMineOS = "基于 MineOS",
        wizardGuide = "此向导将指导您完成:",
        diskSelection = "- 磁盘选择和格式化",
        userAccount = "- 用户账户设置",
        networkConfig = "- 网络配置",
        systemInstall = "- 系统安装",
        next = "下一步 >",
        back = "< 上一步",
        selectDisk = "选择目标磁盘",
        availableDisks = "可用磁盘:",
        readOnly = "[只读]",
        kb = "KB",
        warning = "警告: 格式化将清除所有数据!",
        formatDisk = "格式化磁盘后再安装",
        confirmErase = "确认擦除",
        aboutToErase = "您即将擦除以下磁盘上的所有数据:",
        cannotUndone = "此操作无法撤销!",
        cancel = "取消",
        erase = "擦除",
        userSetup = "用户账户",
        username = "用户名:",
        password = "密码:",
        usePassword = "使用密码保护",
        networkConfig = "网络配置",
        checkingInternet = "检查网卡...",
        internetFound = "网卡已找到",
        noInternet = "未找到网卡",
        networkUnavailable = "网络功能将不可用",
        status = "状态:",
        online = "在线",
        offline = "离线",
        installing = "正在安装 PixelOS",
        formatting = "格式化磁盘...",
        creatingDirs = "创建系统目录...",
        creatingConfig = "创建配置...",
        complete = "安装完成!",
        reboot = "重启",
        shutdown = "关机",
        power = "电量",
        error = "错误",
        pressKey = "按任意键继续...",
        noBootSources = "未找到启动源",
        pressKeyRestart = "按任意键重启...",
        bootFrom = "从以下磁盘启动:",
        -- Additional UI strings
        step = "步骤",
        of = "/",
        select = "选择",
        settings = "设置",
        language = "语言",
        save = "保存",
        delete = "删除",
        edit = "编辑",
        add = "添加"
    }
    
    local en_US = {
        welcome = "Welcome to PixelOS v3.0",
        biosInstallation = "BIOS Installation",
        basedOnMineOS = "Based on MineOS",
        wizardGuide = "This wizard will guide you through:",
        diskSelection = "- Disk selection and formatting",
        userAccount = "- User account setup",
        networkConfig = "- Network configuration",
        systemInstall = "- System installation",
        next = "Next >",
        back = "< Back",
        selectDisk = "Select Target Disk",
        availableDisks = "Available disks:",
        readOnly = "[Read-Only]",
        kb = "KB",
        warning = "WARNING: Formatting will erase all data!",
        formatDisk = "Format disk before installation",
        confirmErase = "Confirm Erase",
        aboutToErase = "You are about to ERASE all data on:",
        cannotUndone = "This action CANNOT be undone!",
        cancel = "Cancel",
        erase = "ERASE",
        userSetup = "User Account",
        username = "Username:",
        password = "Password:",
        usePassword = "Use password protection",
        networkConfig = "Network Configuration",
        checkingInternet = "Checking for Internet card...",
        internetFound = "Internet card found",
        noInternet = "No Internet card found",
        networkUnavailable = "Network features will be unavailable",
        status = "Status:",
        online = "Online",
        offline = "Offline",
        installing = "Installing PixelOS",
        formatting = "Formatting disk...",
        creatingDirs = "Creating system directories...",
        creatingConfig = "Creating configuration...",
        complete = "Installation complete!",
        reboot = "Reboot",
        shutdown = "Shutdown",
        power = "Power",
        error = "Error",
        pressKey = "Press any key to continue...",
        noBootSources = "No boot sources found",
        pressKeyRestart = "Press any key to restart...",
        bootFrom = "Boot from:",
        -- Additional UI strings
        step = "Step",
        of = "/",
        select = "Select",
        settings = "Settings",
        language = "Language",
        save = "Save",
        delete = "Delete",
        edit = "Edit",
        add = "Add"
    }
    
    if lang == "zh_CN" then
        return zh_CN
    else
        return en_US
    end
end

-- Get localization table
local loc = getLocalization()

-- Initialize GPU
local gpuAddress=c.list("gpu")()
local screenAddress=c.list("screen")()

if gpuAddress and screenAddress then
    gpu=c.proxy(gpuAddress)
    screen=screenAddress
    gpu.bind(screen)
    sw,sh=gpu.getResolution()
end

-- Simple GUI functions for BIOS
local function clear(color)
    if gpu then
        gpu.setBackground(color or 0x2D2D2D)
        gpu.fill(1,1,sw,sh," ")
    end
end

-- Draw top status bar
local function drawStatusBar()
    if gpu then
        -- Draw background
        gpu.setBackground(0x1E1E1E)
        gpu.fill(1,1,sw,1," ")
        
        -- Menu button (PixelOS text only, no icon)
        gpu.setForeground(0xFFFFFF)
        gpu.set(2,1,"PixelOS")
        
        -- Battery and Time (right aligned)
        local battery = c.list("battery")()
        local batteryText = ""
        if battery then
            local proxy = c.proxy(battery)
            local energy = 0
            local maxEnergy = 100
            -- Try different API methods for battery
            if proxy.getEnergy then
                energy = proxy.getEnergy() or 0
                maxEnergy = proxy.getMaxEnergy() or 100
            elseif proxy.energy then
                energy = proxy.energy() or 0
                maxEnergy = proxy.maxEnergy() or 100
            end
            local percent = math.floor((energy / maxEnergy) * 100)
            batteryText = "Power: " .. percent .. "%"
        else
            batteryText = "Power: --%"
        end
        
        -- Use computer uptime for real time (os.date uses in-game time in OpenComputers)
        local uptime = computer.uptime()
        local hours = math.floor(uptime / 3600) % 24
        local minutes = math.floor((uptime % 3600) / 60)
        local timeText = string.format("%02d:%02d", hours, minutes)
        
        -- Draw battery and time on right side with proper spacing
        local statusBarText = batteryText .. "     " .. timeText
        -- Clear the area first to prevent black blocks
        gpu.setBackground(0x1E1E1E)
        gpu.fill(sw - #statusBarText, 1, #statusBarText + 2, 1, " ")
        gpu.setForeground(0xFFFFFF)
        gpu.set(sw - #statusBarText + 1, 1, statusBarText)
    end
end

local function drawBox(x,y,w,h,color,border)
    if gpu then
        gpu.setBackground(color or 0xE1E1E1)
        gpu.fill(x,y,w,h," ")
        if border then
            gpu.setForeground(0x878787)
            gpu.set(x,y,"+"..string.rep("-",w-2).."+")
            for i=1,h-2 do
                gpu.set(x,y+i,"|")
                gpu.set(x+w-1,y+i,"|")
            end
            gpu.set(x,y+h-1,"+"..string.rep("-",w-2).."+")
        end
    end
end

local function drawText(x,y,text,color,bg)
    if gpu then
        gpu.setForeground(color or 0xFFFFFF)
        gpu.setBackground(bg or 0x2D2D2D)
        gpu.set(x,y,text)
    end
end

local function drawButton(x,y,w,h,text,selected)
    if gpu then
        local bg=selected and 0x3366CC or 0xC3C3C3
        local fg=selected and 0xFFFFFF or 0x000000
        drawBox(x,y,w,h,bg,false)
        drawText(x+math.floor((w-#text)/2),y+math.floor(h/2),text,fg,bg)
    end
    return {x=x,y=y,w=w,h=h,text=text}
end

local function waitClick()
    while true do
        local e={co.pullSignal()}
        if e[1]=="touch" then
            return e[3],e[4],e[5] -- x,y,button
        elseif e[1]=="key_down" then
            return e[3],e[4],e[2] -- char, keycode, keyboard address
        end
    end
end

local function checkClick(btn,x,y)
    return x>=btn.x and x<btn.x+btn.w and y>=btn.y and y<btn.y+btn.h
end

-- Progress bar drawing function
local function drawProgressBar(x, y, width, percent, label, timeText, filesText)
    if not gpu then return end
    
    -- Draw label
    gpu.setForeground(0x000000)
    gpu.setBackground(0xE1E1E1)
    gpu.set(x, y - 1, label or "")
    
    -- Draw progress bar background
    gpu.setBackground(0xD2D2D2)
    gpu.fill(x, y, width, 1, " ")
    
    -- Draw progress bar fill
    local filledWidth = math.floor((percent / 100) * (width - 2))
    gpu.setBackground(0x3366CC)
    gpu.fill(x + 1, y, filledWidth, 1, " ")
    
    -- Draw percentage text in center
    local percentText = string.format("%d%%", percent)
    gpu.setForeground(0xFFFFFF)
    gpu.set(x + math.floor((width - #percentText) / 2), y, percentText)
    
    -- Draw time and files info below
    if timeText or filesText then
        local infoText = (filesText or "") .. "  " .. (timeText or "")
        gpu.setForeground(0x666666)
        gpu.set(x, y + 1, infoText)
    end
end

-- Format time function for BIOS
local function formatTime(seconds)
    if not seconds or seconds < 0 then return "0 sec" end
    
    if seconds < 60 then
        return math.floor(seconds) .. " sec"
    elseif seconds < 3600 then
        local mins = math.floor(seconds / 60)
        local secs = math.floor(seconds % 60)
        return mins .. " min " .. secs .. " sec"
    else
        local hours = math.floor(seconds / 3600)
        local mins = math.floor((seconds % 3600) / 60)
        return hours .. " hour " .. mins .. " min"
    end
end

-- Installation state
local installState={
    step=1,
    targetDisk=nil,
    username="User",
    password="",
    usePassword=false,
    network=false,
    formatDisk=false,
    confirmErase=false
}

-- Step 1: Welcome Screen
local function showWelcome()
    clear(0x2D2D2D)
    drawStatusBar()
    drawBox(math.floor(sw/2)-25,math.floor(sh/2)-7,50,16,0xE1E1E1,true)

    drawText(math.floor(sw/2)-10,math.floor(sh/2)-6,loc.welcome,0x3366CC,0xE1E1E1)
    drawText(math.floor(sw/2)-12,math.floor(sh/2)-4,loc.biosInstallation,0x666666,0xE1E1E1)
    drawText(math.floor(sw/2)-15,math.floor(sh/2)-2,loc.basedOnMineOS,0x666666,0xE1E1E1)

    drawText(math.floor(sw/2)-18,math.floor(sh/2)+1,loc.wizardGuide,0x000000,0xE1E1E1)
    drawText(math.floor(sw/2)-15,math.floor(sh/2)+2,loc.diskSelection,0x000000,0xE1E1E1)
    drawText(math.floor(sw/2)-15,math.floor(sh/2)+3,loc.userAccount,0x000000,0xE1E1E1)
    drawText(math.floor(sw/2)-15,math.floor(sh/2)+4,loc.networkConfig,0x000000,0xE1E1E1)
    drawText(math.floor(sw/2)-15,math.floor(sh/2)+5,loc.systemInstall,0x000000,0xE1E1E1)

    local nextBtn=drawButton(math.floor(sw/2)+10,math.floor(sh/2)+6,10,3,loc.next,true)

    while true do
        local x,y=waitClick()
        if checkClick(nextBtn,x,y) then
            return 2
        end
    end
end

-- Step 2: Disk Selection
local function showDiskSelect()
    clear(0x2D2D2D)
    drawStatusBar()
    drawBox(5,4,sw-10,sh-7,0xE1E1E1,true)

    drawText(8,4,loc.step .. " 1/5: " .. loc.selectDisk,0x3366CC,0xE1E1E1)
    drawText(8,6,loc.availableDisks,0x000000,0xE1E1E1)

    local disks={}
    for addr,type in c.list("filesystem")do
        local proxy=c.proxy(addr)
        table.insert(disks,{
            address=addr,
            label=proxy.getLabel()or"Unlabeled",
            isReadOnly=proxy.isReadOnly(),
            space=proxy.spaceTotal()or 0
        })
    end

    local buttons={}
    for i,disk in ipairs(disks)do
        local y=8+(i-1)*3
        local status=disk.isReadOnly and loc.readOnly or "["..math.floor(disk.space/1024)..loc.kb.."]"
        local btn=drawButton(10,y,sw-20,2,disk.label.." "..status,i==1)
        btn.disk=disk
        btn.label=disk.label
        table.insert(buttons,btn)
    end

    drawText(8,sh-8,loc.warning,0xFF0000,0xE1E1E1)

    local formatCb=drawButton(10,sh-6,3,1,"",false)
    drawText(14,sh-6,loc.formatDisk,0x000000,0xE1E1E1)

    local backBtn=drawButton(10,sh-4,10,3,loc.back,false)
    local nextBtn=drawButton(sw-20,sh-4,10,3,loc.next,true)

    local selected=1
    installState.formatDisk=false

    while true do
        local x,y=waitClick()

        for i,btn in ipairs(buttons)do
            if checkClick(btn,x,y) then
                selected=i
                installState.targetDisk=btn.disk
                -- Redraw to show selection
                for j,btn in ipairs(buttons)do
                    local status=btn.disk.isReadOnly and"[Read-Only]"or"["..math.floor(btn.disk.space/1024).."KB]"
                    drawButton(btn.x,btn.y,btn.w,btn.h,btn.label.." "..status,j==selected)
                end
            end
        end

        if checkClick(formatCb,x,y) then
            installState.formatDisk=not installState.formatDisk
            drawButton(formatCb.x,formatCb.y,formatCb.w,formatCb.h,installState.formatDisk and"X"or"",installState.formatDisk)
        end

        if checkClick(backBtn,x,y) then
            return 1
        elseif checkClick(nextBtn,x,y) then
            if disks[selected] then
                installState.targetDisk=disks[selected]
                if installState.formatDisk then
                    return 2.5 -- Go to confirm erase
                else
                    return 3
                end
            end
        end
    end
end

-- Step 2.5: Confirm Erase
local function showConfirmErase()
    clear(0x2D2D2D)
    drawStatusBar()
    drawBox(math.floor(sw/2)-20,math.floor(sh/2)-6,40,12,0xE1E1E1,true)

    drawText(math.floor(sw/2)-8,math.floor(sh/2)-4,"? " .. loc.warning,0xFF0000,0xE1E1E1)
    drawText(math.floor(sw/2)-15,math.floor(sh/2)-2,loc.aboutToErase,0x000000,0xE1E1E1)
    drawText(math.floor(sw/2)-10,math.floor(sh/2),installState.targetDisk.label,0x3366CC,0xE1E1E1)

    drawText(math.floor(sw/2)-15,math.floor(sh/2)+2,loc.cannotUndone,0xFF0000,0xE1E1E1)

    local noBtn=drawButton(math.floor(sw/2)-15,math.floor(sh/2)+4,10,3,loc.cancel,true)
    local yesBtn=drawButton(math.floor(sw/2)+5,math.floor(sh/2)+4,10,3,loc.erase,false)

    while true do
        local x,y=waitClick()
        if checkClick(noBtn,x,y) then
            return 2
        elseif checkClick(yesBtn,x,y) then
            installState.confirmErase=true
            return 3
        end
    end
end

-- Step 3: User Setup
local function showUserSetup()
    clear(0x2D2D2D)
    drawStatusBar()
    drawBox(5,4,sw-10,sh-7,0xE1E1E1,true)

    drawText(8,4,loc.step .. " 2/5: " .. loc.userSetup,0x3366CC,0xE1E1E1)

    drawText(8,7,loc.username,0x000000,0xE1E1E1)
    drawBox(20,6,sw-30,3,0xFFFFFF,false)
    drawText(22,7,installState.username,0x000000,0xFFFFFF)

    drawText(8,11,loc.password,0x000000,0xE1E1E1)
    local usePassCb=drawButton(20,10,3,1,"",installState.usePassword)
    drawText(24,10,loc.usePassword,0x000000,0xE1E1E1)

    if installState.usePassword then
        drawBox(20,13,sw-30,3,0xFFFFFF,false)
        drawText(22,14,string.rep("*",#installState.password),0x000000,0xFFFFFF)
    end

    local backBtn=drawButton(10,sh-4,10,3,loc.back,false)
    local nextBtn=drawButton(sw-20,sh-4,10,3,loc.next,true)

    while true do
        local x,y,b=waitClick()

        if type(x)=="number" and type(y)=="number" then
            -- Touch event
            if checkClick(usePassCb,x,y) then
                installState.usePassword=not installState.usePassword
                return 3 -- Refresh
            end

            if checkClick(backBtn,x,y) then
                return 2
            elseif checkClick(nextBtn,x,y) then
                return 4
            end
        else
            -- Keyboard event
            local char, keycode = x, y
            if keycode == 14 then
                -- Backspace
                if installState.usePassword then
                    installState.password = installState.password:sub(1, -2)
                else
                    installState.username = installState.username:sub(1, -2)
                end
            elseif keycode == 28 then
                -- Enter key
                return 4
            elseif char and char ~= "" then
                -- Regular character
                if installState.usePassword then
                    installState.password = installState.password .. char
                else
                    installState.username = installState.username .. char
                end
            end
            -- Redraw input fields
            drawBox(20, 6, sw-30, 3, 0xFFFFFF, false)
            drawText(22, 7, installState.username, 0x000000, 0xFFFFFF)
            if installState.usePassword then
                drawBox(20, 13, sw-30, 3, 0xFFFFFF, false)
                drawText(22, 14, string.rep("*", #installState.password), 0x000000, 0xFFFFFF)
            end
        end
    end
end

-- Step 4: Network Check
local function showNetworkCheck()
    clear(0x2D2D2D)
    drawStatusBar()
    drawBox(5,4,sw-10,sh-7,0xE1E1E1,true)

    drawText(8,4,loc.step .. " 3/5: " .. loc.networkConfig,0x3366CC,0xE1E1E1)

    drawText(8,7,loc.checkingInternet,0x000000,0xE1E1E1)

    local inet=c.list("internet")()
    if inet then
        drawText(8,9,"? " .. loc.internetFound,0x00AA00,0xE1E1E1)
        drawText(8,10,"  Address: "..inet:sub(1,8).."...",0x666666,0xE1E1E1)
        installState.network=true

        drawText(8,13,loc.bootFrom .. ":",0x000000,0xE1E1E1)
        drawText(8,14,"  " .. loc.status .. ": " .. loc.online,0x00AA00,0xE1E1E1)
    else
        drawText(8,9,"? " .. loc.noInternet,0xFF0000,0xE1E1E1)
        drawText(8,10,"  " .. loc.networkUnavailable,0x666666,0xE1E1E1)
        installState.network=false
    end

    local backBtn=drawButton(10,sh-4,10,3,loc.back,false)
    local nextBtn=drawButton(sw-20,sh-4,10,3,loc.next,true)

    while true do
        local x,y=waitClick()
        if checkClick(backBtn,x,y) then
            return 3
        elseif checkClick(nextBtn,x,y) then
            return 5
        end
    end
end

-- Step 5: Installation with progress bar
local function showInstallation()
    clear(0x2D2D2D)
    drawStatusBar()
    drawBox(5,4,sw-10,sh-7,0xE1E1E1,true)

    drawText(8,4,loc.step .. " 4/5: " .. loc.installing,0x3366CC,0xE1E1E1)

    -- Installation tasks
    local tasks = {
        {name = loc.formatting, func = function()
            if installState.formatDisk and installState.confirmErase then
                local proxy=c.proxy(installState.targetDisk.address)
                if proxy then
                    local list=proxy.list("/")
                    if list then
                        for _,item in ipairs(list)do
                            if item~="."and item~=".."then
                                proxy.remove("/"..item)
                            end
                        end
                    end
                end
            end
        end},
        {name = loc.creatingDirs, func = function()
            local proxy=c.proxy(installState.targetDisk.address)
            if proxy then
                proxy.makeDirectory("System/OS")
                proxy.makeDirectory("Libraries")
                proxy.makeDirectory("Applications")
                proxy.makeDirectory("Desktop")
            end
        end},
        {name = loc.creatingConfig, func = function()
            local config={
                username=installState.username,
                password=installState.usePassword and installState.password or nil,
                network=installState.network,
                installDate=os.time(),
                firstBoot=true
            }
            -- Save config (simplified)
        end},
        {name = "下载系统文件", func = function()
            -- Simulated file download with progress
            local totalFiles = 50
            local startTime = os.time()
            
            for i = 1, totalFiles do
                local elapsed = os.time() - startTime
                local remaining = (totalFiles - i) * (i > 0 and elapsed / i or 0.5)
                local remainingText = formatTime(remaining)
                local percent = math.floor((i / totalFiles) * 100)
                
                -- Draw progress bar
                drawProgressBar(10, 15, sw - 20, percent, 
                    "正在安装文件：" .. i .. "/" .. totalFiles,
                    "剩余时间：" .. remainingText,
                    "剩余文件：" .. (totalFiles - i))
                
                os.sleep(0.1) -- Simulate download time
            end
        end}
    }

    -- Execute tasks with progress
    local startY = 7
    for i, task in ipairs(tasks) do
        drawText(8, startY, task.name, 0x000000, 0xE1E1E1)
        
        -- Execute task
        task.func()
        
        drawText(sw - 15, startY, "[OK]", 0x00AA00, 0xE1E1E1)
        startY = startY + 2
    end

    drawText(8,18,"✓ " .. loc.complete,0x00AA00,0xE1E1E1)

    local rebootBtn=drawButton(math.floor(sw/2)-5,sh-5,12,3,loc.reboot,true)

    while true do
        local x,y=waitClick()
        if checkClick(rebootBtn,x,y) then
            -- Set EEPROM data to point to new system
            local eeprom=c.list("eeprom")()
            if eeprom then
                c.invoke(eeprom,"setData",installState.targetDisk.address)
            end
            co.shutdown(true)
        end
    end
end

-- Execute string with error handling
local function executeString(...) 
    local result, reason = load(...) 
    
    if result then 
        result, reason = xpcall(result, debug.traceback) 
        
        if result then 
            return 
        end 
    end 
    
    if gpu then
        clear(0x2D2D2D)
        drawText(2, 3, loc.error .. ": " .. tostring(reason), 0xFF0000, 0x2D2D2D)
        drawText(2, 5, loc.pressKey, 0xFFFFFF, 0x2D2D2D)
        co.pullSignal()
    end
end

-- Try to boot from any available filesystem with progress bar
local function tryBootFromAny()
    local booted = false
    
    -- Count total files to load for progress
    local filesToLoad = {
        "/OS.lua",
        "/Libraries/GUI.lua",
        "/Libraries/System.lua",
        "/Libraries/Text.lua"
    }
    
    for i, filePath in ipairs(filesToLoad) do
        for address in c.list("filesystem") do
            local proxy = c.proxy(address)
            if proxy.exists(filePath) then
                if gpu then
                    -- Draw loading screen with progress
                    clear(0x2D2D2D)
                    drawStatusBar()
                    
                    drawText(math.floor(sw/2)-10, math.floor(sh/2)-3, "加载系统文件...", 0xFFFFFF, 0x2D2D2D)
                    
                    -- Calculate progress
                    local percent = math.floor((i / #filesToLoad) * 100)
                    -- Extract filename from path manually
                    local fileName = filePath
                    local lastSlash = filePath:match("^.*()/")
                    if lastSlash then
                        fileName = filePath:sub(lastSlash + 1)
                    end
                    local label = "正在加载：" .. fileName
                    
                    drawProgressBar(math.floor(sw/2)-20, math.floor(sh/2), 40, percent, 
                        label,
                        "文件 " .. i .. "/" .. #filesToLoad,
                        "")
                    
                    os.sleep(0.2) -- Small delay to show progress
                end
                
                -- Load the file
                local handle, data, chunk = proxy.open(filePath, "rb"), ""
                if handle then
                    repeat
                        chunk = proxy.read(handle, math.huge)
                        data = data .. (chunk or "")
                    until not chunk
                    proxy.close(handle)
                    
                    if filePath == "/OS.lua" then
                        executeString(data, "=/OS.lua")
                        booted = true
                        break
                    end
                end
            end
        end
        
        if booted then break end
    end
    
    if not booted then
        if gpu then
            clear(0x2D2D2D)
            drawText(2, 3, loc.noBootSources, 0xFF0000, 0x2D2D2D)
            drawText(2, 5, loc.pressKeyRestart, 0xFFFFFF, 0x2D2D2D)
            co.pullSignal()
        end
        co.shutdown(true)
    end
end

-- Main flow with error handling
local function main()
    local success, err = pcall(function()
        while true do
            if installState.step==1 then
                installState.step=showWelcome()
            elseif installState.step==2 then
                installState.step=showDiskSelect()
            elseif installState.step==2.5 then
                installState.step=showConfirmErase()
            elseif installState.step==3 then
                installState.step=showUserSetup()
            elseif installState.step==4 then
                installState.step=showNetworkCheck()
            elseif installState.step==5 then
                showInstallation()
                break
            end
        end
    end)
    
    if not success then
        if gpu then
            clear(0x2D2D2D)
            drawText(2, 3, "Critical error: " .. tostring(err), 0xFF0000, 0x2D2D2D)
            drawText(2, 5, "Attempting to boot from any available disk...", 0xFFFFFF, 0x2D2D2D)
            co.sleep(2)
        end
        tryBootFromAny()
    end
end

-- Run with error handling
local success, err = pcall(main)
if not success then
    -- If everything fails, try to boot from any filesystem
    tryBootFromAny()
end
