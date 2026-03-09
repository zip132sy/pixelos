local GUI = require("GUI")
local system = require("System")
local filesystem = require("Filesystem")
local component = component
local localization = require("Localization")

local application = {}
application.name = localization.AppBootManager or "Boot Manager"

-- 获取所有可用的文件系统
local function getAvailableFilesystems()
    local drives = {}
    for address in component.list("filesystem") do
        local label = component.invoke(address, "getLabel") or "Unnamed Drive"
        local spaceTotal = component.invoke(address, "getSpaceTotal")
        local spaceUsed = component.invoke(address, "getSpaceUsed")
        local isReadOnly = component.invoke(address, "isReadOnly")
        
        table.insert(drives, {
            address = address,
            label = label,
            total = spaceTotal,
            used = spaceUsed,
            readOnly = isReadOnly,
            hasOS = filesystem.exists("/OS.lua")
        })
    end
    return drives
end

-- 格式化大小显示
local function formatSize(bytes)
    if bytes >= 1024 * 1024 then
        return string.format("%.1f MB", bytes / (1024 * 1024))
    elseif bytes >= 1024 then
        return string.format("%.1f KB", bytes / 1024)
    else
        return bytes .. " B"
    end
end

-- 保存启动盘设置到 EEPROM
local function setBootDrive(address)
    local eeprom = component.list("eeprom")()
    if not eeprom then
        return false, "No EEPROM found"
    end
    
    -- 将启动盘地址保存到 EEPROM 数据中
    local currentData = component.invoke(eeprom, "get")
    local bootConfig = "--BOOT_DRIVE:" .. address .. "\n"
    
    -- 检查是否已有启动配置
    if currentData:find("%-%-BOOT_DRIVE:") then
        currentData = currentData:gsub("%-%-BOOT_DRIVE:[^\n]*\n", bootConfig)
    else
        currentData = bootConfig .. currentData
    end
    
    component.invoke(eeprom, "set", currentData)
    return true, "Boot drive updated"
end

-- 获取当前启动盘
local function getCurrentBootDrive()
    local eeprom = component.list("eeprom")()
    if not eeprom then
        return nil
    end
    
    local data = component.invoke(eeprom, "get")
    local match = data:match("%-%-BOOT_DRIVE:([^\n]+)")
    return match
end

function application.main()
    local workspace = system.getWorkspace()
    local windowWidth, windowHeight = 60, 25
    local windowX = math.floor((workspace.width - windowWidth) / 2)
    local windowY = math.floor((workspace.height - windowHeight) / 2)
    
    local window = GUI.window(windowX, windowY, windowWidth, windowHeight)
    window.title = "Boot Manager"
    window.colors.title = 0x3366CC
    
    -- 标题
    window:addChild(GUI.label(windowX + 2, windowY + 2, 56, 1, "Select Boot Drive")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
    window:addChild(GUI.label(windowX + 2, windowY + 3, 56, 1, "═══════════════════════════════════════════════════")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
    
    -- 状态文本
    local statusLabel = GUI.label(windowX + 2, windowY + windowHeight - 3, 56, 1, "Ready")
    statusLabel.colors.text = 0x696969
    window:addChild(statusLabel)
    
    -- 获取所有驱动器
    local drives = getAvailableFilesystems()
    local currentBoot = getCurrentBootDrive()
    
    -- 创建驱动器列表容器
    local listContainer = GUI.container(windowX + 2, windowY + 6, 56, 14)
    window:addChild(listContainer)
    
    if #drives == 0 then
        local noDrives = GUI.label(0, 0, 56, 1, "No drives found!")
        noDrives.colors.text = 0xFF0000
        listContainer:addChild(noDrives)
    else
        local y = 0
        for i, drive in ipairs(drives) do
            local isCurrentBoot = (drive.address == currentBoot)
            local icon = isCurrentBoot and "● " or "○ "
            local osIcon = drive.hasOS and "[OS]" or "[   ]"
            local color = isCurrentBoot and 0x3366CC or 0x2D2D2D
            
            -- 驱动器图标和名称
            local driveLabel = GUI.label(0, y, 56, 1, icon .. osIcon .. " " .. drive.label)
            driveLabel.colors.text = color
            listContainer:addChild(driveLabel)
            
            -- 大小信息
            local sizeInfo = string.format("  Total: %s | Used: %s", formatSize(drive.total), formatSize(drive.used))
            listContainer:addChild(GUI.label(2, y + 1, 54, 1, sizeInfo)):setAlignment(GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
            
            -- 选择按钮
            local selectBtn = GUI.button(40, y, 14, 1, "Set as Boot")
            selectBtn.colors.background = isCurrentBoot and 0x99CCFF or 0xE1E1E1
            selectBtn.onTouch = function()
                local success, msg = setBootDrive(drive.address)
                if success then
                    statusLabel.text = "✓ Boot drive set to: " .. drive.label
                    statusLabel.colors.text = 0x00AA00
                    -- 更新显示
                    application.main()
                else
                    statusLabel.text = "✗ Error: " .. msg
                    statusLabel.colors.text = 0xFF0000
                end
            end
            listContainer:addChild(selectBtn)
            
            y = y + 3
        end
    end
    
    -- 关闭按钮
    local closeBtn = GUI.button(windowX + windowWidth - 12, windowY + windowHeight - 2, 10, 3, "Close")
    closeBtn.onTouch = function()
        workspace:removeChild(window)
    end
    window:addChild(closeBtn)
    
    -- 帮助文本
    window:addChild(GUI.label(windowX + 2, windowY + windowHeight - 2, 30, 1, "Select a drive and click 'Set as Boot'")):setAlignment(GUI.ALIGNMENT_HORIZONTAL_LEFT, GUI.ALIGNMENT_VERTICAL_TOP)
    
    workspace:addChild(window)
    return window
end

return application
