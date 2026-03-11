-- PixelOS BIOS v4.0 - macOS Style Boot Manager
-- This code runs from EEPROM after reboot
-- Supports F12 to enter boot manager, auto-boot after delay
-- Password protection for BIOS settings

local c,co=component,computer
local gpu
local screen
local sw, sh = 80, 25

-- Initialize GPU
local gpuAddress = c.list("gpu")()
local screenAddress = c.list("screen")()

if gpuAddress and screenAddress then
    gpu = c.proxy(gpuAddress)
    screen = screenAddress
    gpu.bind(screen)
    sw, sh = gpu.getResolution()
end

-- BIOS Configuration File
local biosConfigPath = "/System/OS/bios.cfg"
local biosConfig = {}

-- Default configuration
local defaultConfig = {
    bootDelay = 3, -- seconds before auto-boot
    bootFromDefault = true, -- boot from default OS after delay
    showBootMenu = true, -- show boot menu on F12
    requirePassword = false, -- require password to change BIOS settings
    password = "", -- BIOS password
    language = "ChineseSimplified", -- interface language
    diskReadOnly = false, -- disk read-only mode
    bootItems = {} -- boot entries
}

-- Load configuration
local function loadConfig()
    -- Get filesystem component
    local fsAddress = component.list("filesystem")()
    if fsAddress then
        local fs = component.proxy(fsAddress)
        if fs.exists(biosConfigPath) then
            local handle = fs.open(biosConfigPath, "r")
            if handle then
                local data = fs.read(handle)
                fs.close(handle)
                local success, config = pcall(load("return " .. data))
                if success and config then
                    biosConfig = config
                else
                    biosConfig = {}
                    for k,v in pairs(defaultConfig) do
                        biosConfig[k] = v
                    end
                end
            else
                biosConfig = {}
                for k,v in pairs(defaultConfig) do
                    biosConfig[k] = v
                end
            end
        else
            biosConfig = {}
            for k,v in pairs(defaultConfig) do
                biosConfig[k] = v
            end
        end
    else
        biosConfig = {}
        for k,v in pairs(defaultConfig) do
            biosConfig[k] = v
        end
    end
end

-- Simple serialization function
local function serialize(tbl)
    local function serialize_value(v)
        if type(v) == "nil" then
            return "nil"
        elseif type(v) == "boolean" then
            return v and "true" or "false"
        elseif type(v) == "number" then
            return tostring(v)
        elseif type(v) == "string" then
            return string.format("%q", v)
        elseif type(v) == "table" then
            local items = {}
            for k, val in pairs(v) do
                local key = type(k) == "string" and string.format("%q", k) or tostring(k)
                table.insert(items, key .. " = " .. serialize_value(val))
            end
            return "{ " .. table.concat(items, ", ") .. " }"
        else
            return "nil"
        end
    end
    return serialize_value(tbl)
end

-- Save configuration
local function saveConfig()
    -- Get filesystem component
    local fsAddress = component.list("filesystem")()
    if fsAddress then
        local fs = component.proxy(fsAddress)
        -- Create directory if it doesn't exist
        local dirPath = biosConfigPath:match("^(.+%/).*") or ""
        if dirPath ~= "" then
            local currentPath = ""
            for dir in dirPath:gmatch("([^%/]+)%/") do
                currentPath = currentPath .. dir .. "/"
                if not fs.exists(currentPath) then
                    fs.makeDirectory(currentPath)
                end
            end
        end
        -- Write configuration
        local handle = fs.open(biosConfigPath, "w")
        if handle then
            local data = "return " .. serialize(biosConfig)
            fs.write(handle, data)
            fs.close(handle)
        end
    end
end

-- Localization
local localization = {
    ChineseSimplified = {
        bootManager = "PixelOS 启动管理器",
        bootItems = "启动项",
        add = "添加",
        edit = "编辑",
        delete = "删除",
        confirm = "确定",
        settings = "设置",
        reboot = "重启",
        shutdown = "关机",
        bootDelay = "启动延迟",
        bootFromDefault = "从默认启动",
        showBootMenu = "显示启动菜单",
        requirePassword = "需要密码",
        passwordPrompt = "请输入BIOS密码",
        wrongPassword = "密码错误",
        booting = "正在启动...",
        bootingIn = "秒后启动",
        autoBoot = "自动启动",
        enterF12 = "按 F12 进入启动管理器",
        pressEnter = "按 Enter 启动默认系统",
        diskInfo = "磁盘信息",
        bootOrder = "启动顺序",
        noBootItems = "没有启动项",
        passwordSettings = "密码设置",
        setPassword = "设置密码",
        changePassword = "更改密码",
        currentPassword = "当前密码",
        newPassword = "新密码",
        confirmPassword = "确认密码",
        passwordsMatch = "密码匹配",
        passwordsNotMatch = "密码不匹配",
        passwordChanged = "密码已更改",
        saveSettings = "保存设置",
        cancel = "取消",
        languageSettings = "语言设置",
        selectLanguage = "选择语言",
        interfaceLanguage = "界面语言",
        bootSettings = "启动设置",
        bootDelaySettings = "启动延迟设置",
        autoBootSettings = "自动启动设置",
        showMenuSettings = "显示菜单设置",
        enablePasswordProtection = "启用密码保护",
        disablePasswordProtection = "禁用密码保护",
        biosLocked = "BIOS已锁定",
        enterPasswordToUnlock = "输入密码解锁BIOS",
        bootItemAdded = "启动项已添加",
        bootItemEdited = "启动项已编辑",
        bootItemDeleted = "启动项已删除",
        bootOrderChanged = "启动顺序已更改",
        bootFromDisk = "从磁盘启动",
        bootFromNetwork = "从网络启动",
        bootFromDefaultOS = "从默认系统启动",
        bootItemName = "启动项名称",
        bootItemPath = "启动路径",
        bootItemDelay = "启动延迟(秒)",
        addBootItem = "添加启动项",
        editBootItem = "编辑启动项",
        deleteBootItem = "删除启动项",
        moveUp = "上移",
        moveDown = "下移",
        setAsDefault = "设为默认",
        bootItemSettings = "启动项设置",
        saveChanges = "保存更改",
        discardChanges = "放弃更改",
        confirmDelete = "确认删除",
        confirmSetDefault = "确认设为默认",
        noDefaultBoot = "没有默认启动项",
        setDefaultBoot = "设置默认启动项",
        power = "电量",
        -- New features
        diskBoot = "磁盘启动",
        networkBoot = "网络启动",
        renameBios = "重命名BIOS",
        biosName = "BIOS名称",
        biosNamePrompt = "输入新的BIOS名称",
        addFromDisk = "从磁盘添加",
        addFromNetwork = "从网络添加",
        autoScan = "自动扫描",
        scanDisks = "扫描磁盘",
        bootFromSelected = "从选定启动项启动",
        moveUp = "上移",
        moveDown = "下移",
        default = "默认",
        selected = "已选择",
        diskBootManager = "磁盘启动管理",
        noDisksFound = "未找到可启动磁盘",
        diskAdded = "磁盘已添加",
        networkBootNotAvailable = "网络启动不可用",
        networkBootSetup = "网络启动设置",
        advancedSettings = "高级设置",
        about = "关于",
        version = "版本",
        copyright = "版权所有"
    },
    English = {
        bootManager = "PixelOS Boot Manager",
        bootItems = "Boot Items",
        add = "Add",
        edit = "Edit",
        delete = "Delete",
        confirm = "Confirm",
        settings = "Settings",
        reboot = "Reboot",
        shutdown = "Shutdown",
        bootDelay = "Boot Delay",
        bootFromDefault = "Boot from Default",
        showBootMenu = "Show Boot Menu",
        requirePassword = "Require Password",
        passwordPrompt = "Enter BIOS Password",
        wrongPassword = "Wrong Password",
        booting = "Booting...",
        bootingIn = "Booting in",
        autoBoot = "Auto Boot",
        enterF12 = "Press F12 to enter Boot Manager",
        pressEnter = "Press Enter to boot default system",
        diskInfo = "Disk Information",
        bootOrder = "Boot Order",
        noBootItems = "No Boot Items",
        passwordSettings = "Password Settings",
        setPassword = "Set Password",
        changePassword = "Change Password",
        currentPassword = "Current Password",
        newPassword = "New Password",
        confirmPassword = "Confirm Password",
        passwordsMatch = "Passwords Match",
        passwordsNotMatch = "Passwords Do Not Match",
        passwordChanged = "Password Changed",
        saveSettings = "Save Settings",
        cancel = "Cancel",
        languageSettings = "Language Settings",
        selectLanguage = "Select Language",
        interfaceLanguage = "Interface Language",
        bootSettings = "Boot Settings",
        bootDelaySettings = "Boot Delay Settings",
        autoBootSettings = "Auto Boot Settings",
        showMenuSettings = "Show Menu Settings",
        enablePasswordProtection = "Enable Password Protection",
        disablePasswordProtection = "Disable Password Protection",
        biosLocked = "BIOS Locked",
        enterPasswordToUnlock = "Enter Password to Unlock BIOS",
        bootItemAdded = "Boot Item Added",
        bootItemEdited = "Boot Item Edited",
        bootItemDeleted = "Boot Item Deleted",
        bootOrderChanged = "Boot Order Changed",
        bootFromDisk = "Boot from Disk",
        bootFromNetwork = "Boot from Network",
        bootFromDefaultOS = "Boot from Default OS",
        bootItemName = "Boot Item Name",
        bootItemPath = "Boot Item Path",
        bootItemDelay = "Boot Delay (seconds)",
        addBootItem = "Add Boot Item",
        editBootItem = "Edit Boot Item",
        deleteBootItem = "Delete Boot Item",
        moveUp = "Move Up",
        moveDown = "Move Down",
        setAsDefault = "Set as Default",
        bootItemSettings = "Boot Item Settings",
        saveChanges = "Save Changes",
        discardChanges = "Discard Changes",
        confirmDelete = "Confirm Delete",
        confirmSetDefault = "Confirm Set as Default",
        noDefaultBoot = "No Default Boot Item",
        setDefaultBoot = "Set Default Boot Item",
        diskStatus = "Disk Status",
        power = "Power",
        -- New features
        diskBoot = "Disk Boot",
        networkBoot = "Network Boot",
        renameBios = "Rename BIOS",
        biosName = "BIOS Name",
        biosNamePrompt = "Enter new BIOS name",
        addFromDisk = "Add from Disk",
        addFromNetwork = "Add from Network",
        autoScan = "Auto Scan",
        scanDisks = "Scan Disks",
        bootFromSelected = "Boot from Selected",
        moveUp = "Move Up",
        moveDown = "Move Down",
        default = "Default",
        selected = "Selected",
        diskBootManager = "Disk Boot Manager",
        noDisksFound = "No bootable disks found",
        diskAdded = "Disk added",
        networkBootNotAvailable = "Network boot not available",
        networkBootSetup = "Network Boot Setup",
        advancedSettings = "Advanced Settings",
        about = "About",
        version = "Version",
        copyright = "Copyright"
    }
}

-- Get current language
local lang = localization[biosConfig.language] or localization.ChineseSimplified
local loc = lang

-- Simple GUI functions
local function clear(color)
    if gpu then
        gpu.setBackground(color or 0x2D2D2D)
        gpu.fill(1,1,sw,sh," ")
    end
end

local function drawStatusBar()
    if gpu then
        gpu.setBackground(0x1E1E1E)
        gpu.fill(1,1,sw,1," ")
        
        -- Menu button (PixelOS text)
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
            batteryText = loc.power .. ": " .. percent .. "%"
        else
            batteryText = loc.power .. ": --%"
        end
        
        -- Use local time
        local timeText = os.date("%H:%M")
        
        -- Draw battery and time on right side with proper spacing
        local statusBarText = batteryText .. "     " .. timeText
        gpu.set(sw - #statusBarText + 1, 1, statusBarText)
    end
end

local function drawBox(x,y,w,h,color,border)
    if gpu then
        gpu.setBackground(color or 0xE1E1E1)
        gpu.fill(x,y,w,h," ")
        if border then
            gpu.setForeground(0x878787)
            gpu.set(x,y,"┌"..string.rep("─",w-2).."┐")
            for i=1,h-2 do
                gpu.set(x,y+i,"│")
                gpu.set(x+w-1,y+i,"│")
            end
            gpu.set(x,y+h-1,"└"..string.rep("─",w-2).."┘")
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
        return {x=x,y=y,w=w,h=h,text=text}
    end
    return {x=x,y=y,w=w,h=h,text=text}
end

local function waitClick()
    while true do
        local e={co.pullSignal()}
        if e[1]=="touch" then
            return e[3],e[4],e[5]
        elseif e[1]=="key_down" and e[4]==28 then
            return -1,-1,0
        elseif e[1]=="key_down" and e[4]==88 then
            return -1,-1,1
        end
    end
end

local function checkClick(btn,x,y)
    return x>=btn.x and x<btn.x+btn.w and y>=btn.y and y<btn.y+btn.h
end

-- Boot Manager State
local bootState = {
    screen = "main",
    selectedBootItem = nil,
    editingBootItem = nil,
    editingField = nil,
    editingValue = nil,
    passwordAttempts = 0,
    maxPasswordAttempts = 3
}

-- Get available disks
local function getDisks()
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
    return disks
end

-- Draw main boot manager screen
local function drawBootManager()
    clear(0x2D2D2D)
    drawStatusBar()
    
    -- Title with BIOS name
    local biosTitle = biosConfig.biosName or "PixelOS"
    drawText(2, 3, biosTitle, 0xFFFFFF, 0x2D2D2D)
    
    -- Boot items
    if bootState.screen=="main" then
        drawText(2, 5, loc.bootItems, 0x3366CC, 0x2D2D2D)
        
        if #biosConfig.bootItems==0 then
            drawText(2, 7, loc.noBootItems, 0x666666, 0x2D2D2D)
        else
            for i, bootItem in ipairs(biosConfig.bootItems) do
                local y = 9 + (i-1) * 2
                if y > sh - 6 then break end
                
                local selected = bootState.selectedBootItem == i
                local prefix = selected and "▶ " or "  "
                local defaultMark = bootItem.isDefault and " ★" or ""
                local itemText = prefix .. bootItem.name .. defaultMark
                drawText(4, y, itemText, selected and 0xFFFFFF or 0xCCCCCC, 0x2D2D2D)
                
                -- Show item type
                local itemType = bootItem.type or "disk"
                local typeText = "[" .. itemType .. "]"
                drawText(4 + #itemText + 1, y, typeText, 0x666666, 0x2D2D2D)
            end
        end
        
        -- Show available disks at bottom
        local disks = getDisks()
        if #disks > 0 then
            drawText(2, sh - 10, loc.diskInfo .. ":", 0x3366CC, 0x2D2D2D)
            for i, disk in ipairs(disks) do
                local y = sh - 8 + i
                if y < sh - 3 then
                    local diskText = disk.label .. " (" .. math.floor(disk.space/1024) .. "KB)"
                    drawText(4, y, diskText, 0x888888, 0x2D2D2D)
                end
            end
        end
        
        -- Bottom buttons - enhanced with more options
        local btnY = sh - 3
        local addBtn = drawButton(2, btnY, 8, 3, loc.addFromDisk, false)
        local bootBtn = drawButton(12, btnY, 10, 3, loc.bootFromSelected, bootState.selectedBootItem ~= nil)
        local settingsBtn = drawButton(24, btnY, 8, 3, loc.settings, false)
        local advancedBtn = drawButton(34, btnY, 8, 3, loc.advancedSettings, false)
        local aboutBtn = drawButton(44, btnY, 8, 3, loc.about, false)
        local rebootBtn = drawButton(54, btnY, 8, 3, loc.reboot, false)
        local shutdownBtn = drawButton(64, btnY, 8, 3, loc.shutdown, false)
        
        return {
            add = addBtn, 
            boot = bootBtn,
            settings = settingsBtn, 
            advanced = advancedBtn,
            about = aboutBtn,
            reboot = rebootBtn, 
            shutdown = shutdownBtn
        }
    end
    
    -- Settings screen
    if bootState.screen=="settings" then
        drawText(2,5,loc.settings,0x3366CC,0x2D2D2D)
        
        -- Boot delay setting
        drawText(4,7,loc.bootDelay,0x000000,0x2D2D2D)
        local delayInput = drawButton(4,8,20,1,tostring(biosConfig.bootDelay),false)
        
        -- Boot from default setting
        drawText(4,11,loc.bootFromDefault,0x000000,0x2D2D2D)
        local defaultSwitch = drawButton(4,12,20,1,biosConfig.bootFromDefault and"ON"or"OFF",false)
        
        -- Show boot menu setting
        drawText(4,15,loc.showBootMenu,0x000000,0x2D2D2D)
        local menuSwitch = drawButton(4,16,20,1,biosConfig.showBootMenu and"ON"or"OFF",false)
        
        -- Password protection setting
        drawText(4,19,loc.passwordSettings,0x000000,0x2D2D2D)
        local passwordSwitch = drawButton(4,20,20,1,biosConfig.requirePassword and"ON"or"OFF",false)
        
        -- Disk status setting
        drawText(4,23,loc.diskStatus,0x000000,0x2D2D2D)
        local diskStatusSwitch = drawButton(4,24,20,1,biosConfig.diskReadOnly and"Read Only"or"Read/Write",false)
        
        -- Language setting
        drawText(4,27,loc.languageSettings,0x000000,0x2D2D2D)
        local langText = biosConfig.language or "ChineseSimplified"
        local langBtn = drawButton(4,28,20,1,langText,false)
        
        -- Bottom buttons
        local btnY=sh-3
        local saveBtn=drawButton(4,btnY,10,3,loc.saveSettings,false)
        local cancelBtn=drawButton(16,btnY,10,3,loc.cancel,false)
        local backBtn=drawButton(28,btnY,10,3,"< Back",false)
        
        return {delayInput=delayInput,defaultSwitch=defaultSwitch,menuSwitch=menuSwitch,passwordSwitch=passwordSwitch,langBtn=langBtn,save=saveBtn,cancel=cancelBtn,back=backBtn}
    end
    
    -- Password screen
    if bootState.screen=="password" then
        drawText(2,5,loc.passwordSettings,0x3366CC,0x2D2D2D)
        
        drawText(4,7,loc.currentPassword,0x000000,0x2D2D2D)
        local currentPassInput = drawButton(4,8,20,1,string.rep("*",#biosConfig.password),false)
        
        drawText(4,11,loc.newPassword,0x000000,0x2D2D2D)
        local newPassInput = drawButton(4,14,20,1,"",false)
        
        drawText(4,17,loc.confirmPassword,0x000000,0x2D2D2D)
        local confirmPassInput = drawButton(4,20,20,1,"",false)
        
        local btnY=sh-3
        local saveBtn=drawButton(4,btnY,10,3,loc.saveSettings,false)
        local cancelBtn=drawButton(16,btnY,10,3,loc.cancel,false)
        local backBtn=drawButton(28,btnY,10,3,"< Back",false)
        
        return {currentPassInput=currentPassInput,newPassInput=newPassInput,confirmPassInput=confirmPassInput,save=saveBtn,cancel=cancelBtn,back=backBtn}
    end
    
    -- Edit boot item screen
    if bootState.screen=="editBootItem" then
        drawText(2,5,loc.bootItemSettings,0x3366CC,0x2D2D2D)
        
        local item = biosConfig.bootItems[bootState.selectedBootItem]
        
        drawText(4,7,loc.bootItemName,0x000000,0x2D2D2D)
        local nameInput = drawButton(4,8,20,1,item.name,false)
        
        drawText(4,11,loc.bootItemPath,0x000000,0x2D2D2D)
        local pathInput = drawButton(4,13,20,1,item.path or "",false)
        
        drawText(4,15,loc.bootItemDelay,0x000000,0x2D2D2D)
        local delayInput = drawButton(4,17,20,1,tostring(item.delay or 0),false)
        
        local btnY=sh-3
        local saveBtn=drawButton(4,btnY,10,3,loc.saveChanges,false)
        local discardBtn=drawButton(16,btnY,10,3,loc.discardChanges,false)
        local backBtn=drawButton(28,btnY,10,3,"< Back",false)
        
        return {nameInput=nameInput,pathInput=pathInput,delayInput=delayInput,save=saveBtn,discard=discardBtn,back=backBtn}
    end
    
    -- Add boot item screen
    if bootState.screen=="addBootItem" then
        drawText(2,5,loc.addBootItem,0x3366CC,0x2D2D2D)
        
        drawText(4,7,loc.bootItemName,0x000000,0x2D2D2D)
        local nameInput = drawButton(4,8,20,1,"",false)
        
        drawText(4,11,loc.bootItemPath,0x000000,0x2D2D2D)
        local pathInput = drawButton(4,13,20,1,"",false)
        
        drawText(4,15,loc.bootItemDelay,0x000000,0x2D2D2D)
        local delayInput = drawButton(4,17,20,1,"0",false)
        
        local btnY=sh-3
        local saveBtn=drawButton(4,btnY,10,3,loc.saveChanges,false)
        local cancelBtn=drawButton(16,btnY,10,3,loc.cancel,false)
        local backBtn=drawButton(28,btnY,10,3,"< Back",false)
        
        return {nameInput=nameInput,pathInput=pathInput,delayInput=delayInput,save=saveBtn,cancel=cancelBtn,back=backBtn}
    end
    
    -- Advanced settings screen
    if bootState.screen == "advanced" then
        drawText(2, 5, loc.advancedSettings, 0x3366CC, 0x2D2D2D)
        
        -- BIOS rename
        drawText(4, 7, loc.renameBios, 0x000000, 0x2D2D2D)
        local renameBtn = drawButton(4, 8, 20, 1, biosConfig.biosName or "PixelOS", false)
        
        -- Disk boot management
        drawText(4, 11, loc.diskBootManager, 0x000000, 0x2D2D2D)
        local scanDisksBtn = drawButton(4, 12, 20, 1, loc.scanDisks, false)
        
        -- Network boot (if available)
        local hasNetwork = c.list("internet")()
        drawText(4, 15, loc.networkBoot, 0x000000, 0x2D2D2D)
        local networkBtn = drawButton(4, 16, 20, 1, hasNetwork and loc.networkBootSetup or loc.networkBootNotAvailable, not hasNetwork)
        
        -- Boot order management
        drawText(4, 19, loc.bootOrder, 0x000000, 0x2D2D2D)
        local moveUpBtn = drawButton(4, 20, 10, 1, loc.moveUp, false)
        local moveDownBtn = drawButton(16, 20, 10, 1, loc.moveDown, false)
        
        local btnY = sh - 3
        local backBtn = drawButton(4, btnY, 10, 3, "< Back", false)
        
        return {
            renameBtn = renameBtn,
            scanDisksBtn = scanDisksBtn,
            networkBtn = networkBtn,
            moveUpBtn = moveUpBtn,
            moveDownBtn = moveDownBtn,
            back = backBtn
        }
    end
    
    -- About screen
    if bootState.screen == "about" then
        drawText(2, 5, loc.about, 0x3366CC, 0x2D2D2D)
        
        local centerX = math.floor(sw / 2)
        
        drawText(centerX - 8, 8, "PixelOS", 0x3366CC, 0x2D2D2D)
        drawText(centerX - 10, 10, "Boot Manager", 0xCCCCCC, 0x2D2D2D)
        drawText(centerX - 5, 12, "v3.0.0", 0x666666, 0x2D2D2D)
        
        drawText(4, 15, loc.copyright, 0x888888, 0x2D2D2D)
        drawText(4, 16, "Based on MineOS by IgorTimofeev", 0x666666, 0x2D2D2D)
        drawText(4, 17, "Modified for PixelOS", 0x666666, 0x2D2D2D)
        
        local btnY = sh - 3
        local backBtn = drawButton(math.floor(sw/2) - 5, btnY, 10, 3, "< Back", false)
        
        return {back = backBtn}
    end
    
    -- Rename BIOS screen
    if bootState.screen == "renameBios" then
        drawText(2, 5, loc.renameBios, 0x3366CC, 0x2D2D2D)
        
        drawText(4, 7, loc.biosName, 0x000000, 0x2D2D2D)
        local nameInput = drawButton(4, 8, 30, 1, biosConfig.biosName or "PixelOS", false)
        
        local btnY = sh - 3
        local saveBtn = drawButton(4, btnY, 10, 3, loc.saveSettings, false)
        local cancelBtn = drawButton(16, btnY, 10, 3, loc.cancel, false)
        local backBtn = drawButton(28, btnY, 10, 3, "< Back", false)
        
        return {nameInput = nameInput, save = saveBtn, cancel = cancelBtn, back = backBtn}
    end
    
    -- Disk scan screen
    if bootState.screen == "diskScan" then
        drawText(2, 5, loc.scanDisks, 0x3366CC, 0x2D2D2D)
        
        local disks = getDisks()
        local diskButtons = {}
        
        for i, disk in ipairs(disks) do
            local y = 7 + (i - 1) * 3
            local diskText = disk.label .. " (" .. math.floor(disk.space/1024) .. "KB)"
            local btn = drawButton(4, y, 40, 2, diskText, false)
            btn.disk = disk
            table.insert(diskButtons, btn)
            
            drawText(45, y + 1, "[+]", 0x00AA00, 0x2D2D2D)
        end
        
        if #disks == 0 then
            drawText(4, 7, loc.noDisksFound, 0xFF6666, 0x2D2D2D)
        end
        
        local btnY = sh - 3
        local backBtn = drawButton(4, btnY, 10, 3, "< Back", false)
        
        return {disks = diskButtons, back = backBtn}
    end
end

-- Handle boot item selection
local function handleBootItemClick(buttons,x,y)
    if bootState.selectedBootItem and bootState.selectedBootItem>0 and bootState.selectedBootItem<=#biosConfig.bootItems then
        local item = biosConfig.bootItems[bootState.selectedBootItem]
        bootFromItem(item)
        return true
    end
    return false
end

-- Handle settings screen clicks
local function handleSettingsClick(buttons,x,y)
    if buttons.delayInput and checkClick(buttons.delayInput,x,y) then
        local delay = tonumber(buttons.delayInput.text)
        if delay and delay>=0 and delay<=30 then
            biosConfig.bootDelay = delay
        end
    elseif buttons.defaultSwitch and checkClick(buttons.defaultSwitch,x,y) then
        biosConfig.bootFromDefault = not biosConfig.bootFromDefault
    elseif buttons.menuSwitch and checkClick(buttons.menuSwitch,x,y) then
        biosConfig.showBootMenu = not biosConfig.showBootMenu
    elseif buttons.diskStatusSwitch and checkClick(buttons.diskStatusSwitch,x,y) then
        biosConfig.diskReadOnly = not biosConfig.diskReadOnly
    elseif buttons.passwordSwitch and checkClick(buttons.passwordSwitch,x,y) then
        biosConfig.requirePassword = not biosConfig.requirePassword
        if not biosConfig.requirePassword then
            biosConfig.password = ""
        end
    elseif buttons.langBtn and checkClick(buttons.langBtn,x,y) then
        bootState.screen = "password"
        bootState.passwordAttempts = 0
    elseif buttons.save and checkClick(buttons.save,x,y) then
        saveConfig()
        bootState.screen = "main"
    elseif buttons.cancel and checkClick(buttons.cancel,x,y) then
        bootState.screen = "main"
    elseif buttons.back and checkClick(buttons.back,x,y) then
        bootState.screen = "main"
    end
    return true
end

-- Handle password screen clicks
local function handlePasswordClick(buttons,x,y)
    if buttons.currentPassInput and checkClick(buttons.currentPassInput,x,y) then
        bootState.editingField = "current"
        bootState.editingValue = biosConfig.password
        bootState.screen = "password"
    elseif buttons.newPassInput and checkClick(buttons.newPassInput,x,y) then
        bootState.editingField = "new"
        bootState.editingValue = ""
        bootState.screen = "password"
    elseif buttons.confirmPassInput and checkClick(buttons.confirmPassInput,x,y) then
        if bootState.editingField=="new" and #bootState.editingValue>=4 then
            biosConfig.password = bootState.editingValue
            bootState.passwordAttempts = 0
            bootState.screen = "settings"
        else
            drawText(4,19,loc.passwordsNotMatch,0xFF0000,0x2D2D2D)
            co.sleep(1)
        end
    elseif buttons.save and checkClick(buttons.save,x,y) then
        saveConfig()
        bootState.screen = "main"
    elseif buttons.cancel and checkClick(buttons.cancel,x,y) then
        bootState.screen = "main"
    elseif buttons.back and checkClick(buttons.back,x,y) then
        bootState.screen = "main"
    end
    return true
end

-- Handle boot item edit/add screen clicks
local function handleBootItemEditClick(buttons,x,y)
    local item = biosConfig.bootItems[bootState.selectedBootItem]
    
    if buttons.nameInput and checkClick(buttons.nameInput,x,y) then
        bootState.editingField = "name"
        bootState.editingValue = buttons.nameInput.text
        bootState.editingValuePath = item and item.path or ""
        bootState.editingValueDelay = item and item.delay or 0
    elseif buttons.pathInput and checkClick(buttons.pathInput,x,y) then
        bootState.editingField = "path"
        bootState.editingValue = buttons.pathInput.text
        bootState.editingValuePath = buttons.pathInput.text
        bootState.editingValueDelay = item and item.delay or 0
    elseif buttons.delayInput and checkClick(buttons.delayInput,x,y) then
        bootState.editingField = "delay"
        bootState.editingValue = tonumber(buttons.delayInput.text) or 0
        bootState.editingValueDelay = tonumber(buttons.delayInput.text) or 0
        bootState.editingValuePath = item and item.path or ""
    elseif buttons.save and checkClick(buttons.save,x,y) then
        if bootState.screen=="addBootItem" then
            local newItem = {
                name = bootState.editingValue or "New Boot Item",
                path = bootState.editingValuePath or "",
                delay = bootState.editingValueDelay or 0
            }
            table.insert(biosConfig.bootItems, newItem)
        else
            if item then
                item.name = bootState.editingValue or item.name
                item.path = bootState.editingValuePath or item.path
                item.delay = bootState.editingValueDelay or item.delay
            end
        end
        saveConfig()
        bootState.screen = "main"
        bootState.selectedBootItem = nil
        bootState.editingField = nil
        bootState.editingValue = nil
        bootState.editingValuePath = nil
        bootState.editingValueDelay = nil
    elseif buttons.discard and checkClick(buttons.discard,x,y) then
        bootState.screen = "main"
        bootState.editingField = nil
        bootState.editingValue = nil
        bootState.editingValuePath = nil
        bootState.editingValueDelay = nil
    elseif buttons.cancel and checkClick(buttons.cancel,x,y) then
        bootState.screen = "main"
        bootState.editingField = nil
        bootState.editingValue = nil
        bootState.editingValuePath = nil
        bootState.editingValueDelay = nil
    end
    return true
end

-- Boot from selected item
local function bootFromItem(item)
    local eeprom=c.list("eeprom")()
    if eeprom then
        c.invoke(eeprom,"setData",item.path or "")
    end
    
    clear(0x2D2D2D)
    drawStatusBar()
    drawText(2,sh-2,loc.booting .. " " .. (item.name or "System"),0xFFFFFF,0x2D2D2D)
    drawText(2,sh,loc.bootingIn .. " " .. tostring(biosConfig.bootDelay) .. " " .. loc.autoBoot,0xFFFFFF,0x2D2D2D)
    
    for i=biosConfig.bootDelay,1,-1 do
        drawText(2,sh,tostring(i),0xFFFFFF,0x2D2D2D)
        co.sleep(1)
    end
    
    co.shutdown(true)
end

-- Main boot manager loop
local function bootManagerLoop()
    while true do
        local buttons=drawBootManager()
        
        local x,y=waitClick()
        
        if bootState.screen=="main" then
            -- Check for boot item clicks
            if #biosConfig.bootItems>0 then
                for i,bootItem in ipairs(biosConfig.bootItems) do
                    local itemY = 9 + (i-1) * 2
                    if x>=4 and x<4+#bootItem.name+10 and y>=itemY and y<itemY+1 then
                        bootState.selectedBootItem = i
                        break
                    end
                end
            end
            
            -- Handle button clicks
            if buttons.add and checkClick(buttons.add, x, y) then
                -- Add boot item from disk
                bootState.screen = "diskScan"
            elseif buttons.boot and buttons.boot.w > 0 and checkClick(buttons.boot, x, y) and bootState.selectedBootItem then
                -- Boot from selected item
                local item = biosConfig.bootItems[bootState.selectedBootItem]
                if item then
                    bootFromItem(item)
                end
            elseif buttons.settings and checkClick(buttons.settings, x, y) then
                bootState.screen = "settings"
            elseif buttons.advanced and checkClick(buttons.advanced, x, y) then
                bootState.screen = "advanced"
            elseif buttons.about and checkClick(buttons.about, x, y) then
                bootState.screen = "about"
            elseif buttons.reboot and checkClick(buttons.reboot, x, y) then
                co.shutdown(true)
            elseif buttons.shutdown and checkClick(buttons.shutdown, x, y) then
                co.shutdown()
            end
            
        elseif bootState.screen=="settings" then
            handleSettingsClick(buttons,x,y)
        elseif bootState.screen=="password" then
            handlePasswordClick(buttons,x,y)
        elseif bootState.screen=="editBootItem" or bootState.screen=="addBootItem" then
            handleBootItemEditClick(buttons,x,y)
        elseif bootState.screen == "advanced" then
            if buttons.renameBtn and checkClick(buttons.renameBtn, x, y) then
                bootState.screen = "renameBios"
            elseif buttons.scanDisksBtn and checkClick(buttons.scanDisksBtn, x, y) then
                bootState.screen = "diskScan"
            elseif buttons.moveUpBtn and checkClick(buttons.moveUpBtn, x, y) and bootState.selectedBootItem and bootState.selectedBootItem > 1 then
                -- Move boot item up
                local idx = bootState.selectedBootItem
                biosConfig.bootItems[idx], biosConfig.bootItems[idx-1] = biosConfig.bootItems[idx-1], biosConfig.bootItems[idx]
                bootState.selectedBootItem = idx - 1
                saveConfig()
            elseif buttons.moveDownBtn and checkClick(buttons.moveDownBtn, x, y) and bootState.selectedBootItem and bootState.selectedBootItem < #biosConfig.bootItems then
                -- Move boot item down
                local idx = bootState.selectedBootItem
                biosConfig.bootItems[idx], biosConfig.bootItems[idx+1] = biosConfig.bootItems[idx+1], biosConfig.bootItems[idx]
                bootState.selectedBootItem = idx + 1
                saveConfig()
            elseif buttons.back and checkClick(buttons.back, x, y) then
                bootState.screen = "main"
            end
        elseif bootState.screen == "about" then
            if buttons.back and checkClick(buttons.back, x, y) then
                bootState.screen = "main"
            end
        elseif bootState.screen == "renameBios" then
            if buttons.nameInput and checkClick(buttons.nameInput, x, y) then
                bootState.editingField = "biosName"
            elseif buttons.save and checkClick(buttons.save, x, y) then
                biosConfig.biosName = bootState.editingValue or "PixelOS"
                saveConfig()
                bootState.screen = "advanced"
            elseif buttons.cancel and checkClick(buttons.cancel, x, y) then
                bootState.screen = "advanced"
            elseif buttons.back and checkClick(buttons.back, x, y) then
                bootState.screen = "advanced"
            end
        elseif bootState.screen == "diskScan" then
            if buttons.disks then
                for i, btn in ipairs(buttons.disks) do
                    if checkClick(btn, x, y) and btn.disk then
                        -- Add disk as boot item
                        local newItem = {
                            name = btn.disk.label or "Disk",
                            path = btn.disk.address,
                            type = "disk",
                            isDefault = #biosConfig.bootItems == 0
                        }
                        table.insert(biosConfig.bootItems, newItem)
                        saveConfig()
                    end
                end
            end
            if buttons.back and checkClick(buttons.back, x, y) then
                bootState.screen = "main"
            end
        end
    end
end

-- Auto-boot countdown
local function autoBootCountdown()
    clear(0x2D2D2D)
    drawStatusBar()
    drawText(2,3,loc.enterF12,0xFFFFFF,0x2D2D2D)
    drawText(2,5,loc.pressEnter,0xFFFFFF,0x2D2D2D)
    
    for i=biosConfig.bootDelay,1,-1 do
        drawText(2,7,tostring(i),0xFFFFFF,0x2D2D2D)
        co.sleep(1)
        
        local e={co.pullSignal(0.1)}
        if e[1]=="key_down" and e[4]==88 then
            bootManagerLoop()
            return
        end
    end
    
    local eeprom=c.list("eeprom")()
    if eeprom then
        c.invoke(eeprom,"setData","")
    end
    co.shutdown(true)
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
        drawText(2, 3, "Error: " .. tostring(reason), 0xFF0000, 0x2D2D2D)
        drawText(2, 5, "Press any key to continue...", 0xFFFFFF, 0x2D2D2D)
        co.pullSignal()
    end
end

-- Try to boot from any available filesystem
local function tryBootFromAny()
    local booted = false
    for address in c.list("filesystem") do
        local proxy = c.proxy(address)
        if proxy and proxy.exists and proxy.exists("/OS.lua") then
            if gpu then
                clear(0x2D2D2D)
                drawText(2, 3, "Booting from " .. (proxy.getLabel and (proxy.getLabel() or address) or address), 0xFFFFFF, 0x2D2D2D)
            end
            
            local handle, data, chunk = proxy.open("/OS.lua", "rb"), ""
            if handle then
                repeat
                    chunk = proxy.read(handle, math.huge)
                    data = data .. (chunk or "")
                until not chunk
                proxy.close(handle)
                
                executeString(data, "=/OS.lua")
                booted = true
                break
            end
        end
    end
    
    if not booted then
        if gpu then
            clear(0x2D2D2D)
            drawText(2, 3, "No boot sources found", 0xFF0000, 0x2D2D2D)
            drawText(2, 5, "Press any key to enter boot manager...", 0xFFFFFF, 0x2D2D2D)
            co.pullSignal()
            bootManagerLoop()
        else
            -- No GPU, just wait for filesystem
            while true do
                if c.pullSignal() == "component_added" then
                    tryBootFromAny()
                end
            end
        end
    end
end

-- Main entry point
local function main()
    local success, err = pcall(function()
        loadConfig()
        
        local f12Pressed = false
        local startTime = computer.uptime()
        
        while computer.uptime() - startTime < 3 do
            local e={co.pullSignal(0.1)}
            if e[1]=="key_down" and e[4]==88 then
                f12Pressed = true
                break
            end
        end
        
        if f12Pressed then
            bootManagerLoop()
        else
            autoBootCountdown()
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