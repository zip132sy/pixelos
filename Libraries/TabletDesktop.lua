-- PixelOS Tablet Desktop Environment v3.0
-- Enhanced tablet-style desktop with app switching and grid layout

local component = require("component")
local computer = require("computer")
local gpu = component.gpu
local screen = component.list("screen")()

gpu.bind(screen)
local sw, sh = gpu.getResolution()

-- Configuration
local config = {
    dockApps = 4,          -- Dock 栏应用数量
    dockHeight = 4,
    statusBarHeight = 1,
    gridIcons = 9,         -- 主屏幕图标数量 (3 行 x3 列)
    tabletModeThreshold = {width = 60, height = 20},  -- 平板模式阈值
    animationDuration = 0.3,
    maxRunningApps = 3,    -- 最多同时显示3个运行应用
}

-- State
local state = {
    tabletMode = false,
    runningApps = {},
    currentApp = nil,
    dockApps = {},
    currentTime = "",
    batteryPercent = 0,
    ramUsed = 0,
    ramTotal = 0,
    diskUsed = 0,
    diskTotal = 0,
    cpuArch = "Unknown",
    animationProgress = 1,
    dockConfig = {},  -- Persistent dock configuration
    appGridPage = 1,  -- Current app grid page
    totalPages = 1,   -- Total pages in app grid
}

-- Localization
local loc = {
    menu = "菜单",
    running = "运行中",
    ram = "内存",
    disk = "磁盘",
    cpu = "CPU",
    battery = "电量",
    noApps = "无运行应用",
    apps = {
        "计算器", "文件", "设置", "终端", "浏览器", "应用店", 
        "音乐", "图片", "视频", "邮件", "日历", "备忘录"
    },
    arrowLeft = "←",
    arrowRight = "→",
}

-- Helper functions
local function centrize(text, width)
    return math.floor((width - #text) / 2)
end

local function updateSystemInfo()
    -- Time
    local uptime = computer.uptime()
    local hours = math.floor(uptime / 3600) % 24
    local minutes = math.floor((uptime % 3600) / 60)
    state.currentTime = string.format("%02d:%02d", hours, minutes)
    
    -- Battery
    local battery = component.list("battery")()
    if battery then
        local proxy = component.proxy(battery)
        if proxy.getEnergy then
            state.batteryPercent = math.floor((proxy.getEnergy() / proxy.getMaxEnergy()) * 100)
        elseif proxy.energy then
            state.batteryPercent = math.floor((proxy.energy() / proxy.maxEnergy()) * 100)
        end
    end
    
    -- RAM
    state.ramUsed = computer.usedMemory()
    state.ramTotal = computer.totalMemory()
    
    -- Disk
    local fs = component.list("filesystem")()
    if fs then
        local proxy = component.proxy(fs)
        state.diskUsed = proxy.spaceUsed()
        state.diskTotal = proxy.spaceTotal()
    end
    
    -- CPU Architecture
    state.cpuArch = _VERSION or "Unknown"
end

local function isTabletMode()
    return sw <= config.tabletModeThreshold.width or sh <= config.tabletModeThreshold.height
end

-- Animation helper
local function lerp(a, b, t)
    return a + (b - a) * t
end

local function animateTo(target, duration)
    local start = computer.uptime()
    while computer.uptime() - start < duration do
        local progress = (computer.uptime() - start) / duration
        yield(progress)
        os.sleep(0.05)
    end
    return target
end

-- Running apps panel
local function drawRunningAppsPanel()
    if #state.runningApps == 0 then
        return
    end
    
    local panelWidth = 6
    local panelHeight = 6
    local panelX = 1
    local panelY = config.statusBarHeight + 1
    
    -- Draw panel background
    gpu.setBackground(0xF0F0F0)
    gpu.fill(panelX, panelY, panelWidth, panelHeight, " ")
    
    -- Draw border
    gpu.setForeground(0xCCCCCC)
    gpu.set(panelX, panelY, "┌" .. string.rep("─", panelWidth - 2) .. "┐")
    for i = 1, panelHeight - 2 do
        gpu.set(panelX, panelY + i, "│")
        gpu.set(panelX + panelWidth - 1, panelY + i, "│")
    end
    gpu.set(panelX, panelY + panelHeight - 1, "└" .. string.rep("─", panelWidth - 2) .. "┘")
    
    -- Draw running app icons (smaller versions)
    local maxApps = math.min(config.maxRunningApps, #state.runningApps)
    for i = 1, maxApps do
        local app = state.runningApps[i]
        local x = panelX + 1
        local y = panelY + i
        
        gpu.setForeground(0x3366CC)
        gpu.set(x, y, "□")  -- Small icon representation
    end
end

-- Drawing functions with animation support
local function drawStatusBar(alpha)
    alpha = alpha or 1
    local baseColor = 0x1E1E1E
    
    gpu.setBackground(baseColor)
    gpu.fill(1, 1, sw, config.statusBarHeight, " ")
    
    gpu.setForeground(0xFFFFFF)
    
    -- Left side: Menu and Running apps
    local leftText = "⋮ " .. loc.menu .. "  │  ≡ " .. loc.running
    gpu.set(2, 1, leftText)
    
    -- Right side: System info
    local rightText = string.format("%s │ 🔋%d%% │ %s:%dMB │ %s:%dMB │ %s",
        state.currentTime,
        state.batteryPercent,
        loc.ram,
        math.floor(state.ramUsed / 1024 / 1024),
        loc.disk,
        math.floor((state.diskTotal - state.diskUsed) / 1024 / 1024),
        state.cpuArch:match("%d%.%d") or "Lua"
    )
    
    gpu.set(sw - #rightText, 1, rightText)
    
    -- Page navigation arrows (for app grid)
    if state.currentApp == nil then
        gpu.set(1, 1, loc.arrowLeft)
        gpu.set(sw, 1, loc.arrowRight)
    end
end

local function drawDock(alpha)
    alpha = alpha or 1
    local dockY = sh - config.dockHeight + 1
    
    gpu.setBackground(0x2D2D2D)
    gpu.fill(1, dockY, sw, config.dockHeight, " ")
    
    -- Draw dock separator line with gradient
    gpu.setForeground(0x3D3D3D)
    gpu.set(1, dockY, string.rep("─", sw))
    
    -- Draw dock apps (centered)
    local appWidth = math.floor(sw / config.dockApps)
    for i = 1, config.dockApps do
        local x = (i - 1) * appWidth + math.floor(appWidth / 2) - 2
        local y = dockY + 1
        
        local appName = state.dockConfig[i] or state.dockApps[i]
        if appName then
            gpu.setForeground(0x3366CC)
            gpu.set(x, y, "📱")
            gpu.set(x + 1, y + 1, appName:sub(1, 4))
        else
            gpu.setForeground(0x666666)
            gpu.set(x, y, "➕")
        end
    end
end

local function drawAppGrid(alpha)
    alpha = alpha or 1
    local gridStartY = 2
    local gridEndY = sh - config.dockHeight - 1
    local gridHeight = gridEndY - gridStartY + 1
    
    -- Calculate grid dimensions (3x3 grid)
    local rows = 3
    local cols = 3
    local cellWidth = math.floor(sw / cols)
    local cellHeight = math.floor(gridHeight / rows)
    
    gpu.setBackground(0xE1E1E1)
    gpu.fill(1, gridStartY, sw, gridHeight, " ")
    
    -- Calculate apps for current page
    local appsPerPage = rows * cols  -- 9 apps per page
    local startIndex = (state.appGridPage - 1) * appsPerPage + 1
    local endIndex = math.min(startIndex + appsPerPage - 1, #loc.apps)
    
    -- Draw page indicator
    gpu.setForeground(0x666666)
    gpu.set(centrize(string.format("第 %d 页", state.appGridPage), sw), gridStartY - 1, string.format("第 %d 页", state.appGridPage))
    
    -- Draw app icons
    for i = 1, appsPerPage do
        local appIndex = startIndex + i - 1
        if appIndex <= #loc.apps then
            local row = math.floor((i - 1) / cols)
            local col = (i - 1) % cols
            
            local x = col * cellWidth + 2
            local y = gridStartY + row * cellHeight + math.floor(cellHeight / 2) - 1
            
            gpu.setForeground(0x3366CC)
            gpu.set(x + math.floor(cellWidth / 2) - 1, y, "📱")
            gpu.setForeground(0x000000)
            gpu.set(x + math.floor(cellWidth / 2) - math.floor(#loc.apps[appIndex] / 2), y + 1, loc.apps[appIndex])
        end
    end
    
    -- Update total pages
    state.totalPages = math.ceil(#loc.apps / appsPerPage)
end

local function drawCurrentApp()
    if not state.currentApp then
        return
    end
    
    local appY = config.statusBarHeight + 1
    local appHeight = sh - config.statusBarHeight - config.dockHeight - 1
    
    gpu.setBackground(0xFFFFFF)
    gpu.fill(1, appY, sw, appHeight, " ")
    
    -- Draw app header
    gpu.setBackground(0xF0F0F0)
    gpu.fill(1, appY, sw, 1, " ")
    gpu.setForeground(0x000000)
    gpu.set(2, appY, state.currentApp)
    
    -- Draw app content placeholder
    gpu.setForeground(0x666666)
    gpu.set(centrize("应用：" .. state.currentApp, sw), appY + math.floor(appHeight / 2), "应用：" .. state.currentApp)
    
    -- Draw close button
    gpu.setForeground(0xFF0000)
    gpu.set(sw - 1, appY, "✕")
end

-- Main render function
local function render()
    updateSystemInfo()
    state.tabletMode = isTabletMode()
    
    -- Clear screen
    gpu.setBackground(0xE1E1E1)
    gpu.fill(1, 1, sw, sh, " ")
    
    -- Draw components
    drawStatusBar(state.animationProgress)
    drawRunningAppsPanel()
    
    if state.tabletMode then
        if not state.currentApp then
            drawAppGrid(state.animationProgress)
        else
            drawCurrentApp()
        end
        drawDock(state.animationProgress)
    end
end

-- App management
local function launchApp(appName)
    -- Check if app is already running
    local isRunning = false
    for i, app in ipairs(state.runningApps) do
        if app == appName then
            isRunning = true
            break
        end
    end
    
    if not isRunning then
        -- Add to running apps if not exceeding limit
        if #state.runningApps < config.maxRunningApps then
            table.insert(state.runningApps, appName)
        else
            -- Replace the oldest running app if limit reached
            table.remove(state.runningApps, 1)
            table.insert(state.runningApps, appName)
        end
    end
    
    state.currentApp = appName
end

local function closeApp(appName)
    for i, app in ipairs(state.runningApps) do
        if app == appName then
            table.remove(state.runningApps, i)
            if state.currentApp == appName then
                -- Switch to the last running app or nil
                state.currentApp = #state.runningApps > 0 and state.runningApps[#state.runningApps] or nil
            end
            break
        end
    end
end

-- Navigation functions
local function nextPage()
    if state.appGridPage < state.totalPages then
        state.appGridPage = state.appGridPage + 1
    end
end

local function prevPage()
    if state.appGridPage > 1 then
        state.appGridPage = state.appGridPage - 1
    end
end

-- Event handling
local function handleTouch(x, y)
    -- Status bar touch
    if y == 1 then
        if x <= 10 then
            -- Menu button - show app grid
            state.currentApp = nil
        elseif x == 1 then
            -- Previous page arrow
            if state.currentApp == nil then
                prevPage()
            end
        elseif x == sw then
            -- Next page arrow
            if state.currentApp == nil then
                nextPage()
            end
        end
        return true
    end
    
    -- Close button in current app
    if state.currentApp and y == config.statusBarHeight + 1 and x == sw - 1 then
        closeApp(state.currentApp)
        return true
    end
    
    -- Dock touch (tablet mode only)
    if state.tabletMode and y >= sh - config.dockHeight + 1 then
        local dockSlot = math.floor((x / sw) * config.dockApps) + 1
        local appName = state.dockConfig[dockSlot] or state.dockApps[dockSlot]
        if appName then
            launchApp(appName)
        end
        return true
    end
    
    -- App grid touch (tablet mode)
    if state.tabletMode and not state.currentApp then
        local gridStartY = 2
        local gridEndY = sh - config.dockHeight - 1
        local gridHeight = gridEndY - gridStartY + 1
        local rows = 3
        local cols = 3
        local cellWidth = math.floor(sw / cols)
        local cellHeight = math.floor(gridHeight / rows)
        
        local row = math.floor((y - gridStartY) / cellHeight)
        local col = math.floor(x / cellWidth)
        
        if row >= 0 and row < rows and col >= 0 and col < cols then
            local appsPerPage = rows * cols  -- 9 apps per page
            local appIndex = (state.appGridPage - 1) * appsPerPage + row * cols + col + 1
            if appIndex <= #loc.apps then
                launchApp(loc.apps[appIndex])
            end
        end
        return true
    end
    
    return false
end

-- Main loop
local function main()
    while true do
        render()
        
        local event = {computer.pullSignal()}
        if event[1] == "touch" then
            handleTouch(event[3], event[4])
        end
        
        os.sleep(0.05)
    end
end

-- Start
main()